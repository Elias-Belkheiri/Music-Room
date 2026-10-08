import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track_model.dart';
import '../models/playlist_model.dart';
import '../providers/auth_provider.dart';
import '../providers/playlist_provider.dart';
import '../config/app_theme.dart';
import '../services/download_service.dart';

class AddToPlaylistModal extends StatefulWidget {
  final Track track;

  const AddToPlaylistModal({super.key, required this.track});

  @override
  State<AddToPlaylistModal> createState() => _AddToPlaylistModalState();
}

class _AddToPlaylistModalState extends State<AddToPlaylistModal> {
  final TextEditingController _playlistNameController = TextEditingController();
  final TextEditingController _playlistDescriptionController = TextEditingController();
  bool _isSubmitting = false;

  // Download states
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      Provider.of<PlaylistProvider>(context, listen: false).loadPlaylists(user);
    });
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    _playlistDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkDownloadStatus() async {
    final downloaded = await DownloadService().isTrackDownloaded(widget.track.id);
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
      });
    }
  }

  Future<void> _toggleDownload() async {
    if (_isDownloading) return;

    if (_isDownloaded) {
      // Remove download
      await DownloadService().deleteTrack(widget.track.id);
      setState(() {
        _isDownloaded = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed track from downloads'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } else {
      // Start download
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final success = await DownloadService().downloadTrack(
        widget.track,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloaded = success;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Track downloaded successfully!' : 'Failed to download track',
            ),
            backgroundColor: success ? AppTheme.accent : AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _createAndAdd(BuildContext context) async {
    final name = _playlistNameController.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter a playlist name'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    if (_isSubmitting) return;

    final navigator = Navigator.of(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    setState(() => _isSubmitting = true);
    try {
      await Provider.of<PlaylistProvider>(context, listen: false).createPlaylistAndAddTrack(
        _playlistNameController.text.trim(),
        _playlistDescriptionController.text.trim(),
        'private',
        widget.track,
        user,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to new playlist!')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to create playlist: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _addToExisting(BuildContext context, Playlist playlist) async {
    if (_isSubmitting) return;
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    setState(() => _isSubmitting = true);
    try {
      await Provider.of<PlaylistProvider>(context, listen: false).addTrackToExistingPlaylist(
        playlist,
        widget.track,
        user,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to playlist!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add track: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _defaultTrackIcon() {
    return Container(
      color: Colors.white10,
      width: 48,
      height: 48,
      child: const Icon(Icons.music_note, color: Colors.white54),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Download Action Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.track.imageUrl != null && widget.track.imageUrl!.isNotEmpty
                      ? Image.network(
                          widget.track.imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultTrackIcon(),
                        )
                      : _defaultTrackIcon(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.title,
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
                        widget.track.artistName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _isDownloading
                    ? SizedBox(
                        width: 32,
                        height: 32,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: _downloadProgress,
                              strokeWidth: 3,
                              color: AppTheme.accent,
                              backgroundColor: Colors.white12,
                            ),
                            Text(
                              '${(_downloadProgress * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _toggleDownload,
                        icon: Icon(
                          _isDownloaded
                              ? Icons.download_done_rounded
                              : Icons.download_rounded,
                          color: _isDownloaded
                              ? AppTheme.accent
                              : Colors.white70,
                          size: 20,
                        ),
                        label: Text(
                          _isDownloaded ? 'Saved' : 'Download',
                          style: TextStyle(
                            color: _isDownloaded
                                ? AppTheme.accent
                                : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.06),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 16),

          const Text(
            'Add to Playlist',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _playlistNameController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _createAndAdd(context),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'New playlist name',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF232323),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isSubmitting ? null : () async => _createAndAdd(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.onAccent,
                  elevation: 0,
                  minimumSize: const Size(104, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _playlistDescriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Description (optional)',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF232323),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your playlists',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Consumer<PlaylistProvider>(
              builder: (context, playlistProvider, child) {
                if (playlistProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
                final filteredPlaylists = playlistProvider.playlists.where((playlist) {
                  final isOwner = playlist.ownerId == currentUser?.id || playlist.permission == 'owner';
                  final isEditor = playlist.permission == 'editor';
                  return isOwner || isEditor;
                }).toList();

                if (filteredPlaylists.isEmpty) {
                  final message = playlistProvider.errorMessage != null
                      ? 'Could not load playlists from backend.\nYou can still create a new one.'
                      : 'No playlists yet.';
                  return Center(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filteredPlaylists.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  itemBuilder: (context, index) {
                    final playlist = filteredPlaylists[index];
                    final title = playlist.title.trim().isEmpty ? 'Untitled playlist' : playlist.title;
                    final creator = playlist.creatorName.trim().isEmpty ? 'Unknown creator' : playlist.creatorName;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      leading: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF282828),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.queue_music_rounded, color: Colors.white70),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        creator,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.add_circle_outline, color: Colors.white70),
                      onTap: _isSubmitting ? null : () async => _addToExisting(context, playlist),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
