import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/track_model.dart';
import 'connectivity_service.dart';

class EventService {
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

  String get baseUrl => _effectiveBaseUrl;

  static const String _eventsPath = '/api/events';

  Future<Map<String, dynamic>> createEvent(
    String name,
    String description,
    bool isPrivate,
    String token,
  ) async {
    if (!ConnectivityService().isOnline) {
      throw Exception('Offline — event creation is unavailable while offline.');
    }
    final url = Uri.parse('$_effectiveBaseUrl$_eventsPath');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'visibility': isPrivate ? 'private' : 'public',
      }),
    );

    if (response.statusCode != 201) {
      final errorMsg = response.body.trim().isEmpty
          ? 'Status ${response.statusCode}'
          : response.body;
      throw Exception('Failed to create event: $errorMsg');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> inviteUser(String eventId, String userId, String token) async {
    final url = Uri.parse('$_effectiveBaseUrl$_eventsPath/$eventId/invite');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({'userId': userId, 'role': 'voter'}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to invite user');
    }
  }

  // Get current user role and access for an event
  Future<Map<String, dynamic>> getEventUserRole(
    String eventId,
    String token,
  ) async {
    final url = Uri.parse('$_effectiveBaseUrl$_eventsPath/$eventId/role');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch event role: ${response.statusCode}');
    }
  }

  // Get current event details
  Future<Map<String, dynamic>> getEventById(
    String eventId,
    String token,
  ) async {
    final url = Uri.parse('$_effectiveBaseUrl$_eventsPath/$eventId');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch event details: ${response.statusCode}');
    }
  }

  // Get event playlist
  Future<List<Map<String, dynamic>>> getEventPlaylist(
    String eventId,
    String token,
  ) async {
    final url = Uri.parse('$_effectiveBaseUrl$_eventsPath/$eventId/playlist');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
      return list.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch event playlist: ${response.statusCode}');
    }
  }

  // Suggest track to event
  Future<Map<String, dynamic>> suggestTrack(
    String eventId,
    Track track,
    String token,
  ) async {
    final url = Uri.parse('$_effectiveBaseUrl$_eventsPath/$eventId/playlist');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'externalId': track.id,
        'provider': 'audius',
        'title': track.title,
        'artist': track.artistName,
        'album': '',
        'coverUrl': track.imageUrl ?? '',
        'durationMs': track.durationMs,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } else {
      final errorMsg = response.body.trim().isEmpty
          ? 'Status ${response.statusCode}'
          : response.body;
      throw Exception('Failed to suggest track: $errorMsg');
    }
  }

  // Remove track from event playlist
  Future<void> removeTrack(String eventId, String entryId, String token) async {
    final url = Uri.parse(
      '$_effectiveBaseUrl$_eventsPath/$eventId/playlist/$entryId',
    );
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      final errorMsg = response.body.trim().isEmpty
          ? 'Status ${response.statusCode}'
          : response.body;
      throw Exception('Failed to remove track: $errorMsg');
    }
  }

  Future<void> updateEventSettings(
    String eventId,
    String name,
    String description,
    bool isPrivate,
    String token,
  ) async {
    final url = Uri.parse('$_effectiveBaseUrl$_eventsPath/$eventId');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'visibility': isPrivate ? 'private' : 'public',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update event settings');
    }
  }

  Future<List<Map<String, dynamic>>> getEventCollaborators(
    String eventId,
    String token,
  ) async {
    final url = Uri.parse(
      '$_effectiveBaseUrl$_eventsPath/$eventId/collaborators',
    );
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
      return list.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch event collaborators');
    }
  }

  Future<List<Map<String, dynamic>>> getEventListeners(
    String eventId,
    String token,
  ) async {
    final url = Uri.parse('$_effectiveBaseUrl$_eventsPath/$eventId/listeners');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
      return list.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch event listeners');
    }
  }

  Future<void> updateCollaboratorRole(
    String eventId,
    String collaboratorId,
    String role,
    String token,
  ) async {
    final url = Uri.parse(
      '$_effectiveBaseUrl$_eventsPath/$eventId/collaborators/$collaboratorId/role?role=$role',
    );
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update collaborator role');
    }
  }

  Future<void> removeCollaborator(
    String eventId,
    String collaboratorId,
    String token,
  ) async {
    final url = Uri.parse(
      '$_effectiveBaseUrl$_eventsPath/$eventId/collaborators/$collaboratorId',
    );
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to remove collaborator');
    }
  }

  // Check if event playback is active
  Future<Map<String, dynamic>> getPlaybackStatus(
    String eventId,
    String token,
  ) async {
    final url = Uri.parse(
      '$_effectiveBaseUrl$_eventsPath/$eventId/playback-status',
    );
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } else {
      throw Exception(
        'Failed to fetch playback status: ${response.statusCode}',
      );
    }
  }

  /// Find active public events near a geographic / beacon location (Bonus VI.2)
  Future<List<Map<String, dynamic>>> getNearbyEvents({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    String? token,
  }) async {
    final url = Uri.parse(
      '$_effectiveBaseUrl$_eventsPath/nearby?lat=$lat&lng=$lng&radiusKm=$radiusKm',
    );
    final headers = {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else {
      throw Exception('Failed to fetch nearby events: ${response.statusCode}');
    }
  }
}
