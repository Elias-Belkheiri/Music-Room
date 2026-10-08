import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Floating pill bottom nav — 3 items only (Library | Home | Settings).
/// Active = accent fill + on-accent icon. Inactive = transparent + secondary.
class AcidBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const AcidBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _icons = [
    Icons.library_music_rounded,
    Icons.play_arrow_rounded,
    Icons.settings_rounded,
  ];
  static const _labels = ['Library', 'Home', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(3, (i) {
          final active = i == selectedIndex;
          return Semantics(
            button: true,
            label: _labels[i],
            selected: active,
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: active ? AppTheme.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icons[i],
                  color: active
                      ? AppTheme.onAccent
                      : AppTheme.textSecondary,
                  size: 26,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
