import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../managers/video_player_state_provider.dart';
import '../services/video_player_theme_service.dart';
import '../widgets/video_visual_area.dart';
import '../widgets/video_control_panel.dart';
import '../../utils/music_player_state_manager.dart';
import '../utils/landscape_video_launcher.dart';

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

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView> {
  VideoPlayerTheme? _theme;
  SystemUiOverlayStyle? _previousOverlayStyle;
  // Track last known orientation so we can react to device rotation
  Orientation? _lastOrientation;
  // Guard to ensure we only launch landscape player once per rotation event
  bool _rotationLaunched = false;

  @override
  void initState() {
    super.initState();
    // We don't have a public API to read the current overlay style reliably
    // across Flutter versions, so keep `null` and only restore if we explicitly
    // captured one earlier in a compatible environment.
    _previousOverlayStyle = null;

    // Apply an initial (safe) overlay immediately so the status bar doesn't
    // flash the system default while we extract colors. We'll update it once
    // the thumbnail-derived theme is ready.
    _theme = VideoPlayerTheme.defaultTheme();
    _updateSystemUI(_theme!);

    // Delay initialization so provider modifications happen after widget build
    Future(() {
      _initializeVideoPlayer();
      // Notify global state manager to hide mini players/navigation while full player is shown
      MusicPlayerStateManager().showFullPlayer();
    });
    _loadTheme();
  }

  Future<void> _initializeVideoPlayer() async {
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

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
    // Restore previous overlay style
    if (_previousOverlayStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(_previousOverlayStyle!);
    }

    // Clean up video player - delay to avoid modifying provider during widget lifecycle
    Future(() {
      // Restore global UI (navigation & mini player) when full player is closed
      MusicPlayerStateManager().hideFullPlayer();
      // Dispose player resources
      ref.read(videoPlayerProvider.notifier).disposeVideo();
    });
    super.dispose();
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
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
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
      );
    }

    // Fallback when no thumbnail available
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
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
    );
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
            onPressed: () => Navigator.of(context).pop(),
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
