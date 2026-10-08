import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicroom/config/app_theme.dart';
import 'package:musicroom/widgets/acid/acid_bottom_nav.dart';

void main() {
  group('accent contrast', () {
    test('dark on-accent foreground meets WCAG AA on accent yellow', () {
      expect(
        _contrastRatio(AppTheme.onAccent, AppTheme.accent),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('active bottom navigation icon uses on-accent foreground', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: AcidBottomNav(selectedIndex: 1, onTap: (_) {})),
        ),
      );

      final activeIcon = tester.widget<Icon>(
        find.byIcon(Icons.play_arrow_rounded),
      );
      expect(activeIcon.color, AppTheme.onAccent);
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
