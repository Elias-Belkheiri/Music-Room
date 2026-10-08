import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../models/playlist_model.dart';
import '../../models/track_model.dart';
import '../../services/audius_service.dart';
import '../../services/playlist_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/audio_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/audio_player_overlay.dart';
import 'package:musicroom/screens/user_public_profile_screen.dart';
import 'invite_playlist_friends_screen.dart';
import '../../services/user_service.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final Playlist? initialPlaylist;
  final bool useBackend;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    this.initialPlaylist,
    this.useBackend = false,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Playlist? _playlist;
  List<Track> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _didRetryAfterOpen = false;
  bool _isSaved = false;
  String? _ownerAvatarUrl;
  List<dynamic> _collaborators = [];

  StompClient? _stompClient;
  bool _isWsConnected = false;

  @override
  void initState() {
    super.initState();
    _fetchPlaylist();
  }

  void _connectWebSocket(String token) {
    if (_stompClient != null && _isWsConnected) return;

    final playlistService = PlaylistService();
    final wsUrl =
        playlistService.effectiveBaseUrl.replaceFirst('http', 'ws') + '/ws';
    debugPrint('Connecting to Playlist WebSocket: $wsUrl');

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (StompFrame frame) {
          debugPrint('STOMP connected for Playlist ${widget.playlistId}');
          if (!mounted) return;
          setState(() {
            _isWsConnected = true;
          });

          // Subscribe to playlist updates topic
          _stompClient?.subscribe(
            destination: '/topic/playlist/${widget.playlistId}',
            callback: (frame) {
              if (frame.body != null && mounted) {
                debugPrint('Received playlist update: ${frame.body}');
                _refreshPlaylistQuietly();
              }
            },
          );
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onDisconnect: (frame) {
          debugPrint('Playlist STOMP disconnected');
          if (mounted) {
            setState(() {
              _isWsConnected = false;
            });
          }
        },
        onStompError: (frame) {
          debugPrint('Playlist STOMP error: ${frame.body}');
        },
        onWebSocketError: (error) {
          debugPrint('Playlist WebSocket error: $error');
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

  Future<void> _refreshPlaylistQuietly() async {
    try {
      final token = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser?.accessToken;
      if (token == null || token.isEmpty) return;

      final playlistService = PlaylistService();
      final freshPlaylist = await playlistService.getPlaylistById(
        widget.playlistId,
        token,
      );
      final tracks = await playlistService.getPlaylistTracks(
        widget.playlistId,
        token,
      );

      List<dynamic> collaborators = [];
      try {
        collaborators = await playlistService.getPlaylistCollaborators(
          widget.playlistId,
          token,
        );
      } catch (e) {
        debugPrint('Error fetching collaborators: $e');
      }

      if (!mounted) return;
      setState(() {
        _playlist = freshPlaylist;
        _tracks = tracks;
        _collaborators = collaborators;
      });
    } catch (e) {
      debugPrint('Error quietly refreshing playlist: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('denied') ||
          errStr.contains('unauthorized') ||
          errStr.contains('403') ||
          errStr.contains('401')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Your access to this playlist has been revoked.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _fetchPlaylist() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.useBackend) {
        final token = Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser?.accessToken;
        if (token == null || token.isEmpty) {
          throw Exception('Missing auth token');
        }

        final playlistService = PlaylistService();
        final freshPlaylist = await playlistService.getPlaylistById(
          widget.playlistId,
          token,
        );
        var tracks = await playlistService.getPlaylistTracks(
          widget.playlistId,
          token,
        );
        if (tracks.isEmpty && !_didRetryAfterOpen) {
          _didRetryAfterOpen = true;
          await Future.delayed(const Duration(milliseconds: 700));
          tracks = await playlistService.getPlaylistTracks(
            widget.playlistId,
            token,
          );
        }

        bool isSaved = false;
        try {
          isSaved = await playlistService.isPlaylistSaved(
            widget.playlistId,
            token,
          );
        } catch (e) {
          debugPrint('Error fetching status: $e');
        }

        String? ownerAvatarUrl;
        if (freshPlaylist.ownerId.isNotEmpty) {
          try {
            final ownerProfile = await UserService().getUserProfile(
              freshPlaylist.ownerId,
              token,
            );
            ownerAvatarUrl = ownerProfile.avatarUrl;
          } catch (e) {
            debugPrint('Error fetching owner profile: $e');
          }
        }

        List<dynamic> collaborators = [];
        try {
          collaborators = await playlistService.getPlaylistCollaborators(
            widget.playlistId,
            token,
          );
        } catch (e) {
          debugPrint('Error fetching collaborators: $e');
        }

        if (!mounted) return;
        setState(() {
          _playlist = freshPlaylist;
          _tracks = tracks;
          _isSaved = isSaved;
          _ownerAvatarUrl = ownerAvatarUrl;
          _collaborators = collaborators;
          _isLoading = false;
        });

        if (_stompClient == null || !_isWsConnected) {
          _connectWebSocket(token);
        }
        return;
      }

      final audiusService = AudiusService();
      final playlist = await audiusService.getPlaylist(widget.playlistId);
      if (!mounted) return;
      setState(() {
        _playlist = playlist;
        _tracks = [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSave() async {
    final token = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.accessToken;
    if (token == null) return;
    final playlistService = PlaylistService();
    try {
      if (_isSaved) {
        await playlistService.unsavePlaylist(widget.playlistId, token);
      } else {
        await playlistService.savePlaylist(widget.playlistId, token);
      }
      setState(() {
        _isSaved = !_isSaved;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update save status: $e')),
      );
    }
  }

  void _showCollaboratorsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final isOwner = _playlist?.ownerId == auth.currentUser?.id;
        final myId = auth.currentUser?.id;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return _CollaboratorsSheetContent(
              playlist: _playlist,
              collaborators: _collaborators,
              ownerAvatarUrl: _ownerAvatarUrl,
              isOwner: isOwner,
              myId: myId,
              playlistId: widget.playlistId,
              onCollaboratorsChanged: (freshColabs) {
                setState(() {
                  _collaborators = freshColabs;
                });
                setModalState(() {});
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.useBackend && _playlist != null)
            Builder(
              builder: (context) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final isOwner = _playlist!.ownerId == auth.currentUser?.id;
                if (!isOwner) return const SizedBox.shrink();

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.person_add_alt_1,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InvitePlaylistFriendsScreen(
                              playlistId: widget.playlistId,
                            ),
                          ),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: AppTheme.surface,
                      onSelected: (value) async {
                        if (value == 'toggle_visibility') {
                          final newVisibility =
                              _playlist!.visibility == 'private'
                              ? 'public'
                              : 'private';
                          final playlistProvider =
                              Provider.of<PlaylistProvider>(
                                context,
                                listen: false,
                              );
                          try {
                            setState(() {
                              _isLoading = true;
                            });
                            final updated = await playlistProvider
                                .updatePlaylistVisibility(
                                  _playlist!,
                                  newVisibility,
                                  auth.currentUser,
                                );
                            setState(() {
                              _playlist = updated;
                              _isLoading = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Playlist is now $newVisibility!',
                                    style: const TextStyle(
                                      color: AppTheme.onAccent,
                                    ),
                                  ),
                                  backgroundColor: AppTheme.accent,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              _isLoading = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update: $e')),
                              );
                            }
                          }
                        } else if (value == 'delete_playlist') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppTheme.surface,
                              title: const Text(
                                'Delete Playlist',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'Are you sure you want to delete this playlist? This cannot be undone.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            setState(() => _isLoading = true);
                            try {
                              final playlistService = PlaylistService();
                              await playlistService.deletePlaylist(
                                widget.playlistId,
                                auth.currentUser!.accessToken,
                              );

                              if (mounted) {
                                final provider = Provider.of<PlaylistProvider>(
                                  context,
                                  listen: false,
                                );
                                provider.removePlaylistLocal(widget.playlistId);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Playlist deleted successfully',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                Navigator.pop(
                                  context,
                                  true,
                                ); // Pop back to library/home
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() => _isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'toggle_visibility',
                          child: Row(
                            children: [
                              Icon(
                                _playlist!.visibility == 'private'
                                    ? Icons.public_rounded
                                    : Icons.lock_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _playlist!.visibility == 'private'
                                    ? 'Make Public'
                                    : 'Make Private',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        const PopupMenuItem<String>(
                          value: 'delete_playlist',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Delete Playlist',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                )
              : _playlist == null
              ? const Center(
                  child: Text(
                    'Playlist not found',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Playlist Artwork
                      Builder(
                        builder: (context) {
                          final String? displayCoverUrl =
                              (_playlist!.imageUrl != null &&
                                  _playlist!.imageUrl!.isNotEmpty)
                              ? _playlist!.imageUrl
                              : (_tracks.isNotEmpty &&
                                    _tracks.first.imageUrl != null &&
                                    _tracks.first.imageUrl!.isNotEmpty)
                              ? _tracks.first.imageUrl
                              : null;

                          if (displayCoverUrl != null) {
                            return Center(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  displayCoverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, _, __) => Container(
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.grey,
                                      size: 80,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return Center(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[900],
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white24,
                                  size: 80,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      // Playlist Info
                      Padding(
                        padding: const EdgeInsets.only(left: 0, right: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _playlist!.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_playlist!.description != null &&
                                _playlist!.description!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _playlist!.description!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final editors = widget.useBackend
                                    ? _collaborators
                                          .where(
                                            (c) => c['permission'] == 'editor',
                                          )
                                          .toList()
                                    : [];

                                // Avatars stack
                                final List<String?> displayAvatars = [];
                                if (widget.useBackend) {
                                  displayAvatars.add(_ownerAvatarUrl);
                                  for (var ed in editors) {
                                    displayAvatars.add(
                                      ed['avatarUrl'] as String?,
                                    );
                                  }
                                }

                                final int trackCount = _tracks.length;
                                final String trackText = trackCount == 1
                                    ? '1 song'
                                    : '$trackCount songs';

                                // Names list
                                String names = _playlist!.creatorName;
                                if (editors.isNotEmpty) {
                                  if (editors.length == 1) {
                                    names +=
                                        ' & ${editors[0]['displayName'] ?? 'User'}';
                                  } else {
                                    names += ' & ${editors.length} others';
                                  }
                                }

                                return Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: 8,
                                  spacing: 8,
                                  children: [
                                    GestureDetector(
                                      onTap: _showCollaboratorsBottomSheet,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (displayAvatars.isNotEmpty) ...[
                                            SizedBox(
                                              width: displayAvatars.length == 1
                                                  ? 20
                                                  : displayAvatars.length == 2
                                                  ? 30
                                                  : 40,
                                              height: 20,
                                              child: Stack(
                                                children: List.generate(
                                                  displayAvatars.length > 3
                                                      ? 3
                                                      : displayAvatars.length,
                                                  (index) {
                                                    final url =
                                                        displayAvatars[index];
                                                    return Positioned(
                                                      left: index * 10.0,
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                color: AppTheme
                                                                    .background,
                                                                width: 1.5,
                                                              ),
                                                            ),
                                                        child: CircleAvatar(
                                                          radius: 8.5,
                                                          backgroundImage:
                                                              url != null &&
                                                                  url.isNotEmpty &&
                                                                  !url.contains(
                                                                    'photo-1535713875002-d1d0cf377fde',
                                                                  )
                                                              ? NetworkImage(
                                                                  url,
                                                                )
                                                              : null,
                                                          backgroundColor:
                                                              Colors.grey[800],
                                                          child:
                                                              url == null ||
                                                                  url.isEmpty ||
                                                                  url.contains(
                                                                    'photo-1535713875002-d1d0cf377fde',
                                                                  )
                                                              ? const Icon(
                                                                  Icons.person,
                                                                  size: 8,
                                                                  color: Colors
                                                                      .white70,
                                                                )
                                                              : null,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ] else ...[
                                            CircleAvatar(
                                              radius: 10,
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.1),
                                              child: const Icon(
                                                Icons.person,
                                                size: 11,
                                                color: Colors.white70,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(
                                            names,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '• $trackText',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (widget.useBackend)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _playlist!.visibility == 'private'
                                                  ? Icons.lock_outline_rounded
                                                  : Icons.public_rounded,
                                              size: 10,
                                              color: Colors.white60,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              _playlist!.visibility == 'private'
                                                  ? 'Private'
                                                  : 'Public',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.useBackend)
                        Builder(
                          builder: (context) {
                            final currentUser = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            ).currentUser;
                            final isOwner =
                                currentUser?.id == _playlist!.ownerId;
                            if (isOwner) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: OutlinedButton.icon(
                                onPressed: _toggleSave,
                                icon: Icon(
                                  _isSaved
                                      ? Icons.remove_circle_outline
                                      : Icons.add,
                                  color: _isSaved
                                      ? Colors.redAccent
                                      : Colors.white,
                                  size: 18,
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: _isSaved
                                        ? Colors.redAccent
                                        : Colors.white,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                label: Text(
                                  _isSaved
                                      ? 'Remove Playlist'
                                      : 'Save Playlist',
                                  style: TextStyle(
                                    color: _isSaved
                                        ? Colors.redAccent
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      if (widget.useBackend)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Tracks (${_tracks.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      if (widget.useBackend) const SizedBox(height: 10),
                      if (widget.useBackend && _tracks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'No tracks in this playlist yet.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      if (widget.useBackend && _tracks.isNotEmpty)
                        ..._tracks.asMap().entries.map(
                          (entry) => _buildTrackTile(entry.key, entry.value),
                        ),
                      const SizedBox(height: 160),
                    ],
                  ),
                ),
          const AudioPlayerOverlay(),
        ],
      ),
    );
  }

  Widget _buildTrackTile(int index, Track track) {
    final trailingWidget = Builder(
      builder: (context) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final isOwner = _playlist?.ownerId == auth.currentUser?.id;
        final isEditor = _playlist?.permission == 'editor';
        final hasEditPermission = isOwner || isEditor;

        if (widget.useBackend &&
            hasEditPermission &&
            track.playlistTrackId != null) {
          return PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            color: AppTheme.surface,
            onSelected: (value) async {
              if (value == 'remove_track') {
                try {
                  setState(() => _isLoading = true);
                  final playlistProvider = Provider.of<PlaylistProvider>(
                    context,
                    listen: false,
                  );
                  await playlistProvider.removeTrackFromPlaylist(
                    _playlist!,
                    track.playlistTrackId!,
                    auth.currentUser,
                  );

                  setState(() {
                    _tracks.removeAt(index);
                    _isLoading = false;
                  });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Track removed successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to remove track: $e')),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'remove_track',
                child: Row(
                  children: [
                    Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Remove Track',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return const Padding(
          padding: EdgeInsets.all(12.0),
          child: Icon(
            Icons.music_note_rounded,
            color: Colors.white54,
            size: 20,
          ),
        );
      },
    );

    return InkWell(
      onTap: track.audioUrl == null
          ? null
          : () {
              final audioProvider = Provider.of<AudioProvider>(
                context,
                listen: false,
              );
              audioProvider.playTrack(track, playlist: _tracks, index: index);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Rank Number
            SizedBox(
              width: 25,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            // Cover Art
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: track.imageUrl != null && track.imageUrl!.isNotEmpty
                  ? Image.network(
                      track.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[900],
                        width: 44,
                        height: 44,
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[900],
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artistName,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Actions Menu or Status Icon
            trailingWidget,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stompClient?.deactivate();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Collaborators Sheet Content — with search, invite, role management
// ══════════════════════════════════════════════════════════════════════════════
class _CollaboratorsSheetContent extends StatefulWidget {
  final Playlist? playlist;
  final List<dynamic> collaborators;
  final String? ownerAvatarUrl;
  final bool isOwner;
  final String? myId;
  final String playlistId;
  final Function(List<dynamic>) onCollaboratorsChanged;

  const _CollaboratorsSheetContent({
    required this.playlist,
    required this.collaborators,
    required this.ownerAvatarUrl,
    required this.isOwner,
    required this.myId,
    required this.playlistId,
    required this.onCollaboratorsChanged,
  });

  @override
  State<_CollaboratorsSheetContent> createState() =>
      _CollaboratorsSheetContentState();
}

class _CollaboratorsSheetContentState
    extends State<_CollaboratorsSheetContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  final UserService _userService = UserService();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  final Set<String> _invitingIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.currentUser?.accessToken;
    if (token == null) return;

    setState(() => _isSearching = true);
    try {
      final results = await _userService.searchUsers(query.trim(), token);
      // Filter out: self, owner, existing collaborators
      final collabIds = widget.collaborators
          .map((c) => (c as Map<String, dynamic>)['userId'] as String)
          .toSet();
      collabIds.add(widget.playlist?.ownerId ?? '');
      final filtered = results
          .where((u) => u['id'] != widget.myId && !collabIds.contains(u['id']))
          .toList();
      if (mounted)
        setState(() {
          _searchResults = filtered;
          _isSearching = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _inviteUser(String userId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.currentUser?.accessToken;
    if (token == null) return;

    setState(() => _invitingIds.add(userId));
    try {
      final playlistService = PlaylistService();
      await playlistService.inviteUserToPlaylist(
        widget.playlistId,
        userId,
        'editor',
        token,
      );
      final freshColabs = await playlistService.getPlaylistCollaborators(
        widget.playlistId,
        token,
      );
      widget.onCollaboratorsChanged(freshColabs);
      setState(() {
        _searchResults.removeWhere((u) => u['id'] == userId);
        _invitingIds.remove(userId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Collaborator added!',
              style: TextStyle(color: AppTheme.onAccent),
            ),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _invitingIds.remove(userId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the collaborator list items (owner + collaborators, excluding self)
    final List<Map<String, dynamic>> listItems = [];
    if (widget.playlist != null) {
      listItems.add({
        'userId': widget.playlist!.ownerId,
        'displayName': widget.playlist!.creatorName,
        'avatarUrl': widget.ownerAvatarUrl ?? '',
        'permission': 'owner',
        'isOwner': true,
      });
    }
    for (var c in widget.collaborators) {
      listItems.add({
        'userId': c['userId'] as String,
        'displayName': c['displayName'] as String? ?? 'User',
        'avatarUrl': c['avatarUrl'] as String? ?? '',
        'permission': c['permission'] as String? ?? 'editor',
        'isOwner': false,
      });
    }

    final showingSearch = _searchCtrl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Collaborators (${listItems.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Search bar (owner only)
            if (widget.isOwner)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    prefixIcon: const Icon(
                      Icons.person_add_alt_1,
                      color: Colors.white38,
                      size: 20,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white38,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {
                                _searchResults = [];
                                _isSearching = false;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    hintText: 'Search & add collaborators...',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

            if (widget.isOwner) const SizedBox(height: 8),

            // Search results area
            if (showingSearch) ...[
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                )
              else if (_searchResults.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ),
                )
              else
                ...List.generate(_searchResults.length, (i) {
                  final user = _searchResults[i];
                  final userId = user['id'] as String;
                  final name = user['displayName'] as String? ?? 'User';
                  final avatar = user['avatarUrl'] as String? ?? '';
                  final isInviting = _invitingIds.contains(userId);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      backgroundImage: avatar.isNotEmpty
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 18,
                            )
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: SizedBox(
                      width: 76,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: isInviting
                            ? null
                            : () => _inviteUser(userId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.onAccent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: isInviting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.onAccent,
                                ),
                              )
                            : const Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  );
                }),

              Divider(
                color: Colors.white.withValues(alpha: 0.08),
                indent: 20,
                endIndent: 20,
              ),
            ],

            // Existing collaborators list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: listItems.length,
                itemBuilder: (context, idx) {
                  final item = listItems[idx];
                  final userId = item['userId'] as String;
                  final displayName = item['displayName'] as String;
                  final avatarUrl = item['avatarUrl'] as String;
                  final permission = item['permission'] as String;
                  final isOwnerRole = item['isOwner'] as bool;
                  final isMe = userId == widget.myId;

                  return ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserPublicProfileScreen(
                            userId: userId,
                            displayName: displayName,
                          ),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          avatarUrl.isNotEmpty &&
                              !avatarUrl.contains(
                                'photo-1535713875002-d1d0cf377fde',
                              )
                          ? NetworkImage(avatarUrl)
                          : null,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      child:
                          avatarUrl.isEmpty ||
                              avatarUrl.contains(
                                'photo-1535713875002-d1d0cf377fde',
                              )
                          ? const Icon(Icons.person, color: Colors.white70)
                          : null,
                    ),
                    title: Text(
                      '$displayName ${isMe ? "(You)" : ""}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      permission.toUpperCase(),
                      style: TextStyle(
                        color: isOwnerRole
                            ? AppTheme.accent
                            : permission == 'editor'
                            ? AppTheme.accent
                            : Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: widget.isOwner && !isMe && !isOwnerRole
                        ? PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white70,
                            ),
                            color: AppTheme.surface,
                            onSelected: (value) async {
                              final auth = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              final token = auth.currentUser?.accessToken;
                              if (token == null) return;
                              final playlistService = PlaylistService();

                              try {
                                if (value == 'make_editor') {
                                  await playlistService.updateCollaboratorRole(
                                    widget.playlistId,
                                    userId,
                                    'editor',
                                    token,
                                  );
                                } else if (value == 'make_viewer') {
                                  await playlistService.updateCollaboratorRole(
                                    widget.playlistId,
                                    userId,
                                    'viewer',
                                    token,
                                  );
                                } else if (value == 'remove') {
                                  await playlistService.removeCollaborator(
                                    widget.playlistId,
                                    userId,
                                    token,
                                  );
                                }
                                final freshColabs = await playlistService
                                    .getPlaylistCollaborators(
                                      widget.playlistId,
                                      token,
                                    );
                                widget.onCollaboratorsChanged(freshColabs);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Updated!',
                                        style: TextStyle(
                                          color: AppTheme.onAccent,
                                        ),
                                      ),
                                      backgroundColor: AppTheme.accent,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              if (permission != 'editor')
                                const PopupMenuItem(
                                  value: 'make_editor',
                                  child: Text(
                                    'Change to Editor',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              if (permission != 'viewer')
                                const PopupMenuItem(
                                  value: 'make_viewer',
                                  child: Text(
                                    'Change to Viewer',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              const PopupMenuDivider(height: 1),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  'Remove',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          )
                        : isOwnerRole
                        ? const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 20,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
