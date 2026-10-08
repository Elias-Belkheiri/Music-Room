import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/audio_provider.dart';
import 'acid/acid_buttons.dart';
import 'acid/waveform_progress.dart';
import 'add_to_playlist_modal.dart';

/// Reusable mini player pill (no positioning) so shells can stack it
/// above the bottom nav with a proper gap instead of hard-coded offsets.
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        if (!audioProvider.hasTrack || audioProvider.isPlayerMaximized) {
          return const SizedBox.shrink();
        }
        final track = audioProvider.currentTrack!;
        return GestureDetector(
          onTap: () => audioProvider.maximizePlayer(),
          child: Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSm),
                  child: track.imageUrl != null
                      ? Image.network(
                          track.imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _MiniFallback(),
                        )
                      : const _MiniFallback(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        style: AppTheme.titleMd
                            .copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track.artistName,
                        style: AppTheme.caption
                            .copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (audioProvider.isLiveEvent)
                  GestureDetector(
                    onTap: audioProvider.onSyncPlayback,
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill),
                        border: Border.all(
                          color: AppTheme.accent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'SYNC',
                        style: AppTheme.label.copyWith(
                          color: AppTheme.accent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            audioProvider.togglePlayPause(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            audioProvider.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppTheme.onAccent,
                            size: 24,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            audioProvider.nextTrack(),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8),
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: AppTheme.textPrimary,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniFallback extends StatelessWidget {
  const _MiniFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: AppTheme.surfaceRaised,
      child: const Icon(
        Icons.music_note_rounded,
        color: AppTheme.textSecondary,
        size: 24,
      ),
    );
  }
}

/// Acid Noir player — mini pill + full player sheet (DESIGN.md 5.8).
/// Hero art, surface-raised title panel, waveform seek, circular controls.
class AudioPlayerOverlay extends StatelessWidget {
  /// Extra space reserved below the mini player (e.g. bottom nav height).
  /// Main shell stacks mini + nav itself, so it uses [AudioMiniPlayer]
  /// directly; pushed routes use this overlay standalone with 0 reserve.
  final double reservedBottomHeight;
  const AudioPlayerOverlay({super.key, this.reservedBottomHeight = 0});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        if (audioProvider.playbackError != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(audioProvider.playbackError!),
                backgroundColor: AppTheme.danger,
                duration: const Duration(seconds: 3),
              ),
            );
            audioProvider.clearPlaybackError();
          });
        }

        if (!audioProvider.hasTrack) return const SizedBox.shrink();

        final track = audioProvider.currentTrack!;

        if (audioProvider.isPlayerMaximized) {
          final totalMs =
              audioProvider.duration.inMilliseconds;
          final posMs = audioProvider.position.inMilliseconds;
          final progress = totalMs > 0
              ? (posMs / totalMs).clamp(0.0, 1.0)
              : 0.0;
          return GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! > 300) {
                audioProvider.minimizePlayer();
              }
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -300) {
                audioProvider.nextTrack();
              } else if (velocity > 300) {
                audioProvider.previousTrack();
              }
            },
            child: Container(
              color: AppTheme.background,
              width: double.infinity,
              height: double.infinity,
              child: SafeArea(
                child: Column(
                  children: [
                    // ── Top bar ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                audioProvider.minimizePlayer(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceRaised,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppTheme.textPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                          Text('Now Playing',
                              style: AppTheme.label.copyWith(
                                  color: AppTheme.textPrimary)),
                          GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) =>
                                    AddToPlaylistModal(track: track),
                              );
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceRaised,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                color: AppTheme.textPrimary,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            // ── Hero art ──────────────────────────────
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: track.imageUrl != null
                                    ? Image.network(
                                        track.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error,
                                                stackTrace) =>
                                            _artFallback(),
                                      )
                                    : _artFallback(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // ── Title panel ───────────────────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceRaised,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLg),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    style: AppTheme.titleLg,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    track.artistName,
                                    style: AppTheme.body.copyWith(
                                        color:
                                            AppTheme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                  WaveformProgress(
                                    progress: progress,
                                    onSeek: audioProvider.isLiveEvent
                                        ? null
                                        : (p) {
                                            final target =
                                                audioProvider.duration *
                                                    p;
                                            audioProvider
                                                .seek(target);
                                          },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(
                                            audioProvider.position),
                                        style: AppTheme.caption.copyWith(
                                            fontFeatures: const []),
                                      ),
                                      Text(
                                        _formatDuration(
                                            audioProvider.duration),
                                        style: AppTheme.caption,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // ── Controls ──────────────────────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceRaised,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLg),
                              ),
                              child: audioProvider.isLiveEvent
                                  ? GestureDetector(
                                      onTap: audioProvider
                                          .onSyncPlayback,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    AppTheme
                                                        .radiusPill),
                                            border: Border.all(
                                              color: AppTheme.accent,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.sync_rounded,
                                                color: AppTheme.accent,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'LIVE — TAP TO SYNC',
                                                style:
                                                    AppTheme.label.copyWith(
                                                  color: AppTheme.accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        AcidSecondaryButton(
                                          icon: Icons
                                              .skip_previous_rounded,
                                          onTap: () => audioProvider
                                              .previousTrack(),
                                        ),
                                        const SizedBox(width: 20),
                                        AcidPrimaryButton(
                                          icon: audioProvider.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons
                                                  .play_arrow_rounded,
                                          size: 72,
                                          pulse:
                                              audioProvider.isPlaying,
                                          onTap: () => audioProvider
                                              .togglePlayPause(),
                                        ),
                                        const SizedBox(width: 20),
                                        AcidSecondaryButton(
                                          icon: Icons
                                              .skip_next_rounded,
                                          onTap: () => audioProvider
                                              .nextTrack(),
                                        ),
                                      ],
                                    ),
                            ),
                            if (track.description != null &&
                                track.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('About',
                                        style: AppTheme.label
                                            .copyWith(
                                                color: AppTheme
                                                    .textPrimary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      track.description!,
                                      style: AppTheme.caption,
                                      maxLines: 3,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ── Mini player (standalone use, e.g. pushed routes) ──────────
        // Wrapped in SafeArea + bottom offset so it never sits under the
        // system gesture bar. Shells with their own bottom nav should use
        // AudioMiniPlayer stacked above the nav instead (see MainScreen).
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: 16 + reservedBottomHeight,
              ),
              child: const AudioMiniPlayer(),
            ),
          ),
        );
      },
    );
  }

  Widget _artFallback() => Container(
        color: AppTheme.surfaceRaised,
        child: const Icon(
          Icons.music_note_rounded,
          color: AppTheme.textSecondary,
          size: 100,
        ),
      );

}
