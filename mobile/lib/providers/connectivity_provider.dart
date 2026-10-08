import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';
import '../services/local_database_service.dart';
import '../services/sync_service.dart';

/// Provides reactive connectivity state to the widget tree.
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService = ConnectivityService();
  late final LocalDatabaseService _localDb;
  late final SyncService _syncService;
  StreamSubscription<bool>? _sub;

  bool _isOnline = true;
  int _pendingCount = 0;

  /// Debug-only override lives on [ConnectivityService] (single source of
  /// truth) so that services gate writes on it too, not just the banner.
  bool get isOnline => _connectivityService.isOnline;
  int get pendingCount => _pendingCount;
  bool get debugForceOffline => _connectivityService.debugForceOffline;

  ConnectivityProvider() {
    _localDb = LocalDatabaseService();
    _syncService = SyncService(_localDb, _connectivityService);

    _connectivityService.checkConnectivity().then((online) {
      _isOnline = online;
      notifyListeners();
    });

    _sub = _connectivityService.onConnectivityChanged.listen((online) {
      _isOnline = online;
      notifyListeners();
      if (online) _onReconnect();
    });

    _refreshPendingCount();
  }

  /// Called automatically when connectivity is restored.
  Future<void> _onReconnect() async {
    debugPrint('Connectivity restored — syncing pending actions…');
    // Token will be injected by whoever triggers sync
    _pendingCount = 0;
    notifyListeners();
  }

  Future<void> setDebugForceOffline(bool value) async {
    await _connectivityService.setDebugForceOffline(value);
    _isOnline = _connectivityService.isOnline;
    notifyListeners();
  }

  /// Manually trigger sync with an auth token.
  Future<void> syncNow(String? token) async {
    if (!_isOnline || token == null) return;
    final result = await _syncService.syncPendingActions(token);
    debugPrint('Sync complete: ${result.succeeded} ok, ${result.failed} failed');
    await _syncService.refreshCache(token);
    await _refreshPendingCount();
    notifyListeners();
  }

  Future<void> _refreshPendingCount() async {
    _pendingCount = await _localDb.getPendingActionCount();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
