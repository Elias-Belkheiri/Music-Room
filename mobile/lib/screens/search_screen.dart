import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/audius_service.dart';
import '../models/track_model.dart';
import '../providers/audio_provider.dart';
import '../widgets/acid/acid_section_header.dart';
import '../widgets/acid/collection_card.dart';
import '../widgets/acid/search_pill.dart';
import '../widgets/acid/track_row.dart';
import '../widgets/audio_player_overlay.dart';
import '../widgets/add_to_playlist_modal.dart';
import '../widgets/responsive_layout.dart';
import 'home_screen.dart' show formatTrackDuration;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final AudiusService _audiusService = AudiusService();
  final TextEditingController _searchController = TextEditingController();
  List<Track> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  final List<Map<String, dynamic>> _categories = const [
    {
      'title': 'Pop',
      'image':
          'https://images.unsplash.com/photo-1520127877998-122c33e8eb38?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
    {
      'title': 'Hip-Hop',
      'image':
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
    {
      'title': 'Rock',
      'image':
          'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
    {
      'title': 'Jazz',
      'image':
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
    {
      'title': 'Electronic',
      'image':
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
    {
      'title': 'Chill',
      'image':
          'https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
    {
      'title': 'Party',
      'image':
          'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
    {
      'title': 'Workout',
      'image':
          'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
    {
      'title': 'Focus',
      'image':
          'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
    {
      'title': 'Mood',
      'image':
          'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=400&h=400&fit=crop',
      'artist': 'Playlist',
    },
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _audiusService.searchTracks(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      // Stacked overlay: this screen is pushed on top of MainScreen, which
      // hides the shell's mini player — so it needs its own. Without this,
      // tapping a result plays audio with zero visual feedback.
      body: Stack(
        children: [
          CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Back + title ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (Navigator.canPop(context))
                    Semantics(
                      button: true,
                      label: 'Back',
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppTheme.surfaceRaised,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppTheme.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  if (Navigator.canPop(context))
                    const SizedBox(height: 12),
                  Text(
                    'Recommended\nFor You Today',
                    style: AppTheme.display.copyWith(fontSize: 30),
                  ),
                ],
              ),
            ),
          ),

          // ── Search pill ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SearchPill(
                controller: _searchController,
                onSubmitted: _performSearch,
                onClear: () {
                  _searchController.clear();
                  _performSearch('');
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          if (!_hasSearched) ...[
            // ── Hero card (wide feature) ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () {
                    final title =
                        _categories[1]['title'] as String;
                    _searchController.text = title;
                    _performSearch(title);
                  },
                  child: Container(
                    height: 210,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusLg),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusLg),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _categories[1]['image'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.surfaceRaised,
                              child: const Icon(
                                  Icons.music_note_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 48),
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                                gradient: AppTheme.scrim),
                          ),
                          Positioned(
                            left: 18,
                            bottom: 16,
                            child: Text(
                              _categories[1]['title'] as String,
                              style: AppTheme.titleLg.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── New Collection rail ─────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: AcidSectionHeader(
                  title: 'New Collection',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 214,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final c = _categories[index];
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: 14),
                      child: CollectionCard(
                        title: c['title'] as String,
                        artist: c['artist'] as String,
                        imageUrl: c['image'] as String,
                        onTap: () {
                          _searchController.text =
                              c['title'] as String;
                          _performSearch(c['title'] as String);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Browse all grid ─────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: AcidSectionHeader(title: 'Browse all'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 170),
              sliver: SliverGrid(
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: ResponsiveLayout.gridCrossAxisCount(context),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final c = _categories[index];
                    final size =
                        (MediaQuery.of(context).size.width - 54) / 2;
                    return CollectionCard(
                      title: c['title'] as String,
                      artist: c['artist'] as String,
                      imageUrl: c['image'] as String,
                      size: size,
                      onTap: () {
                        _searchController.text =
                            c['title'] as String;
                        _performSearch(c['title'] as String);
                      },
                    );
                  },
                  childCount: _categories.length,
                ),
              ),
            ),
          ] else if (_isLoading) ...[
            const SliverFillRemaining(
              child: Center(
                child:
                    CircularProgressIndicator(color: AppTheme.accent),
              ),
            ),
          ] else if (_searchResults.isEmpty) ...[
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No results found',
                        style: AppTheme.titleMd),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                      child: Text('Clear search',
                          style: AppTheme.caption.copyWith(
                              color: AppTheme.accent)),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // ── Search results as track rows ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  '${_searchResults.length} results',
                  style: AppTheme.caption,
                ),
              ),
            ),
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 170),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = _searchResults[index];
                    return TrackRow(
                      title: track.title,
                      artist: track.artistName,
                      imageUrl: track.imageUrl,
                      duration: formatTrackDuration(track),
                      onTap: () {
                        if (track.audioUrl == null ||
                            track.audioUrl!.isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'This track is not currently streamable on Audius.',
                              ),
                            ),
                          );
                          return;
                        }
                        Provider.of<AudioProvider>(context,
                                listen: false)
                            .playTrack(
                          track,
                          playlist: _searchResults,
                          index: index,
                        );
                      },
                      onMore: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            AddToPlaylistModal(track: track),
                      ),
                    );
                  },
                  childCount: _searchResults.length,
                ),
              ),
            ),
          ],
        ],
          ),
          const AudioPlayerOverlay(),
        ],
      ),
    );
  }
}
