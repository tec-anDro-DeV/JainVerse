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
  final bool showSeekBar;

  const VideoControlPanel({
    super.key,
    this.textColor,
    this.accentColor,
    this.showTrackInfo = true,
    this.showSeekBar = true,
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

        // Reduced vertical gap between the track info and the seek bar.
        // Decreased from 24.h to 12.h to tighten the layout.
        SizedBox(height: 4.h),

        // Seek bar removed from UI (not needed). Playback controls remain.

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
          iconSize: 50.w,
          // Make repeat and volume icons smaller than the primary controls
          repeatIconSize: 40.w,
          volumeIconSize: 40.w,
          // Make play/pause a bit larger on video full-screen for better tap/visibility
          playPauseIconSize: 60.w,
          volumeEnabled: videoState.isReady,
        ),
      ],
    );
  }
}
