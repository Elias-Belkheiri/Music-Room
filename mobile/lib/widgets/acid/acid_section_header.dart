import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Section header — title left + "See all" right, same baseline.
class AcidSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final bool large;

  const AcidSectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: large ? AppTheme.display.copyWith(fontSize: 28) : AppTheme.titleLg,
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text('See all', style: AppTheme.caption),
            ),
          ),
      ],
    );
  }
}

/// Pill chip — surface-raised; active = accent.
class AcidChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const AcidChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          label,
          style: AppTheme.label.copyWith(
            color: selected ? AppTheme.onAccent : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
