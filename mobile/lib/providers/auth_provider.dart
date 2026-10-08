import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Authentication status enum used by the router to determine which
/// screen stack to display.
enum AuthStatus { loading, authenticated, unauthenticated }

/// Custom exception for unverified user flow
class UserNotVerifiedException implements Exception {
  const UserNotVerifiedException();
}

/// Central auth state manager.
/// The RouterDelegate listens to this provider and rebuilds the
/// navigation stack whenever [authStatus] changes.
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _authStatus = AuthStatus.loading;
  UserModel? _currentUser;
  String? _errorMessage;
  bool _isBusy = false; // true while an HTTP request is in-flight

  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSub;
  bool _isProcessingGoogleAuth = false;

  AuthProvider() {
    _initGoogleSignInListener();
  }

  void _initGoogleSignInListener() {
    try {
      _googleAuthSub = GoogleSignIn.instance.authenticationEvents.listen(
        (event) async {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            await _handleGoogleSignInSuccess(event.user);
          }
        },
        onError: (error) {
          debugPrint('Google Sign-In stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Could not initialize Google Sign-In listener: $e');
    }
  }

  @override
  void dispose() {
    _googleAuthSub?.cancel();
    super.dispose();
  }

  // ── Getters ───────────────────────────────────────────────────────────
  AuthStatus get authStatus => _authStatus;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _isBusy;

  // ── SharedPreferences key ─────────────────────────────────────────────
  static const String _userKey = 'current_user';

  // ── Check Session ─────────────────────────────────────────────────────
  /// Called on app launch from the splash screen.
  /// Reads persisted user data from SharedPreferences.
  Future<void> checkSession() async {
    _authStatus = AuthStatus.loading;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);

    if (userData != null) {
      _currentUser = UserModel.decode(userData);
      _authStatus = AuthStatus.authenticated;
    } else {
      _authStatus = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  // ── Login ─────────────────────────────────────────────────────────────
  /// Calls POST /login, persists user on success.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      final response = await _authService.login(
        email: email,
        password: password,
      );

      // Extract user and tokens from response
      final userInfo = response['userInfo'];
      if (userInfo is! Map) {
        throw const AuthException('Unexpected login response from server');
      }
      final userJson = Map<String, dynamic>.from(userInfo);
      final isEmailVerified = _toBool(userJson['emailVerified']);
      if (!isEmailVerified) {
        _isBusy = false;
        notifyListeners();
        throw const UserNotVerifiedException();
      }

      userJson['fullName'] = userJson['displayname'] ?? '';
      userJson['accessToken'] = response['accessToken'];
      userJson['refreshToken'] = response['refreshToken'];
      _currentUser = UserModel.fromJson(userJson);

      // Persist session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, _currentUser!.encode());

      _authStatus = AuthStatus.authenticated;
      _isBusy = false;
      notifyListeners();
      return true;
    } on UserNotVerifiedException {
      _isBusy = false;
      notifyListeners();
      rethrow;
    } on AuthException catch (e) {
      _errorMessage = _mapErrorMessage(e.message);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  /// Calls POST /signup.
  /// Does NOT auto-verify. Returns true on success so UI can navigate to OTP screen.
  Future<bool> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _authService.signup(
        fullName: fullName,
        email: email,
        password: password,
      );

      _isBusy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapErrorMessage(e.message);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ── Verify OTP and Login ──────────────────────────────────────────────
  Future<bool> verifyOtpAndLogin({
    required String email,
    required String otp,
  }) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _authService.verifyOtp(email: email, otp: otp);
      _isBusy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapErrorMessage(e.message);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────────────
  Future<bool> resendOtp({required String email}) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _authService.resendOtp(email: email);
      _isBusy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapErrorMessage(e.message);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────
  Future<bool> forgotPassword({required String email}) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _authService.forgotPassword(email: email);
      _isBusy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapErrorMessage(e.message);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ── Verify Reset OTP ──────────────────────────────────────────────────
  Future<bool> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _authService.verifyResetOtp(email: email, otp: otp);
      _isBusy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapErrorMessage(e.message);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ── Reset Password ────────────────────────────────────────────────────
  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _authService.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
      _isBusy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapErrorMessage(e.message);
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error. Please try again.';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ── Google Sign-In Helpers & Initialization ───────────────────────────
  static const String defaultWebClientId =
      '469783669296-jmg77fa22j04dnik6mrambtc26qccc14.apps.googleusercontent.com';
  static const String defaultIosClientId =
      '469783669296-vrfmrpagvj6tlbijel1olsr3kdl9q1t2.apps.googleusercontent.com';

  static String _readEnv(String key) {
    try {
      if (dotenv.isInitialized) {
        return dotenv.env[key]?.trim() ?? '';
      }
    } catch (_) {}
    return '';
  }

  static String get effectiveWebClientId {
    final fromWeb = _readEnv('GOOGLE_WEB_CLIENT_ID');
    if (fromWeb.isNotEmpty &&
        fromWeb != 'default-web-client-id' &&
        !fromWeb.contains('your-google-web-client-id')) {
      return fromWeb;
    }
    final fromClient = _readEnv('GOOGLE_CLIENT_ID').isNotEmpty
        ? _readEnv('GOOGLE_CLIENT_ID')
        : _readEnv('CLIENT_ID');
    if (fromClient.isNotEmpty &&
        fromClient != 'default-client-id' &&
        !fromClient.contains('your-google-web-client-id')) {
      return fromClient;
    }
    return defaultWebClientId;
  }

  static String? get effectiveIosClientId {
    final fromIos = _readEnv('GOOGLE_IOS_CLIENT_ID');
    if (fromIos.isNotEmpty &&
        fromIos != 'default-ios-client-id' &&
        !fromIos.contains('your-google-ios-client-id')) {
      return fromIos;
    }
    return defaultIosClientId;
  }

  /// Explicitly initialize GoogleSignIn based on the running platform.
  static Future<void> initializeGoogleSignIn() async {
    try {
      final webId = effectiveWebClientId;
      final iosId = effectiveIosClientId;

      // On iOS, Google OAuth strictly requires the serverClientId (audience)
      // to belong to the exact same Google Cloud project as the iOS clientId.
      String serverClientId = webId;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && iosId != null) {
        final iosProject = iosId.split('-').first;
        final webProject = webId.split('-').first;
        if (iosProject != webProject) {
          debugPrint(
            'GoogleSignIn project mismatch: iOS=$iosProject, Web=$webProject. '
            'Falling back to default matching webClientId.',
          );
          serverClientId = defaultWebClientId;
        }
      }

      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb
            ? webId
            : (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                ? iosId
                : null),
        // serverClientId is NOT supported on Web (plugin asserts on it).
        serverClientId: kIsWeb ? null : serverClientId,
      );
    } catch (e) {
      debugPrint('GoogleSignIn.initialize failed: $e');
    }
  }

  Future<bool> _handleGoogleSignInSuccess(GoogleSignInAccount user) async {
    if (_isProcessingGoogleAuth || _authStatus == AuthStatus.authenticated) {
      return true;
    }
    _isProcessingGoogleAuth = true;
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      final googleAuth = await user.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Google sign-in failed: No ID token returned');
      }

      final response = await _authService.googleSignIn(
        idToken: idToken,
      );

      final userJson = Map<String, dynamic>.from(
        response['userInfo'] as Map<String, dynamic>,
      );
      userJson['fullName'] = userJson['displayname'] ?? '';
      userJson['accessToken'] = response['accessToken'] as String? ?? '';
      userJson['refreshToken'] = response['refreshToken'] as String? ?? '';
      _currentUser = UserModel.fromJson(userJson);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, _currentUser!.encode());

      _authStatus = AuthStatus.authenticated;
      _isBusy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapErrorMessage(e.message);
      _isBusy = false;
      notifyListeners();
      return false;
    } on PlatformException catch (e) {
      _errorMessage = _mapGoogleSignInPlatformError(e);
      debugPrint(
        'Google Sign-In platform error: '
        'code=${e.code}, message=${e.message}, details=${e.details}',
      );
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Google Sign-In unexpected error: $e');
      _errorMessage = 'Google sign-in failed: $e';
      _isBusy = false;
      notifyListeners();
      return false;
    } finally {
      _isProcessingGoogleAuth = false;
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────
  /// Launches interactive Google authentication if supported.
  /// On success, persists session and updates authStatus.
  Future<bool> signInWithGoogle() async {
    _errorMessage = null;
    _isBusy = true;
    notifyListeners();

    try {
      await initializeGoogleSignIn();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        if (kIsWeb) {
          // On web, `authenticate()` is unsupported — the GIS renderButton
          // handles the click and completes via authenticationEvents.
          // Fire a One Tap prompt as fallback for taps landing outside the
          // iframe, and return a visible hint instead of failing silently
          // (auth_screen only shows a SnackBar when errorMessage != null).
          try {
            await GoogleSignIn.instance.attemptLightweightAuthentication();
          } catch (_) {}
          _isBusy = false;
          _errorMessage =
              'Opening Google sign-in… if nothing pops up, allow popups / third-party cookies and click the G button again.';
          notifyListeners();
          return false;
        }
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      return await _handleGoogleSignInSuccess(googleUser);
    } on AuthException catch (e) {
      _errorMessage = _mapErrorMessage(e.message);
      _isBusy = false;
      notifyListeners();
      return false;
    } on PlatformException catch (e) {
      _errorMessage = _mapGoogleSignInPlatformError(e);
      debugPrint(
        'Google Sign-In platform error: '
        'code=${e.code}, message=${e.message}, details=${e.details}',
      );
      _isBusy = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Google Sign-In unexpected error: $e');
      _errorMessage = 'Google sign-in failed: $e';
      _isBusy = false;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────
  /// Clears persisted session and resets state.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    _currentUser = null;
    _authStatus = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Refresh Token ─────────────────────────────────────────────────────
  /// Uses the stored refresh token to get a new access token.
  /// If it fails, logs the user out.
  Future<bool> refreshTokens() async {
    if (_currentUser == null || _currentUser!.refreshToken.isEmpty) {
      await logout();
      return false;
    }

    try {
      final response = await _authService.refreshToken(
        refreshToken: _currentUser!.refreshToken,
      );

      final newAccessToken = response['accessToken'];
      final newRefreshToken = response['refreshToken'] ?? _currentUser!.refreshToken;

      if (newAccessToken != null) {
        // Update current user model
        final updatedJson = _currentUser!.toJson();
        updatedJson['accessToken'] = newAccessToken;
        updatedJson['refreshToken'] = newRefreshToken;
        
        _currentUser = UserModel.fromJson(updatedJson);

        // Persist new session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, _currentUser!.encode());
        
        notifyListeners();
        return true;
      } else {
        throw const AuthException('No access token in response');
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      await logout(); // Force re-login if refresh token is expired or invalid
      return false;
    }
  }

  /// Clears any displayed error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('user not found')) {
      return 'Email does not exist';
    }
    return message;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return false;
  }

  String _mapGoogleSignInPlatformError(PlatformException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    if (code.contains('canceled') || code.contains('cancelled')) {
      return 'Google sign-in canceled.';
    }

    // Common Android Google Sign-In config mismatch.
    if (message.contains('developer_error') || message.contains('10')) {
      return 'Google Sign-In configuration error (SHA-1, package name, or client ID mismatch).';
    }

    if (message.contains('network_error') || code.contains('network')) {
      return 'Network error during Google sign-in. Check your internet and try again.';
    }

    if ((e.message ?? '').trim().isNotEmpty) {
      return 'Google sign-in failed: ${e.message}';
    }

    return 'Google sign-in failed. Please try again.';
  }
}
