import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Track row — 64px: 48px thumb | title + artist | duration.
class TrackRow extends StatelessWidget {
  final String title;
  final String artist;
  final String? imageUrl;
  final String? duration;
  final String? voteCount;
  final bool votedByMe;
  final VoidCallback? onTap;
  final VoidCallback? onVote;
  final VoidCallback? onMore;

  const TrackRow({
    super.key,
    required this.title,
    required this.artist,
    this.imageUrl,
    this.duration,
    this.voteCount,
    this.votedByMe = false,
    this.onTap,
    this.onVote,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbFallback(),
                    )
                  : _thumbFallback(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTheme.titleMd,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(artist,
                      style: AppTheme.caption,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (voteCount != null)
              GestureDetector(
                onTap: onVote,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: votedByMe ? AppTheme.accent : AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    voteCount!,
                    style: AppTheme.label.copyWith(
                      color: votedByMe
                          ? AppTheme.onAccent
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            if (duration != null)
              Text(duration!,
                  style: AppTheme.caption.copyWith(fontFeatures: const [])),
            if (onMore != null)
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppTheme.textSecondary, size: 20),
                onPressed: onMore,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() => Container(
        width: 48, height: 48,
        color: AppTheme.surfaceRaised,
        child: const Icon(Icons.music_note_rounded,
            color: AppTheme.textSecondary, size: 24),
      );
}
