import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:musicroom/services/sync_service.dart';
import 'package:musicroom/providers/connectivity_provider.dart';
import 'package:musicroom/widgets/offline_banner.dart';

class MockConnectivityProvider extends ChangeNotifier
    implements ConnectivityProvider {
  bool _mockOnline = true;
  int _mockPending = 0;

  @override
  bool get isOnline => _mockOnline;

  @override
  int get pendingCount => _mockPending;

  void setOnline(bool val) {
    _mockOnline = val;
    notifyListeners();
  }

  void setPending(int count) {
    _mockPending = count;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SyncResult Tests', () {
    test('SyncResult defaults and offline constant', () {
      const normal = SyncResult(succeeded: 3, failed: 1);
      expect(normal.succeeded, 3);
      expect(normal.failed, 1);
      expect(normal.wasOffline, isFalse);

      expect(SyncResult.offline.wasOffline, isTrue);
      expect(SyncResult.offline.succeeded, 0);
      expect(SyncResult.offline.failed, 0);
    });
  });

  group('OfflineBanner Widget Tests', () {
    testWidgets('OfflineBanner is hidden when online', (tester) async {
      final mock = MockConnectivityProvider()..setOnline(true);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ConnectivityProvider>.value(
            value: mock,
            child: const Scaffold(
              body: OfflineBanner(),
            ),
          ),
        ),
      );

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.textContaining('Offline'), findsNothing);
    });

    testWidgets('OfflineBanner displays message when offline', (tester) async {
      final mock = MockConnectivityProvider()..setOnline(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ConnectivityProvider>.value(
            value: mock,
            child: const Scaffold(
              body: OfflineBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Offline — changes will sync when connected'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('OfflineBanner displays pending changes count when offline', (tester) async {
      final mock = MockConnectivityProvider()
        ..setOnline(false)
        ..setPending(3);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ConnectivityProvider>.value(
            value: mock,
            child: const Scaffold(
              body: OfflineBanner(),
            ),
          ),
        ),
      );

      expect(find.text('Offline — 3 change(s) pending'), findsOneWidget);
    });
  });
}
