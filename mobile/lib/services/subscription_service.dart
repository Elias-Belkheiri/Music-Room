import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SubscriptionService {
  String get _effectiveBaseUrl {
    final url = dotenv.env['API_URL'];
    if (url != null && url.isNotEmpty) {
      if (url.contains('localhost') && !kIsWeb && Platform.isAndroid) {
        return url.replaceAll('localhost', '10.0.2.2');
      }
      return url;
    }
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  static const String _subPath = '/api/subscription';

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'MusicRoomApp/1.0',
        'ngrok-skip-browser-warning': 'true',
      };

  /// Fetches subscription status for the current user
  Future<Map<String, dynamic>> getStatus(String token) async {
    final response = await http.get(
      Uri.parse('$_effectiveBaseUrl$_subPath/status'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load subscription status: ${response.statusCode}');
    }
  }

  /// Upgrades user to premium
  Future<Map<String, dynamic>> upgrade(String token, {String duration = 'monthly'}) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_subPath/upgrade'),
      headers: _headers(token),
      body: jsonEncode({'duration': duration, 'tier': 'premium'}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to upgrade subscription: ${response.statusCode}');
    }
  }

  /// Downgrades user to free
  Future<Map<String, dynamic>> downgrade(String token) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl$_subPath/downgrade'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to downgrade subscription: ${response.statusCode}');
    }
  }

  /// Fetches available plans
  Future<List<Map<String, dynamic>>> getPlans() async {
    final response = await http.get(
      Uri.parse('$_effectiveBaseUrl$_subPath/plans'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
      return [];
    } else {
      throw Exception('Failed to load plans: ${response.statusCode}');
    }
  }
}
