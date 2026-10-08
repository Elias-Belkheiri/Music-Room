import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import 'acid_buttons.dart';

/// Feature card (genre/event) — ~4:5, radius-lg, full-bleed art,
/// title bottom-left over scrim, circular play bottom-right.
class FeatureCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? sideLabel;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final bool useAccentPlay;

  const FeatureCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.sideLabel,
    this.width = 220,
    this.height = 275,
    this.onTap,
    this.onPlay,
    this.useAccentPlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback(),
                )
              else
                _fallback(),
              Container(decoration: const BoxDecoration(gradient: AppTheme.scrim)),
              if (sideLabel != null)
                Positioned(
                  left: 12,
                  top: 64,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      sideLabel!,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 76,
                bottom: 16,
                child: Text(
                  title,
                  style: AppTheme.titleLg.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: AcidPlayBadge(
                  onTap: onPlay ?? onTap,
                  useAccent: useAccentPlay,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: AppTheme.surfaceRaised,
        child: const Icon(Icons.music_note_rounded,
            color: AppTheme.textSecondary, size: 48),
      );
}
