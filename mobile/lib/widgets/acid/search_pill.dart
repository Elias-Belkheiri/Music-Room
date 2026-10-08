import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

/// Full-width 52px search pill.
class SearchPill extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool readOnly;
  final String hint;

  const SearchPill({
    super.key,
    this.controller,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.onClear,
    this.readOnly = false,
    this.hint = 'search',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: AppTheme.textSecondary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: readOnly
                  ? Text(hint, style: AppTheme.caption.copyWith(fontSize: 15))
                  : TextField(
                      controller: controller,
                      readOnly: false,
                      onSubmitted: onSubmitted,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: AppTheme.body,
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: AppTheme.caption.copyWith(fontSize: 15),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
            ),
            // Clear button: reactive to text changes (ListenableBuilder)
            // and tappable with a full 44px hit area.
            if (!readOnly && controller != null)
              ListenableBuilder(
                listenable: controller!,
                builder: (_, __) {
                  if (controller!.text.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    onTap: onClear ??
                        () {
                          controller!.clear();
                        },
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.clear_rounded,
                          color: AppTheme.textSecondary, size: 20),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
