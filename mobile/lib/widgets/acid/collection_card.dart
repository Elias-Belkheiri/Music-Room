import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Collection card — square 1:1, radius-md, art + title + artist below.
class CollectionCard extends StatelessWidget {
  final String title;
  final String artist;
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;
  final String? badge;

  const CollectionCard({
    super.key,
    required this.title,
    required this.artist,
    this.imageUrl,
    this.size = 150,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          imageUrl!,
                          width: size, height: size, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallback(),
                        )
                      : _fallback(),
                ),
                if (badge != null)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.headphones_rounded,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(badge!,
                              style: AppTheme.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title,
                style: AppTheme.titleMd.copyWith(fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(artist, style: AppTheme.caption,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        width: size, height: size,
        color: AppTheme.surfaceRaised,
        child: const Icon(Icons.music_note_rounded,
            color: AppTheme.textSecondary, size: 40),
      );
}
