import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

const _kPrimary = Color(0xFFF47B36);

/// Hard cap on how long a trim selection may be (3 minutes).
const _kMaxTrimSeconds = 180;

/// Minimum window fraction to prevent a zero-width selection.
const _kMinWindowFrac = 0.02;

/// Width of each handle's interactive hit area (logical pixels).
/// Wider than the 22-px pill visual so it's easier to grab.
const _kHandleHitW = 60.0;

/// Width of the playhead hit area (logical pixels).
const _kPlayheadHitW = 32.0;

/// Gesture mode locked at drag-start.
///
/// Once [TrimGestureMode] is set in [onPanStart] it is held for the entire
/// pointer lifetime — [onPanUpdate] guards against the wrong mode so zones
/// can never bleed into each other mid-gesture.
enum TrimGestureMode { none, leftHandle, rightHandle, window, playhead }

/// Professional trim UI shown in the reel upload flow.
///
/// The timeline always renders the **complete** video duration.
/// A fixed-size (3 min) trim window sits on top as an orange highlighted
/// overlay with dimmed regions on either side.
///
/// • For videos **≤ 3 minutes**: the window defaults to the full duration.
///   Individual start/end handles allow the user to narrow the selection
///   (still capped at 3 minutes maximum).
///
/// • For videos **> 3 minutes**: the window is fixed at exactly 3 minutes
///   and is dragged as a whole unit across the full timeline.
///   Separate start/end handles are visible but non-interactive in this mode.
///
/// The white playhead is draggable — dragging seeks the video player to the
/// corresponding position. It is disabled (IgnorePointer) while the user is
/// dragging a handle or the window body.
///
/// Calls [onApply] with the chosen [Duration] range when the user confirms,
/// or [onSkip] when no meaningful trim was applied (full video selected).
class ReelTrimWidget extends StatefulWidget {
  const ReelTrimWidget({
    super.key,
    required this.file,
    required this.onApply,
    required this.onSkip,
    this.isTrimRequired = false,
  });

  final File file;
  final void Function(Duration start, Duration end) onApply;
  final VoidCallback onSkip;

  /// When true the video is > 3 min: Skip is hidden and trim is mandatory.
  final bool isTrimRequired;

  @override
  State<ReelTrimWidget> createState() => _ReelTrimWidgetState();
}

class _ReelTrimWidgetState extends State<ReelTrimWidget> {
  VideoPlayerController? _controller;
  Duration _total = Duration.zero;

  // Trim window as fractions of total duration (0.0 – 1.0).
  double _windowStartFrac = 0.0;
  double _windowEndFrac = 1.0;

  // Playhead fraction — updated by the controller listener AND by drag.
  double _playheadFrac = 0.0;

  // Locked at drag-start; held for the full pointer lifetime.
  TrimGestureMode _gestureMode = TrimGestureMode.none;

  bool _isPlaying = false;
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Derived getters
  // ---------------------------------------------------------------------------

  Duration get _windowStart => _lerp(_total, _windowStartFrac);
  Duration get _windowEnd => _lerp(_total, _windowEndFrac);

  /// True when the video is longer than the max allowed trim duration.
  bool get _isLongVideo => _total.inSeconds > _kMaxTrimSeconds;

