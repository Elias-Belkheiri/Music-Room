import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Yellow Discover banner from the inspiration (left phone):
/// acid block with "Discover" title, vertical "Your playlist" label,
/// and a cut-out that the feature card overlaps.
class DiscoverBanner extends StatelessWidget {
  final String? sideLabel;
  final VoidCallback? onMore;
  final VoidCallback? onTap;

  const DiscoverBanner({super.key, this.sideLabel, this.onMore, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
      height: 250,
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discover',
                  style: AppTheme.display.copyWith(
                    color: AppTheme.onAccent,
                    fontSize: 30,
                  ),
                ),
                GestureDetector(
                  onTap: onMore,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppTheme.onAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_horiz_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          if (sideLabel != null)
            Positioned(
              left: 8,
              top: 90,
              child: RotatedBox(
                quarterTurns: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.library_music_rounded,
                        color: AppTheme.onAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      sideLabel!,
                      style: AppTheme.label.copyWith(
                        color: AppTheme.onAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom cut-out notch (the black circle bite on the right edge)
          Positioned(
            right: -28,
            bottom: -28,
            child: Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: AppTheme.background,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
