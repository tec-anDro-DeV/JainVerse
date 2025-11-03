import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// YouTube-style video card that auto-plays (muted) when visible.
/// Transitions smoothly from thumbnail to video.
class AutoplayVideoCard extends StatefulWidget {
  final VideoItem item;
  final VoidCallback? onTap;
  final bool shouldPlay;
  final VideoPlayerController? sharedController;
  final VoidCallback? onVisibilityChanged;
  final double? width;

  const AutoplayVideoCard({
    Key? key,
    required this.item,
    this.onTap,
    this.shouldPlay = false,
    this.sharedController,
    this.onVisibilityChanged,
    this.width,
  }) : super(key: key);

  @override
  State<AutoplayVideoCard> createState() => _AutoplayVideoCardState();
}

class _AutoplayVideoCardState extends State<AutoplayVideoCard>
    with AutomaticKeepAliveClientMixin {
  bool _isVideoVisible = false;
  // Seek/progress state
  double _progress = 0.0; // 0..1
  bool _isInteracting = false; // user is dragging/tapping the seekbar
  bool _controlsVisible =
      true; // overlay controls visible; auto-hide but keep seekbar
  Timer? _hideControlsTimer;
  final GlobalKey _barKey = GlobalKey();
  VoidCallback? _controllerListener;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(AutoplayVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle play/pause state changes
    if (widget.shouldPlay != oldWidget.shouldPlay) {
      _updatePlaybackState();
    }

    // If controller changed, update visibility state
    if (widget.sharedController != oldWidget.sharedController) {
      if (!widget.shouldPlay || widget.sharedController == null) {
        setState(() => _isVideoVisible = false);
      }
      // Reattach listener to new controller
      _detachController(oldWidget.sharedController);
      _attachController(widget.sharedController);
    }
  }

  @override
  void initState() {
    super.initState();
    _attachController(widget.sharedController);
  }

  @override
  void dispose() {
    // Cancel timer first
    try {
      _hideControlsTimer?.cancel();
      _hideControlsTimer = null;
    } catch (e) {
      debugPrint('[AutoplayCard] Error canceling timer: $e');
    }

    // Detach controller listener
    try {
      _detachController(widget.sharedController);
    } catch (e) {
      debugPrint('[AutoplayCard] Error detaching controller: $e');
    }

    super.dispose();
  }

  void _attachController(VideoPlayerController? controller) {
    if (controller == null) return;
    // remove old if any
    _detachController(controller);
    _controllerListener = () {
      if (!mounted) return;
      final c = controller;
      if (c.value.isInitialized) {
        final d = c.value.duration.inMilliseconds;
        final p = c.value.position.inMilliseconds.clamp(0, d);
        final newProgress = d == 0 ? 0.0 : (p / d);
        if (!_isInteracting) {
          // Schedule setState for after the current frame to avoid build-phase conflicts
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _progress = newProgress);
            }
          });
        }
      }
    };
    controller.addListener(_controllerListener!);
  }

  void _detachController(VideoPlayerController? controller) {
    if (controller == null) return;
    if (_controllerListener != null) {
      try {
        controller.removeListener(_controllerListener!);
      } catch (_) {}
      _controllerListener = null;
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _controlsVisible = false;
        _isInteracting = false;
      });
    });
  }

  void _showControlsTemporarily() {
    _hideControlsTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _controlsVisible = true;
    });
    _startHideControlsTimer();
  }

  void _handleSeekAtGlobal(Offset globalPosition) {
    final barBox = _barKey.currentContext?.findRenderObject() as RenderBox?;
    final controller = widget.sharedController;
    if (barBox == null || controller == null || !controller.value.isInitialized)
      return;
    final local = barBox.globalToLocal(globalPosition);
    final rel = (local.dx / barBox.size.width).clamp(0.0, 1.0);
    setState(() => _progress = rel);
    _seekToRelative(rel);
    // show dot briefly for taps
    setState(() => _isInteracting = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _isInteracting = false);
    });
    _startHideControlsTimer();
  }

  void _updateDragProgress(Offset globalPosition) {
    final barBox = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (barBox == null) return;
    final local = barBox.globalToLocal(globalPosition);
    final rel = (local.dx / barBox.size.width).clamp(0.0, 1.0);
    setState(() => _progress = rel);
  }

  void _finishDragSeek() {
    final controller = widget.sharedController;
    if (controller == null || !controller.value.isInitialized) {
      setState(() => _isInteracting = false);
      return;
    }
    _seekToRelative(_progress);
    setState(() => _isInteracting = false);
    _startHideControlsTimer();
  }

  void _seekToRelative(double rel) {
    final controller = widget.sharedController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration == Duration.zero) return;
    final millis = (duration.inMilliseconds * rel).round();
    controller.seekTo(Duration(milliseconds: millis));
  }

  void _updatePlaybackState() {
    if (!mounted) return;

    final controller = widget.sharedController;
    if (controller == null || !controller.value.isInitialized) {
      setState(() => _isVideoVisible = false);
      return;
    }

    if (widget.shouldPlay) {
      // Fade in video and start playback
      setState(() => _isVideoVisible = true);
      if (!controller.value.isPlaying) {
        // Use post frame callback to avoid build conflicts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              controller.value.isInitialized &&
              !controller.value.isPlaying) {
            controller.play();
          }
        });
      }
      // Show controls briefly when this card gains focus
      _showControlsTemporarily();
    } else {
      // Pause and fade back to thumbnail
      if (controller.value.isPlaying) {
        // Use post frame callback to avoid build conflicts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              controller.value.isInitialized &&
              controller.value.isPlaying) {
            controller.pause();
          }
        });
      }
      _hideControlsTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = false);
      setState(() => _isVideoVisible = false);
    }
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  String _formatViews(int? views) {
    if (views == null || views == 0) return '0 views';

    if (views < 1000) {
      return '$views ${views == 1 ? 'view' : 'views'}';
    } else if (views < 1000000) {
      final k = (views / 1000).toStringAsFixed(1);
      return '${k.endsWith('.0') ? k.substring(0, k.length - 2) : k}K views';
    } else {
      final m = (views / 1000000).toStringAsFixed(1);
      return '${m.endsWith('.0') ? m.substring(0, m.length - 2) : m}M views';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return VisibilityDetector(
      key: Key('video_${widget.item.id}'),
      onVisibilityChanged: (info) {
        widget.onVisibilityChanged?.call();
      },
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video/Thumbnail container
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      // Background thumbnail (always visible)
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: widget.item.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade900,
                            child: Center(
                              child: Icon(
                                Icons.video_library_rounded,
                                size: 48.w,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade900,
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 48.w,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),

                      // Video player layer (instant replace when playing)
                      if (_isVideoVisible &&
                          widget.sharedController != null &&
                          widget.sharedController!.value.isInitialized)
                        Positioned.fill(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: widget.sharedController!.value.size.width,
                              height:
                                  widget.sharedController!.value.size.height,
                              child: VideoPlayer(widget.sharedController!),
                            ),
                          ),
                        ),

                      // Duration badge (bottom right) — only visible when controls are shown
                      if (widget.item.duration.isNotEmpty && _controlsVisible)
                        Positioned(
                          bottom: 28.h,
                          right: 8.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4.w),
                            ),
                            child: Text(
                              widget.item.duration,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      // Thin sticky seek bar at the very bottom of the video (no gap)
                      // Only enabled for the focused card (shouldPlay) and when controller is ready
                      if (widget.sharedController != null &&
                          widget.sharedController!.value.isInitialized &&
                          widget.shouldPlay)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          // keep height a little larger for touch area but the visible track is thin
                          child: GestureDetector(
                            key: _barKey,
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (details) {
                              if (!widget.shouldPlay) return;
                              _showControlsTemporarily();
                              _handleSeekAtGlobal(details.globalPosition);
                            },
                            onHorizontalDragStart: (details) {
                              if (!widget.shouldPlay) return;
                              _hideControlsTimer?.cancel();
                              setState(() => _isInteracting = true);
                            },
                            onHorizontalDragUpdate: (details) {
                              if (!widget.shouldPlay) return;
                              _updateDragProgress(details.globalPosition);
                            },
                            onHorizontalDragEnd: (details) {
                              if (!widget.shouldPlay) return;
                              _finishDragSeek();
                            },
                            child: SizedBox(
                              height: 28.h,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final primary = Theme.of(
                                    context,
                                  ).primaryColor;
                                  // Ensure we render progress with smooth animation when not interacting
                                  // Anchor the visible track to the very bottom so it is flush with the video edge.
                                  return Stack(
                                    children: [
                                      // background track anchored to bottom
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          height: 5.w,
                                          decoration: BoxDecoration(
                                            color: primary.withOpacity(0.18),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(2.w),
                                              topRight: Radius.circular(2.w),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // animated progress anchored to bottom
                                      Positioned(
                                        left: 0,
                                        bottom: 0,
                                        child: AnimatedContainer(
                                          duration: _isInteracting
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 300,
                                                ),
                                          width: (width * _progress).clamp(
                                            0.0,
                                            width,
                                          ),
                                          height: 5.w,
                                          decoration: BoxDecoration(
                                            color: primary,
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(2.w),
                                              topRight: Radius.circular(2.w),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // seek dot — visible only while interacting and when controls visible
                                      if (_isInteracting &&
                                          widget.shouldPlay &&
                                          _controlsVisible)
                                        Positioned(
                                          left:
                                              (width * _progress).clamp(
                                                0.0,
                                                width,
                                              ) -
                                              6.w,
                                          // position the dot so its center aligns with the track center
                                          bottom: (5.h / 2) - 6.w,
                                          child: AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            opacity: _isInteracting ? 1.0 : 0.0,
                                            child: Container(
                                              width: 12.w,
                                              height: 12.w,
                                              decoration: BoxDecoration(
                                                color: primary,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Metadata section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel avatar
                    if (widget.item.channelImageUrl != null &&
                        widget.item.channelImageUrl!.isNotEmpty)
                      CircleAvatar(
                        radius: 18.w,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: CachedNetworkImageProvider(
                          widget.item.channelImageUrl!,
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 18.w,
                        backgroundColor: Colors.grey.shade800,
                        child: Icon(
                          Icons.person,
                          size: 18.w,
                          color: Colors.grey.shade600,
                        ),
                      ),

                    SizedBox(width: 12.w),

                    // Title and metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            [
                              if (widget.item.channelName != null &&
                                  widget.item.channelName!.isNotEmpty)
                                widget.item.channelName!,
                              _formatViews(widget.item.totalViews),
                              _getTimeAgo(widget.item.createdAt),
                            ].where((s) => s.isNotEmpty).join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 8.w),

                    // Three-dot menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20.w,
                        color: Colors.grey.shade700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.w),
                      ),
                      offset: Offset(0, 8.h),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share_rounded, size: 20.w),
                              SizedBox(width: 12.w),
                              const Text('Share'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'save',
                          child: Row(
                            children: [
                              Icon(Icons.bookmark_outline_rounded, size: 20.w),
                              SizedBox(width: 12.w),
                              const Text('Save to playlist'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'not_interested',
                          child: Row(
                            children: [
                              Icon(Icons.not_interested_rounded, size: 20.w),
                              SizedBox(width: 12.w),
                              const Text('Not interested'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        // Handle menu actions
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
