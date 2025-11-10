import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import '../managers/video_player_state_provider.dart';
import '../../managers/music_manager.dart';
import '../utils/orientation_helper.dart';

/// Full-screen landscape video player with YouTube-style controls
///
/// Features:
/// - Auto-rotating landscape layout
/// - Overlay controls with auto-hide
/// - Top bar: title, channel, settings
/// - Center: play/pause, 10s rewind/forward
/// - Bottom: seek bar, timestamps, fullscreen exit
/// - Gesture detection for show/hide controls
class LandscapeVideoPlayer extends ConsumerStatefulWidget {
  final String videoUrl;
  final String videoId;
  final String? title;
  final String? channelName;
  final String? thumbnailUrl;

  const LandscapeVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.videoId,
    this.title,
    this.channelName,
    this.thumbnailUrl,
  });

  @override
  ConsumerState<LandscapeVideoPlayer> createState() =>
      _LandscapeVideoPlayerState();
}

class _LandscapeVideoPlayerState extends ConsumerState<LandscapeVideoPlayer> {
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isInitialized = false;
  // Double-tap skip/back accumulation state
  int _accumulatedTapsLeft = 0; // count of 10s increments for left side (back)
  int _accumulatedTapsRight =
      0; // count of 10s increments for right side (forward)
  Timer? _leftTapWindowTimer;
  Timer? _rightTapWindowTimer;
  bool _showLeftOverlay = false;
  bool _showRightOverlay = false;
  // Duration of the persistent tap window opened after the first double-tap
  final Duration _tapWindow = const Duration(milliseconds: 1200);
  // Stable base positions to avoid races with async controller updates.
  Duration? _leftBasePosition;
  Duration? _rightBasePosition;

  // Safe check to see if a controller is initialized without throwing when
  // the controller has been disposed concurrently.
  bool controllerIsInitializedSafely(VideoPlayerController? c) {
    try {
      return c?.value.isInitialized ?? false;
    } catch (_) {
      return false;
    }
  }

  double controllerAspectRatioSafely(VideoPlayerController? c) {
    try {
      final a = c?.value.aspectRatio ?? 0;
      return (a == 0) ? 16 / 9 : a;
    } catch (_) {
      return 16 / 9;
    }
  }

  Widget _safeBuildVideoPlayer(VideoPlayerController? controller) {
    if (controller == null) return const SizedBox.shrink();
    try {
      return VideoPlayer(controller);
    } catch (err, st) {
      debugPrint(
        '[LandscapeVideoPlayer] VideoPlayer construction failed: $err\n$st',
      );
      return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _setLandscapeOrientation();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    unawaited(_restoreOrientation());
    super.dispose();
  }

  void _setLandscapeOrientation() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Also inform native iOS to allow landscape for this route
    try {
      OrientationHelper.setLandscape();
    } catch (_) {}
  }

