import 'package:flutter/material.dart';
import '../models/user_profile_model.dart';
import '../services/user_service.dart';
import '../services/follow_service.dart';
import 'auth_provider.dart';

class UserProfileProvider with ChangeNotifier {
  final UserService _userService = UserService();
  AuthProvider? _authProvider;

  void updateAuthProvider(AuthProvider auth) {
    _authProvider = auth;
  }

  UserProfileModel? _profile;
  List<Map<String, dynamic>> _userEvents = [];
  int _friendsCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfileModel? get profile => _profile;
  List<Map<String, dynamic>> get userEvents => _userEvents;
  int get playlistsCount => _userEvents.length;
  int get friendsCount => _friendsCount;
  int get followersCount => _followersCount;
  int get followingCount => _followingCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<T> _withAuthRetry<T>(Future<T> Function(String token) action) async {
    final auth = _authProvider;
    if (auth == null) {
      throw Exception('AuthProvider not initialized');
    }
    String currentToken = auth.currentUser?.accessToken ?? '';
    try {
      return await action(currentToken);
    } catch (e) {
      // Only 401/403 mean the access token is bad. A 404 (or anything
      // else) is a real backend response — refreshing the token for it is
      // wrong and can even log the user out when the refresh fails.
      if (e.toString().contains('401') || e.toString().contains('403')) {
        final success = await auth.refreshTokens();
        if (success) {
          currentToken = auth.currentUser?.accessToken ?? '';
          return await action(currentToken);
        }
      }
      rethrow;
    }
  }

  Future<void> fetchProfile(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _withAuthRetry((activeToken) async {
        _profile = await _userService.getCurrentUserProfile(activeToken);
        if (_profile != null && _profile!.id.isNotEmpty) {
          final results = await Future.wait([
            _userService.getUserEvents(activeToken, _profile!.id),
            _userService.getUserFriendsCount(activeToken),
            FollowService().getFollowers(_profile!.id, activeToken),
            FollowService().getFollowing(_profile!.id, activeToken),
          ]);
          _userEvents = results[0] as List<Map<String, dynamic>>;
          _friendsCount = results[1] as int;
          _followersCount = (results[2] as List).length;
          _followingCount = (results[3] as List).length;
        }
      });
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(
    String token,
    String newDisplayName,
    String? newAvatarUrl, {
    Map<String, dynamic>? publicInfo,
    Map<String, dynamic>? privateInfo,
    Map<String, dynamic>? friendsInfo,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updateData = <String, dynamic>{
        // Never send an empty display name: it would wipe the server-side
        // name when the local profile hasn't loaded yet.
        if (newDisplayName.trim().isNotEmpty) 'displayName': newDisplayName.trim(),
        if (newAvatarUrl != null && newAvatarUrl.isNotEmpty) 'avatarUrl': newAvatarUrl,
        if (publicInfo != null) 'publicInfo': publicInfo,
        if (privateInfo != null) 'privateInfo': privateInfo,
        if (friendsInfo != null) 'friendsInfo': friendsInfo,
      };

      await _withAuthRetry((activeToken) async {
        _profile = await _userService.updateUserProfile(activeToken, updateData);
      });
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

  Future<bool> updatePreferences(
    String token, // Original token Param is kept so signature matches UI calls, but we ignore it inside.
    Map<String, dynamic> newPreferences,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _withAuthRetry((activeToken) async {
        _profile = await _userService.updateUserPreferences(activeToken, newPreferences);
      });
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
