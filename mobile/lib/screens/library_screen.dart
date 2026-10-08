import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/playlist_model.dart';
import '../models/track_model.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/playlist_service.dart';
import '../services/download_service.dart';
import '../widgets/library_list_item.dart';
import 'package:provider/provider.dart';
import 'profile/profile_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../providers/audio_provider.dart';
import '../widgets/responsive_layout.dart';

enum _LibraryFilter { all, myPlaylists, saved, downloads }

class LibraryScreen extends StatefulWidget {
  final VoidCallback? onPlusTap;
  const LibraryScreen({super.key, this.onPlusTap});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isSearching = false;
  bool _isGridView = false;
  String _searchQuery = '';
  _LibraryFilter _filter = _LibraryFilter.all;
  final TextEditingController _searchController = TextEditingController();

  List<Playlist> _savedPlaylists = [];
  List<Track> _downloadedTracks = [];
  bool _isLoadingSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<PlaylistProvider>(context, listen: false)
          .loadPlaylists(auth.currentUser);
      _loadSavedPlaylists();
      _loadDownloadedTracks();
    });
  }

  Future<void> _loadSavedPlaylists() async {
    final token =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.accessToken;
    if (token == null || token.isEmpty) return;
    setState(() => _isLoadingSaved = true);
    try {
      final saved = await PlaylistService().getSavedPlaylists(token);
      if (mounted) setState(() => _savedPlaylists = saved);
    } catch (e) {
      debugPrint('Failed to load saved playlists: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSaved = false);
    }
  }

  Future<void> _loadDownloadedTracks() async {
    try {
      final tracks = await DownloadService().getDownloadedTracks();
      if (mounted) setState(() => _downloadedTracks = tracks);
    } catch (e) {
      debugPrint('Failed to load downloaded tracks: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredItems(BuildContext context) {
    final playlistProvider = Provider.of<PlaylistProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.id ?? '';

    // My Playlists: playlists owned by current user or where they are an editor
    final myPlaylists = playlistProvider.playlists
        .where((p) {
          final isOwner = p.ownerId == currentUserId || p.permission == 'owner';
          final isEditor = p.permission == 'editor';
          return isOwner || isEditor;
        })
        .map((p) => _toItem(p, isSaved: false))
        .toList();

    // Saved Playlists: exclude ones already owned by me or where I am an editor (no duplicates)
    final savedItems = _savedPlaylists
        .where((p) => p.ownerId != currentUserId && p.permission != 'editor')
        .map((p) => _toItem(p, isSaved: true))
        .toList();

    // Downloaded Tracks
    final downloadedItems = _downloadedTracks
        .map((t) => {
              'id': t.id,
              'title': t.title.isEmpty ? 'Untitled Track' : t.title,
              'subtitle': 'Downloaded • ${t.artistName.isEmpty ? 'Unknown' : t.artistName}',
              'image': t.imageUrl ??
                  'https://images.unsplash.com/photo-1514525253344-f814d074e015?w=200&h=200&fit=crop',
              'isCircular': false,
              'track': t,
              'isPrivate': false,
              'isSaved': false,
              'isDownloadItem': true,
            })
        .toList();

    List<Map<String, dynamic>> combined;
    switch (_filter) {
      case _LibraryFilter.myPlaylists:
        combined = myPlaylists;
        break;
      case _LibraryFilter.saved:
        combined = savedItems;
        break;
      case _LibraryFilter.downloads:
        combined = downloadedItems;
        break;
      case _LibraryFilter.all:
        combined = [...myPlaylists, ...savedItems, ...downloadedItems];
        break;
    }

    if (_searchQuery.isEmpty) return combined;
    return combined
        .where((item) =>
            item['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Map<String, dynamic> _toItem(Playlist p, {required bool isSaved}) {
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
    return {
      'id': p.id,
      'title': p.title.isEmpty ? 'Untitled Playlist' : p.title,
      'subtitle': isSaved
          ? 'Saved • ${p.creatorName.isEmpty ? 'Unknown' : p.creatorName}'
          : p.ownerId == currentUserId
              ? 'Playlist • You'
              : 'Playlist • ${p.creatorName.isEmpty ? 'Unknown' : p.creatorName}',
      'image': p.imageUrl ??
          'https://images.unsplash.com/photo-1514525253344-f814d074e015?w=200&h=200&fit=crop',
      'isCircular': false,
      'playlist': p,
      'isPrivate': p.visibility == 'private',
      'isSaved': isSaved,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final userName = auth.currentUser?.fullName ?? 'User';

        return RefreshIndicator(
          color: AppTheme.accent,
          backgroundColor: AppTheme.surface,
          onRefresh: () async {
            Provider.of<PlaylistProvider>(context, listen: false)
                .loadPlaylists(auth.currentUser);
            await _loadSavedPlaylists();
            await _loadDownloadedTracks();
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header ─────────────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                pinned: true,
                backgroundColor: AppTheme.background,
                elevation: 0,
                toolbarHeight: 80,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
                    child: _isSearching
                        ? _buildSearchBar()
                        : _buildDefaultHeader(userName),
                  ),
                ),
              ),

              // ── Filter Chips ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _chip('All', _LibraryFilter.all),
                      const SizedBox(width: 8),
                      _chip('Playlists', _LibraryFilter.myPlaylists),
                      const SizedBox(width: 8),
                      _chip('Saved', _LibraryFilter.saved),
                      const SizedBox(width: 8),
                      _chip('Downloads', _LibraryFilter.downloads),
                    ],
                  ),
                ),
              ),

              // ── Sort & View Toggle ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.import_export_rounded,
                              color: AppTheme.textPrimary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Recently added',
                            style: AppTheme.label.copyWith(
                                color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () =>
                            setState(() => _isGridView = !_isGridView),
                        icon: Icon(
                          _isGridView
                              ? Icons.list_rounded
                              : Icons.grid_view_rounded,
                          color: AppTheme.textPrimary,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Loading ─────────────────────────────────────────────────────
              if (_isLoadingSaved)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                        child: SizedBox(
                            height: 2,
                            child: LinearProgressIndicator(color: AppTheme.accent))),
                  ),
                ),

              // ── Empty State ─────────────────────────────────────────────────
              Builder(builder: (context) {
                final items = _getFilteredItems(context);
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.library_music_outlined,
                              color: AppTheme.textSecondary, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            _filter == _LibraryFilter.saved
                                ? 'No saved playlists yet'
                                : _filter == _LibraryFilter.downloads
                                    ? 'No downloaded tracks yet'
                                    : 'No items yet',
                            style: AppTheme.titleMd.copyWith(
                                color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _filter == _LibraryFilter.saved
                                ? 'Save playlists from their detail page'
                                : _filter == _LibraryFilter.downloads
                                    ? 'Go to Search and tap on options menu to download tracks'
                                    : 'Create playlists or download songs',
                            style: AppTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }),

              // ── Library List / Grid ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
                sliver: _isGridView
                    ? SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: ResponsiveLayout.gridCrossAxisCount(context),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final items = _getFilteredItems(context);
                            return _buildGridItem(items[index]);
                          },
                          childCount: _getFilteredItems(context).length,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final items = _getFilteredItems(context);
                            final item = items[index];
                            final isDownload = item['isDownloadItem'] == true;
                            final track = isDownload ? item['track'] as Track : null;

                            final listItem = LibraryListItem(
                              title: item['title'],
                              subtitle: item['subtitle'],
                              imageUrl: item['image'],
                              isCircular: item['isCircular'],
                              isPrivate: item['isPrivate'] ?? false,
                              onTap: () => _openPlaylistDetail(context, item),
                              trailing: isDownload
                                  ? IconButton(
                                      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                                      onPressed: () => _showDownloadOptionsBottomSheet(context, track!),
                                    )
                                  : null,
                            );

                            if (isDownload) {
                              return Dismissible(
                                key: Key('download_${track!.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  color: AppTheme.danger,
                                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                ),
                                onDismissed: (direction) async {
                                  await DownloadService().deleteTrack(track.id);
                                  setState(() {
                                    _downloadedTracks.removeWhere((t) => t.id == track.id);
                                  });
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Removed "${track.title}" from downloads'),
                                        backgroundColor: AppTheme.danger,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: listItem,
                              );
                            }

                            return listItem;
                          },
                          childCount: _getFilteredItems(context).length,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, _LibraryFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        if (value == _LibraryFilter.downloads) {
          _loadDownloadedTracks();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          label,
          style: AppTheme.label.copyWith(
            color: selected ? AppTheme.onAccent : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  void _showDownloadOptionsBottomSheet(BuildContext context, Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  track.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text(
                  'Remove from downloads',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await DownloadService().deleteTrack(track.id);
                  setState(() {
                    _downloadedTracks.removeWhere((t) => t.id == track.id);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed "${track.title}" from downloads'),
                        backgroundColor: Colors.redAccent,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.close_rounded, color: Colors.white),
                title: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridItem(Map<String, dynamic> item) {
    final isDownload = item['isDownloadItem'] == true;
    final track = isDownload ? item['track'] as Track : null;

    return InkWell(
      onTap: () => _openPlaylistDetail(context, item),
      onLongPress: isDownload
          ? () => _showDownloadOptionsBottomSheet(context, track!)
          : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                    image: DecorationImage(
                      image: NetworkImage(item['image']),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (item['isSaved'] == true)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text('Saved',
                          style: AppTheme.label.copyWith(
                              color: AppTheme.onAccent,
                              fontSize: 10)),
                    ),
                  ),
                if (isDownload)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text('Offline',
                          style: AppTheme.label.copyWith(
                              color: AppTheme.onAccent,
                              fontSize: 10)),
                    ),
                  ),
                if (item['isPrivate'] == true)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          color: AppTheme.danger, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(item['title'],
              style: AppTheme.titleMd.copyWith(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(item['subtitle'],
              style: AppTheme.caption.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _openPlaylistDetail(BuildContext context, Map<String, dynamic> item) {
    if (item['isDownloadItem'] == true) {
      final track = item['track'] as Track;
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.playTrack(
        track,
        playlist: _downloadedTracks,
        index: _downloadedTracks.indexWhere((t) => t.id == track.id),
      );
      return;
    }

    final playlist = item['playlist'];
    if (playlist == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(
          playlistId: playlist.id,
          initialPlaylist: playlist,
          useBackend: true,
        ),
      ),
    ).then((_) {
      _loadSavedPlaylists(); // Refresh saved state on return
      _loadDownloadedTracks();
    });
  }

  Widget _buildDefaultHeader(String userName) {
    return Row(
      children: [
        Consumer<UserProfileProvider>(
          builder: (context, profileProvider, child) {
            final profile = profileProvider.profile;
            final avatarUrl = profile?.avatarUrl;
            return GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.surfaceRaised,
                backgroundImage: avatarUrl != null &&
                        avatarUrl.isNotEmpty &&
                        !avatarUrl.contains('photo-1535713875002-d1d0cf377fde')
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null ||
                        avatarUrl.isEmpty ||
                        avatarUrl.contains('photo-1535713875002-d1d0cf377fde')
                    ? const Icon(Icons.person,
                        size: 18, color: AppTheme.textSecondary)
                    : null,
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        Text(
          'Your Library',
          style: AppTheme.titleLg.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => setState(() => _isSearching = true),
          icon: const Icon(Icons.search_rounded,
              color: AppTheme.textPrimary, size: 28),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: widget.onPlusTap,
          icon: const Icon(Icons.add_rounded,
              color: AppTheme.textPrimary, size: 32),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: AppTheme.body.copyWith(fontSize: 14),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Find in Your Library',
                hintStyle:
                    AppTheme.caption.copyWith(fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textSecondary, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          }),
          child: const Text('Cancel',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
