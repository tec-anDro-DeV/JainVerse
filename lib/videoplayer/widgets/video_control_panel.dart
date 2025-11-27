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
  final VoidCallback? contextSkipPrevious;
  final VoidCallback? contextSkipNext;
  final IconData? contextSkipPreviousIcon;
  final IconData? contextSkipNextIcon;

  const VideoControlPanel({
    super.key,
    this.textColor,
    this.accentColor,
    this.showTrackInfo = true,
    this.showSeekBar = true,
    this.contextSkipPrevious,
    this.contextSkipNext,
    this.contextSkipPreviousIcon,
    this.contextSkipNextIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    final effectiveTextColor = textColor ?? Colors.white;
    final effectiveAccentColor = accentColor ?? Theme.of(context).primaryColor;

    final VoidCallback? previousHandler = contextSkipPrevious;
    final VoidCallback? nextHandler = contextSkipNext;

    final IconData previousIcon =
        contextSkipPreviousIcon ?? Icons.skip_previous_rounded;
    final IconData nextIcon = contextSkipNextIcon ?? Icons.skip_next_rounded;

    final Color dimmedColor = effectiveTextColor.withOpacity(0.35);
    final Color previousColor = previousHandler != null
        ? effectiveAccentColor
        : dimmedColor;
    final Color nextColor = nextHandler != null
        ? effectiveAccentColor
        : dimmedColor;

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
          onSkipPrevious: previousHandler,
          onSkipNext: nextHandler,
          onShuffle: null, // Videos don't typically have shuffle
          // Show playlist skip icons when context is available, otherwise 10s icons
          skipPreviousIcon: previousIcon,
          skipNextIcon: nextIcon,
          skipPreviousColor: previousColor,
          skipNextColor: nextColor,
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
