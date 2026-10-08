import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'connectivity_service.dart';
import 'local_database_service.dart';

/// Result of a sync attempt.
class SyncResult {
  final int succeeded;
  final int failed;
  final bool wasOffline;

  const SyncResult({
    this.succeeded = 0,
    this.failed = 0,
    this.wasOffline = false,
  });

  static const offline = SyncResult(wasOffline: true);
}

/// Processes queued offline actions when connectivity is restored
/// and refreshes the local cache from the server.
class SyncService {
  final LocalDatabaseService _localDb;
  final ConnectivityService _connectivity;

  SyncService(this._localDb, this._connectivity);

  String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080';

  /// Replay pending offline actions against the server.
  Future<SyncResult> syncPendingActions(String? token) async {
    if (!_connectivity.isOnline || token == null) return SyncResult.offline;

    final pending = await _localDb.getPendingActions();
    if (pending.isEmpty) return const SyncResult();

    int succeeded = 0;
    int failed = 0;

    for (final action in pending) {
      try {
        final uri = Uri.parse('$_baseUrl${action['endpoint']}');
        final headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        final bodyStr = action['body'] as String?;

        http.Response response;
        if (action['method'] == 'POST') {
          response = await http.post(uri,
              headers: headers, body: bodyStr);
        } else if (action['method'] == 'PUT') {
          response = await http.put(uri,
              headers: headers, body: bodyStr);
        } else if (action['method'] == 'DELETE') {
          response = await http.delete(uri, headers: headers);
        } else {
          // Unsupported method — discard
          await _localDb.removePendingAction(action['id'] as int);
          failed++;
          continue;
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _localDb.removePendingAction(action['id'] as int);
          succeeded++;
        } else if (response.statusCode == 409) {
          // Conflict — server version wins, discard local action
          debugPrint(
              'Sync conflict for ${action['endpoint']} — discarding local action');
          await _localDb.removePendingAction(action['id'] as int);
          failed++;
        } else {
          debugPrint(
              'Sync failed for ${action['endpoint']} — status ${response.statusCode}');
          failed++;
        }
      } catch (e) {
        debugPrint('Sync error for ${action['endpoint']}: $e');
        failed++;
      }
    }

    return SyncResult(succeeded: succeeded, failed: failed);
  }

  /// Pull fresh data from server and update local cache.
  Future<void> refreshCache(String? token) async {
    if (!_connectivity.isOnline || token == null) return;

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    // Cache playlists
    try {
      final playlistResp = await http.get(
        Uri.parse('$_baseUrl/api/playlists/my'),
        headers: headers,
      );
      if (playlistResp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(playlistResp.bodyBytes));
        if (data is List) {
          await _localDb.cachePlaylists(
              List<Map<String, dynamic>>.from(data));
        }
      }
    } catch (e) {
      debugPrint('Cache refresh (playlists) failed: $e');
    }

    // Cache events
    try {
      final eventResp = await http.get(
        Uri.parse('$_baseUrl/api/events'),
        headers: headers,
      );
      if (eventResp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(eventResp.bodyBytes));
        if (data is List) {
          await _localDb
              .cacheEvents(List<Map<String, dynamic>>.from(data));
        } else if (data is Map && data['events'] is List) {
          await _localDb.cacheEvents(
              List<Map<String, dynamic>>.from(data['events']));
        }
      }
    } catch (e) {
      debugPrint('Cache refresh (events) failed: $e');
    }
  }
}
