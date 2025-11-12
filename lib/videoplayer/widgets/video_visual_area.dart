import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/shared_media_controls/overlay_seek_bar.dart';
import '../services/video_player_theme_service.dart';
import '../managers/video_player_state_provider.dart';

/// Visual area displaying the video player
/// This replaces the album art section in the music player
class VideoVisualArea extends ConsumerWidget {
  final VoidCallback? onFullscreen;
  // New callback to minimize / close the full-screen player (down-arrow)
  final VoidCallback? onMinimize;
  // Optional player theme provided by VideoPlayerView so overlays use the
  // same extracted theme colors.
  final VideoPlayerTheme? theme;

  const VideoVisualArea({
    super.key,
    this.onFullscreen,
    this.onMinimize,
    this.theme,
  });

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

    String _formatDuration(Duration d) {
      String two(int n) => n.toString().padLeft(2, '0');
      if (d.inHours > 0) {
        return '${d.inHours}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
      }
      return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.black),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Keep the original clip for the video visuals so rounded corners
            // and children that shouldn't overflow still behave the same.
            ClipRRect(
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
                      !videoNotifier.isControllerScheduledForDisposal(
                        controller,
                      ) &&
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

                  // Fullscreen overlay button (bottom-right of the video)
                  if (videoState.showControls && onFullscreen != null)
                    Positioned(
                      bottom: 8.w,
                      right: 8.w,
                      child: _glassCircleIcon(
                        Icons.fullscreen_rounded,
                        onTap: onFullscreen,
                        size: 46,
                      ),
                    ),

                  // Timestamp pill (bottom-left) — matches the fullscreen icon styling
                  // Increased size for better legibility on modern devices.
                  if (videoState.showControls)
                    Positioned(
                      bottom: 8.w,
                      left: 8.w,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14.w),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                          child: Container(
                            constraints: BoxConstraints(
                              minWidth: 70.w,
                              minHeight: 30.h,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14.w),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                              ),
                            ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: _formatDuration(videoState.position),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _formatDuration(videoState.duration),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                      child: _glassCircleIcon(
                        Icons.keyboard_arrow_down_rounded,
                        onTap: onMinimize,
                        size: 46,
                      ),
                    ),

                  // Error message
                  if (videoState.errorMessage != null)
                    _buildError(videoState.errorMessage!),
                ],
              ),
            ),

            // Overlay seek bar that sits half above and half below the video's
            // bottom edge. It is positioned with a negative bottom offset so
            // it visually straddles the horizon without affecting layout.
            // We keep it horizontally centered and constrained on wide screens.
            Positioned(
              left: 0,
              right: 0,
              bottom: -28.h,
              child: IgnorePointer(
                ignoring: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 900.w),
                    child: SafeArea(
                      bottom: true,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 0.w),
                        child: OverlaySeekBar(
                          position:
                              (controller != null &&
                                  controller.value.isInitialized)
                              ? controller.value.position
                              : Duration.zero,
                          duration:
                              (controller != null &&
                                  controller.value.isInitialized)
                              ? controller.value.duration
                              : Duration.zero,
                          buffered:
                              (controller != null &&
                                  controller.value.isInitialized &&
                                  controller.value.buffered.isNotEmpty)
                              ? controller.value.buffered.last.end
                              : Duration.zero,
                          // Use the injected VideoPlayerTheme when available so
                          // overlay colors match the rest of the player screen.
                          progressColor:
                              theme?.primaryColor ??
                              Theme.of(context).colorScheme.primary,
                          backgroundColor:
                              theme?.backgroundColor ?? Colors.white24,
                          handleColor:
                              theme?.accentColor ??
                              Theme.of(context).primaryColor,
                          textColor: theme?.textColor ?? Colors.white,
                          onSeek: (pos) async {
                            try {
                              if (controller != null)
                                await controller.seekTo(pos);
                            } catch (_) {}
                          },
                          enabled: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable glass-morphism circular icon used for controls like
  /// fullscreen, keyboard toggle and minimize. Keeps visual style
  /// consistent across the player overlays.
  Widget _glassCircleIcon(
    IconData icon, {
    VoidCallback? onTap,
    double size = 46,
  }) {
    // Clip + BackdropFilter is required so the blur affects only the
    // region behind the circular control (glass effect).
    return ClipRRect(
      borderRadius: BorderRadius.circular((size / 2).w),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          width: size.w,
          height: size.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular((size / 2).w),
              onTap: onTap,
              child: Center(
                child: Icon(
                  icon,
                  size: (size * 0.62).w, // keeps the icon proportional
                  color: Colors.white,
                ),
              ),
            ),
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
        // Use a subtle loader as the fallback instead of a static video icon.
        // This improves perceived responsiveness when the video is still
        // initializing or when a thumbnail isn't available.
        child: SizedBox(
          width: 48.w,
          height: 48.w,
          child: const CircularProgressIndicator(
            color: Colors.white54,
            strokeWidth: 3.0,
          ),
        ),
      ),
    );
  }

  // Play/pause overlay helper removed (unused). Keep remaining UI helpers below.

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
