# App-wide Color Contrast Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate yellow/white low-contrast foreground/background pairs throughout the Flutter app while retaining the current brand palette.

**Architecture:** Preserve centralized color tokens in `AppTheme`; correct component-level foreground overrides wherever the rendered background is yellow or white. Add regression tests around shared theme controls and navigation, then run a source audit and the Flutter test/analyze suites.

**Tech Stack:** Flutter, Dart, `flutter_test`.

---

### Task 1: Add a regression test for shared accent button contrast

**Files:**
- Create: `mobile/test/color_contrast_test.dart`
- Reference: `mobile/lib/config/app_theme.dart`

**Step 1: Write the failing test**

Test that `AppTheme.darkTheme`'s `ElevatedButtonThemeData` has accent background and `AppTheme.onAccent` foreground. Resolve the button style’s foreground and background colors, accounting for `WidgetStateProperty` resolution.

**Step 2: Run test to verify behavior**

Run: `cd mobile && flutter test test/color_contrast_test.dart`
Expected: PASS if the shared theme is already correct; this test locks in the expected token pairing before per-widget corrections.

### Task 2: Audit all app yellow/white combinations

**Files:**
- Inspect: `mobile/lib/**/*.dart`

**Step 1: Search color declarations**

Run: `cd mobile && rg -n 'AppTheme\\.accent|0xFF(E9FE5C|FFFF|FFFFFF|FFC107)|Colors\\.(white|amber|yellow)' lib`

**Step 2: Inspect each actual foreground/background pairing**

Record only actual yellow-on-white or white-on-yellow text/icon/control combinations. Ignore yellow indicators on dark surfaces and white text on dark surfaces. Check button selected/disabled states, snackbar/dialogs, chips, and `ColorScheme`-driven defaults.

### Task 3: Correct each confirmed failing pairing

**Files:**
- Modify: only confirmed affected Dart files under `mobile/lib/`
- Modify: `mobile/lib/config/app_theme.dart` only if a shared default still resolves to an invalid foreground

**Step 1: Add or update targeted regression coverage**

For each shared control with a failing pairing, extend `mobile/test/color_contrast_test.dart` to assert its foreground/background tokens.

**Step 2: Run targeted tests**

Run: `cd mobile && flutter test test/color_contrast_test.dart`
Expected: FAIL for a newly captured violation before its correction.

**Step 3: Apply the smallest correction**

Use `AppTheme.onAccent` for text/icons on `AppTheme.accent`; use a dark foreground when white surfaces are unavoidable, or retain the existing dark surface and remove the inappropriate white foreground. Do not globally replace white or alter the palette.

**Step 4: Run targeted tests again**

Run: `cd mobile && flutter test test/color_contrast_test.dart`
Expected: PASS.

### Task 4: Verify app-wide behavior and tooling

**Files:**
- Verify: `mobile/lib/**/*.dart`
- Verify: `mobile/test/color_contrast_test.dart`

**Step 1: Repeat source audit**

Run: `cd mobile && rg -n 'AppTheme\\.accent|0xFF(E9FE5C|FFFF|FFFFFF|FFC107)|Colors\\.(white|amber|yellow)' lib`
Expected: remaining matches are documented valid combinations or non-text decorative/status colors.

**Step 2: Run all Flutter tests**

Run: `cd mobile && flutter test`
Expected: all tests pass.

**Step 3: Analyze Dart sources**

Run: `cd mobile && flutter analyze`
Expected: no new analyzer errors from these changes.
