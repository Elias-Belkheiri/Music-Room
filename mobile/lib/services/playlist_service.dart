import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/playlist_model.dart';
import '../models/track_model.dart';
import 'connectivity_service.dart';
import 'local_database_service.dart';

class PlaylistService {
  String get effectiveBaseUrl => _effectiveBaseUrl;

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

  StompClient? _stompClient;
  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'User-Agent': 'MusicRoomApp/1.0',
    'ngrok-skip-browser-warning': 'true',
  };

  // Retrieve current playlists (with offline local DB fallback)
  Future<List<Playlist>> getMyPlaylists(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_effectiveBaseUrl/api/playlists'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        try {
          await LocalDatabaseService().cachePlaylists(
            data.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
        } catch (_) {}
        return data.map((json) => Playlist.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load playlists (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
        );
      }
    } catch (e) {
      // Offline fallback: load cached playlists
      try {
        final cached = await LocalDatabaseService().getCachedPlaylists();
        if (cached.isNotEmpty) {
          return cached.map((json) => Playlist.fromJson(json)).toList();
        }
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Track>> getPlaylistTracks(String playlistId, String token) async {
    final response = await http.get(
      Uri.parse('$_effectiveBaseUrl/api/playlists/$playlistId/tracks'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data
          .map(
            (json) => Track.fromPlaylistTrackJson(json as Map<String, dynamic>),
          )
          .toList();
    }

    throw Exception(
      'Failed to load playlist tracks (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
    );
  }

  Future<void> savePlaylist(String playlistId, String token) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl/api/playlists/$playlistId/save'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save playlist: ${response.body}');
    }
  }

  Future<void> unsavePlaylist(String playlistId, String token) async {
    final response = await http.delete(
      Uri.parse('$_effectiveBaseUrl/api/playlists/$playlistId/save'),
      headers: _headers(token),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to unsave playlist: ${response.body}');
    }
  }

  Future<bool> isPlaylistSaved(String playlistId, String token) async {
    final response = await http.get(
      Uri.parse('$_effectiveBaseUrl/api/playlists/$playlistId/saved'),
      headers: _headers(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as bool;
    }
    return false;
  }

  Future<List<Playlist>> getSavedPlaylists(String token) async {
    final response = await http.get(
      Uri.parse('$_effectiveBaseUrl/api/playlists/saved'),
      headers: _headers(token),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Playlist.fromJson(json)).toList();
    }
    throw Exception('Failed to load saved playlists (${response.statusCode})');
  }

  Future<List<Playlist>> getPublicPlaylistsByUser(
    String userId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$_effectiveBaseUrl/api/playlists/public/user/$userId'),
      headers: _headers(token),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Playlist.fromJson(json)).toList();
    }
    return [];
  }

  // Create a new playlist
  Future<Playlist> createPlaylist(
    String name,
    String description,
    String visibility,
    String token,
  ) async {
    if (!ConnectivityService().isOnline) {
      throw Exception(
        'Offline — playlist creation is unavailable while offline.',
      );
    }
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl/api/playlists'),
      headers: _headers(token),
      body: jsonEncode({
        'name': name,
        'description': description,
        'visibility': visibility,
        'licenseType': 'open',
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return Playlist.fromJson(data);
    } else {
      throw Exception(
        'Failed to create playlist (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
      );
    }
  }

  // Delete a playlist
  Future<void> deletePlaylist(String playlistId, String token) async {
    final response = await http.delete(
      Uri.parse('$_effectiveBaseUrl/api/playlists/$playlistId'),
      headers: _headers(token),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete playlist (${response.statusCode})');
    }
  }

  // Invite user to playlist
  Future<void> inviteUserToPlaylist(
    String playlistId,
    String userId,
    String permission,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$_effectiveBaseUrl/api/playlists/$playlistId/invite'),
      headers: _headers(token),
      body: json.encode({'userId': userId, 'permission': permission}),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to invite user (${response.statusCode})');
    }
  }

  // Add track to playlist using WebSockets
  Future<void> addTrackToPlaylist(
    String playlistId,
    Track track,
    String token,
    int version,
  ) async {
    final completer = Completer<void>();

    if (_stompClient != null && _stompClient!.isActive) {
      _sendAddTrackMessage(playlistId, track, token, version);
      completer.complete();
      return completer.future;
    }

    final wsUrl = _effectiveBaseUrl.replaceFirst('http', 'ws') + '/ws';

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (StompFrame frame) {
          _sendAddTrackMessage(playlistId, track, token, version);
          if (!completer.isCompleted) {
            completer.complete();
          }

          // Disconnect after sending (or keep it open for other things)
          Future.delayed(const Duration(seconds: 2), () {
            _stompClient?.deactivate();
            _stompClient = null;
          });
        },
        onStompError: (frame) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception(
                frame.body ?? 'WebSocket STOMP error while adding track',
              ),
            );
          }
        },
        onWebSocketError: (dynamic error) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('WebSocket error: $error'));
          }
        },
        onDisconnect: (frame) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('WebSocket disconnected before track add'),
            );
          }
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );

    _stompClient!.activate();
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () =>
          throw Exception('Timed out while adding track to playlist'),
    );
  }

  void _sendAddTrackMessage(
    String playlistId,
    Track track,
    String token,
    int version,
  ) {
    if (_stompClient == null) return;

    _stompClient!.send(
      destination: '/app/playlist/$playlistId/add',
      headers: {'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'externalId': track.id,
        'provider': 'audius', // or fallback
        'title': track.title,
        'artist': track.artistName,
        'album': '',
        'coverUrl': track.imageUrl ?? '',
        'durationMs': track.durationMs,
        'version': version,
      }),
    );
  }

  // Remove track from playlist using WebSockets
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String playlistTrackId,
    String token,
    int version,
  ) async {
    final completer = Completer<void>();

    if (_stompClient != null && _stompClient!.isActive) {
      _sendRemoveTrackMessage(playlistId, playlistTrackId, token, version);
      completer.complete();
      return completer.future;
    }

    final wsUrl = _effectiveBaseUrl.replaceFirst('http', 'ws') + '/ws';

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (StompFrame frame) {
          _sendRemoveTrackMessage(playlistId, playlistTrackId, token, version);
          if (!completer.isCompleted) {
            completer.complete();
          }

          Future.delayed(const Duration(seconds: 2), () {
            _stompClient?.deactivate();
            _stompClient = null;
          });
        },
        onStompError: (frame) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception(
                frame.body ?? 'WebSocket STOMP error while removing track',
              ),
            );
          }
        },
        onWebSocketError: (dynamic error) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('WebSocket error: $error'));
          }
        },
        onDisconnect: (frame) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('WebSocket disconnected before track remove'),
            );
          }
        },
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );

    _stompClient!.activate();
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () =>
          throw Exception('Timed out while removing track from playlist'),
    );
  }

  void _sendRemoveTrackMessage(
    String playlistId,
    String playlistTrackId,
    String token,
    int version,
  ) {
    if (_stompClient == null) return;

    _stompClient!.send(
      destination: '/app/playlist/$playlistId/remove',
      headers: {'Authorization': 'Bearer $token'},
      body: jsonEncode({'trackId': playlistTrackId, 'version': version}),
    );
  }

  Future<Playlist> getPlaylistById(String playlistId, String token) async {
    final response = await http.get(
      Uri.parse('$_effectiveBaseUrl/api/playlists/$playlistId'),
      headers: _headers(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return Playlist.fromJson(data);
    } else {
      throw Exception(
        'Failed to load playlist (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
      );
    }
  }

  // Update playlist visibility
  Future<Playlist> updatePlaylistVisibility(
    String playlistId,
    String visibility,
    String token,
  ) async {
    final response = await http.put(
      Uri.parse('$_effectiveBaseUrl/api/playlists/$playlistId'),
      headers: _headers(token),
      body: jsonEncode({'visibility': visibility}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return Playlist.fromJson(data);
    } else {
      throw Exception(
        'Failed to update playlist visibility (${response.statusCode}): ${utf8.decode(response.bodyBytes)}',
      );
    }
  }

  // Get all collaborators
  Future<List<dynamic>> getPlaylistCollaborators(
    String playlistId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$_effectiveBaseUrl/api/playlists/$playlistId/collaborators'),
      headers: _headers(token),
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    }
    throw Exception('Failed to load collaborators (${response.statusCode})');
  }

  // Update collaborator role
  Future<void> updateCollaboratorRole(
    String playlistId,
    String collaboratorId,
    String permission,
    String token,
  ) async {
    final response = await http.put(
      Uri.parse(
        '$_effectiveBaseUrl/api/playlists/$playlistId/collaborators/$collaboratorId',
      ),
      headers: _headers(token),
      body: jsonEncode({'permission': permission}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update role (${response.statusCode})');
    }
  }

  // Remove collaborator
  Future<void> removeCollaborator(
    String playlistId,
    String collaboratorId,
    String token,
  ) async {
    final response = await http.delete(
      Uri.parse(
        '$_effectiveBaseUrl/api/playlists/$playlistId/collaborators/$collaboratorId',
      ),
      headers: _headers(token),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to remove collaborator (${response.statusCode})');
    }
  }
}
