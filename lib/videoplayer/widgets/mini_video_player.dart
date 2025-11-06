import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:video_player/video_player.dart';
import '../managers/video_player_state_provider.dart';
import '../screens/video_player_view.dart';

/// Configuration constants for the mini video player
class _MiniVideoPlayerConfig {
  // Colors
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Duration animationDuration = Duration(milliseconds: 350);

  // Card-style sizing similar to music mini player
  static double get height => 100.w;
  static double get borderRadius => 12.w;
  static double get marginHorizontal => 10.w;
  static double get spacing => 10.w;
  // previewSize removed — preview now sized dynamically as 30% of card width
  static double get playButtonSize => 46.w;
  static double get playIconSize => 36.w;
  static double get progressBarHeight => 6.w;
}

/// Mini video player widget that appears at the bottom of the screen
/// Shows LIVE video playback (not thumbnail) with controls
/// Supports:
/// - Tap to expand to full screen
/// - Swipe left/right to dismiss
/// - Continuous video playback during transitions
class MiniVideoPlayer extends ConsumerStatefulWidget {
  const MiniVideoPlayer({super.key});

  @override
  ConsumerState<MiniVideoPlayer> createState() => _MiniVideoPlayerState();
}

class _MiniVideoPlayerState extends ConsumerState<MiniVideoPlayer>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _slideAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // State tracking
  bool _isVisible = false;
  bool _hasVideo = false;
  String? _lastBuildSummary;
  String? _lastVisibilityAction;
  String? _lastRenderDecision;

  // Swipe dismiss state
  // raw drag (1:1 with finger) and displayed offset (after resistance mapping)
  double _rawHorizontalDragOffset = 0.0;
  double _horizontalDragOffset = 0.0;

  // Distance (in logical pixels) the user must drag to consider a dismiss.
  // This is initialized to a sensible fixed value but updated in `build`
  // to be proportional to screen width so resistance scales across devices.
  double _dismissThreshold = 100.0; // pixels (updated in build)

  // Animation controller for animating the horizontal offset (snap-back or
  // animate-off-screen). Nullable to avoid LateInitializationError; we
  // initialize it in _initializeAnimations but guard accesses.
  AnimationController? _dragAnimationController;
  Animation<double>? _dragAnimation;
  bool _isDismissing = false;

  // Seek interaction state for the mini-player progress bar
  // _seekDragValue is a temporary progress value (0.0 - 1.0) while user is
  // dragging the mini-player seekbar. When null, we display the real progress
  // from the controller.
  double? _seekDragValue;
  // When true, the outer swipe-to-dismiss gesture should ignore the current
  // horizontal drag because it started inside the seek bar area.
  bool _ignoreOuterDrag = false;

  // Cache screen width (updated in build) so animations can target off-screen
  // positions without requiring a BuildContext during the animation completion.
  double _screenWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Slide animation controller (bottom to top)
    _slideAnimationController = AnimationController(
      duration: _MiniVideoPlayerConfig.animationDuration,
      vsync: this,
    );

    // Fade animation controller
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Slide animation (from bottom to top)
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0.0, 1.0), // Start from bottom (off-screen)
          end: Offset.zero, // End at normal position
        ).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeOut),
    );

    // Drag animation controller (used to animate snap-back or to animate the
    // view off-screen when dismissing)
    _dragAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _showMiniPlayer() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });

      // Stagger the animations
      _slideAnimationController.forward();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _fadeAnimationController.forward();
        }
      });

      // Add haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  void _hideMiniPlayer() {
    if (_isVisible) {
      _fadeAnimationController.reverse();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _slideAnimationController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isVisible = false;
              });
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    _fadeAnimationController.dispose();
    _dragAnimationController?.dispose();
    super.dispose();
  }

  // Safely check if a controller is initialized without throwing if it's disposed
  bool controllerIsInitializedSafely(VideoPlayerController? c) {
    try {
      return c?.value.isInitialized ?? false;
    } catch (_) {
      return false;
    }
  }

  // Safely read aspect ratio with a sensible fallback
  double controllerAspectRatioSafely(VideoPlayerController? c) {
    try {
      final a = c?.value.aspectRatio ?? 0;
      return (a == 0) ? 16 / 9 : a;
    } catch (_) {
      return 16 / 9;
    }
  }

  /// Handle horizontal drag start
  void _onHorizontalDragStart(DragStartDetails details) {
    // If the drag begins inside the seekbar area, mark to ignore outer drag
    // handling so the seekbar can handle the gesture without interference.
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        final local = box.globalToLocal(details.globalPosition);
        // Compute top of progress bar inside the mini-player container.
        // The progress bar sits at bottom with bottom: 2.w and height
        // _MiniVideoPlayerConfig.progressBarHeight, so top = height - 2.w - barHeight.
        final barBottomPadding = 2.w;
        final barHeight = _MiniVideoPlayerConfig.progressBarHeight;
        final hitPadding = 8.w; // extend touch area vertically a bit
        final barTop =
            box.size.height - barBottomPadding - barHeight - hitPadding;
        if (local.dy >= barTop) {
          _ignoreOuterDrag = true;
          return;
        }
      }
    } catch (_) {
      // If anything goes wrong, fall back to normal behavior.
    }
    // Cancel any running drag animation and start fresh
    if (_dragAnimationController?.isAnimating ?? false) {
      _dragAnimationController!.stop();
    }

    _rawHorizontalDragOffset = 0.0;
    _horizontalDragOffset = 0.0;
    _isDismissing = false;
  }

  /// Handle horizontal drag update
  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // If this drag was marked as belonging to the seekbar, ignore the outer
    // drag handling so the inner progress bar can receive updates.
    if (_ignoreOuterDrag) return;
    // Track the raw finger movement but display a resisted mapping so the
    // view doesn't follow the finger 1:1 initially.
    _rawHorizontalDragOffset += details.delta.dx;

    // Map raw drag to displayed offset using resistance curve
    final mapped = _mapDragWithResistance(_rawHorizontalDragOffset);

    setState(() {
      _horizontalDragOffset = mapped;
    });
  }

  /// Handle horizontal drag end
  void _onHorizontalDragEnd(DragEndDetails details) {
    // If we ignored the outer drag because it was a seek interaction, clear
    // the flag and don't treat this as a dismiss gesture.
    if (_ignoreOuterDrag) {
      _ignoreOuterDrag = false;
      return;
    }
    final rawAbs = _rawHorizontalDragOffset.abs();
    final velocityAbs = details.velocity.pixelsPerSecond.dx.abs();

    // Update thresholds based on (possibly updated) _dismissThreshold.
    final resistanceWindow = _dismissThreshold * 0.4;

    // If the user released before reaching the resistance threshold, always
    // snap back. Require a stronger fling to bypass (avoid accidental swipes).
    if (rawAbs < resistanceWindow && velocityAbs < 650) {
      _animateHorizontalOffsetTo(
        0.0,
        duration: const Duration(milliseconds: 320),
      );
      return;
    }

    // If user dragged far enough (or flung), animate off-screen and dismiss.
    final shouldDismiss = rawAbs >= _dismissThreshold || velocityAbs > 850;

    if (shouldDismiss) {
      // animate off-screen in the direction of the drag
      final sign = _rawHorizontalDragOffset.sign == 0
          ? 1.0
          : _rawHorizontalDragOffset.sign;
      final screenWidth = _screenWidth > 0
          ? _screenWidth
          : MediaQuery.of(context).size.width;
      final target = sign * (screenWidth + 120.0);
      _animateHorizontalOffsetTo(
        target,
        duration: const Duration(milliseconds: 340),
      );
    } else {
      // Animate back to origin (snap back)
      _animateHorizontalOffsetTo(
        0.0,
        duration: const Duration(milliseconds: 340),
      );
    }
  }

  // Map the raw finger drag to a displayed offset that applies high
  // resistance for the first 40% of the dismiss distance.
  double _mapDragWithResistance(double rawDx) {
    final sign = rawDx.sign == 0 ? 1.0 : rawDx.sign;
    final absRaw = rawDx.abs();

    // Make resistance scale with _dismissThreshold so it feels consistent on
    // different screen sizes.
    final resistanceWindow = _dismissThreshold * 0.4; // first 40%

    // Strong initial resistance, then medium resistance until full threshold,
    // then 1:1 beyond that.
    const firstFactor = 0.12; // very resistant (12% of finger movement)
    const midFactor = 0.6; // medium resistance (60% of finger movement)

    if (absRaw <= resistanceWindow) {
      // Very resistant: tiny movement for small drags
      return sign * absRaw * firstFactor;
    }

    if (absRaw <= _dismissThreshold) {
      // After leaving the strongly resisted window, track with midFactor
      final firstDisplayed = resistanceWindow * firstFactor;
      final extra = absRaw - resistanceWindow;
      return sign * (firstDisplayed + extra * midFactor);
    }

    // Past full threshold, add overflow 1:1 so it can animate off-screen.
    final firstDisplayed = resistanceWindow * firstFactor;
    final midDisplayed = (_dismissThreshold - resistanceWindow) * midFactor;
    final overflow = absRaw - _dismissThreshold;
    return sign * (firstDisplayed + midDisplayed + overflow);
  }

  // Animate the visible horizontal offset to a target value. If target is
  // off-screen (abs > screen width) we will call the dismiss routine once the
  // animation completes.
  void _animateHorizontalOffsetTo(double target, {Duration? duration}) {
    if (_dragAnimationController?.isAnimating ?? false) {
      _dragAnimationController!.stop();
    }

    // Ensure controller exists and set duration
    if (_dragAnimationController == null) {
      _dragAnimationController = AnimationController(
        duration: duration ?? const Duration(milliseconds: 300),
        vsync: this,
      );
    } else {
      _dragAnimationController!.duration =
          duration ?? const Duration(milliseconds: 300);
    }

    _dragAnimation =
        Tween<double>(begin: _horizontalDragOffset, end: target).animate(
          CurvedAnimation(
            parent: _dragAnimationController!,
            curve: Curves.easeOutCubic,
          ),
        )..addListener(() {
          setState(() {
            _horizontalDragOffset = _dragAnimation!.value;
          });
        });

    _dragAnimationController!
      ..reset()
      ..forward().whenComplete(() async {
        // If the target is off-screen, perform the dismiss sequence once.
        final sw = (_screenWidth > 0
            ? _screenWidth
            : MediaQuery.of(context).size.width);
        if (!_isDismissing && target.abs() > sw) {
          _isDismissing = true;
          await _dismissMiniPlayer();
        } else {
          // If snapped back to 0, clear raw offset
          if (target == 0.0) {
            _rawHorizontalDragOffset = 0.0;
            _horizontalDragOffset = 0.0;
          }
        }
      });
  }

  /// Dismiss mini player
  Future<void> _dismissMiniPlayer() async {
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    // Animate out (don't await since it's void)
    _hideMiniPlayer();

    // Close and stop video
    await videoNotifier.closeMiniPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoPlayerProvider);
    final shouldShow = videoState.showMiniPlayer && videoState.isMinimized;

    final buildSummary =
        '$shouldShow|${videoState.showMiniPlayer}|${videoState.isMinimized}|${videoState.currentVideoId}';
    if (_lastBuildSummary != buildSummary) {
      debugPrint(
        '[MiniVideoPlayer] build - shouldShow: $shouldShow, showMiniPlayer: ${videoState.showMiniPlayer}, isMinimized: ${videoState.isMinimized}, currentVideoId: ${videoState.currentVideoId}',
      );
      _lastBuildSummary = buildSummary;
    }

    // Update visibility based on video state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldShow && !_hasVideo) {
        if (_lastVisibilityAction != 'show') {
          debugPrint('[MiniVideoPlayer] Showing mini player');
          _lastVisibilityAction = 'show';
        }
        _showMiniPlayer();
      } else if (!shouldShow && _hasVideo) {
        if (_lastVisibilityAction != 'hide') {
          debugPrint('[MiniVideoPlayer] Hiding mini player');
          _lastVisibilityAction = 'hide';
        }
        _hideMiniPlayer();
      }
      _hasVideo = shouldShow;
    });

    // Don't render if not visible
    if (!_isVisible && !shouldShow) {
      if (_lastRenderDecision != 'skip') {
        debugPrint(
          '[MiniVideoPlayer] Not rendering - _isVisible: $_isVisible, shouldShow: $shouldShow',
        );
        _lastRenderDecision = 'skip';
      }
      return const SizedBox.shrink();
    }

    _lastRenderDecision = 'render';

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildMiniPlayerContent(context, videoState),
      ),
    );
  }

  Widget _buildMiniPlayerContent(BuildContext context, videoState) {
    final videoNotifier = ref.read(videoPlayerProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    _screenWidth = screenWidth;
    // Make the dismiss threshold proportional to screen width so the
    // resistance scales across devices. Use at least 100 px to avoid being
    // too small on very narrow screens.
    _dismissThreshold = (screenWidth * 0.25).clamp(100.0, screenWidth);
    final cardWidth =
        screenWidth -
        (_MiniVideoPlayerConfig.marginHorizontal * 2); // account for margins
    final previewWidth = (cardWidth * 0.30).clamp(48.w, 160.w);

    final opacity = (1.0 - (_horizontalDragOffset.abs() / screenWidth)).clamp(
      0.0,
      1.0,
    );

    return GestureDetector(
      onTap: () => _openFullPlayer(context),
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Transform.translate(
        offset: Offset(_horizontalDragOffset, 0),
        child: Opacity(
          opacity: opacity,
          child: Container(
            height: _MiniVideoPlayerConfig.height,
            margin: EdgeInsets.symmetric(
              horizontal: _MiniVideoPlayerConfig.marginHorizontal,
            ),
            decoration: BoxDecoration(
              color: _MiniVideoPlayerConfig.backgroundColor,
              borderRadius: BorderRadius.circular(
                _MiniVideoPlayerConfig.borderRadius,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 12.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 5.h, 10.w, 13.h),

                  child: Row(
                    children: [
                      // Video preview as rounded "album art" (30% of card)
                      _buildVideoPreview(videoState, previewWidth),

                      SizedBox(width: _MiniVideoPlayerConfig.spacing),

                      // Video info (title + subtitle)
                      Expanded(child: _buildVideoInfo(videoState)),

                      SizedBox(width: _MiniVideoPlayerConfig.spacing),

                      // Play/Pause button
                      _buildPlayPauseButton(videoState, videoNotifier),

                      SizedBox(width: 8.w),

                      // Close button
                      _buildCloseButton(videoNotifier),
                    ],
                  ),
                ),

                // Progress bar at bottom (interactive). We compute progress
                // from the controller and allow tap/drag seeking via the
                // provider's seekTo API. While dragging we keep a temporary
                // _seekDragValue to show the transient position.
                (() {
                  final controller = videoState.controller;

                  final isInit = controllerIsInitializedSafely(controller);

                  Duration position = Duration.zero;
                  Duration duration = Duration(milliseconds: 30000);

                  if (isInit) {
                    try {
                      position = controller!.value.position;
                      duration = controller.value.duration ?? duration;
                    } catch (_) {
                      position = Duration.zero;
                      duration = Duration(milliseconds: 30000);
                    }
                  }

                  final posMs = position.inMilliseconds.toDouble();
                  final durMs = duration.inMilliseconds > 0
                      ? duration.inMilliseconds.toDouble()
                      : (posMs + 30000);

                  final progress = durMs > 0
                      ? (posMs / durMs).clamp(0.0, 1.0)
                      : 0.0;

                  // Use temporary seek drag value if user is interacting
                  final effectiveProgress = _seekDragValue ?? progress;

                  return Stack(
                    children: [
                      // Interactive bar (handles taps and drags)
                      _buildInteractiveProgressBar(
                        progress: progress,
                        videoState: videoState,
                        videoNotifier: videoNotifier,
                        cardWidth: cardWidth,
                        duration: duration,
                      ),

                      // Overlaying dot that sits above the whole card UI.
                      // Calculate left offset relative to the card container.
                      Builder(
                        builder: (ctx) {
                          final totalBarWidth = (cardWidth - (8.w * 2)).clamp(
                            0.0,
                            double.infinity,
                          );
                          final dotSize = 12.w;
                          final filledWidth = totalBarWidth * effectiveProgress;

                          final dotLeft = (8.w + (filledWidth - dotSize / 2))
                              .clamp(0.0, cardWidth - dotSize);

                          return Positioned(
                            left: dotLeft,
                            bottom:
                                3.w +
                                (_MiniVideoPlayerConfig.progressBarHeight -
                                        dotSize) /
                                    2,
                            child: Container(
                              width: dotSize,
                              height: dotSize,
                              decoration: BoxDecoration(
                                color: appColors().primaryColorApp,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 2.w,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: dotSize * 0.58,
                                  height: dotSize * 0.58,
                                  decoration: BoxDecoration(
                                    color: appColors().primaryColorApp,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                })(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build live video preview
  Widget _buildVideoPreview(videoState, double previewWidth) {
    final controller = videoState.controller;
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    final canShowLive =
        controller != null &&
        !videoNotifier.isControllerDisposed(controller) &&
        !videoNotifier.isControllerScheduledForDisposal(controller) &&
        controllerIsInitializedSafely(controller);

    return SizedBox(
      width: previewWidth,
      height: previewWidth,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10.w),
        ),
        clipBehavior: Clip.hardEdge,
        child: canShowLive
            ? AspectRatio(
                aspectRatio: controllerAspectRatioSafely(controller),
                child: _safeBuildVideoPlayer(controller),
              )
            : _buildVideoPlaceholder(videoState),
      ),
    );
  }

  Widget _safeBuildVideoPlayer(VideoPlayerController? controller) {
    if (controller == null) return _buildDefaultPlaceholder();
    try {
      return VideoPlayer(controller);
    } catch (err, st) {
      debugPrint(
        '[MiniVideoPlayer] VideoPlayer construction failed: $err\n$st',
      );
      return _buildDefaultPlaceholder();
    }
  }

  /// Build video placeholder when not initialized
  Widget _buildVideoPlaceholder(videoState) {
    return Container(
      color: Colors.grey[900],
      child: videoState.thumbnailUrl != null
          ? Image.network(
              videoState.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildDefaultPlaceholder(),
            )
          : _buildDefaultPlaceholder(),
    );
  }

  /// Build default placeholder icon
  Widget _buildDefaultPlaceholder() {
    return Center(
      child: Icon(Icons.videocam_rounded, size: 40.w, color: Colors.black38),
    );
  }

  Widget _buildVideoInfo(videoState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          videoState.currentVideoTitle ?? 'Unknown Video',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (videoState.currentVideoSubtitle != null) ...[
          SizedBox(height: 2.h),
          Text(
            videoState.currentVideoSubtitle!,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildPlayPauseButton(videoState, videoNotifier) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        videoNotifier.togglePlayPause();
      },
      child: Container(
        width: _MiniVideoPlayerConfig.playButtonSize,
        height: _MiniVideoPlayerConfig.playButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: appColors().primaryColorApp,
        ),
        child: Center(
          child: videoState.isLoading
              ? SizedBox(
                  width: _MiniVideoPlayerConfig.playIconSize,
                  height: _MiniVideoPlayerConfig.playIconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.w,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      appColors().primaryColorApp,
                    ),
                  ),
                )
              : Icon(
                  videoState.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: _MiniVideoPlayerConfig.playIconSize,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(videoNotifier) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _dismissMiniPlayer();
      },
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black12,
        ),
        child: Icon(Icons.close_rounded, size: 20.w, color: Colors.black),
      ),
    );
  }

  /// Build an interactive progress bar for the mini-player. Supports
  /// tap-to-seek and drag-to-seek. While dragging we set a temporary
  /// `_seekDragValue` to show the transient position; the actual seek is
  /// performed on drag end (tap seeks immediately).
  Widget _buildInteractiveProgressBar({
    required double progress,
    required dynamic videoState,
    required dynamic videoNotifier,
    required double cardWidth,
    required Duration duration,
  }) {
    final barRadius = 4.w;

    // The interactive area width (accounting for horizontal margins used
    // when rendering the bar).
    final totalBarWidth = (cardWidth - (8.w * 2)).clamp(0.0, double.infinity);

    return Positioned(
      bottom: 2.w,
      left: 0,
      right: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          try {
            final dx = details.localPosition.dx.clamp(0.0, totalBarWidth);
            final rel = (totalBarWidth > 0) ? (dx / totalBarWidth) : 0.0;
            final millis = (rel * duration.inMilliseconds).round();
            videoNotifier.seekTo(Duration(milliseconds: millis));
            // show transient value briefly
            setState(() {
              _seekDragValue = rel;
            });
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _seekDragValue = null;
                });
              }
            });
          } catch (_) {}
        },
        onHorizontalDragStart: (details) {
          setState(() {
            _seekDragValue = progress;
          });
        },
        onHorizontalDragUpdate: (details) {
          try {
            final dx = details.localPosition.dx.clamp(0.0, totalBarWidth);
            final rel = (totalBarWidth > 0) ? (dx / totalBarWidth) : 0.0;
            setState(() {
              _seekDragValue = rel;
            });
          } catch (_) {}
        },
        onHorizontalDragEnd: (details) {
          try {
            final rel = (_seekDragValue ?? progress).clamp(0.0, 1.0);
            final millis = (rel * duration.inMilliseconds).round();
            videoNotifier.seekTo(Duration(milliseconds: millis));
          } catch (_) {}
          if (mounted) {
            setState(() {
              _seekDragValue = null;
            });
          }
        },
        child: Container(
          height: _MiniVideoPlayerConfig.progressBarHeight,
          margin: EdgeInsets.symmetric(horizontal: 8.w),
          child: Stack(
            children: [
              // Background track
              Container(
                width: double.infinity,
                height: _MiniVideoPlayerConfig.progressBarHeight,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(barRadius),
                ),
              ),

              // Filled portion — use the transient seek drag value when the
              // user is interacting so the colored track moves with the dot.
              // Fall back to the real progress when not interacting.
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ((_seekDragValue ?? progress).isFinite)
                    ? (_seekDragValue ?? progress).clamp(0.0, 1.0)
                    : 0.0,
                child: Container(
                  height: _MiniVideoPlayerConfig.progressBarHeight,
                  decoration: BoxDecoration(
                    color: appColors().primaryColorApp,
                    borderRadius: BorderRadius.circular(barRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullPlayer(BuildContext context) {
    final videoState = ref.read(videoPlayerProvider);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    if (videoState.currentVideoId == null) return;

    HapticFeedback.lightImpact();

    // Expand to full screen
    videoNotifier.expandToFullScreen();

    // Navigate to full video player
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerView(
          videoUrl: '', // Will use existing controller
          videoId: videoState.currentVideoId!,
          title: videoState.currentVideoTitle,
          subtitle: videoState.currentVideoSubtitle,
          thumbnailUrl: videoState.thumbnailUrl,
          // Use channel metadata from provider when available so expanding
          // the mini-player preserves avatar/subscribe info.
          channelId: videoState.channelId,
          channelAvatarUrl: videoState.channelAvatarUrl,
          videoItem: null,
          playlist: videoState.playlist,
          playlistIndex: videoState.currentIndex,
        ),
      ),
    );
  }
}
