import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../playlist_detail_screen.dart';

class AllPlaylistsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> playlists;

  const AllPlaylistsScreen({Key? key, required this.playlists}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Playlists',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.8, end: 1.2),
                    duration: const Duration(seconds: 2),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    curve: Curves.easeInOut,
                    onEnd: () {
                      // Note: for a continuous loop in a simple way without a controller
                      // doing a clean bounce needs an AnimationController, but we just want
                      // a quick fun empty state. Let's stick with a nice styled icon.
                    },
                    child: Icon(
                      Icons.music_off_outlined,
                      size: 100,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No playlists yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create some events to see them here!',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                final String title = playlist['name'] ?? 'Unknown';
                final String subtitle = playlist['trackCount'] != null
                    ? '${playlist['trackCount']} tracks'
                    : '0 tracks';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(
                            playlistId: (playlist['id'] ?? '').toString(),
                            initialPlaylist: playlist['playlist'],
                            useBackend: true,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey[800],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: playlist['imageUrl'] != null && playlist['imageUrl'].toString().isNotEmpty
                              ? Image.network(
                                  playlist['imageUrl'].toString(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, _, __) => const Icon(Icons.music_note, color: Colors.grey, size: 30),
                                )
                              : const Icon(Icons.music_note, color: Colors.grey, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
