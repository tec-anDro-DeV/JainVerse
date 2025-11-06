import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../widgets/shared_media_controls/shared_media_controls.dart';
import '../managers/video_player_state_provider.dart';

/// Control panel for video player
/// Uses shared media controls (seek bar, playback controls, volume, track info)
class VideoControlPanel extends ConsumerWidget {
  final Color? textColor;
  final Color? accentColor;
  final bool showTrackInfo;

  const VideoControlPanel({
    super.key,
    this.textColor,
    this.accentColor,
    this.showTrackInfo = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    final effectiveTextColor = textColor ?? Colors.white;
    final effectiveAccentColor = accentColor ?? Theme.of(context).primaryColor;

    return Column(
      children: [
        // Track info (video title and subtitle) - optionally hidden by caller
        if (showTrackInfo)
          MediaTrackInfo(
            title: videoState.currentVideoTitle ?? 'Unknown Video',
            subtitle: videoState.currentVideoSubtitle ?? '',
            titleColor: effectiveTextColor,
            subtitleColor: effectiveTextColor.withOpacity(0.7),
            textAlign: TextAlign.center,
          ),

        SizedBox(height: 24.h),

        // Seek bar
        MediaSeekBar(
          position: videoState.position,
          duration: videoState.duration,
          onSeek: videoState.isReady
              ? (newPosition) {
                  videoNotifier.seekTo(newPosition);
                }
              : (position) {}, // No-op when not ready
          progressColor: effectiveAccentColor,
          backgroundColor: effectiveTextColor.withOpacity(0.3),
          textColor: effectiveTextColor,
          enabled: videoState.isReady,
        ),

        SizedBox(height: 32.h),

        // Playback controls
        MediaPlaybackControls(
          isPlaying: videoState.isPlaying,
          isLoading: videoState.isLoading,
          onPlay: videoNotifier.play,
          onPause: videoNotifier.pause,
          // Change previous/next to seek -10s / +10s (clamped to 0..duration)
          onSkipPrevious: videoState.isReady
              ? () {
                  final current = videoState.position;
                  final seekTo = current - const Duration(seconds: 10);
                  final clamped = seekTo < Duration.zero
                      ? Duration.zero
                      : seekTo;
                  videoNotifier.seekTo(clamped);
                }
              : null,
          onSkipNext: videoState.isReady
              ? () {
                  final current = videoState.position;
                  final duration = videoState.duration;
                  final seekTo = current + const Duration(seconds: 10);
                  final clamped = seekTo > duration ? duration : seekTo;
                  videoNotifier.seekTo(clamped);
                }
              : null,
          onShuffle: null, // Videos don't typically have shuffle
          // Show 10s seek icons for previous/next
          skipPreviousIcon: Icons.replay_10,
          skipNextIcon: Icons.forward_10,
          onRepeat: videoNotifier.toggleRepeat,
          isShuffleEnabled: false,
          isRepeatEnabled: videoState.repeatMode,
          repeatMode: videoState.repeatMode ? 'one' : 'none',
          iconColor: effectiveTextColor,
          accentColor: effectiveAccentColor,
          showShuffle: false, // Hide shuffle for video
          iconSize: 36.w,
          // Make play/pause a bit larger on video full-screen for better tap/visibility
          playPauseIconSize: 64.w,
        ),

        SizedBox(height: 24.h),

        // Volume slider (Android only)
        MediaVolumeSlider(
          iconColor: effectiveTextColor,
          sliderColor: effectiveAccentColor,
          backgroundColor: effectiveTextColor.withOpacity(0.2),
          enabled: videoState.isReady,
        ),
      ],
    );
  }
}
