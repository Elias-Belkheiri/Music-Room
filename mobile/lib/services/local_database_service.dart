import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite cache for offline playlists, events, and pending actions.
class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;
  final Map<String, List<Map<String, dynamic>>> _memoryCache = {};

  Future<Database?> get database async {
    if (kIsWeb) return null;
    _database ??= await _initDB();
    return _database;
  }

  Future<Database?> _initDB() async {
    if (kIsWeb) return null;
    final dbPath = join(await getDatabasesPath(), 'musicroom_cache.db');
    return openDatabase(dbPath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cached_playlists (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cached_events (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        body TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        last_synced_at INTEGER NOT NULL
      )
    ''');
  }

  // ── Playlist Cache ──────────────────────────────────────────────────────

  Future<void> cachePlaylists(List<Map<String, dynamic>> playlists) async {
    final db = await database;
    if (db == null) {
      _memoryCache['playlists'] = List.from(playlists);
      return;
    }
    final batch = db.batch();
    batch.delete('cached_playlists');
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in playlists) {
      batch.insert('cached_playlists', {
        'id': p['id']?.toString() ?? '',
        'data': jsonEncode(p),
        'cached_at': now,
      });
    }
    await batch.commit(noResult: true);
    await _updateSyncMeta('playlists');
  }

  Future<List<Map<String, dynamic>>> getCachedPlaylists() async {
    final db = await database;
    if (db == null) {
      return _memoryCache['playlists'] ?? [];
    }
    final rows = await db.query('cached_playlists', orderBy: 'cached_at DESC');
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  // ── Event Cache ─────────────────────────────────────────────────────────

  Future<void> cacheEvents(List<Map<String, dynamic>> events) async {
    final db = await database;
    if (db == null) {
      _memoryCache['events'] = List.from(events);
      return;
    }
    final batch = db.batch();
    batch.delete('cached_events');
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final e in events) {
      batch.insert('cached_events', {
        'id': e['id']?.toString() ?? '',
        'data': jsonEncode(e),
        'cached_at': now,
      });
    }
    await batch.commit(noResult: true);
    await _updateSyncMeta('events');
  }

  Future<List<Map<String, dynamic>>> getCachedEvents() async {
    final db = await database;
    if (db == null) {
      return _memoryCache['events'] ?? [];
    }
    final rows = await db.query('cached_events', orderBy: 'cached_at DESC');
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  // ── Pending Actions Queue ───────────────────────────────────────────────

  Future<void> queueAction({
    required String actionType,
    required String endpoint,
    required String method,
    String? body,
  }) async {
    final db = await database;
    if (db == null) return;
    await db.insert('pending_actions', {
      'action_type': actionType,
      'endpoint': endpoint,
      'method': method,
      'body': body,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final db = await database;
    if (db == null) return [];
    return db.query('pending_actions', orderBy: 'created_at ASC');
  }

  Future<void> removePendingAction(int id) async {
    final db = await database;
    if (db == null) return;
    await db.delete('pending_actions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getPendingActionCount() async {
    final db = await database;
    if (db == null) return 0;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM pending_actions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Staleness ───────────────────────────────────────────────────────────

  Future<bool> isStale(String key,
      {Duration maxAge = const Duration(hours: 1)}) async {
    final db = await database;
    if (db == null) return true;
    final rows =
        await db.query('sync_metadata', where: '"key" = ?', whereArgs: [key]);
    if (rows.isEmpty) return true;
    final lastSynced = rows.first['last_synced_at'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - lastSynced;
    return age > maxAge.inMilliseconds;
  }

  Future<void> _updateSyncMeta(String key) async {
    final db = await database;
    if (db == null) return;
    await db.insert(
      'sync_metadata',
      {'key': key, 'last_synced_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
