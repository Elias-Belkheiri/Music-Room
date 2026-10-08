class Track {
  final String id;
  final String? playlistTrackId;
  final String title;
  final String? imageUrl;
  final String artistName;
  final String? audioUrl;
  final bool isStreamable;
  final bool isStreamGated;
  final String? description;
  final int? durationMs;

  Track({
    required this.id,
    this.playlistTrackId,
    required this.title,
    this.imageUrl,
    required this.artistName,
    this.audioUrl,
    this.isStreamable = true,
    this.isStreamGated = false,
    this.description,
    this.durationMs,
  });

  /// Audius returns 403 `{"code":403,"error":"track not streamable"}` on
  /// `/v1/tracks/{id}/stream` for stream-gated (premium / special-access)
  /// tracks even though `is_streamable` is `true`. Those tracks can never
  /// play in the app, so they must be treated as unstreamable here —
  /// otherwise the queue fills with tracks that fail with iOS AVPlayer
  /// error (-1102) "You do not have permission to access the requested
  /// resource" and show 00:00/00:00.
  static bool _resolveStreamable(Map<String, dynamic> json) {
    final bool gated = json['is_stream_gated'] == true;
    if (gated) return false;
    if (json['is_delete'] == true) return false;
    if (json['is_unlisted'] == true) return false;
    final dynamic streamable = json['is_streamable'];
    if (streamable is bool) return streamable;
    final dynamic available = json['is_available'];
    if (available is bool) return available;
    return true;
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['track_id'];
    final String? streamUrl = json['stream']?['url']?.toString();
    final String? fallbackStreamUrl = rawId != null
        ? 'https://discoveryprovider.audius.co/v1/tracks/$rawId/stream?app_name=MusicRoomApp'
        : null;

    final int? durationSec = json['duration'] as int?;
    final int? durationMs = durationSec != null ? durationSec * 1000 : null;
    final bool gated = json['is_stream_gated'] == true;

    return Track(
      id: rawId?.toString() ?? '',
      title: json['title'] ?? '',
      imageUrl:
          json['artwork']?['150x150'] ??
          json['artwork']?['480x480'] ??
          json['artwork']?['1000x1000'],
      artistName: json['user']?['name'] ?? 'Unknown Artist',
      audioUrl: (streamUrl != null && streamUrl.isNotEmpty)
          ? streamUrl
          : fallbackStreamUrl,
      isStreamable: _resolveStreamable(json),
      isStreamGated: gated,
      description: json['description'],
      durationMs: durationMs,
    );
  }

  factory Track.fromPlaylistTrackJson(Map<String, dynamic> json) {
    final String? externalId =
        json['externalId']?.toString() ?? json['external_id']?.toString();
    final String? fallbackStreamUrl =
        externalId != null && externalId.isNotEmpty
        ? 'https://discoveryprovider.audius.co/v1/tracks/$externalId/stream?app_name=MusicRoomApp'
        : null;

    return Track(
      id: externalId ?? (json['id'] ?? '').toString(),
      playlistTrackId: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      imageUrl: json['coverUrl'] as String?,
      artistName: (json['artist'] ?? 'Unknown Artist').toString(),
      audioUrl: fallbackStreamUrl,
      isStreamable: true,
      description: null,
      durationMs: json['durationMs'] as int? ?? json['duration_ms'] as int?,
    );
  }
}