  Future<void> _restoreOrientation() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    } catch (_) {}

    // Restore app to portrait defaults immediately so the underlying screens
    // render using the expected layout regardless of the device's physical
    // orientation at the moment the user exits landscape mode.
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (_) {}

    try {
      await OrientationHelper.setPortrait();
    } catch (_) {}
  }

  Future<void> _initializePlayer() async {
    try {
      await MusicManager.instance.stopAndDisposeAll(
        reason: 'landscape-video-init',
      );
    } catch (e) {
      debugPrint('[LandscapeVideoPlayer] Failed to stop music: $e');
    }

    final videoNotifier = ref.read(videoPlayerProvider.notifier);
    final currentState = ref.read(videoPlayerProvider);

    // If the provider already has the same video loaded and the controller
    // is present and safe to use, reuse it instead of reinitializing which
    // would dispose and recreate the controller (causing playback to restart).
    final existingController = currentState.controller;
    final hasSameVideo = currentState.currentVideoId == widget.videoId;

    final canReuseController =
        hasSameVideo &&
        existingController != null &&
        controllerIsInitializedSafely(existingController) &&
        !videoNotifier.isControllerDisposed(existingController) &&
        !videoNotifier.isControllerScheduledForDisposal(existingController);

    if (canReuseController) {
      // Attach to existing controller (no init required). Mark initialized
      // so the UI stops showing loading indicators.
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      // If the provider isn't playing, don't force-play here; leave it to
      // provider state or user interaction to control playback.
      return;
    }

    // Otherwise initialize a fresh controller via the notifier. Let the
    // notifier handle autoplay (it tries to autoPlay by default).
    await videoNotifier.initializeVideo(
      videoUrl: widget.videoUrl,
      videoId: widget.videoId,
      title: widget.title,
      subtitle: widget.channelName,
      thumbnailUrl: widget.thumbnailUrl,
      // Keep the provider's default autoPlay behavior.
    );

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _startHideTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onUserInteraction() {
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }
    _startHideTimer();
  }

  Future<void> _exitFullscreen() async {
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    unawaited(_restoreOrientation());

    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  Future<bool> _handleWillPop() async {
    await _restoreOrientation();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoPlayerProvider);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          // Detect double-taps and their positions to implement left/right 10s skip
          onDoubleTapDown: (details) =>
              _handleDoubleTapDown(details, videoNotifier),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Video player surface (center-aligned)
              Center(
                child: Builder(
                  builder: (context) {
                    final controller = videoState.controller;
                    final canShow =
                        _isInitialized &&
                        controller != null &&
                        !ref
                            .read(videoPlayerProvider.notifier)
                            .isControllerDisposed(controller) &&
                        !ref
                            .read(videoPlayerProvider.notifier)
                            .isControllerScheduledForDisposal(controller) &&
                        controllerIsInitializedSafely(controller);

                    if (!canShow) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    return AspectRatio(
                      aspectRatio: controllerAspectRatioSafely(controller),
                      child: _safeBuildVideoPlayer(controller),
                    );
                  },
                ),
              ),

              // Overlay controls
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _showControls
                    ? _buildOverlayControls(videoState, videoNotifier)
                    : const SizedBox.shrink(),
              ),

              // Left / Right double-tap overlay feedback (persistent during tap window)
              // Left (rewind) overlay
              IgnorePointer(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 36.w),
                    child: AnimatedOpacity(
                      opacity: _showLeftOverlay ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      child: _buildTapOverlay(isLeft: true),
                    ),
                  ),
                ),
              ),

              // Right (forward) overlay
              IgnorePointer(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 36.w),
                    child: AnimatedOpacity(
                      opacity: _showRightOverlay ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      child: _buildTapOverlay(isLeft: false),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle double-tap down details to determine left/right and accumulate seeks
  void _handleDoubleTapDown(TapDownDetails details, dynamic videoNotifier) {
    // Determine which half of the screen was double-tapped
    final dx = details.globalPosition.dx;
    final width = MediaQuery.of(context).size.width;

    final isLeft = dx < width / 2;

    final videoState = ref.read(videoPlayerProvider);

    if (isLeft) {
      // Light haptic feedback
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
      // Rewind: set base position on first tap, then accumulate
      if (_accumulatedTapsLeft == 0) {
        _leftBasePosition = videoState.position;
      }
      _accumulatedTapsLeft++;
      _showLeftOverlay = true;
      // Cancel and (re)start the left-side tap window timer
      _leftTapWindowTimer?.cancel();
      _leftTapWindowTimer = Timer(_tapWindow, () => _clearLeftAccumulation());

      // Seek backward by accumulated amount based on stable base position
      try {
        final base = _leftBasePosition ?? videoState.position;
        final seconds = _accumulatedTapsLeft * 10;
        final target = base - Duration(seconds: seconds);
        final clamped = target < Duration.zero ? Duration.zero : target;
        videoNotifier.seekTo(clamped);
      } catch (_) {
        // ignore if controller disposed concurrently
      }
    } else {
      // Light haptic feedback
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
      // Forward: set base position on first tap, then accumulate
      if (_accumulatedTapsRight == 0) {
        _rightBasePosition = videoState.position;
      }
      _accumulatedTapsRight++;
      _showRightOverlay = true;
      _rightTapWindowTimer?.cancel();
      _rightTapWindowTimer = Timer(_tapWindow, () => _clearRightAccumulation());

      try {
        final base = _rightBasePosition ?? videoState.position;
        final seconds = _accumulatedTapsRight * 10;
        final duration = videoState.duration;
        final target = base + Duration(seconds: seconds);
        final clamped = target > duration ? duration : target;
        videoNotifier.seekTo(clamped);
      } catch (_) {
        // ignore if controller disposed concurrently
      }
    }

    // Ensure controls are visible briefly when user interacts
    _onUserInteraction();
    // Force rebuild to show overlay label updates
    if (mounted) setState(() {});
  }

  void _clearLeftAccumulation() {
    _leftTapWindowTimer?.cancel();
    _accumulatedTapsLeft = 0;
    _showLeftOverlay = false;
    _leftBasePosition = null;
    if (mounted) setState(() {});
  }

  void _clearRightAccumulation() {
    _rightTapWindowTimer?.cancel();
    _accumulatedTapsRight = 0;
    _showRightOverlay = false;
    _rightBasePosition = null;
    if (mounted) setState(() {});
  }

  Widget _buildTapOverlay({required bool isLeft}) {
    final count = isLeft ? _accumulatedTapsLeft : _accumulatedTapsRight;
    if (count <= 0) return const SizedBox.shrink();
    final seconds = count * 10;
    final label = isLeft ? '${seconds}s' : '${seconds}s';
    // Polished: fade + slide + scale animation, smaller font and icon
    final show = isLeft ? _showLeftOverlay : _showRightOverlay;
    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.94, end: show ? 1.0 : 0.94),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          final slideX = isLeft ? -8.0 * (1 - scale) : 8.0 * (1 - scale);
          return Transform.translate(
            offset: Offset(slideX, 0),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLeft ? Icons.replay_10_rounded : Icons.forward_10_rounded,
              color: Colors.white,
              size: 18.w,
              shadows: [const Shadow(blurRadius: 4, color: Colors.black45)],
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                shadows: [const Shadow(blurRadius: 4, color: Colors.black45)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayControls(videoState, videoNotifier) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Top bar
          _buildTopBar(),

          // Center controls (play/pause, rewind, forward)
          Center(child: _buildCenterControls(videoState, videoNotifier)),

          // Bottom bar (seek bar, timestamps, exit button)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(videoState, videoNotifier),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        // Make the top bar more compact on landscape
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        child: Row(
          children: [
            // Title and channel name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title ?? 'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.channelName != null) ...[
                    SizedBox(height: 1.h),
                    Text(
                      widget.channelName!,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(width: 6.w),

            // Settings button (ultra-compact visual, preserved hit area)
            IconButton(
              icon: Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 14.w,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.w),
              onPressed: () {
                _onUserInteraction();
                _showSettingsBottomSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls(videoState, videoNotifier) {
    // Each control gets its own small glass pill
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rewind glass pill (circular)
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: Container(
              constraints: BoxConstraints.tightFor(width: 40.w, height: 40.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.2),
                border: Border.all(color: Colors.white.withOpacity(0.02)),
              ),
              child: _buildCircleControlInner(
                icon: Icons.replay_10_rounded,
                onPressed: () {
                  _onUserInteraction();
                  videoNotifier.seekTo(
                    videoState.position - const Duration(seconds: 10),
                  );
                },
              ),
            ),
          ),
        ),

        SizedBox(width: 28.w),

        // Play/Pause glass pill (wraps the existing play button)
        ClipRRect(
          borderRadius: BorderRadius.circular(26.w),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: Container(
              // fix the pill size to avoid stretching
              constraints: BoxConstraints.tightFor(width: 46.w, height: 46.w),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.04)),
              child: _buildPlayPauseInner(videoState, videoNotifier),
            ),
          ),
        ),

        SizedBox(width: 28.w),

        // Forward glass pill (circular)
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: Container(
              constraints: BoxConstraints.tightFor(width: 40.w, height: 40.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.20),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: _buildCircleControlInner(
                icon: Icons.forward_10_rounded,
                onPressed: () {
                  _onUserInteraction();
                  videoNotifier.seekTo(
                    videoState.position + const Duration(seconds: 10),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Inner control for small circular buttons (no outer container)
  Widget _buildCircleControlInner({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.w),
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Icon(icon, color: Colors.white, size: 18.w),
        ),
      ),
    );
  }

  // Inner play/pause tappable content without outer container — used by glass pill
  Widget _buildPlayPauseInner(videoState, videoNotifier) {
    return SizedBox(
      width: 46.w,
      height: 46.w,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26.w),
          onTap: () {
            _onUserInteraction();
            if (videoState.isPlaying) {
              videoNotifier.pause();
            } else {
              videoNotifier.play();
            }
          },
          child: Center(
            child: videoState.isLoading
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : Icon(
                    videoState.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26.w,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(videoState, videoNotifier) {
    return SafeArea(
      child: Padding(
        // Reduce horizontal padding so the seek bar spans wider with minimal margins
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 6.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Combined timestamp above the seek bar on the left, fullscreen exit on the right
            // Glass row: timestamp left, fullscreen right
            // Glass only around timestamp and fullscreen button separately
            Row(
              children: [
                // Timestamp glass pill (hugs content)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.w),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10.w),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Text(
                        '${_formatDuration(videoState.position)}/${_formatDuration(videoState.duration)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

                Spacer(),

                // Fullscreen exit mini glass button — tightened to hug icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.w),
                  child: BackdropFilter(
                    // minimal blur for performance and small pill
                    filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(4.w),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.03),
                        ),
                      ),
                      // Use a tight GestureDetector instead of IconButton to avoid default padding
                      child: GestureDetector(
                        onTap: () => _exitFullscreen(),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: Center(
                            child: Icon(
                              Icons.fullscreen_exit_rounded,
                              color: Colors.white,
                              size: 12.w,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Seek bar
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 1.5.h,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4.w),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 8.w),
                activeTrackColor: Colors.red,
                inactiveTrackColor: Colors.white.withOpacity(0.28),
                thumbColor: Colors.red,
                overlayColor: Colors.red.withOpacity(0.24),
              ),
              child: Slider(
                value: videoState.position.inMilliseconds.toDouble(),
                min: 0,
                max: videoState.duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  _onUserInteraction();
                  videoNotifier.seekTo(Duration(milliseconds: value.toInt()));
                },
              ),
            ),

            SizedBox(height: 0.h),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2.h),
              ),
            ),
            SizedBox(height: 16.h),

            ListTile(
              leading: const Icon(Icons.hd_rounded, color: Colors.white),
              title: const Text(
                'Quality',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Quality selection coming soon'),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.speed_rounded, color: Colors.white),
              title: const Text(
                'Playback Speed',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
              onTap: () {
                Navigator.pop(context);
                _showPlaybackSpeedDialog();
              },
            ),

            ListTile(
              leading: const Icon(Icons.subtitles_rounded, color: Colors.white),
              title: const Text(
                'Subtitles',
                style: TextStyle(color: Colors.white),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Subtitles coming soon')),
                );
              },
            ),

            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  void _showPlaybackSpeedDialog() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final videoState = ref.read(videoPlayerProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Playback Speed',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((speed) {
            return ListTile(
              title: Text(
                '${speed}x',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                // Use the controller's native setPlaybackSpeed method
                try {
                  videoState.controller?.setPlaybackSpeed(speed);
                } catch (_) {
                  // ignore if controller disposed concurrently
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
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
