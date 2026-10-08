import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../services/audius_service.dart';
import '../services/user_service.dart';
import '../services/event_service.dart';
import '../models/track_model.dart';
import '../providers/user_profile_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/subscription_provider.dart';
import '../config/app_theme.dart';
import 'create_event_screen.dart';
import 'profile/profile_screen.dart';
import 'playlist_detail_screen.dart';
import 'event_detail_screen.dart';
import 'nearby_events_screen.dart';
import 'search_screen.dart';
import '../providers/audio_provider.dart';
import '../widgets/acid/acid_section_header.dart';
import '../widgets/acid/collection_card.dart';
import '../widgets/acid/discover_banner.dart';
import '../widgets/acid/feature_card.dart';
import '../widgets/acid/search_pill.dart';
import '../widgets/acid/track_row.dart';
import '../widgets/add_to_playlist_modal.dart';

String formatTrackDuration(Track t) {
  final ms = t.durationMs;
  if (ms == null || ms <= 0) return '--:--';
  final totalSec = (ms / 1000).round();
  final m = totalSec ~/ 60;
  final s = (totalSec % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final AudiusService _audiusService = AudiusService();
  final UserService _userService = UserService();
  final EventService _eventService = EventService();
  bool isLoadingTracks = true;
  bool isLoadingEvents = true;
  List<Track> trendingTracks = [];
  List<Track> randomTracks = [];
  List<Map<String, dynamic>> events = [];
  String? trackError;
  String? eventError;

  StompClient? _eventsStompClient;
  bool _isEventsWsConnected = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.currentUser?.accessToken;
      if (token != null) {
        Provider.of<UserProfileProvider>(
          context,
          listen: false,
        ).fetchProfile(token);
        Provider.of<PlaylistProvider>(
          context,
          listen: false,
        ).loadPlaylists(authProvider.currentUser);
        Provider.of<SubscriptionProvider>(
          context,
          listen: false,
        ).fetchStatus(token);
        _fetchEvents(token);
        _connectEventsWebSocket(token);
      } else {
        setState(() => isLoadingEvents = false);
      }
    });
  }

  @override
  void dispose() {
    _eventsStompClient?.deactivate();
    super.dispose();
  }

  Future<void> _fetchData({bool showLoadingSpinner = true}) async {
    await _fetchTracks(showLoadingSpinner: showLoadingSpinner);
  }

  Future<void> _fetchEvents(String token,
      {bool showLoadingSpinner = true}) async {
    try {
      if (showLoadingSpinner) {
        setState(() {
          isLoadingEvents = true;
          eventError = null;
        });
      } else {
        setState(() {
          eventError = null;
        });
      }
      final fetchedEvents = await _userService.getAllEvents(token);
      if (mounted) {
        setState(() {
          events = fetchedEvents;
          isLoadingEvents = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('404')) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.refreshTokens();
        if (success) {
          final newToken = authProvider.currentUser?.accessToken;
          if (newToken != null) {
            try {
              final refetched = await _userService.getAllEvents(newToken);
              if (mounted) {
                setState(() {
                  events = refetched;
                  isLoadingEvents = false;
                });
                _connectEventsWebSocket(newToken);
              }
              return;
            } catch (_) {}
          }
        }
      }
      if (mounted) {
        setState(() {
          eventError = e.toString();
          isLoadingEvents = false;
        });
      }
    }
  }

  void _processEventWebSocketMessage(String body) {
    if (!mounted) return;
    try {
      final data = jsonDecode(body);
      final String type = data['type'] ?? '';
      debugPrint('Received event WS message: $type');

      if (type == 'EVENT_CREATED') {
        if (data['event'] != null) {
          final newEvent = Map<String, dynamic>.from(data['event']);
          setState(() {
            events.removeWhere((e) => e['id'] == newEvent['id']);
            events.add(newEvent);
          });
        }
      } else if (type == 'EVENT_UPDATED') {
        if (data['event'] != null) {
          final updatedEvent = Map<String, dynamic>.from(data['event']);
          setState(() {
            final idx = events.indexWhere((e) => e['id'] == updatedEvent['id']);
            if (idx != -1) {
              events[idx] = updatedEvent;
            } else {
              events.add(updatedEvent);
            }
          });
        }
      } else if (type == 'EVENT_DELETED') {
        final String? deletedEventId = data['eventId'];
        if (deletedEventId != null) {
          setState(() {
            events.removeWhere((e) => e['id'] == deletedEventId);
          });
        }
      } else if (type == 'LISTENER_COUNT_CHANGED') {
        final String? eventId = data['eventId'];
        final int? count = data['count'];
        if (eventId != null && count != null) {
          setState(() {
            final idx = events.indexWhere((e) => e['id'] == eventId);
            if (idx != -1) {
              final copy = Map<String, dynamic>.from(events[idx]);
              copy['participantCount'] = count;
              events[idx] = copy;
            }
          });
        }
      } else if (type == 'EVENT_PLAYBACK_CHANGED') {
        final String? eventId = data['eventId'];
        final bool? isPlaying = data['isPlaying'];
        if (eventId != null && isPlaying != null) {
          setState(() {
            final idx = events.indexWhere((e) => e['id'] == eventId);
            if (idx != -1) {
              final copy = Map<String, dynamic>.from(events[idx]);
              copy['playing'] = isPlaying;
              events[idx] = copy;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error parsing event WS message: $e');
    }
  }

  void _connectEventsWebSocket(String token) {
    if (_eventsStompClient != null && _eventsStompClient!.isActive) {
      _eventsStompClient!.deactivate();
    }

    final wsUrl = _eventService.baseUrl.replaceFirst('http', 'ws') + '/ws';
    debugPrint('Connecting to Global Events WebSocket: $wsUrl');

    _eventsStompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (StompFrame frame) {
          debugPrint('STOMP connected for Global Events');
          if (!mounted) return;
          setState(() {
            _isEventsWsConnected = true;
          });

          // Subscribe to global events topic
          _eventsStompClient?.subscribe(
            destination: '/topic/events',
            callback: (frame) {
              if (frame.body != null) {
                _processEventWebSocketMessage(frame.body!);
              }
            },
          );

          // Subscribe to personal events topic
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          final currentUserId = authProvider.currentUser?.id;
          if (currentUserId != null) {
            final personalTopic = '/topic/user/$currentUserId/events';
            debugPrint('Subscribing to personal events topic: $personalTopic');
            _eventsStompClient?.subscribe(
              destination: personalTopic,
              callback: (frame) {
                if (frame.body != null) {
                  _processEventWebSocketMessage(frame.body!);
                }
              },
            );
          }
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        onDisconnect: (frame) {
          debugPrint('Global Events STOMP disconnected');
          if (mounted) {
            setState(() {
              _isEventsWsConnected = false;
            });
          }
        },
        onStompError: (frame) {
          debugPrint('Global Events STOMP error: ${frame.body}');
        },
        onWebSocketError: (error) {
          debugPrint('Global Events WebSocket error: $error');
          if (mounted) {
            setState(() {
              _isEventsWsConnected = false;
            });
          }
        },
      ),
    );

    _eventsStompClient?.activate();
  }

  Future<void> _fetchTracks({bool showLoadingSpinner = true}) async {
    try {
      if (showLoadingSpinner) {
        setState(() {
          isLoadingTracks = true;
          trackError = null;
        });
      } else {
        setState(() {
          trackError = null;
        });
      }
      final futures = await Future.wait([
        _audiusService.getTrendingTracks(),
        _audiusService.getRandomTracks(),
      ]);
      if (mounted) {
        setState(() {
          trendingTracks = futures[0];
          randomTracks = futures[1];
          isLoadingTracks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          trackError = e.toString();
          isLoadingTracks = false;
        });
      }
    }
  }

  Future<void> handleRefresh() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.currentUser?.accessToken;

    final List<Future<dynamic>> futures = [
      _fetchData(showLoadingSpinner: false),
    ];

    if (token != null) {
      futures.add(Provider.of<UserProfileProvider>(context, listen: false)
          .fetchProfile(token));
      futures.add(Provider.of<PlaylistProvider>(context, listen: false)
          .loadPlaylists(authProvider.currentUser));
      futures.add(_fetchEvents(token, showLoadingSpinner: false));
    }

    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return _HomeContent();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Acid Noir Discover UI (redesigned; data logic above is unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _HomeContent extends StatelessWidget {
  static const _genres = ['Trap', 'Pop', 'Hip-Hop', 'RnB'];

  /// Play [track] with user-visible feedback when it can't be streamed.
  /// Never fails silently — shows a SnackBar instead of doing nothing.
  void _playTrack(BuildContext context, Track track,
      {required List<Track> playlist, required int index}) {
    if (track.audioUrl == null || track.audioUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This track is not currently streamable.'),
        ),
      );
      return;
    }
    Provider.of<AudioProvider>(context, listen: false)
        .playTrack(track, playlist: playlist, index: index);
  }

  /// Bottom sheet for the Discover banner's "..." button.
  void _showDiscoverOptions(BuildContext context, HomeScreenState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search_rounded,
                  color: AppTheme.textPrimary),
              title: const Text('Discover music',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SearchScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shuffle_rounded,
                  color: AppTheme.textPrimary),
              title: const Text('Shuffle play trending',
                  style: TextStyle(color: Colors.white)),
              enabled: state.trendingTracks.isNotEmpty,
              onTap: () {
                Navigator.pop(context);
                final shuffled =
                    List<Track>.of(state.trendingTracks)..shuffle();
                _playTrack(context, shuffled.first,
                    playlist: shuffled, index: 0);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<HomeScreenState>();
    if (state == null) return const SizedBox.shrink();

    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, child) {
        final playlists = playlistProvider.playlists;
        final railTracks = state.trendingTracks.take(4).toList();

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surface,
            onRefresh: state.handleRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ── Greeting ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Row(
                      children: [
                        Consumer<UserProfileProvider>(
                          builder: (context, profileProvider, child) {
                            final profile = profileProvider.profile;
                            final avatarUrl = profile?.avatarUrl;
                            final hasAvatar = avatarUrl != null &&
                                avatarUrl.isNotEmpty &&
                                !avatarUrl.contains(
                                    'photo-1535713875002-d1d0cf377fde');
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: AppTheme.surfaceRaised,
                                backgroundImage:
                                    hasAvatar ? NetworkImage(avatarUrl) : null,
                                child: hasAvatar
                                    ? null
                                    : const Icon(Icons.person_rounded,
                                        size: 22,
                                        color: AppTheme.textSecondary),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Good evening',
                                  style: AppTheme.caption),
                              Consumer<UserProfileProvider>(
                                builder: (context, p, _) => Text(
                                  p.profile?.displayName ?? 'Music lover',
                                  style: AppTheme.titleMd,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state._isEventsWsConnected)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Search pill → Recommended ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SearchPill(
                      readOnly: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SearchScreen()),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Discover banner + overlapping genre cards ─────────────
                // The Stack is explicitly 372px tall (cards start at 132
                // and are 240 tall) so the overflow doesn't cover content
                // below — Stack alone would only measure the 250px banner.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 372,
                      child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        DiscoverBanner(
                          sideLabel: 'Your playlist',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SearchScreen()),
                          ),
                          onMore: () =>
                              _showDiscoverOptions(context, state),
                        ),
                        Positioned(
                          top: 132,
                          left: 44,
                          right: -20,
                          height: 240,
                          child: state.isLoadingTracks
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: AppTheme.onAccent),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding:
                                      const EdgeInsets.only(right: 20),
                                  itemCount: _genres.length,
                                  itemBuilder: (context, i) {
                                    final track = state
                                            .trendingTracks.isNotEmpty
                                        ? state.trendingTracks[
                                            i % state.trendingTracks.length]
                                        : null;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 12),
                                      child: FeatureCard(
                                        title: _genres[i],
                                        imageUrl: track?.imageUrl,
                                        width: 190,
                                        height: 240,
                                        onTap: () {
                                          if (track != null) {
                                            _playTrack(context, track,
                                                playlist:
                                                    state.trendingTracks,
                                                index: i %
                                                    state.trendingTracks
                                                        .length);
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Tracks are still loading — try again in a moment.'),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
                // Spacer below the overlapping cards
                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Your playlist rail (track rows) ───────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: AcidSectionHeader(
                      title: 'Your playlist',
                      onSeeAll: playlists.isNotEmpty
                          ? () {
                              final first = playlists.first;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistDetailScreen(
                                    playlistId: first.id,
                                    initialPlaylist: first,
                                    useBackend: true,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ),
                if (state.isLoadingTracks)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.accent),
                      ),
                    ),
                  )
                else if (railTracks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text('Pull to refresh to load tracks.',
                          style: AppTheme.caption),
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final t = railTracks[i];
                          return TrackRow(
                            title: t.title,
                            artist: t.artistName,
                            imageUrl: t.imageUrl,
                            duration: formatTrackDuration(t),
                            onTap: () => _playTrack(context, t,
                                playlist: state.trendingTracks,
                                index: state.trendingTracks.indexOf(t)),
                            onMore: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) =>
                                  AddToPlaylistModal(track: t),
                            ),
                          );
                        },
                        childCount: railTracks.length,
                      ),
                    ),
                  ),

                // ── Live rooms (events) ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Live rooms', style: AppTheme.titleLg),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const NearbyEventsScreen()),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceRaised,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusPill),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.bluetooth_searching_rounded,
                                      size: 14,
                                      color: AppTheme.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Radar',
                                      style: AppTheme.caption.copyWith(
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CreateEventScreen()),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text('Create', style: AppTheme.caption),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 240,
                    child: state.isLoadingEvents
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.accent),
                          )
                        : state.eventError != null
                            ? Center(
                                child: Text('Could not load rooms.',
                                    style: AppTheme.caption),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                itemCount: state.events.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == state.events.length) {
                                    return _CreateRoomCard(
                                        onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const CreateEventScreen()),
                                            ));
                                  }
                                  final event = state.events[index];
                                  final String? firstCover =
                                      event['firstTrackCoverUrl'];
                                  final String? cover =
                                      event['coverUrl'];
                                  final imageUrl = (firstCover != null &&
                                          firstCover.isNotEmpty)
                                      ? firstCover
                                      : cover;
                                  final isLive =
                                      event['playing'] == true;
                                  final count =
                                      event['participantCount'] ?? 1;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(right: 12),
                                    child: FeatureCard(
                                      title:
                                          event['name'] ?? 'Unnamed room',
                                      imageUrl: imageUrl,
                                      sideLabel: '$count listening',
                                      width: 190,
                                      height: 240,
                                      useAccentPlay: isLive,
                                      onTap: () =>
                                          _openEvent(context, state, event),
                                      onPlay: () =>
                                          _openEvent(context, state, event),
                                    ),
                                  );
                                },
                              ),
                  ),
                ),

                // ── Trending now ──────────────────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: AcidSectionHeader(title: 'Trending now'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 214,
                    child: state.isLoadingTracks
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.accent),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            itemCount: state.trendingTracks.length,
                            itemBuilder: (context, i) {
                              final t = state.trendingTracks[i];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: 14),
                                child: CollectionCard(
                                  title: t.title,
                                  artist: t.artistName,
                                  imageUrl: t.imageUrl,
                                  onTap: () => _playTrack(context, t,
                                      playlist: state.trendingTracks,
                                      index: i),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                // ── New collection ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: AcidSectionHeader(
                      title: 'New collection',
                      onSeeAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SearchScreen()),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 214,
                    child: state.isLoadingTracks
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.accent),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            itemCount: state.randomTracks.length,
                            itemBuilder: (context, i) {
                              final t = state.randomTracks[i];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: 14),
                                child: CollectionCard(
                                  title: t.title,
                                  artist: t.artistName,
                                  imageUrl: t.imageUrl,
                                  onTap: () => _playTrack(context, t,
                                      playlist: state.randomTracks,
                                      index: i),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                // Bottom breathing room for pill nav + mini player
                const SliverToBoxAdapter(child: SizedBox(height: 170)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEvent(
      BuildContext context, HomeScreenState state, Map<String, dynamic> event) {
    final isLive = event['playing'] == true;
    if (isLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: const Text(
            'This room is already live. You cannot join now.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: event['id'],
          eventName: event['name'] ?? 'Event',
        ),
      ),
    );
  }
}

class _CreateRoomCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateRoomCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 240,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppTheme.onAccent, size: 30),
            ),
            const SizedBox(height: 12),
            Text('Host a room',
                style: AppTheme.titleMd.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text('Go live', style: AppTheme.caption),
          ],
        ),
      ),
    );
  }
}
