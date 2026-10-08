import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
/// Handles all HTTP communication with the authentication backend.
/// Base URL points to the backend API.
class AuthService {
  // Get base URL from .env file
  String get _effectiveBaseUrl {
    return '${dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080'}';
  }

  static const String _authPath = '/api/auth';
  /// POST /login
  /// Returns the full parsed response body.
  /// Throws [AuthException] on failure.
// import 'dart:io' show Platform;
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:package_info_plus/package_info_plus.dart';

Future<Map<String, dynamic>> login({
  required String email,
  required String password,
}) async {
  // Gather device info
  final deviceData = await _getDeviceInfo();

  final response = await http.post(
    Uri.parse('$_effectiveBaseUrl$_authPath/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'deviceName': deviceData['deviceName'],   // e.g. "Samsung Galaxy S21"
      'platform': deviceData['platform'],        // e.g. "Android"
      'appVersion': deviceData['appVersion'],    // e.g. "1.0.0"
    }),
  );

  final decoded = _decodeBody(response.body);
  final body = _toMap(decoded);

  if (response.statusCode != 200) {
    throw AuthException(_extractErrorMessage(decoded, 'Login failed'));
  }

  return body;
}

Future<Map<String, String>> _getDeviceInfo() async {
  final deviceInfo = DeviceInfoPlugin();
  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = packageInfo.version; // e.g. "1.2.3"

  if (kIsWeb) {
    return {
      'deviceName': 'Web Browser',
      'platform': 'Web',
      'appVersion': appVersion,
    };
  }

  if (Platform.isAndroid) {
    final android = await deviceInfo.androidInfo;
    return {
      'deviceName': '${android.manufacturer} ${android.model}', // "Samsung Galaxy S21"
      'platform': 'Android',
      'appVersion': appVersion,
    };
  } else if (Platform.isIOS) {
    final ios = await deviceInfo.iosInfo;
    return {
      'deviceName': ios.name,        // "John's iPhone"
      'platform': 'iOS',
      'appVersion': appVersion,
    };
  }

  // Fallback (desktop/web)
  return {
    'deviceName': 'Unknown Device',
    'platform': Platform.operatingSystem,
    'appVersion': appVersion,
  };
}
  /// POST /signup
  /// Returns the full parsed response body (includes token).
  /// Throws [AuthException] on failure.
  Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_authPath/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'displayname': fullName,
        'email': email,
        'password': password,
      }),
    );

    final decoded = _decodeBody(response.body);
    final body = _toMap(decoded);

    if (response.statusCode != 200) {
      throw AuthException(_extractErrorMessage(decoded, 'Signup failed'));
    }

    return body;
  }

  /// POST /verify-otp
  /// Verifies a user account using the OTP from signup.
  /// Returns the response body which now includes tokens.
  /// Throws [AuthException] on failure.
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_authPath/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'verificationCode': otp}),
    );

    final decoded = _decodeBody(response.body);
    final body = _toMap(decoded);

    if (response.statusCode != 200) {
      throw AuthException(_extractErrorMessage(decoded, 'Verification failed'));
    }

    return body;
  }

  /// POST /resend-otp
  /// Generates and sends a new OTP for an unverified user.
  /// Throws [AuthException] on failure.
  Future<void> resendOtp({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_authPath/send-verification-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final decoded = _decodeBody(response.body);

    if (response.statusCode != 200) {
      throw AuthException(
        _extractErrorMessage(decoded, 'Failed to resend OTP'),
      );
    }
  }

  /// POST /forgot-password
  /// Requests an OTP for password reset.
  /// Throws [AuthException] on failure.
  Future<void> forgotPassword({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_authPath/send-verification-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final decoded = _decodeBody(response.body);

    if (response.statusCode != 200) {
      throw AuthException(
        _extractErrorMessage(decoded, 'Failed to request password reset'),
      );
    }
  }

  /// POST /verify-reset-otp
  /// Verifies the OTP for password reset.
  /// Throws [AuthException] on failure.
  Future<void> verifyResetOtp({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_authPath/verify-email-password-reset'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'verificationCode': otp}),
    );

    final decoded = _decodeBody(response.body);

    if (response.statusCode != 200) {
      throw AuthException(_extractErrorMessage(decoded, 'Verification failed'));
    }
  }

  /// POST /reset-password
  /// Resets the user's password and returns tokens.
  /// Throws [AuthException] on failure.
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_authPath/Password-reset-change'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'verificationCode': otp,
        'newPassword': newPassword,
      }),
    );

    final decoded = _decodeBody(response.body);

    if (response.statusCode != 200) {
      throw AuthException(
        _extractErrorMessage(decoded, 'Failed to reset password'),
      );
    }

  }

  /// POST /auth/google
  /// Sends Google profile data to the backend for login/auto-registration.
  /// Returns the full response body (includes user, accessToken, refreshToken).
  /// Throws [AuthException] on failure.
  Future<Map<String, dynamic>> googleSignIn({
    required String idToken,
  }) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_authPath/google-login'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
    );

    final decoded = _decodeBody(response.body);
    final body = _toMap(decoded);

    if (response.statusCode != 200) {
      throw AuthException(_extractErrorMessage(decoded, 'Google sign-in failed'));
    }

    return body;
  }

  /// POST /refresh
  /// Uses the refresh token to get a new access token.
  /// Returns the new tokens.
  /// Throws [AuthException] on failure.
  Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_authPath/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    final decoded = _decodeBody(response.body);
    final body = _toMap(decoded);

    if (response.statusCode != 200) {
      throw AuthException(_extractErrorMessage(decoded, 'Token refresh failed'));
    }

    return body;
  }

  dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  Map<String, dynamic> _toMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{'message': decoded.toString()};
  }

  String _extractErrorMessage(dynamic decoded, String fallback) {
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final message = map['message'];
      if (message is String && message.trim().isNotEmpty) return message;

      final error = map['error'];
      if (error is String && error.trim().isNotEmpty) return error;

      final detail = map['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;

      final errors = map['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is String && first.trim().isNotEmpty) return first;
        if (first is Map) {
          final firstMap = Map<String, dynamic>.from(first);
          final firstMsg = firstMap['message'];
          if (firstMsg is String && firstMsg.trim().isNotEmpty) {
            return firstMsg;
          }
          final firstDefault = firstMap['defaultMessage'];
          if (firstDefault is String && firstDefault.trim().isNotEmpty) {
            return firstDefault;
          }
        }
      }
    }

    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded;
    }

    return fallback;
  }
}

/// Custom exception for auth-related errors.
/// Carries a user-friendly message from the backend.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
