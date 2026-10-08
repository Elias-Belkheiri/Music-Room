import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Legacy section header — kept in sync with Acid Noir.
/// Prefer [AcidSectionHeader] (widgets/acid/) for new screens.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTheme.titleLg,
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                'See all',
                style: AppTheme.caption,
              ),
            ),
          ),
      ],
    );
  }
}
