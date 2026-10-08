import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../config/app_theme.dart';
import '../models/track_model.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_provider.dart';
import '../services/event_service.dart';
import '../services/audius_service.dart';
import 'manage_delegations_screen.dart';
import 'invite_friends_screen.dart';
import 'event_settings_screen.dart';
import '../widgets/audio_player_overlay.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventService _eventService = EventService();
  final AudiusService _audiusService = AudiusService();

  StompClient? _stompClient;
  bool _isLoading = true;
  bool _isWsConnected = false;
  bool _isEventPlaying = false;
  late AudioProvider _audioProvider;

  Map<String, dynamic>? _eventDetails;
  String _userRole = 'none'; // 'editor' | 'viewer' | 'none'
  bool _allowed = false;
  bool _isLocked = false;
  String _visibility = 'public';
  List<Map<String, dynamic>> _tracks = [];
  List<Map<String, dynamic>> _collaborators = [];
  bool _loadingCollaborators = false;
  StateSetter? _sheetState;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioProvider = Provider.of<AudioProvider>(context, listen: false);
    _audioProvider.onSyncPlayback = _syncLivePlayback;
    _audioProvider.onTrackCompleted = _onLocalTrackCompleted;
  }

  @override
  void initState() {
    super.initState();
    _loadEventData();
  }

  Future<void> _loadEventData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.currentUser?.accessToken;

      if (token == null) {
        throw Exception('User is not authenticated');
      }

      // 1. Fetch user role and permission
      final roleData = await _eventService.getEventUserRole(
        widget.eventId,
        token,
      );
      setState(() {
        _userRole = roleData['role'] ?? 'none';
        _allowed = roleData['allowed'] ?? false;
        _visibility = roleData['visibility'] ?? 'public';
        _isLocked = roleData['locked'] ?? false;
      });

      if (!_allowed) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch event details & playlist
      final details = await _eventService.getEventById(widget.eventId, token);
      final playlist = await _eventService.getEventPlaylist(
        widget.eventId,
        token,
      );

      bool isPlaying = false;
      int seekToMs = 0;
      try {
        final playbackStatus = await _eventService.getPlaybackStatus(
          widget.eventId,
          token,
        );
        isPlaying = playbackStatus['isPlaying'] ?? false;
        seekToMs = playbackStatus['positionMs'] as int? ?? 0;
      } catch (e) {
        debugPrint('Error fetching playback status: $e');
      }

      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      final isLocallyPlayingLive =
          audioProvider.isPlaying && audioProvider.isLiveEvent;

      setState(() {
        _eventDetails = details;
        _tracks = playlist;
        _isEventPlaying = isPlaying || _isEventPlaying || isLocallyPlayingLive;
        _isLoading = false;
      });

      _loadCollaborators();

      if (isPlaying && playlist.isNotEmpty) {
        final firstTrack = Track.fromPlaylistTrackJson(playlist[0]);
        final audioProvider = Provider.of<AudioProvider>(
          context,
          listen: false,
        );
        if (audioProvider.currentTrack?.id != firstTrack.id ||
            !audioProvider.isPlaying) {
          audioProvider.playTrack(
            firstTrack,
            isLiveEvent: true,
            seekToMs: seekToMs,
          );
        }
      }

      // 3. Connect to STOMP WebSocket
      if (_stompClient == null || !_isWsConnected) {
        _connectWebSocket(token);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load event: $e')));
    }
  }

  Future<void> _syncLivePlayback() async {
    final token = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.accessToken;
    if (token == null) return;
    try {
      final playbackStatus = await _eventService.getPlaybackStatus(
        widget.eventId,
        token,
      );
      final isPlaying = playbackStatus['isPlaying'] ?? false;
      final seekToMs = playbackStatus['positionMs'] as int? ?? 0;

      if (isPlaying && _tracks.isNotEmpty) {
        final firstTrack = Track.fromPlaylistTrackJson(_tracks[0]);
        final audioProvider = Provider.of<AudioProvider>(
          context,
          listen: false,
        );

        // Force play/seek to sync
        await audioProvider.playTrack(
          firstTrack,
          isLiveEvent: true,
          seekToMs: seekToMs,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 2),
              backgroundColor: AppTheme.accent,
              content: Text(
                'Synchronized with live room playback!',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.onAccent),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 2),
              backgroundColor: Colors.amber,
              content: Text(
                'No active live room playback found.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error synchronizing live playback: $e');
    }
  }

  void _onLocalTrackCompleted() {
    debugPrint('--- event_detail_screen: _onLocalTrackCompleted triggered');
    if (!mounted) return;

    // During live events, do NOT send NEXT_TRACK to the server.
    // The server's scheduled timer already handles auto-advance based on track duration.
    // Sending NEXT_TRACK from the client would race with the server timer,
    // causing double-deletes (removing more than just the finished track).
    if (_isEventPlaying) {
      debugPrint(
        '--- event_detail_screen: live event active — waiting for server auto-advance (no client NEXT_TRACK)',
      );
      return;
    }
  }

  Future<void> _loadCollaborators() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.currentUser?.accessToken;
      if (token == null) return;

      if (_collaborators.isEmpty) {
        setState(() {
          _loadingCollaborators = true;
        });
      }

      final list = await _eventService.getEventCollaborators(widget.eventId, token);

      if (!mounted) return;
      setState(() {
        _collaborators = list;
        _loadingCollaborators = false;
      });

      if (_sheetState != null) {
        _sheetState!(() {});
      }
    } catch (e) {
      debugPrint('Error loading collaborators: $e');
      if (mounted) {
        setState(() {
          _loadingCollaborators = false;
        });
      }
    }
  }

  Future<void> _refreshRoleAndAccess() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.currentUser?.accessToken;
      if (token == null) return;

      final roleData = await _eventService.getEventUserRole(
        widget.eventId,
        token,
      );
      final newRole = roleData['role'] ?? 'none';
      final newAllowed = roleData['allowed'] ?? false;
      final newVisibility = roleData['visibility'] ?? 'public';

      if (!mounted) return;

      if (!newAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You no longer have access to this event.'),
          ),
        );
        Navigator.pop(context);
        return;
      }

      final details = await _eventService.getEventById(widget.eventId, token);

      setState(() {
        _userRole = newRole;
        _allowed = newAllowed;
        _visibility = newVisibility;
        _eventDetails = details;
      });

      _loadCollaborators();
    } catch (e) {
      debugPrint('Error refreshing role and access: $e');
    }
  }

  void _connectWebSocket(String token) {
    final wsUrl = _eventService.baseUrl.replaceFirst('http', 'ws') + '/ws';
    debugPrint('Connecting to Event WebSocket: $wsUrl');

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (StompFrame frame) {
          debugPrint('STOMP connected for Event ${widget.eventId}');
          if (!mounted) return;
          setState(() {
            _isWsConnected = true;
          });

          // Subscribe to topic
          _stompClient?.subscribe(
            destination: '/topic/event/${widget.eventId}/playlist',
            callback: (frame) {
              if (frame.body != null && mounted) {
                try {
                  final data = jsonDecode(frame.body!);
                  final List<dynamic> updatedPlaylist = data['playlist'] ?? [];
                  setState(() {
                    _tracks = updatedPlaylist.cast<Map<String, dynamic>>();
                  });
                } catch (e) {
                  debugPrint('Error parsing STOMP frame body: $e');
                }
              }
            },
          );

          // Subscribe to listeners count topic
          _stompClient?.subscribe(
            destination: '/topic/event/${widget.eventId}/listeners',
            callback: (frame) {
              if (frame.body != null && mounted) {
                try {
                  final data = jsonDecode(frame.body!);
                  final int count = data['count'] ?? 1;
                  setState(() {
                    if (_eventDetails != null) {
                      _eventDetails!['participantCount'] = count;
                    }
                  });
                  _loadCollaborators();
                } catch (e) {
                  debugPrint('Error parsing listeners count: $e');
                }
              }
            },
          );

          // Subscribe to general updates topic (visibility, role changes)
          _stompClient?.subscribe(
            destination: '/topic/event/${widget.eventId}/updates',
            callback: (frame) {
              if (frame.body != null && mounted) {
                try {
                  final data = jsonDecode(frame.body!);
                  final String type = data['type'] ?? '';
                  if (type == 'VISIBILITY_CHANGE' ||
                      type == 'ROLE_CHANGE' ||
                      type == 'EVENT_UPDATED') {
                    _refreshRoleAndAccess();
                    _loadCollaborators();
                  } else if (type == 'EVENT_STARTED') {
                    setState(() {
                      _isEventPlaying = true;
                    });
                  }
                } catch (e) {
                  debugPrint('Error parsing event updates: $e');
                }
              }
            },
          );

          // Subscribe to playback synchronization topic
          _stompClient?.subscribe(
            destination: '/topic/event/${widget.eventId}/playback',
            callback: (frame) {
              if (frame.body != null && mounted) {
                try {
                  final data = jsonDecode(frame.body!);
                  final String command = data['command'] ?? 'PLAY_TRACK';
                  final String trackId = data['trackId']?.toString() ?? '';
                  final String title = data['title'] ?? '';
                  final String artistName = data['artist'] ?? '';
                  final String imageUrl = data['coverUrl'] ?? '';
                  final String audioUrl = data['audioUrl'] ?? '';

                  if (command == 'QUEUE_EMPTY') {
                    setState(() {
                      _isEventPlaying = false;
                    });
                    final audioProvider = Provider.of<AudioProvider>(
                      context,
                      listen: false,
                    );
                    audioProvider.stop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.amber,
                        content: Text(
                          'Queue is empty. Playback stopped.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _isEventPlaying = true;
                  });

                  final audioProvider = Provider.of<AudioProvider>(
                    context,
                    listen: false,
                  );

                  // Prevent looping/stuttering if already playing/loading this track as a live event
                  if (audioProvider.currentTrack?.id == trackId &&
                      audioProvider.isPlaying &&
                      audioProvider.isLiveEvent) {
                    return;
                  }

                  final int seekToMs = data['positionMs'] as int? ?? 0;

                  final receivedTrack = Track(
                    id: trackId,
                    title: title,
                    artistName: artistName,
                    imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                    audioUrl: audioUrl.isNotEmpty ? audioUrl : null,
                  );

                  audioProvider.playTrack(
                    receivedTrack,
                    isLiveEvent: true,
                    seekToMs: seekToMs,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      backgroundColor: AppTheme.accent,
                      content: Text(
                        'Live Track: "$title" by $artistName',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onAccent),
                      ),
                    ),
                  );
                } catch (e) {
                  debugPrint('Error parsing playback event: $e');
                }
              }
            },
          );
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onDisconnect: (frame) {
          debugPrint('STOMP disconnected');
          if (mounted) {
            setState(() {
              _isWsConnected = false;
            });
          }
        },
        onStompError: (frame) {
          debugPrint('STOMP error: ${frame.body}');
        },
        onWebSocketError: (error) {
          debugPrint('WebSocket error: $error');
          if (mounted) {
            setState(() {
              _isWsConnected = false;
            });
          }
        },
      ),
    );

    _stompClient?.activate();
  }

  void _sendVote(String entryId, int value) {
    if (_stompClient == null || !_isWsConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected. Reconnecting...')),
      );
      // Attempt manual reload in the meantime
      _refreshPlaylist();
      return;
    }

    final token = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.accessToken;

    final payload = {'entryId': entryId, 'value': value};

    _stompClient?.send(
      destination: '/app/event/${widget.eventId}/vote',
      body: jsonEncode(payload),
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    );
  }

  Future<void> _refreshPlaylist() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.currentUser?.accessToken;
      if (token == null) return;

      final playlist = await _eventService.getEventPlaylist(
        widget.eventId,
        token,
      );
      if (mounted) {
        setState(() {
          _tracks = playlist;
        });
      }
    } catch (e) {
      debugPrint('Failed to refresh playlist: $e');
    }
  }

  Future<void> _removeTrack(String entryId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.currentUser?.accessToken;
      if (token == null) return;
      await _eventService.removeTrack(widget.eventId, entryId, token);
      // Stop local playback if we removed the currently playing track,
      // otherwise just_audio keeps the failed source loaded.
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      await audioProvider.stop();
      await _refreshPlaylist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed unplayable track from the queue.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to remove track: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove track: $e')));
      }
    }
  }

  @override
  void dispose() {
    _stompClient?.deactivate();
    try {
      _audioProvider.onSyncPlayback = null;
      _audioProvider.onTrackCompleted = null;
      // Do NOT stop audio here — allow background listening while navigating.
      // The user can come back to the event and rejoin seamlessly.
    } catch (e) {
      debugPrint('Error cleaning up on dispose: $e');
    }
    super.dispose();
  }

  void _showListenersSheet() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;
    if (token == null) return;

    _loadCollaborators();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            _sheetState = setSheetState;
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Listeners in the room',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _loadingCollaborators && _collaborators.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.accent),
                          )
                        : _collaborators.isEmpty
                            ? const Center(
                                child: Text(
                                  'No listeners yet.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _collaborators.length,
                                itemBuilder: (context, index) {
                                  final listener = _collaborators[index];
                                  final name = listener['displayName'] ?? 'Unknown';
                                  final role = listener['permission'] ?? 'viewer';
                                  final avatarUrl = listener['avatarUrl'] ?? '';

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.grey[800],
                                      backgroundImage: avatarUrl.isNotEmpty
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: avatarUrl.isEmpty
                                          ? const Icon(Icons.person, color: Colors.grey)
                                          : null,
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      role.toUpperCase(),
                                      style: TextStyle(
                                        color: role == 'owner'
                                            ? AppTheme.accent
                                            : (role == 'editor'
                                                ? Colors.blueAccent
                                                : Colors.grey[400]),
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
    }).whenComplete(() {
      _sheetState = null;
    });
  }

  void _showAddTrackSheet() {
    if (_userRole == 'viewer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Viewers are not allowed to suggest tracks. You can only listen and vote.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }
    if (_tracks.length >= 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Queue is full (15/15)! Upvote existing tracks to hear them next.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventAddTrackModal(
        eventId: widget.eventId,
        eventService: _eventService,
        audiusService: _audiusService,
        currentQueueLength: _tracks.length,
        onTrackAdded: () {
          _refreshPlaylist();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (!_allowed) {
      return _buildPrivateRoomAccessDenied();
    }

    final String eventName = _eventDetails?['name'] ?? widget.eventName;
    final String description =
        _eventDetails?['description'] ?? 'No description provided';
    final String ownerName = _eventDetails?['ownerName'] ?? 'Host';
    final String coverUrl = _eventDetails?['coverUrl'] ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Background Cover Art and Gradient ────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F2027),
                    Color(0xFF203A43),
                    Color(0xFF2C5364),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          if (coverUrl.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 250,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            ),

          // ── Content ──────────────────────────────────────────────────────────
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── App Bar ───────────────────────────────────────────────────
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      _audioProvider.stop();
                      Navigator.pop(context);
                    },
                  ),
                  actions: [
                    if (_userRole == 'owner')
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventSettingsScreen(
                                eventId: widget.eventId,
                                eventName: eventName,
                                description: description,
                                visibility: _visibility,
                              ),
                            ),
                          ).then((_) {
                            // Refresh event data silently when returning from settings
                            _loadEventData(silent: true);
                          });
                        },
                      ),
                    // Connection Status Badge
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isWsConnected
                                ? AppTheme.accent.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isWsConnected
                                  ? AppTheme.accent
                                  : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isWsConnected
                                      ? AppTheme.accent
                                      : Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isWsConnected ? 'LIVE' : 'CONNECTING',
                                style: TextStyle(
                                  color: _isWsConnected
                                      ? AppTheme.accent
                                      : Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Header Details ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        // Badges: Public/Private & Role
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _visibility == 'public'
                                    ? Colors.cyan.withOpacity(0.2)
                                    : Colors.redAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _visibility.toUpperCase(),
                                style: TextStyle(
                                  color: _visibility == 'public'
                                      ? Colors.cyanAccent
                                      : Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (_userRole == 'editor' ||
                                        _userRole == 'owner')
                                    ? AppTheme.accent.withOpacity(0.2)
                                    : AppTheme.accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _userRole.toUpperCase(),
                                style: TextStyle(
                                  color:
                                      (_userRole == 'editor' ||
                                          _userRole == 'owner')
                                      ? AppTheme.accent
                                      : AppTheme.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          eventName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hosted by $ownerName',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showListenersSheet,
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: Colors.grey[400],
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_eventDetails?['participantCount'] ?? 1} listeners in the room',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Add Music Suggest Button and Start Event Button
                        Consumer<AudioProvider>(
                          builder: (context, audioProvider, child) {
                            final hasTracks = _tracks.isNotEmpty;
                            final showStartButton =
                                _userRole == 'owner' && !_isEventPlaying;
                            final showSuggestButton = _userRole != 'viewer';

                            // If no buttons are visible for this role/state, don't show the row
                            if (!showStartButton && !showSuggestButton) {
                              return const SizedBox.shrink();
                            }

                            return Row(
                              children: [
                                if (showStartButton) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        elevation: 4,
                                      ),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                        size: 22,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'Start Event',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      onPressed: !hasTracks
                                          ? null
                                          : () {
                                              if (_stompClient != null &&
                                                  _isWsConnected) {
                                                final token =
                                                    Provider.of<AuthProvider>(
                                                      context,
                                                      listen: false,
                                                    ).currentUser?.accessToken;
                                                final payload = {
                                                  'command': 'START_EVENT',
                                                };
                                                _stompClient?.send(
                                                  destination:
                                                      '/app/event/${widget.eventId}/playback',
                                                  body: jsonEncode(payload),
                                                  headers: token != null
                                                      ? {
                                                          'Authorization':
                                                              'Bearer $token',
                                                        }
                                                      : null,
                                                );
                                              }
                                            },
                                    ),
                                  ),
                                  if (showSuggestButton)
                                    const SizedBox(width: 12),
                                ],
                                if (showSuggestButton) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accent,
                                        foregroundColor: AppTheme.onAccent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        elevation: 4,
                                      ),
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 22,
                                      ),
                                      label: const Text(
                                        'Suggest Music',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      onPressed: _showAddTrackSheet,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Live Queue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _tracks.length >= 15
                                    ? Colors.redAccent.withOpacity(0.2)
                                    : AppTheme.accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _tracks.length >= 15
                                      ? Colors.redAccent
                                      : AppTheme.accent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${_tracks.length}/15',
                                style: TextStyle(
                                  color: _tracks.length >= 15
                                      ? Colors.redAccent
                                      : AppTheme.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Consumer<AudioProvider>(
                          builder: (context, ap, _) {
                            if (ap.playbackError == null) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      ap.playbackError!,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Tracks List ───────────────────────────────────────────────
                if (_tracks.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            color: Colors.grey,
                            size: 48,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Queue is empty.',
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Suggest the first track to get the party started!',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final entry = _tracks[index];
                        final String entryId = entry['id']?.toString() ?? '';
                        final String title = entry['title'] ?? 'Unknown Title';
                        final String artist =
                            entry['artist'] ?? 'Unknown Artist';
                        final String coverUrl = entry['coverUrl'] ?? '';
                        final int voteCount = entry['voteCount'] ?? 0;
                        final String suggestedByName =
                            entry['suggestedByName'] ?? '';

                        final votedList =
                            entry['votedUsers'] as List<dynamic>? ?? [];
                        final currentUserId = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).currentUser?.id;
                        int userVoteVal = 0;
                        for (var voteObj in votedList) {
                          if (voteObj is Map &&
                              voteObj['userId']?.toString() == currentUserId) {
                            userVoteVal = voteObj['value'] as int? ?? 0;
                          }
                        }
                        final bool hasUpvoted = userVoteVal == 1;
                        final bool hasDownvoted = userVoteVal == -1;

                        final upvoters = votedList
                            .where((v) => v is Map && v['value'] == 1)
                            .map(
                              (v) =>
                                  (v as Map)['displayName']?.toString() ??
                                  'User',
                            )
                            .toList();
                        final downvoters = votedList
                            .where((v) => v is Map && v['value'] == -1)
                            .map(
                              (v) =>
                                  (v as Map)['displayName']?.toString() ??
                                  'User',
                            )
                            .toList();

                        final track = Track.fromPlaylistTrackJson(entry);

                        return Consumer<AudioProvider>(
                          builder: (context, audioProvider, child) {
                            final isCurrent =
                                audioProvider.currentTrack?.id == track.id;
                            final isPlaying =
                                isCurrent && audioProvider.isPlaying;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Rank Number or Active playing volume icon
                                  Container(
                                    width: 24,
                                    alignment: Alignment.center,
                                    child: isPlaying
                                        ? const Icon(
                                            Icons.volume_up_rounded,
                                            color: AppTheme.accent,
                                            size: 18,
                                          )
                                        : Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: index == 0
                                                  ? AppTheme.accent
                                                  : Colors.white70,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Album Art
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: coverUrl.isNotEmpty
                                        ? Image.network(
                                            coverUrl,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      color: Colors.grey[900],
                                                      width: 50,
                                                      height: 50,
                                                      child: const Icon(
                                                        Icons.music_note,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                          )
                                        : Container(
                                            color: Colors.grey[900],
                                            width: 50,
                                            height: 50,
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.grey,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Title and Artist
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            color: isPlaying
                                                ? AppTheme.accent
                                                : Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          artist,
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isCurrent) ...[
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                            child: LinearProgressIndicator(
                                              value:
                                                  audioProvider
                                                          .duration
                                                          .inMilliseconds >
                                                      0
                                                  ? audioProvider
                                                            .position
                                                            .inMilliseconds /
                                                        audioProvider
                                                            .duration
                                                            .inMilliseconds
                                                  : 0.0,
                                              backgroundColor: Colors.white10,
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                    Color
                                                  >(AppTheme.accent),
                                              minHeight: 4,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _formatDuration(
                                                  audioProvider.position,
                                                ),
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 10,
                                                ),
                                              ),
                                              Text(
                                                _formatDuration(
                                                  audioProvider.duration,
                                                ),
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (suggestedByName.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Suggested by $suggestedByName',
                                            style: const TextStyle(
                                              color: AppTheme.accent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        if (index > 0 &&
                                            (upvoters.isNotEmpty ||
                                                downvoters.isNotEmpty)) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Votes: ${upvoters.isNotEmpty ? '▲ ${upvoters.join(', ')}' : ''}${upvoters.isNotEmpty && downvoters.isNotEmpty ? '  ' : ''}${downvoters.isNotEmpty ? '▼ ${downvoters.join(', ')}' : ''}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                0.5,
                                              ),
                                              fontSize: 10,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Voting Widget (Only visible from position 2 and above, i.e., index > 0)
                                  // Owners/editors can remove the now-playing track (index 0),
                                  // which is the recovery path when a restricted/unstreamable
                                  // Audius track got queued before the gated-track filter.
                                  if (index == 0 &&
                                      (_userRole == 'owner' ||
                                          _userRole == 'editor'))
                                    Consumer<AudioProvider>(
                                      builder: (context, ap, _) {
                                        if (ap.playbackError == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return IconButton(
                                          tooltip: 'Remove unplayable track',
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () =>
                                              _removeTrack(entryId),
                                        );
                                      },
                                    ),
                                  if (index > 0)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Downvote
                                        IconButton(
                                          icon: Icon(
                                            Icons.arrow_downward_rounded,
                                            size: 20,
                                            color: hasDownvoted
                                                ? Colors.redAccent
                                                : Colors.grey,
                                          ),
                                          onPressed: () =>
                                              _sendVote(entryId, -1),
                                        ),

                                        // Vote Count Bold pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: voteCount > 0
                                                ? AppTheme.accent.withOpacity(0.2)
                                                : (voteCount < 0
                                                      ? Colors.red.withOpacity(
                                                          0.2,
                                                        )
                                                      : Colors.white
                                                            .withOpacity(0.1)),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            voteCount > 0
                                                ? '+$voteCount'
                                                : '$voteCount',
                                            style: TextStyle(
                                              color: voteCount > 0
                                                  ? AppTheme.accent
                                                  : (voteCount < 0
                                                        ? Colors.redAccent
                                                        : Colors.white70),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),

                                        // Upvote
                                        IconButton(
                                          icon: Icon(
                                            Icons.arrow_upward_rounded,
                                            size: 20,
                                            color: hasUpvoted
                                                ? AppTheme.accent
                                                : Colors.white70,
                                          ),
                                          onPressed: () =>
                                              _sendVote(entryId, 1),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      }, childCount: _tracks.length),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateRoomAccessDenied() {
    final title = _isLocked
        ? 'Event Room is Locked'
        : 'Private Room Access Denied';
    final subtitle = _isLocked
        ? 'This live music session has already started and is locked for new participants. Tap below to find other active rooms!'
        : 'This room is private. You must be invited by the owner in order to join the groove.';
    final iconData = _isLocked ? Icons.lock_clock_rounded : Icons.lock_rounded;
    final iconColor = _isLocked ? Colors.amberAccent : Colors.redAccent;
    final gradientColors = _isLocked
        ? [const Color(0xFF0F2027), const Color(0xFF203A43)]
        : [const Color(0xFF1F1C2C), const Color(0xFF928DAB)];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor, width: 2),
                  ),
                  child: Icon(iconData, color: iconColor, size: 80),
                ),
                const SizedBox(height: 32),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search & Suggest Tracks Modal ───────────────────────────────────────────
class _EventAddTrackModal extends StatefulWidget {
  final String eventId;
  final EventService eventService;
  final AudiusService audiusService;
  final VoidCallback onTrackAdded;
  final int currentQueueLength;

  const _EventAddTrackModal({
    required this.eventId,
    required this.eventService,
    required this.audiusService,
    required this.onTrackAdded,
    required this.currentQueueLength,
  });

  @override
  State<_EventAddTrackModal> createState() => _EventAddTrackModalState();
}

class _EventAddTrackModalState extends State<_EventAddTrackModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _searchResults = [];
  List<Track> _randomTracks = [];
  bool _isLoading = false;
  bool _isLoadingRandom = false;
  bool _isSuggesting = false;

  @override
  void initState() {
    super.initState();
    _loadRandomTracks();
  }

  void _loadRandomTracks() async {
    setState(() {
      _isLoadingRandom = true;
    });
    try {
      final tracks = await widget.audiusService.getRandomTracks();
      if (mounted) {
        setState(() {
          _randomTracks = tracks;
          _isLoadingRandom = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRandom = false;
        });
      }
    }
  }

  void _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await widget.audiusService.searchTracks(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to search tracks: $e')));
      }
    }
  }

  Future<void> _suggestTrack(Track track) async {
    if (widget.currentQueueLength >= 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Queue is full (15/15)! Upvote existing tracks to hear them next.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSuggesting = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.currentUser?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      if (!track.isStreamable || track.isStreamGated) {
        if (mounted) {
          setState(() {
            _isSuggesting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                'This track is restricted on Audius and cannot be played. Please pick another one.',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
        return;
      }

      final streamable =
          await widget.audiusService.verifyTrackStreamable(track);
      if (!streamable) {
        if (mounted) {
          setState(() {
            _isSuggesting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                'This track is not streamable on Audius (403). Please pick another one.',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
        return;
      }

      await widget.eventService.suggestTrack(widget.eventId, track, token);

      if (mounted) {
        widget.onTrackAdded();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accent,
            content: Text(
              'Successfully suggested "${track.title}"!',
              style: const TextStyle(
                color: AppTheme.onAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSuggesting = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to suggest track: $e')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Suggest a Track',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Search Input
            TextField(
              controller: _searchController,
              onSubmitted: _performSearch,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Search Audius tracks...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Search Results or Loading
            Expanded(
              child: _searchController.text.trim().isEmpty
                  ? (_isLoadingRandom
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: AppTheme.accent),
                                SizedBox(height: 12),
                                Text(
                                  'Loading trending suggestions...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _randomTracks.isEmpty
                        ? const Center(
                            child: Text(
                              'Type something to search',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.local_fire_department,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Trending Suggestions',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(child: _buildTrackList(_randomTracks)),
                            ],
                          ))
                  : _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    )
                  : (_searchResults.isEmpty
                        ? const Center(
                            child: Text(
                              'No results found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : _buildTrackList(_searchResults)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackList(List<Track> tracks) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: track.imageUrl != null && track.imageUrl!.isNotEmpty
                ? Image.network(
                    track.imageUrl!,
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey[900],
                    width: 45,
                    height: 45,
                    child: const Icon(Icons.music_note, color: Colors.grey),
                  ),
          ),
          title: Text(
            track.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track.artistName,
            style: TextStyle(color: Colors.grey[400]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _isSuggesting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accent,
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.accent,
                  ),
                  onPressed: () => _suggestTrack(track),
                ),
        );
      },
    );
  }
}
