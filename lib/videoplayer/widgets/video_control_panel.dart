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

  const VideoControlPanel({super.key, this.textColor, this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    final effectiveTextColor = textColor ?? Colors.white;
    final effectiveAccentColor = accentColor ?? Theme.of(context).primaryColor;

    return Column(
      children: [
        // Track info (video title and subtitle)
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
          onSkipPrevious: videoState.hasPrevious
              ? () => videoNotifier.playPrevious()
              : null,
          onSkipNext: videoState.hasNext
              ? () => videoNotifier.playNext()
              : null,
          onShuffle: null, // Videos don't typically have shuffle
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

        SizedBox(height: 16.h),

        // Additional controls row (fullscreen, quality, etc.)
        _buildAdditionalControls(
          context,
          videoState,
          videoNotifier,
          effectiveTextColor,
        ),
      ],
    );
  }

  /// Build additional control buttons
  Widget _buildAdditionalControls(
    BuildContext context,
    videoState,
    videoNotifier,
    Color iconColor,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Quality selector (placeholder for future implementation)
          IconButton(
            icon: Icon(Icons.hd_rounded),
            iconSize: 24.w,
            color: iconColor.withOpacity(0.7),
            onPressed: () {
              // TODO: Implement quality selector
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Quality selection coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),

          // Playback speed
          IconButton(
            icon: Icon(Icons.speed_rounded),
            iconSize: 24.w,
            color: iconColor.withOpacity(0.7),
            onPressed: () {
              // TODO: Implement playback speed selector
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Speed control coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),

          // Fullscreen toggle
          IconButton(
            icon: Icon(
              videoState.isFullScreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
            iconSize: 24.w,
            color: iconColor.withOpacity(0.7),
            onPressed: () => videoNotifier.toggleFullScreen(),
          ),

          // Share
          IconButton(
            icon: Icon(Icons.share_rounded),
            iconSize: 24.w,
            color: iconColor.withOpacity(0.7),
            onPressed: () {
              // TODO: Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
