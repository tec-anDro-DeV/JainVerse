// dart:async not required after removing timestamp hide timer

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Overlay seek bar that straddles the bottom edge of the video area.
///
/// - Renders half over the video and half over the content below by using a
///   negative vertical offset (Positioned with negative bottom).
/// - Does not change layout height (stays in an overlay Stack).
/// - Shows buffered track, play progress, draggable thumb, tap-to-seek.
/// - Auto-hides timestamps after 2s of pointer inactivity. Any pointer move
///   or tap will show timestamps again.
class OverlaySeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration? buffered;
  final ValueChanged<Duration> onSeek;
  final bool enabled;
  final Color? progressColor;
  final Color? backgroundColor;
  final Color? handleColor;
  final Color? textColor;

  const OverlaySeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.buffered,
    this.enabled = true,
    this.progressColor,
    this.backgroundColor,
    this.handleColor,
    this.textColor,
  });

  @override
  State<OverlaySeekBar> createState() => _OverlaySeekBarState();
}

class _OverlaySeekBarState extends State<OverlaySeekBar>
    with SingleTickerProviderStateMixin {
  // drag progress value 0..1
  double? _dragValue;
  // whether to show the timestamps
  // timestamps removed per UX request
  // animation for enter/exit
  late AnimationController _animController;

  // simple haptic debounce when scrubbing keyframes
  int? _lastHapticSecond;

  // Increased total widget height to give a larger, easier-to-hit area
  // while keeping the visible track unchanged. Improves tap/drag reliability.
  static final double _barHeight = 84.h; // total widget height (hit area)

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..value = 1.0;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
    }
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
  }

  double _getBufferedFraction() {
    if (widget.duration.inMilliseconds <= 0) return 0.0;
    final b = widget.buffered ?? Duration.zero;
    return (b.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0);
  }

  double _getPlayedFraction() {
    if (widget.duration.inMilliseconds <= 0) return 0.0;
    final base =
        _dragValue ??
        (widget.position.inMilliseconds / widget.duration.inMilliseconds);
    return base.clamp(0.0, 1.0);
  }

  void _seekToFraction(double fraction) {
    final newPos = Duration(
      milliseconds: (fraction * widget.duration.inMilliseconds).round(),
    );
    widget.onSeek(newPos);
  }

  // Haptic feedback when dragged across integer seconds
  void _maybeHapticForFraction(double fraction) {
    if (!widget.enabled) return;
    final seconds = (fraction * widget.duration.inSeconds).round();
    if (_lastHapticSecond == null || _lastHapticSecond != seconds) {
      HapticFeedback.selectionClick();
      _lastHapticSecond = seconds;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Match colors and defaults with MediaSeekBar for a consistent look
    final progressColor = widget.progressColor ?? theme.primaryColor;
    final backgroundColor = widget.backgroundColor ?? Colors.white24;
    final handleColor =
        widget.handleColor ?? widget.progressColor ?? theme.primaryColor;

    final played = _getPlayedFraction();
    final buffered = _getBufferedFraction();

    return RepaintBoundary(
      child: Semantics(
        label: 'Video seek bar',
        value: '${_format(widget.position)} of ${_format(widget.duration)}',
        slider: true,
        child: MouseRegion(
          onHover: (_) {},
          onEnter: (_) {},
          child: GestureDetector(
            // Prevent vertical drags from bubbling to parent scroll views by
            // handling vertical drag gestures here. We only act on
            // horizontal drags for seeking; vertical drags are captured
            // (to stop scroll) but not used.
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: (_) {},
            onVerticalDragUpdate: (_) {},
            onVerticalDragEnd: (_) {},
            onTapDown: (details) {
              // compute local fraction and seek
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final local = box.globalToLocal(details.globalPosition);
              final w = box.size.width; // full width - no internal padding
              final dx = (local.dx).clamp(0.0, w);
              final frac = (w > 0) ? (dx / w) : 0.0;
              _seekToFraction(frac);
            },
            onHorizontalDragStart: (_) {
              _lastHapticSecond = null;
            },
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final w = box.size.width;
              if (w <= 0) return;
              final local = box.globalToLocal(details.globalPosition);
              final dx = local.dx.clamp(0.0, w);
              final frac = (dx / w).clamp(0.0, 1.0);
              setState(() {
                _dragValue = frac;
              });
              _maybeHapticForFraction(frac);
            },
            onHorizontalDragEnd: (details) {
              final frac = (_dragValue ?? played).clamp(0.0, 1.0);
              _seekToFraction(frac);
              setState(() => _dragValue = null);
            },
            child: FadeTransition(
              opacity: _animController,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _animController,
                        curve: Curves.easeOut,
                      ),
                    ),
                child: Container(
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: SizedBox(
                    height: _barHeight.h,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 900.w),
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // visual bar
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 0.w),
                                child: SizedBox(
                                  height: 24.h,
                                  child: Stack(
                                    // Allow the thumb hit target and visible dot
                                    // to slightly overflow the track so the
                                    // visible dot can be centered exactly at
                                    // the start/end positions.
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      Container(
                                        height: 6.h,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: buffered,
                                        child: Container(
                                          height: 6.h,
                                          decoration: BoxDecoration(
                                            color: backgroundColor.withOpacity(
                                              0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4.w,
                                            ),
                                          ),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: played,
                                        child: Container(
                                          height: 6.h,
                                          decoration: BoxDecoration(
                                            color: progressColor,
                                          ),
                                        ),
                                      ),
                                      // thumb hit target — position so the *center* of the
                                      // visible dot aligns with the played fraction.
                                      LayoutBuilder(
                                        builder: (context, bc) {
                                          final width = bc.maxWidth;
                                          // Larger hit-target so users can tap and drag
                                          // comfortably, especially near edges.
                                          final thumbSize = 56.w;
                                          final dotSize = 15.w;
                                          // Position the hit-target such that its
                                          // center equals `played * width`. Instead
                                          // of clamping the left edge (which caused
                                          // a visible gap at the ends), clamp the
                                          // center so the visible dot can sit flush
                                          // with the track start/end.
                                          var left =
                                              (played * width) -
                                              (thumbSize / 2);
                                          // Clamp so the *center* stays within the
                                          // track (this allows partial overflow of
                                          // the hit target while keeping the visible
                                          // dot centered exactly at 0..width).
                                          left = left.clamp(
                                            -thumbSize / 2,
                                            width - (thumbSize / 2),
                                          );
                                          // Make the visible thumb draggable by wrapping
                                          // the hit-target in a GestureDetector that
                                          // calculates the seek fraction using the
                                          // LayoutBuilder's width. This keeps drag
                                          // behavior reliable even when the thumb
                                          // partially overflows the track.
                                          return Transform.translate(
                                            offset: Offset(left, 0),
                                            child: GestureDetector(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              // Capture vertical drags on the thumb so
                                              // parent scroll views don't steal the
                                              // gesture when the user intends to seek.
                                              onVerticalDragStart: (_) {},
                                              onVerticalDragUpdate: (_) {},
                                              onVerticalDragEnd: (_) {},
                                              onHorizontalDragStart: (_) {
                                                _lastHapticSecond = null;
                                              },
                                              onHorizontalDragUpdate:
                                                  (DragUpdateDetails details) {
                                                    final box =
                                                        context.findRenderObject()
                                                            as RenderBox?;
                                                    if (box == null) return;
                                                    final w = width;
                                                    if (w <= 0) return;
                                                    final local = box
                                                        .globalToLocal(
                                                          details
                                                              .globalPosition,
                                                        );
                                                    final dx = local.dx.clamp(
                                                      0.0,
                                                      w,
                                                    );
                                                    final frac = (dx / w).clamp(
                                                      0.0,
                                                      1.0,
                                                    );
                                                    setState(() {
                                                      _dragValue = frac;
                                                    });
                                                    _maybeHapticForFraction(
                                                      frac,
                                                    );
                                                  },
                                              onHorizontalDragEnd: (_) {
                                                final frac =
                                                    (_dragValue ?? played)
                                                        .clamp(0.0, 1.0);
                                                _seekToFraction(frac);
                                                setState(
                                                  () => _dragValue = null,
                                                );
                                              },
                                              child: SizedBox(
                                                width: thumbSize,
                                                height: thumbSize,
                                                child: Center(
                                                  child: Container(
                                                    width: dotSize,
                                                    height: dotSize,
                                                    decoration: BoxDecoration(
                                                      color: handleColor,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black26,
                                                          blurRadius: 2.r,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // timestamps removed
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
