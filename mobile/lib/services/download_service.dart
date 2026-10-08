import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track_model.dart';

class DownloadService {
  static const String _downloadedTracksKey = 'downloaded_tracks_metadata';

  // Singleton instance
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  // Get path where downloaded music is stored
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/offline_music';
  }

  // Create folder if it doesn't exist
  Future<Directory> get _localFolder async {
    final path = await _localPath;
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  // Download track audio and save metadata
  Future<bool> downloadTrack(Track track, {Function(double progress)? onProgress}) async {
    // No filesystem on web — downloads unsupported, stream only.
    if (kIsWeb) return false;
    if (track.audioUrl == null || track.audioUrl!.isEmpty) return false;

    try {
      final folder = await _localFolder;
      final file = File('${folder.path}/${track.id}.mp3');

      // Download file bytes
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(track.audioUrl!));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        client.close();
        return false;
      }

      final int totalLength = response.contentLength ?? 0;
      int downloaded = 0;
      
      // Open the file sink to write bytes on the fly
      final sink = file.openWrite();

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          if (totalLength > 0 && onProgress != null) {
            onProgress(downloaded / totalLength);
          }
        }
      } finally {
        await sink.close();
        client.close();
      }

      // Save metadata to SharedPreferences
      await _saveTrackMetadata(track);
      return true;
    } catch (e) {
      print("Download failed: $e");
      return false;
    }
  }

  // Check if a track is downloaded locally
  Future<bool> isTrackDownloaded(String trackId) async {
    if (kIsWeb) return false;
    final folder = await _localPath;
    final file = File('$folder/$trackId.mp3');
    return await file.exists();
  }

  // Get local file path for a track
  Future<String?> getLocalTrackPath(String trackId) async {
    // Web has no local files — always stream, never throw (path_provider
    // is unsupported on web and would break playback for every track).
    if (kIsWeb) return null;
    final folder = await _localPath;
    final file = File('$folder/$trackId.mp3');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  // Delete downloaded track
  Future<void> deleteTrack(String trackId) async {
    if (!kIsWeb) {
      final folder = await _localPath;
      final file = File('$folder/$trackId.mp3');
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _removeTrackMetadata(trackId);
  }

  // Save metadata list
  Future<void> _saveTrackMetadata(Track track) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getDownloadedTracks();
    
    // Avoid duplicates
    list.removeWhere((t) => t.id == track.id);
    list.add(track);

    final jsonList = list.map((t) => {
      'id': t.id,
      'title': t.title,
      'artistName': t.artistName,
      'imageUrl': t.imageUrl,
      'durationMs': t.durationMs,
    }).toList();

    await prefs.setString(_downloadedTracksKey, jsonEncode(jsonList));
  }

  Future<void> _removeTrackMetadata(String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getDownloadedTracks();
    list.removeWhere((t) => t.id == trackId);
    
    final jsonList = list.map((t) => {
      'id': t.id,
      'title': t.title,
      'artistName': t.artistName,
      'imageUrl': t.imageUrl,
      'durationMs': t.durationMs,
    }).toList();

    await prefs.setString(_downloadedTracksKey, jsonEncode(jsonList));
  }

  // Retrieve list of downloaded tracks (self-healing: only returns physically existing files)
  Future<List<Track>> getDownloadedTracks() async {
    // No downloadable files on web.
    if (kIsWeb) return [];
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_downloadedTracksKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final folder = await _localPath;
      final List<Track> tracks = [];

      for (final item in decoded) {
        final trackId = item['id']?.toString() ?? '';
        final file = File('$folder/$trackId.mp3');
        if (await file.exists()) {
          tracks.add(Track(
            id: trackId,
            title: item['title']?.toString() ?? '',
            artistName: item['artistName']?.toString() ?? 'Unknown Artist',
            imageUrl: item['imageUrl']?.toString(),
            durationMs: item['durationMs'] as int?,
            isStreamable: true,
          ));
        }
      }
      return tracks;
    } catch (e) {
      print("Error decoding downloaded tracks: $e");
      return [];
    }
  }
}
