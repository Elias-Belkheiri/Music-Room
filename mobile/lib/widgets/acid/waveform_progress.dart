import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Waveform progress bar — ~40px rounded bars.
/// Played = accent, unplayed = #5A5A5A. Scrubbable via tap/drag.
class WaveformProgress extends StatelessWidget {
  final double progress; // 0..1
  final ValueChanged<double>? onSeek;
  final int barCount;

  const WaveformProgress({
    super.key,
    required this.progress,
    this.onSeek,
    this.barCount = 48,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        if (onSeek == null) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final x = d.localPosition.dx.clamp(0.0, box.size.width);
        onSeek!(x / box.size.width);
      },
      onTapDown: (d) {
        if (onSeek == null) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final x = d.localPosition.dx.clamp(0.0, box.size.width);
        onSeek!(x / box.size.width);
      },
      child: SizedBox(
        height: 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (i) {
            // Deterministic pseudo-random heights (stable across rebuilds)
            final t = (i * 37 % 23) / 23.0;
            final h = 8 + t * 32;
            final played = (i / barCount) <= progress.clamp(0.0, 1.0);
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: h,
                decoration: BoxDecoration(
                  color: played ? AppTheme.accent : AppTheme.unplayedBar,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
