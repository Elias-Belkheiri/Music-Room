import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track_model.dart';
import '../services/connectivity_service.dart';
import '../services/download_service.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Track> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _isPlayerMaximized = false;
  bool _isMuted = false;
  bool _isLiveEvent = false;

  String? _playbackError;
  String? get playbackError => _playbackError;

  VoidCallback? onTrackCompleted;
  Function(String command, int positionMs)? onPlaybackStateChanged;
  Future<void> Function()? onSyncPlayback;

  AudioProvider() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        if (onTrackCompleted != null) {
          onTrackCompleted!();
        } else if (!_isLiveEvent) {
          nextTrack();
        }
      }
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  Track? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length)
      ? _playlist[_currentIndex]
      : null;

  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlayerMaximized => _isPlayerMaximized;
  bool get hasTrack => currentTrack != null;
  bool get isMuted => _isMuted;
  bool get isLiveEvent => _isLiveEvent;

  void maximizePlayer() {
    _isPlayerMaximized = true;
    notifyListeners();
  }

  void minimizePlayer() {
    _isPlayerMaximized = false;
    notifyListeners();
  }

  void clearPlaybackError() {
    _playbackError = null;
    notifyListeners();
  }

  Future<void> _loadAudioSource(Track track, {int seekToMs = 0}) async {
    // 1. Check if Offline Mode is active — either the user-facing setting
    // or actual/simulated loss of connectivity (banner state).
    final prefs = await SharedPreferences.getInstance();
    final isOfflineMode = prefs.getBool('offline_mode') ?? false;
    final effectiveOffline = isOfflineMode || !ConnectivityService().isOnline;

    // 2. Check if track is downloaded
    final localPath = await DownloadService().getLocalTrackPath(track.id);

    if (effectiveOffline && localPath == null) {
      _playbackError = "Offline mode active. Playback is limited to downloaded tracks.";
      notifyListeners();
      throw Exception("Offline mode: track not downloaded");
    }

    // Clear previous errors
    _playbackError = null;

    if (localPath != null) {
      debugPrint("--- AudioProvider: Playing offline file from $localPath");
      if (seekToMs > 0) {
        await _audioPlayer.setFilePath(
          localPath,
          initialPosition: Duration(milliseconds: seekToMs),
        );
      } else {
        await _audioPlayer.setFilePath(localPath);
      }
    } else if (track.audioUrl != null && track.audioUrl!.isNotEmpty) {
      debugPrint("--- AudioProvider: Streaming from online URL ${track.audioUrl}");
      if (seekToMs > 0) {
        await _audioPlayer.setUrl(
          track.audioUrl!,
          initialPosition: Duration(milliseconds: seekToMs),
        );
      } else {
        await _audioPlayer.setUrl(track.audioUrl!);
      }
    } else {
      _playbackError = "This track is not currently streamable.";
      notifyListeners();
      throw Exception("No streamable source or local file found.");
    }
  }

  Future<void> playTrack(
    Track track, {
    List<Track>? playlist,
    int index = 0,
    bool isLiveEvent = false,
    int seekToMs = 0,
  }) async {
    _isLiveEvent = isLiveEvent;
    if (playlist != null) {
      _playlist = playlist;
      _currentIndex = index;
    } else {
      _playlist = [track];
      _currentIndex = 0;
    }

    debugPrint(
      "--- AudioProvider.playTrack: playing track id: ${track.id}, title: ${track.title}, URL: ${track.audioUrl}, isLiveEvent: $isLiveEvent, seekToMs: $seekToMs",
    );

    try {
      await _loadAudioSource(track, seekToMs: seekToMs);
      await _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
      await _audioPlayer.play();
      if (!_isLiveEvent) {
        onPlaybackStateChanged?.call('PLAY', seekToMs);
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
      // Surface the failure to the UI instead of failing silently
      // (mini player listens to playbackError and shows a SnackBar).
      if (_playbackError == null) {
        final msg = e.toString();
        if (msg.contains('Offline mode')) {
          _playbackError =
              "Offline mode active. Playback is limited to downloaded tracks.";
        } else if (msg.contains('-1102') ||
            msg.contains('permission') ||
            msg.contains('403') ||
            msg.contains('not streamable')) {
          // Audius stream-gated tracks answer /stream with 403, which
          // iOS AVPlayer reports as (-1102) permission denied.
          _playbackError = _isLiveEvent
              ? "This track isn't streamable on Audius (restricted access). Ask an editor to skip it."
              : "This track isn't streamable on Audius (restricted access). Try another one.";
        } else {
          _playbackError = "Could not play this track. Try another one.";
        }
      }
      notifyListeners();
    }
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_isLiveEvent)
      return; // Block playback state changes locally during live events
    final targetCommand = _isPlaying ? 'PAUSE' : 'PLAY';
    final currentPositionMs = _position.inMilliseconds;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    onPlaybackStateChanged?.call(targetCommand, currentPositionMs);
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
    notifyListeners();
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _playlist = [];
      _currentIndex = -1;
      _isPlaying = false;
      _isLiveEvent = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _playbackError = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Error stopping audio: $e");
    }
  }

  Future<void> nextTrack() async {
    if (_isLiveEvent) return;
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      final trackToPlay = _playlist[_currentIndex];
      try {
        await _loadAudioSource(trackToPlay);
        await _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
        _audioPlayer.play();
        onPlaybackStateChanged?.call('PLAY', 0);
      } catch (e) {
        debugPrint("Error playing next audio: $e");
        if (_playbackError == null) {
          _playbackError = "Could not play this track. Skipping.";
          notifyListeners();
          nextTrack();
        }
      }
      notifyListeners();
    }
  }

  Future<void> previousTrack() async {
    if (_isLiveEvent) return;
    if (_currentIndex > 0) {
      _currentIndex--;
      final prevTrack = _playlist[_currentIndex];
      try {
        await _loadAudioSource(prevTrack);
        await _audioPlayer.setVolume(_isMuted ? 0.0 : 1.0);
        _audioPlayer.play();
        onPlaybackStateChanged?.call('PLAY', 0);
      } catch (e) {
        debugPrint("Error playing previous audio: $e");
      }
      notifyListeners();
    }
  }

  Future<void> seek(Duration position) async {
    if (_isLiveEvent) return;
    await _audioPlayer.seek(position);
    onPlaybackStateChanged?.call('SEEK', position.inMilliseconds);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
