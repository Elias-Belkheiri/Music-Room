import 'package:flutter/foundation.dart';
import '../services/subscription_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _service = SubscriptionService();

  String _tier = 'free';
  bool _isPremium = false;
  DateTime? _expiresAt;
  DateTime? _startedAt;
  List<Map<String, dynamic>> _plans = [];
  bool _isLoading = false;
  String? _errorMessage;

  String get tier => _tier;
  bool get isPremium => _isPremium;
  DateTime? get expiresAt => _expiresAt;
  DateTime? get startedAt => _startedAt;
  List<Map<String, dynamic>> get plans => _plans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchStatus(String? token) async {
    if (token == null || token.isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await _service.getStatus(token);
      _tier = (status['tier'] ?? 'free').toString().toLowerCase();
      _isPremium = status['isPremium'] == true || _tier == 'premium';
      if (status['expiresAt'] != null) {
        _expiresAt = DateTime.tryParse(status['expiresAt'].toString());
      } else {
        _expiresAt = null;
      }
      if (status['startedAt'] != null) {
        _startedAt = DateTime.tryParse(status['startedAt'].toString());
      } else {
        _startedAt = null;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPlans() async {
    try {
      _plans = await _service.getPlans();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load plans: $e');
    }
  }

  Future<bool> upgrade(String? token, {String duration = 'monthly'}) async {
    if (token == null || token.isEmpty) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await _service.upgrade(token, duration: duration);
      _tier = (status['tier'] ?? 'premium').toString().toLowerCase();
      _isPremium = status['isPremium'] == true || _tier == 'premium';
      if (status['expiresAt'] != null) {
        _expiresAt = DateTime.tryParse(status['expiresAt'].toString());
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> downgrade(String? token) async {
    if (token == null || token.isEmpty) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final status = await _service.downgrade(token);
      _tier = (status['tier'] ?? 'free').toString().toLowerCase();
      _isPremium = false;
      _expiresAt = null;
      _startedAt = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
