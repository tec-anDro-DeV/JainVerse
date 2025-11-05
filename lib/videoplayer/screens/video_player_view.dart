import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import '../managers/video_player_state_provider.dart';
import '../services/video_player_theme_service.dart';
import '../widgets/video_visual_area.dart';
import '../widgets/video_control_panel.dart';
import '../../utils/music_player_state_manager.dart';
import '../utils/landscape_video_launcher.dart';
import '../../managers/music_manager.dart';

/// Full-screen video player view
/// Mirrors the MusicPlayerView design with video-specific adaptations
class VideoPlayerView extends ConsumerStatefulWidget {
  final String videoUrl;
  final String videoId;
  final String? title;
  final String? subtitle;
  final String? thumbnailUrl;
  final List<String>? playlist;
  final int? playlistIndex;

  const VideoPlayerView({
    super.key,
    required this.videoUrl,
    required this.videoId,
    this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.playlist,
    this.playlistIndex,
  });

  @override
  ConsumerState<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView>
    with TickerProviderStateMixin {
  VideoPlayerTheme? _theme;
  // Track last known orientation so we can react to device rotation
  Orientation? _lastOrientation;
  // Guard to ensure we only launch landscape player once per rotation event
  bool _rotationLaunched = false;

  // Drag gesture state
  late AnimationController _dragAnimationController;
  late Animation<Offset> _dragAnimation;
  double _dragDistance = 0.0;
  bool _isProgrammaticPop = false;
  bool _isMinimizeInProgress = false;
  final double _dismissThreshold = 0.3; // 30% of screen height  @override
  void initState() {
    super.initState();
    // We don't attempt to capture the prior overlay style (not reliably
    // available across platforms). Instead we restore a safe default on exit.

    // Apply an initial (safe) overlay immediately so the status bar doesn't
    // flash the system default while we extract colors. We'll update it once
    // the thumbnail-derived theme is ready.
    _theme = VideoPlayerTheme.defaultTheme();
    _updateSystemUI(_theme!);

    // Initialize drag animation controller
    _dragAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _dragAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1))
        .animate(
          CurvedAnimation(
            parent: _dragAnimationController,
            curve: Curves.easeOut,
          ),
        );

