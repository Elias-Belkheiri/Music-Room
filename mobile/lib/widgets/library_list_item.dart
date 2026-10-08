import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class LibraryListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final bool isCircular;
  final bool isPrivate;
  final VoidCallback? onTap;
  final Widget? trailing;

  const LibraryListItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.isCircular = false,
    this.isPrivate = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            // Image
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isCircular
                    ? null
                    : BorderRadius.circular(AppTheme.radiusSm),
                color: AppTheme.surfaceRaised,
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 12),
            // Title & Subtitle
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isPrivate) ...[
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: AppTheme.danger,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          style: AppTheme.titleMd.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.caption.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        isCircular ? Icons.person_rounded : Icons.music_note_rounded,
        color: Colors.white24,
        size: 32,
      ),
    );
  }
}
