import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/playlist_model.dart';
import '../models/track_model.dart';

class AudiusService {
  static const String baseUrl = 'https://discoveryprovider.audius.co/v1';
  static const String appName = 'MusicRoomApp';

  Uri _buildUri(String path, [Map<String, String>? params]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: {
      'app_name': appName,
      ...?params,
    });
  }

  /// Only tracks that can actually be streamed via
  /// `/v1/tracks/{id}/stream` may enter the app. In particular Audius
  /// stream-gated tracks report `is_streamable: true` but answer the
  /// stream endpoint with 403 `track not streamable`, which surfaces on
  /// iOS as AVPlayer (-1102) "permission denied" and a stuck 00:00 queue.
  bool _isPlayable(Track track) {
    return track.isStreamable &&
        !track.isStreamGated &&
        track.audioUrl != null &&
        track.audioUrl!.isNotEmpty;
  }

  List<Track> _parsePlayableTracks(List<dynamic> tracksJson) {
    return tracksJson
        .whereType<Map<String, dynamic>>()
        .map(Track.fromJson)
        .where(_isPlayable)
        .toList();
  }

  /// Verifies the stream endpoint actually serves audio (not a 403
  /// `track not streamable` JSON). Used before suggesting a track so
  /// gated/restricted tracks never enter an event queue.
  Future<bool> verifyTrackStreamable(Track track) async {
    if (!_isPlayable(track)) return false;
    try {
      final response = await http
          .get(
            Uri.parse(track.audioUrl!),
            headers: {'Range': 'bytes=0-1'},
          )
          .timeout(const Duration(seconds: 10));
      // Audius answers playable streams with 302 (redirect to content
      // node), 200 or 206. Gated tracks answer 403.
      if (response.statusCode == 403) return false;
      return response.statusCode < 400;
    } catch (_) {
      // On network failure don't block the suggestion; playback will
      // surface the error if the track is truly unplayable.
      return true;
    }
  }

  Future<List<Playlist>> getTrendingPlaylists() async {
    try {
      final response = await http
          .get(_buildUri('/playlists/trending', {'limit': '6'}))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> playlistsJson = data['data'] ?? [];
        return playlistsJson.map((json) => Playlist.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Audius Error (playlists): $e');
      return [];
    }
  }

  Future<List<Track>> getTrendingTracks() async {
    try {
      final response = await http
          .get(_buildUri('/tracks/trending', {'limit': '10'}))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> tracksJson = data['data'] ?? [];
        return _parsePlayableTracks(tracksJson);
      }
      return [];
    } catch (e) {
      print('Audius Error (tracks): $e');
      return [];
    }
  }

  Future<List<Track>> getRandomTracks() async {
    try {
      final response = await http
          .get(_buildUri('/tracks/trending', {'time': 'allTime', 'limit': '50'}))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> tracksJson = data['data'] ?? [];
        final tracks = _parsePlayableTracks(tracksJson);
        tracks.shuffle();
        return tracks.take(10).toList();
      }
      return [];
    } catch (e) {
      print('Audius Error (random tracks): $e');
      return [];
    }
  }

  // Example of using the requested endpoint, although for counting transactions
  // Get a specific playlist by ID
  Future<Playlist?> getPlaylist(String playlistId) async {
    try {
      final response = await http.get(
        _buildUri('/playlists/$playlistId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final playlistJson = data['data'];
        if (playlistJson != null &&
            playlistJson is List &&
            playlistJson.isNotEmpty) {
          return Playlist.fromJson(playlistJson[0]);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching playlist $playlistId: $e');
      return null;
    }
  }

  Future<int> getUsdcTransactionCount(String userId) async {
    try {
      final response = await http.get(
        _buildUri('/users/$userId/transactions/usdc/count'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error fetching USDC transaction count: $e');
      return 0;
    }
  }

  Future<List<Track>> searchTracks(String query) async {
    try {
      final response = await http
          .get(_buildUri('/tracks/search', {'query': query, 'limit': '25'}))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> tracksJson = data['data'] ?? [];
        return _parsePlayableTracks(tracksJson);
      }
      return [];
    } catch (e) {
      print('Audius Error (search): $e');
      return [];
    }
  }

  /// Fetches track data from Audius (videos aren't a distinct type, but we can fetch trending)
  Future<List<Track>> getMusicVideos() async {
    try {
      final response = await http
          .get(_buildUri('/tracks/trending', {'limit': '5'}))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> tracksJson = data['data'] ?? [];
        return _parsePlayableTracks(tracksJson);
      }
      return [];
    } catch (e) {
      print('Audius Error (videos): $e');
      return [];
    }
  }
}