    // Delay initialization so provider modifications happen after widget build
    Future(() {
      // Check if still mounted before accessing ref
      if (!mounted) return;

      _initializeVideoPlayer();
      // Notify global state manager to hide mini players/navigation while full player is shown
      MusicPlayerStateManager().showFullPlayer();

      // Clear mini player flags now that full player is showing
      try {
        final videoNotifier = ref.read(videoPlayerProvider.notifier);
        final videoState = ref.read(videoPlayerProvider);
        if (videoState.showMiniPlayer) {
          videoNotifier.clearMiniPlayerFlag();
        }
      } catch (e) {
        debugPrint('[VideoPlayerView] Error clearing mini player flag: $e');
      }
    });
    _loadTheme();
  }

  // Safe check to see if a controller is initialized without throwing when
  // the controller is disposed concurrently.
  bool controllerIsInitializedSafely(VideoPlayerController? c) {
    try {
      return c?.value.isInitialized ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeVideoPlayer() async {
    // Check if widget is still mounted
    if (!mounted) return;

    try {
      await MusicManager.instance.stopAndDisposeAll(
        reason: 'video-player-view-init',
      );
    } catch (e) {
      debugPrint('[VideoPlayerView] Failed to stop music before init: $e');
    }

    final videoNotifier = ref.read(videoPlayerProvider.notifier);
    final videoState = ref.read(videoPlayerProvider);
    final controller = videoState.controller;
    final hasInitializedController =
        controller != null &&
        !videoNotifier.isControllerDisposed(controller) &&
        !videoNotifier.isControllerScheduledForDisposal(controller) &&
        controllerIsInitializedSafely(controller);
    final hasStableId = widget.videoId.isNotEmpty;
    final isSameVideo =
        hasInitializedController &&
        hasStableId &&
        videoState.currentVideoId == widget.videoId;

    // Reuse controller only when we're expanding the exact same video from the mini player.
    if (isSameVideo) {
      debugPrint(
        '[VideoPlayerView] Using existing controller from mini player',
      );
      if (mounted) {
        videoNotifier.expandToFullScreen();
        if (videoState.showMiniPlayer) {
          videoNotifier.clearMiniPlayerFlag();
        }
      }
      return;
    }

    // Ensure mini-player flags are cleared before loading a new video.
    if (videoState.isMinimized) {
      videoNotifier.expandToFullScreen();
    }
    if (videoState.showMiniPlayer) {
      videoNotifier.clearMiniPlayerFlag();
    }

    // Otherwise, initialize new video
    if (mounted) {
      await videoNotifier.initializeVideo(
        videoUrl: widget.videoUrl,
        videoId: widget.videoId,
        title: widget.title,
        subtitle: widget.subtitle,
        thumbnailUrl: widget.thumbnailUrl,
        playlist: widget.playlist,
        playlistIndex: widget.playlistIndex,
      );
    }
  }

  Future<void> _loadTheme() async {
    if (widget.thumbnailUrl == null) {
      setState(() {
        _theme = VideoPlayerTheme.defaultTheme();
        _updateSystemUI(_theme!);
      });
      return;
    }

    try {
      final theme = await VideoPlayerThemeService().generateThemeFromThumbnail(
        thumbnailUrl: widget.thumbnailUrl!,
        context: context,
      );

      if (mounted) {
        setState(() {
          _theme = theme;
          _updateSystemUI(theme);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _theme = VideoPlayerTheme.defaultTheme();
          _updateSystemUI(_theme!);
        });
      }
    }
  }

  void _updateSystemUI(VideoPlayerTheme theme) {
    final statusBarColor = theme.primaryColor;

    // Force light status bar icons/text for better visibility over the
    // extracted primary color. On iOS `statusBarBrightness` should be the
    // inverse of the icon brightness.
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    // Apply overlay after the current frame to reduce chances of being
    // immediately overridden by other widgets or route changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        SystemChrome.setSystemUIOverlayStyle(overlayStyle);
      } catch (_) {
        // Ignore any platform/version incompatibilities
      }
    });
  }

  @override
  void dispose() {
    debugPrint('[VideoPlayerView] dispose() called');

    // Dispose drag animation controller
    _dragAnimationController.dispose();

    // Restore previous overlay style
    // Restore a safe default: white background with dark icons.
    // Some Flutter versions don't expose the currently-active overlay style,
    // so we proactively set a normal (white) status bar here to ensure the
    // app returns to the expected look when leaving the full-screen player.
    try {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          // On iOS the `statusBarBrightness` should be the inverse of the
          // icon brightness.
          statusBarBrightness: Brightness.light,
        ),
      );
    } catch (_) {
      // Ignore any platform/version incompatibilities
    }

    // Restore global UI (navigation & mini player)
    MusicPlayerStateManager().hideFullPlayer();

    debugPrint('[VideoPlayerView] dispose() complete');

    // Note: Video controller disposal is handled by the VideoPlayerStateNotifier
    // We don't dispose it here to avoid "ref after unmount" errors
    // When minimizing, the controller is reused by the mini player
    // When closing without minimizing, the provider will handle cleanup when appropriate

    super.dispose();
  }

  Future<bool> _handleWillPop() async {
    if (_isProgrammaticPop) {
      return true;
    }

    if (!mounted) {
      return true;
    }

    final videoState = ref.read(videoPlayerProvider);

    if (_isMinimizeInProgress || videoState.isMinimized) {
      return true;
    }

    // If there is no active controller yet (loading/error), allow the pop so
    // the user can exit cleanly.
    if (videoState.controller == null) {
      return true;
    }

    _minimizeToMiniPlayer();
    return false;
  }

  void _handleBackPressed() {
    _handleWillPop().then((shouldPop) {
      if (!mounted || !shouldPop) {
        return;
      }

      _isProgrammaticPop = true;
      Navigator.of(context).pop();
    });
  }

  /// Handle vertical drag start
  void _onVerticalDragStart(DragStartDetails details) {
    _dragDistance = 0.0;
  }

  /// Handle vertical drag update
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragDistance += details.delta.dy;
      // Clamp to prevent upward drag
      if (_dragDistance < 0) _dragDistance = 0;
    });
  }

  /// Handle vertical drag end
  void _onVerticalDragEnd(DragEndDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dragPercentage = _dragDistance / screenHeight;

    if (dragPercentage > _dismissThreshold ||
        details.velocity.pixelsPerSecond.dy > 300) {
      // User dragged far enough or fast enough - minimize to mini player
      _minimizeToMiniPlayer();
    } else {
      // Snap back to original position
      setState(() {
        _dragDistance = 0.0;
      });
    }
  }

  /// Minimize to mini player with animation
  void _minimizeToMiniPlayer() async {
    debugPrint('[VideoPlayerView] _minimizeToMiniPlayer called');

    if (_isMinimizeInProgress || _isProgrammaticPop) {
      debugPrint('[VideoPlayerView] Minimize request ignored (in progress)');
      return;
    }

    _isMinimizeInProgress = true;
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    // Set minimized state first
    videoNotifier.minimizeToMiniPlayer();

    debugPrint(
      '[VideoPlayerView] State after minimizeToMiniPlayer: ${ref.read(videoPlayerProvider).isMinimized}, ${ref.read(videoPlayerProvider).showMiniPlayer}',
    );

    // Animate out
    try {
      await _dragAnimationController.forward(from: 0.0);
    } catch (_) {
      // Controller may be disposed during rapid pops; ignore.
    }

    debugPrint('[VideoPlayerView] Animation complete, about to pop');

    // Pop the route after animation
    if (mounted) {
      _isProgrammaticPop = true;
      Navigator.of(context).pop();
      debugPrint('[VideoPlayerView] Navigator.pop() called');
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoPlayerProvider);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);
    final theme = _theme ?? VideoPlayerTheme.defaultTheme();

    // Apply status bar style using extracted primary color
    final statusBarColor = theme.primaryColor;

    // Use light status bar icons/text for consistent visibility over the
    // extracted control color.
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    // If a thumbnail is available, use it as a full-bleed blurred background
    final thumbnail = widget.thumbnailUrl;

    Widget content;

    // Auto-launch landscape player when device orientation becomes landscape.
    // This relies on the app responding to system rotation (i.e. device
    // auto-rotate is enabled). We schedule the launch after the current
    // frame to avoid navigator calls during build.
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != currentOrientation) {
      // Orientation changed
      if (currentOrientation == Orientation.landscape && !_rotationLaunched) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Double-check mounted and guard flag
          if (!mounted) return;
          _rotationLaunched = true;

          await LandscapeVideoLauncher.launch(
            context: context,
            videoUrl: widget.videoUrl,
            videoId: widget.videoId,
            title: widget.title,
            channelName: widget.subtitle,
            thumbnailUrl: widget.thumbnailUrl,
          );

          // When the landscape player is popped, reset the guard so future
          // rotations can re-open it.
          if (mounted) {
            setState(() {
              _rotationLaunched = false;
            });
          }
        });
      } else if (currentOrientation == Orientation.portrait) {
        // Reset when returning to portrait
        _rotationLaunched = false;
      }
      _lastOrientation = currentOrientation;
    }

    if (thumbnail != null) {
      content = AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: GestureDetector(
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: AnimatedBuilder(
            animation: _dragAnimation,
            builder: (context, child) {
              // Calculate opacity based on drag distance
              final screenHeight = MediaQuery.of(context).size.height;
              final opacity =
                  1.0 - (_dragDistance / screenHeight).clamp(0.0, 1.0);

              return Transform.translate(
                offset: Offset(0, _dragDistance),
                child: Opacity(opacity: opacity, child: child),
              );
            },
            child: Scaffold(
              // No AppBar here — paint the status bar area manually with a
              // positioned container so we don't change the scaffold's layout.
              backgroundColor: theme.backgroundColor,
              body: Stack(
                children: [
                  // Status bar color painted behind the system bar (does not alter layout)
                  if (MediaQuery.of(context).padding.top > 0)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: MediaQuery.of(context).padding.top,
                      child: Container(color: statusBarColor),
                    ),
                  // Background image
                  Positioned.fill(
                    child: Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, st) =>
                          Container(color: theme.backgroundColor),
                    ),
                  ),

                  // Heavy blur + subtle dark overlay to keep controls readable
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                      child: Container(
                        color: theme.backgroundColor.withOpacity(0.4),
                      ),
                    ),
                  ),

                  // Foreground content
                  SafeArea(
                    top: true,
                    child: Column(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              videoNotifier.toggleControls();
                            },
                            child: Column(
                              children: [
                                // Top bar with back button and title
                                _buildTopBar(context, videoState, theme),

                                SizedBox(height: 16.h),

                                // Scrollable content
                                Expanded(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      children: [
                                        SizedBox(height: 24.h),

                                        // Video visual area (passes fullscreen launch)
                                        VideoVisualArea(
                                          onFullscreen: () {
                                            LandscapeVideoLauncher.launch(
                                              context: context,
                                              videoUrl: widget.videoUrl,
                                              videoId: widget.videoId,
                                              title: widget.title,
                                              channelName: widget.subtitle,
                                              thumbnailUrl: widget.thumbnailUrl,
                                            );
                                          },
                                        ),

                                        SizedBox(height: 32.h),

                                        // Control panel
                                        VideoControlPanel(
                                          textColor: theme.textColor,
                                          accentColor: theme.primaryColor,
                                        ),

                                        SizedBox(height: 24.h),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // Fallback when no thumbnail available
      content = AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: GestureDetector(
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: AnimatedBuilder(
            animation: _dragAnimation,
            builder: (context, child) {
              // Calculate opacity based on drag distance
              final screenHeight = MediaQuery.of(context).size.height;
              final opacity =
                  1.0 - (_dragDistance / screenHeight).clamp(0.0, 1.0);

              return Transform.translate(
                offset: Offset(0, _dragDistance),
                child: Opacity(opacity: opacity, child: child),
              );
            },
            child: Scaffold(
              backgroundColor: theme.backgroundColor,
              body: Stack(
                children: [
                  // Background gradient layer
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(gradient: theme.gradient),
                    ),
                  ),

                  // Status bar color painted behind the system bar (does not alter layout)
                  if (MediaQuery.of(context).padding.top > 0)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: MediaQuery.of(context).padding.top,
                      child: Container(color: statusBarColor),
                    ),

                  // Main content
                  SafeArea(
                    top: true,
                    child: GestureDetector(
                      onTap: () => videoNotifier.toggleControls(),
                      child: Column(
                        children: [
                          // Top bar with back button and title
                          _buildTopBar(context, videoState, theme),

                          SizedBox(height: 16.h),

                          // Scrollable content
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                children: [
                                  SizedBox(height: 24.h),

                                  // Video visual area (passes fullscreen launch)
                                  VideoVisualArea(
                                    onFullscreen: () {
                                      LandscapeVideoLauncher.launch(
                                        context: context,
                                        videoUrl: widget.videoUrl,
                                        videoId: widget.videoId,
                                        title: widget.title,
                                        channelName: widget.subtitle,
                                        thumbnailUrl: widget.thumbnailUrl,
                                      );
                                    },
                                  ),

                                  SizedBox(height: 32.h),

                                  // Control panel
                                  VideoControlPanel(
                                    textColor: theme.textColor,
                                    accentColor: theme.primaryColor,
                                  ),

                                  SizedBox(height: 24.h),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return WillPopScope(onWillPop: _handleWillPop, child: content);
  }

  Widget _buildTopBar(
    BuildContext context,
    videoState,
    VideoPlayerTheme theme,
  ) {
    // Keep the top-row icons (back & more) always visible so the user can
    // exit or access options even when the in-video controls are hidden.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          // Back button (always visible)
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32.w,
              color: theme.textColor,
            ),
            onPressed: _handleBackPressed,
            splashRadius: 24.w,
          ),

          // Spacer
          const Spacer(),

          // More options button (always visible)
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 24.w,
              color: theme.textColor,
            ),
            onPressed: () {
              _showMoreOptions(context, theme);
            },
            splashRadius: 20.w,
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, VideoPlayerTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor.withOpacity(0.95),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: theme.textColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.h),
                ),
              ),
              SizedBox(height: 16.h),

              _buildMoreOption(
                icon: Icons.download_rounded,
                label: 'Download',
                theme: theme,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download coming soon')),
                  );
                },
              ),

              _buildMoreOption(
                icon: Icons.playlist_add_rounded,
                label: 'Add to Playlist',
                theme: theme,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Add to playlist coming soon'),
                    ),
                  );
                },
              ),

              _buildMoreOption(
                icon: Icons.info_outline_rounded,
                label: 'Video Info',
                theme: theme,
                onTap: () {
                  Navigator.pop(context);
                  _showVideoInfo(context, theme);
                },
              ),

              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOption({
    required IconData icon,
    required String label,
    required VideoPlayerTheme theme,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.textColor, size: 24.w),
      title: Text(
        label,
        style: TextStyle(
          color: theme.textColor,
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showVideoInfo(BuildContext context, VideoPlayerTheme theme) {
    final videoState = ref.read(videoPlayerProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.w),
        ),
        title: Text(
          'Video Information',
          style: TextStyle(
            color: theme.textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Title',
              videoState.currentVideoTitle ?? 'Unknown',
              theme,
            ),
            SizedBox(height: 12.h),
            _buildInfoRow(
              'Subtitle',
              videoState.currentVideoSubtitle ?? 'N/A',
              theme,
            ),
            SizedBox(height: 12.h),
            _buildInfoRow(
              'Duration',
              _formatDuration(videoState.duration),
              theme,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, VideoPlayerTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textColor.withOpacity(0.7),
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