  /// True while the user is dragging a handle or the window body.
  /// Used to disable the playhead via IgnorePointer.
  bool get _isTrimming =>
      _gestureMode == TrimGestureMode.leftHandle ||
      _gestureMode == TrimGestureMode.rightHandle ||
      _gestureMode == TrimGestureMode.window;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final c = VideoPlayerController.file(widget.file);
    await c.initialize();
    c.addListener(_onVideoUpdate);
    await c.setLooping(false);
    await c.play();
    if (mounted) {
      final total = c.value.duration;
      // For long videos the window covers only the first 3 minutes.
      final windowEndFrac = (total.inSeconds > _kMaxTrimSeconds)
          ? (_kMaxTrimSeconds / total.inSeconds.toDouble()).clamp(0.0, 1.0)
          : 1.0;
      setState(() {
        _controller = c;
        _total = total;
        _windowEndFrac = windowEndFrac;
        _playheadFrac = 0.0;
        _isPlaying = true;
        _initialized = true;
      });
    }
  }

  void _onVideoUpdate() {
    if (_controller == null || !mounted) return;
    final pos = _controller!.value.position;

    // Loop playback within the selected trim window.
    // Use a 100 ms look-ahead so the seek fires *before* the player fires
    // the video-complete event, preventing the playhead from overshooting
    // the window end and desyncing with the transcoder pipeline.
    final loopPoint = _windowEnd - const Duration(milliseconds: 100);
    if (_total > Duration.zero &&
        loopPoint >= _windowStart &&
        pos >= loopPoint) {
      _controller!.seekTo(_windowStart);
    }

    setState(() {
      _isPlaying = _controller!.value.isPlaying;
      // Do not override the playhead while the user is dragging it.
      if (_gestureMode != TrimGestureMode.playhead &&
          _total.inMilliseconds > 0) {
        _playheadFrac = (pos.inMilliseconds / _total.inMilliseconds).clamp(
          0.0,
          1.0,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Video preview ────────────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: _togglePlay,
            child: Container(
              color: Colors.black,
              child: _initialized && _controller!.value.isInitialized
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                        if (!_isPlaying)
                          Container(
                            width: 56.w,
                            height: 56.w,
                            decoration: const BoxDecoration(
                              color: Colors.black38,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 32.w,
                            ),
                          ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: _kPrimary),
                    ),
            ),
          ),
        ),

        // ── Controls ─────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(26.w, 16.h, 26.w, 0),
                child: _buildTimeLabels(),
              ),
              SizedBox(height: 10.h),

              // Full-duration timeline with trim window overlay — full width.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: LayoutBuilder(
                  builder: (_, constraints) =>
                      _buildTimeline(constraints.maxWidth),
                ),
              ),
              SizedBox(height: 16.h),

              // Buttons
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 26.w),
                child: Row(
                  children: [
                    if (!widget.isTrimRequired) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onSkip,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black54,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 13.h),
                          ),
                          child: const Text('Skip Trim'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                    ],
                    Expanded(
                      flex: widget.isTrimRequired ? 1 : 2,
                      child: ElevatedButton.icon(
                        onPressed: _initialized ? _onApplyPressed : null,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Apply'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade200,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h + MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Time labels
  // ---------------------------------------------------------------------------

  Widget _buildTimeLabels() {
    final selectedMs =
        ((_windowEndFrac - _windowStartFrac) * _total.inMilliseconds).round();
    final clipDuration = Duration(
      milliseconds: selectedMs.clamp(0, _total.inMilliseconds),
    );

    return Row(
      children: [
        // Trim start
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fmt(_windowStart),
              style: TextStyle(
                fontSize: 13.sp,
                color: _kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Start',
              style: TextStyle(fontSize: 10.sp, color: Colors.black38),
            ),
          ],
        ),

        const Spacer(),

        // Center — selected duration + hint
        Column(
          children: [
            Text(
              _fmt(clipDuration),
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.isTrimRequired
                  ? 'Select up to 3 minutes to continue'
                  : 'Optional: trim your video',
              style: TextStyle(fontSize: 10.sp, color: Colors.black38),
            ),
          ],
        ),

        const Spacer(),

        // Trim end + total duration
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _fmt(_windowEnd),
              style: TextStyle(
                fontSize: 13.sp,
                color: _kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'End  •  ${_fmt(_total)}',
              style: TextStyle(fontSize: 10.sp, color: Colors.black38),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Timeline
  // ---------------------------------------------------------------------------

  /// Builds the interactive timeline.
  ///
  /// ## Coordinate space
  ///
  /// The full track background spans [0, maxWidth].  The two handle pills
  /// are always flush against the edges — the LEFT pill's right edge and the
  /// RIGHT pill's left edge define the **inner coordinate space**:
  ///
  /// ```
  /// |<pill>|←──── inner timeline (full duration) ────→|<pill>|
  /// 0      innerLeft                              innerRight   maxWidth
  /// ```
  ///
  /// All fractions (0.0–1.0) map to [innerLeft, innerRight].  startX / endX
  /// are the **inner edges** of their respective pills.
  ///
  /// ## Gesture zone layout (strictly non-overlapping)
  ///
  /// ```
  /// |← handleW →|←── centerWidth ──→|← handleW →|
  /// [ LEFT HANDLE][  CENTER / WINDOW ][ RIGHT HANDLE]
  /// ```
  Widget _buildTimeline(double maxWidth) {
    // ── Layout constants ─────────────────────────────────────────────────────
    const double trackH = 68;
    const double handleVisualW = 22; // pill width (visual only)
    const double vOverflow = 8; // pill protrudes above + below track
    const double handleW = _kHandleHitW; // hit area (wider than visual)

    // Inner coordinate space: fractions 0.0–1.0 map to [innerLeft, innerRight].
    const double innerLeft = handleVisualW;
    final double innerRight = maxWidth - handleVisualW;
    final double innerWidth =
        innerRight - innerLeft; // maxWidth - 2 * handleVisualW

    // ── Derived positions ────────────────────────────────────────────────────
    // startX / endX = inner edges of each pill (boundary between pill & content).
    //   left pill  → [startX - handleVisualW, startX]
    //   right pill → [endX,                   endX + handleVisualW]
    final double startX = innerLeft + _windowStartFrac * innerWidth;
    final double endX = innerLeft + _windowEndFrac * innerWidth;
    final double playheadX = innerLeft + _playheadFrac * innerWidth;

    // Orange border rect spans outer-left of left pill → outer-right of right pill.
    final double borderLeft = startX - handleVisualW;
    final double borderWidth = (endX + handleVisualW) - borderLeft;

    // Left handle hit area: starts at pill's left edge, extends right (into content).
    final double lhLeft = borderLeft.clamp(0.0, maxWidth - handleW);
    final double lhRight = lhLeft + handleW;

    // Right handle hit area: ends at pill's right edge, extends left (into content).
    final double rhLeft = (endX + handleVisualW - handleW).clamp(
      0.0,
      maxWidth - handleW,
    );

    // Center zone: strictly between the two handle hit areas (never negative).
    final double centerLeft = lhRight;
    final double centerWidth = (rhLeft - lhRight).clamp(0.0, maxWidth);

    return SizedBox(
      height: trackH + vOverflow * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── 0. Full-duration track background ─────────────────────────────
          Positioned(
            top: vOverflow,
            left: 0,
            right: 0,
            height: trackH,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),

          // ── 1. Tick marks (inner coordinate space) ─────────────────────────
          if (_initialized && _total.inSeconds > 0)
            Positioned(
              top: vOverflow,
              left: 0,
              width: maxWidth,
              height: trackH,
              child: CustomPaint(
                painter: _TicksPainter(
                  total: _total,
                  innerLeft: innerLeft,
                  innerWidth: innerWidth,
                ),
              ),
            ),

          // ── 2. Dim overlay — left of trim window ───────────────────────────
          if (_windowStartFrac > 0)
            Positioned(
              top: vOverflow,
              left: 0,
              width: borderLeft,
              height: trackH,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0x75000000),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
              ),
            ),

          // ── 3. Dim overlay — right of trim window ──────────────────────────
          if (_windowEndFrac < 1.0)
            Positioned(
              top: vOverflow,
              left: borderLeft + borderWidth,
              right: 0,
              height: trackH,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0x75000000),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                ),
              ),
            ),

          // ── 4. Trim window highlight + orange border ───────────────────────
          // Spans outer-left of left pill → outer-right of right pill.
          // The handle pills render on top (z=7/8), covering the vertical sides
          // of this border so the handles appear as the "walls" of the selection.
          Positioned(
            top: vOverflow,
            left: borderLeft,
            width: borderWidth,
            height: trackH,
            child: Container(
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.18),
                border: Border.all(color: _kPrimary, width: 2.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // ── 5. CENTER drag zone ────────────────────────────────────────────
          if (centerWidth > 0)
            Positioned(
              top: vOverflow,
              left: centerLeft,
              width: centerWidth,
              height: trackH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) {
                  if (kDebugMode) debugPrint('Gesture mode: WINDOW');
                  setState(() => _gestureMode = TrimGestureMode.window);
                },
                onPanUpdate: (d) {
                  if (_gestureMode != TrimGestureMode.window) return;
                  _onWindowBodyDrag(d.delta.dx, innerWidth);
                },
                onPanEnd: (_) => _onDragEnd(),
                onPanCancel: () => _onDragEnd(),
                child: const SizedBox.expand(),
              ),
            ),

          // ── 6. Playhead (visual + gesture) ────────────────────────────────
          // Rendered ABOVE the track but BELOW handles (z-order 6 vs 7/8).
          // IgnorePointer disables it completely while a trim gesture is active.
          if (_initialized)
            Positioned(
              top: 0,
              left: playheadX - _kPlayheadHitW / 2,
              width: _kPlayheadHitW,
              height: trackH + vOverflow * 2,
              child: IgnorePointer(
                ignoring: _isTrimming,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    if (kDebugMode) debugPrint('Gesture mode: PLAYHEAD');
                    setState(() => _gestureMode = TrimGestureMode.playhead);
                  },
                  onPanUpdate: (d) {
                    if (_gestureMode != TrimGestureMode.playhead) return;
                    _onPlayheadDrag(d.delta.dx, innerWidth);
                  },
                  onPanEnd: (_) => _onDragEnd(),
                  onPanCancel: () => _onDragEnd(),
                  child: Center(
                    child: Opacity(
                      opacity: _isTrimming ? 0.35 : 1.0,
                      child: Container(
                        width: 3,
                        height: trackH + vOverflow * 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: const [
                            BoxShadow(color: Color(0x40000000), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── 7. LEFT handle zone (gesture + visual) ─────────────────────────
          // Hit area starts at the pill's left edge and extends right.
          // Pill is aligned to the LEFT so it sits flush against borderLeft.
          Positioned(
            top: 0,
            left: lhLeft,
            width: handleW,
            height: trackH + vOverflow * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                if (_isLongVideo) return; // long video: visual only
                if (kDebugMode) debugPrint('LEFT HANDLE START');
                setState(() => _gestureMode = TrimGestureMode.leftHandle);
              },
              onPanUpdate: (d) {
                if (kDebugMode) debugPrint('LEFT HANDLE DRAG: ${d.delta.dx}');
                _onStartHandleDrag(d.delta.dx, innerWidth);
              },
              onPanEnd: (_) => _onDragEnd(),
              onPanCancel: () => _onDragEnd(),
              child: _TrimHandle(
                icon: Icons.chevron_left_rounded,
                alignment: Alignment.centerLeft,
                visualWidth: handleVisualW,
                trackHeight: trackH,
                overflow: vOverflow,
                isActive: _gestureMode == TrimGestureMode.leftHandle,
              ),
            ),
          ),

          // ── 8. RIGHT handle zone (gesture + visual) ────────────────────────
          // Hit area ends at the pill's right edge and extends left.
          // Pill is aligned to the RIGHT so it sits flush against borderLeft + borderWidth.
          Positioned(
            top: 0,
            left: rhLeft,
            width: handleW,
            height: trackH + vOverflow * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                if (_isLongVideo) return; // long video: visual only
                if (kDebugMode) debugPrint('RIGHT HANDLE START');
                setState(() => _gestureMode = TrimGestureMode.rightHandle);
              },
              onPanUpdate: (d) {
                if (kDebugMode) debugPrint('RIGHT HANDLE DRAG: ${d.delta.dx}');
                _onEndHandleDrag(d.delta.dx, innerWidth);
              },
              onPanEnd: (_) => _onDragEnd(),
              onPanCancel: () => _onDragEnd(),
              child: _TrimHandle(
                icon: Icons.chevron_right_rounded,
                alignment: Alignment.centerRight,
                visualWidth: handleVisualW,
                trackHeight: trackH,
                overflow: vOverflow,
                isActive: _gestureMode == TrimGestureMode.rightHandle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Gesture handlers
  // ---------------------------------------------------------------------------

  /// Adjusts the start of the trim window (short videos only).
  void _onStartHandleDrag(double dx, double innerWidth) {
    final delta = dx / innerWidth;
    final totalSec = _total.inSeconds.toDouble();
    // Start must not go so far left that the window exceeds 3 minutes.
    final minStart = totalSec > 0
        ? (_windowEndFrac - _kMaxTrimSeconds / totalSec).clamp(0.0, 1.0)
        : 0.0;
    final maxStart = _windowEndFrac - _kMinWindowFrac;
    final next = (_windowStartFrac + delta).clamp(minStart, maxStart);
    setState(() => _windowStartFrac = next);
    _controller?.seekTo(_windowStart);
  }

  /// Adjusts the end of the trim window (short videos only).
  void _onEndHandleDrag(double dx, double innerWidth) {
    final delta = dx / innerWidth;
    final totalSec = _total.inSeconds.toDouble();
    // End must not go so far right that the window exceeds 3 minutes.
    final maxEnd = totalSec > 0
        ? (_windowStartFrac + _kMaxTrimSeconds / totalSec).clamp(0.0, 1.0)
        : 1.0;
    final minEnd = _windowStartFrac + _kMinWindowFrac;
    final next = (_windowEndFrac + delta).clamp(minEnd, maxEnd);
    setState(() => _windowEndFrac = next);
    _controller?.seekTo(_windowEnd);
  }

  /// Shifts the entire trim window (keeps duration fixed).
  void _onWindowBodyDrag(double dx, double innerWidth) {
    final delta = dx / innerWidth;
    final windowSize = _windowEndFrac - _windowStartFrac;
    final newStart = (_windowStartFrac + delta).clamp(0.0, 1.0 - windowSize);
    setState(() {
      _windowStartFrac = newStart;
      _windowEndFrac = newStart + windowSize;
      // Keep playhead inside the window after it shifts.
      if (_playheadFrac < _windowStartFrac || _playheadFrac > _windowEndFrac) {
        _playheadFrac = _windowStartFrac;
      }
    });
    _controller?.seekTo(_windowStart);
  }

  /// Seeks the video to the playhead position.
  void _onPlayheadDrag(double dx, double innerWidth) {
    final delta = dx / innerWidth;
    final next = (_playheadFrac + delta).clamp(0.0, 1.0);
    setState(() => _playheadFrac = next);
    _controller?.seekTo(_lerp(_total, next));
  }

  /// Clears the gesture lock. Snaps the playhead back into the window if it
  /// was dragged outside.
  void _onDragEnd() {
    if (_gestureMode == TrimGestureMode.playhead) {
      final wasOut =
          _playheadFrac < _windowStartFrac || _playheadFrac > _windowEndFrac;
      setState(() {
        _gestureMode = TrimGestureMode.none;
        if (wasOut) _playheadFrac = _windowStartFrac;
      });
      if (wasOut) _controller?.seekTo(_windowStart);
    } else {
      setState(() => _gestureMode = TrimGestureMode.none);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _onApplyPressed() {
    if (_windowStartFrac == 0.0 && _windowEndFrac >= 1.0) {
      widget.onSkip();
      return;
    }

    final totalUs = _total.inMicroseconds;
    if (totalUs <= 0) {
      widget.onSkip();
      return;
    }

    // Re-derive microsecond boundaries from fractions (more precise than the
    // millisecond-rounded _windowStart/_windowEnd from _lerp).
    // Leave a 500 ms gap from the absolute end so the underlying extractor
    // never reads past the trim boundary.
    const endBufferUs = 500000; // 500 ms
    const minWindowUs = 1000000; // 1 s minimum clip

    final startUs = (_windowStartFrac * totalUs).toInt().clamp(
      0,
      totalUs - minWindowUs,
    );
    // Safe maximum: 500 ms before the video end (skip buffer for very short clips).
    final maxEndUs = totalUs > (endBufferUs + minWindowUs)
        ? totalUs - endBufferUs
        : totalUs;
    final endUs = (_windowEndFrac * totalUs).toInt().clamp(
      startUs + minWindowUs,
      maxEndUs,
    );

    if (endUs <= startUs) {
      widget.onSkip();
      return;
    }

    // Validate selected duration does not exceed 3 minutes.
    final selectedSec = (endUs - startUs) ~/ 1000000;
    if (selectedSec > _kMaxTrimSeconds) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video must be within 3 minutes')),
      );
      return;
    }

    widget.onApply(
      Duration(microseconds: startUs),
      Duration(microseconds: endUs),
    );
  }

  void _togglePlay() {
    if (_controller == null) return;
    _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
  }

  static Duration _lerp(Duration total, double t) =>
      Duration(milliseconds: (total.inMilliseconds * t).round());

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ---------------------------------------------------------------------------
// Trim handle widget
// ---------------------------------------------------------------------------

/// Rounded pill handle that protrudes above and below the track.
///
/// Rendered as the child of its zone's [GestureDetector] — purely visual,
/// no gesture handling of its own.
///
/// [alignment] pins the pill to the correct edge of the (wider) hit area:
/// [Alignment.centerLeft] for the left handle, [Alignment.centerRight] for
/// the right handle — so the pill is always flush with the bar edge.
///
/// [isActive] switches the pill from orange to white to signal active drag.
class _TrimHandle extends StatelessWidget {
  const _TrimHandle({
    required this.icon,
    required this.alignment,
    required this.visualWidth,
    required this.trackHeight,
    required this.overflow,
    required this.isActive,
  });

  final IconData icon;
  final Alignment alignment;
  final double visualWidth;
  final double trackHeight;
  final double overflow;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: visualWidth,
        height: trackHeight + overflow * 2,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : _kPrimary,
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: isActive ? _kPrimary : Colors.white, size: 14),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tick marks painter
// ---------------------------------------------------------------------------

/// Draws faint vertical tick marks inside the inner coordinate space.
///
/// Ticks are placed at [innerLeft + (s / totalSec) * innerWidth] so they
/// respect the same coordinate space as the handles and playhead.
///
/// Tick density adapts to video length:
/// - ≤ 60 s  → minor every 5 s
/// - ≤ 300 s → minor every 10 s
/// - > 300 s → minor every 30 s
///
/// Major ticks (taller, more opaque) appear every 6 minor intervals.
class _TicksPainter extends CustomPainter {
  const _TicksPainter({
    required this.total,
    required this.innerLeft,
    required this.innerWidth,
  });

  final Duration total;
  final double innerLeft;
  final double innerWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final totalSec = total.inSeconds;
    if (totalSec <= 0) return;

    final minorEvery = totalSec <= 60
        ? 5
        : totalSec <= 300
        ? 10
        : 30;
    final majorEvery = minorEvery * 6;

    final minorPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1.0;
    final majorPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1.5;

    for (int s = minorEvery; s < totalSec; s += minorEvery) {
      final x = innerLeft + (s / totalSec) * innerWidth;
      final isMajor = (s % majorEvery == 0);
      final paint = isMajor ? majorPaint : minorPaint;
      final tickH = isMajor ? size.height * 0.55 : size.height * 0.30;
      canvas.drawLine(Offset(x, 0), Offset(x, tickH), paint);
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) =>
      old.total != total ||
      old.innerLeft != innerLeft ||
      old.innerWidth != innerWidth;
}
