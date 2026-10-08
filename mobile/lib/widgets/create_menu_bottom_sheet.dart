import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/subscription_provider.dart';
import '../screens/create_event_screen.dart';
import '../screens/create_playlist_screen.dart';
import '../screens/subscription_screen.dart';

class CreateMenuOverlay extends StatelessWidget {
  final VoidCallback onClose;

  const CreateMenuOverlay({super.key, required this.onClose});

  void _showUpgradeDialog(NavigatorState navigator) {
    showDialog(
      context: navigator.context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            const Icon(Icons.star_rounded, color: AppTheme.accent),
            const SizedBox(width: 8),
            const Text('Premium Feature', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Collaborative Playlist Editor is only available to Premium members. Upgrade to create and collaborate on playlists in real time!',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
            child: const Text('View Plans'),
            onPressed: () {
              Navigator.pop(ctx);
              navigator.push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.radiusLg),
              topRight: Radius.circular(AppTheme.radiusLg),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuItem(
                context,
                icon: Icons.music_note_rounded,
                title: 'Playlist',
                subtitle: 'Create a playlist with songs or episodes (Premium)',
                onTap: () {
                  final navigator =
                      Navigator.of(context, rootNavigator: true);
                  final sub = Provider.of<SubscriptionProvider>(context, listen: false);
                  onClose();
                  if (!sub.isPremium) {
                    _showUpgradeDialog(navigator);
                    return;
                  }
                  navigator.push(
                    MaterialPageRoute(
                      builder: (context) => const CreatePlaylistScreen(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.campaign_rounded,
                title: 'Event',
                subtitle: 'Start a new live event',
                onTap: () {
                  final navigator =
                      Navigator.of(context, rootNavigator: true);
                  onClose();
                  navigator.push(
                    MaterialPageRoute(
                      builder: (context) => const CreateEventScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              SafeArea(top: false, child: const SizedBox.shrink()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(icon, color: AppTheme.onAccent, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleMd.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.caption.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
