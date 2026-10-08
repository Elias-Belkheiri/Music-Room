# App-wide Color Contrast Fix — Design

## Goal
Fix low-contrast yellow/white combinations across the Flutter app without changing the Acid Noir brand palette.

## Context
The app’s shared design tokens are in `mobile/lib/config/app_theme.dart`: acid yellow `accent` (`#E9FE5C`), dark `onAccent` (`#141414`), primary text (`#F4F4F4`), and secondary text (`#9A9A9A`). The screenshot shows a yellow active navigation indicator against a dark surface; that pairing itself is not the issue. Failures are likely where white foregrounds are used on yellow backgrounds or pale/yellow text on white/light surfaces. Color usage also exists as per-widget overrides, so changing only the theme is insufficient.

## Design
Keep the current yellow and dark palette. Treat `onAccent` as the required foreground for text and icons on accent-colored backgrounds, including primary buttons and selected states. Keep yellow as an accent foreground only where its actual background has sufficient contrast. Audit all Flutter source for yellow/white combinations and fix each confirmed failing pairing, including `Colors.amber`/other yellow variants and control states. Do not blanket-replace `Colors.white`: white on dark surfaces is intentional and readable.

## Validation
Add targeted widget/theme tests for shared accent button foregrounds and the active navigation indicator. Audit remaining explicit yellow/white uses by checking rendered foreground/background pairings, then run `flutter test` and `flutter analyze` from `mobile/`.
