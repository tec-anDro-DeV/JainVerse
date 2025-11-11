import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../managers/video_player_state_provider.dart';

/// Visual area displaying the video player
/// This replaces the album art section in the music player
class VideoVisualArea extends ConsumerWidget {
  final VoidCallback? onFullscreen;
  // New callback to minimize / close the full-screen player (down-arrow)
  final VoidCallback? onMinimize;

  const VideoVisualArea({super.key, this.onFullscreen, this.onMinimize});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    // Helper to safely check controller initialization without crashing
    // when a controller has been disposed concurrently.
    bool controllerIsInitializedSafely(VideoPlayerController? c) {
      if (c == null) return false;
      try {
        return c.value.isInitialized;
      } catch (_) {
        // If the controller was disposed concurrently, accessing `value`
        // can throw in debug mode. Treat as not initialized.
        return false;
      }
    }

    final controller = videoState.controller;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.black),
        child: ClipRRect(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video player or thumbnail
              // Only build the VideoPlayer if the controller appears initialized
              // and the notifier does not consider it disposed/scheduled for
              // disposal. This reduces races where a controller is disposed
              // between our check and the framework mounting the VideoPlayer.
              if (controller != null &&
                  !videoNotifier.isControllerDisposed(controller) &&
                  !videoNotifier.isControllerScheduledForDisposal(controller) &&
                  controllerIsInitializedSafely(controller))
                _buildVideoPlayer(controller, videoNotifier)
              else if (videoState.thumbnailUrl != null)
                _buildThumbnail(videoState.thumbnailUrl!)
              else
                _buildPlaceholder(),

              // Loading indicator
              if (videoState.isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),

              // Buffering indicator
              if (videoState.isBuffering)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),

              // (Play/pause overlay removed) Only keep other overlays such as fullscreen

              // Fullscreen overlay button (bottom-right of the video)
              if (videoState.showControls && onFullscreen != null)
                Positioned(
                  bottom: 8.w,
                  right: 8.w,
                  child: Container(
                    width: 46.w,
                    height: 46.w,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20.w),
                        onTap: onFullscreen,
                        child: Icon(
                          Icons.fullscreen_rounded,
                          size: 28.w,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

              // Minimize / close overlay button (top-left of the video)
              if (videoState.showControls && onMinimize != null)
                Positioned(
                  top: 8.w,
                  left: 8.w,
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20.w),
                        onTap: onMinimize,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 28.w,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

              // Error message
              if (videoState.errorMessage != null)
                _buildError(videoState.errorMessage!),
            ],
          ),
        ),
      ),
    );
  }

  /// Build video player widget
  Widget _buildVideoPlayer(
    VideoPlayerController controller,
    dynamic videoNotifier,
  ) {
    // Forward taps to the notifier so controls toggle consistently.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => videoNotifier.toggleControls(),
      child: Center(
        child: AspectRatio(
          aspectRatio: (() {
            try {
              return controller.value.aspectRatio;
            } catch (_) {
              // If controller is disposed concurrently, fallback to 16:9
              return 16 / 9;
            }
          })(),
          child: Builder(
            builder: (context) {
              // Protect VideoPlayer constructor in case the controller was
              // disposed between the parent check and widget creation.
              try {
                return VideoPlayer(controller);
              } catch (_) {
                // In case of race/disposal, show a placeholder instead of
                // letting the app throw.
                return _buildPlaceholder();
              }
            },
          ),
        ),
      ),
    );
  }

  /// Build thumbnail while loading
  Widget _buildThumbnail(String thumbnailUrl) {
    // Use CachedNetworkImage so disk + memory caching is handled. This
    // will also honor precaching via CachedNetworkImageProvider.
    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  /// Build placeholder when no thumbnail
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(Icons.videocam_rounded, size: 80.w, color: Colors.white30),
      ),
    );
  }

  /// Build play/pause overlay
  Widget _buildPlayPauseOverlay(
    BuildContext context,
    videoState,
    videoNotifier,
  ) {
    return GestureDetector(
      onTap: () => videoNotifier.togglePlayPause(),
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: AnimatedOpacity(
            opacity: videoState.showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: 70.w,
              height: 70.w,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                videoState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 40.w,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build error message
  Widget _buildError(String errorMessage) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          // Allow long error messages to scroll instead of causing a
          // RenderFlex overflow when the visual area is constrained.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 60.w,
                  color: Colors.red[300],
                ),
                SizedBox(height: 16.h),
                Text(
                  'Error Loading Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
