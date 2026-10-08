import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global singleton that monitors network reachability.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal() {
    // Restore the debug override (used on simulators where airplane mode
    // / wifi toggle is unavailable) so services see it even before the
    // provider is created.
    SharedPreferences.getInstance().then((prefs) {
      _debugForceOffline =
          prefs.getBool(debugForceOfflineKey) ?? false;
      _controller.add(isOnline);
    });
    _connectivity.onConnectivityChanged.listen((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      _controller.add(isOnline);
    });
  }

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  /// Debug-only override for simulators where airplane mode / wifi toggle
  /// is unavailable. When true, the app behaves as offline even though the
  /// OS reports connectivity.
  static const String debugForceOfflineKey = 'debug_force_offline';
  bool _debugForceOffline = false;

  /// Live stream of connectivity changes.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Current connectivity state (synchronous read).
  /// False when the OS reports no connectivity OR the debug override is on.
  bool get isOnline => _isOnline && !_debugForceOffline;

  bool get debugForceOffline => _debugForceOffline;

  Future<void> setDebugForceOffline(bool value) async {
    _debugForceOffline = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(debugForceOfflineKey, value);
    } catch (_) {}
    _controller.add(isOnline);
  }

  /// One-shot check — also updates the cached [isOnline] value.
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    return isOnline;
  }

  void dispose() => _controller.close();
}
