import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicroom/widgets/responsive_layout.dart';

void main() {
  group('ResponsiveLayout Tests', () {
    testWidgets('renders mobile widget on screen width < 600', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            mobile: Text('Mobile View'),
            tablet: Text('Tablet View'),
            desktop: Text('Desktop View'),
          ),
        ),
      );

      expect(find.text('Mobile View'), findsOneWidget);
      expect(find.text('Tablet View'), findsNothing);
      expect(find.text('Desktop View'), findsNothing);
    });

    testWidgets('renders tablet widget on screen width between 600 and 1200', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            mobile: Text('Mobile View'),
            tablet: Text('Tablet View'),
            desktop: Text('Desktop View'),
          ),
        ),
      );

      expect(find.text('Tablet View'), findsOneWidget);
      expect(find.text('Mobile View'), findsNothing);
      expect(find.text('Desktop View'), findsNothing);
    });

    testWidgets('renders desktop widget on screen width >= 1200', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            mobile: Text('Mobile View'),
            tablet: Text('Tablet View'),
            desktop: Text('Desktop View'),
          ),
        ),
      );

      expect(find.text('Desktop View'), findsOneWidget);
      expect(find.text('Mobile View'), findsNothing);
      expect(find.text('Tablet View'), findsNothing);
    });

    testWidgets('gridCrossAxisCount returns correct column counts per breakpoint', (tester) async {
      // Mobile
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            expect(ResponsiveLayout.gridCrossAxisCount(context), 2);
            return const SizedBox();
          }),
        ),
      );

      // Tablet
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            expect(ResponsiveLayout.gridCrossAxisCount(context), 3);
            return const SizedBox();
          }),
        ),
      );

      // Desktop
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            expect(ResponsiveLayout.gridCrossAxisCount(context), 4);
            return const SizedBox();
          }),
        ),
      );
      tester.view.resetPhysicalSize();
    });
  });
}
