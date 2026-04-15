import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

const _kPrimary = Color(0xFFF47B36);

/// Inline trim UI shown in [ReelUploadScreen] when status is [UploadStatus.trimming].
///
/// Displays a looping video preview and a horizontal timeline with draggable
/// start/end handles. Calls [onApply] with the chosen [Duration] range or
/// [onSkip] to proceed without trimming.
class ReelTrimWidget extends StatefulWidget {
  const ReelTrimWidget({
    super.key,
    required this.file,
    required this.onApply,
    required this.onSkip,
  });

  final File file;
  final void Function(Duration start, Duration end) onApply;
  final VoidCallback onSkip;

  @override
  State<ReelTrimWidget> createState() => _ReelTrimWidgetState();
}

class _ReelTrimWidgetState extends State<ReelTrimWidget> {
  VideoPlayerController? _controller;
  Duration _total = Duration.zero;

  // Trim handles as fractions of the total duration (0.0 – 1.0).
  double _startFrac = 0.0;
  double _endFrac = 1.0;

  bool _isPlaying = false;
  bool _initialized = false;

  Duration get _startTime => _lerp(_total, _startFrac);
  Duration get _endTime => _lerp(_total, _endFrac);

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
      setState(() {
        _controller = c;
        _total = c.value.duration;
        _isPlaying = true;
        _initialized = true;
      });
    }
  }

  void _onVideoUpdate() {
    if (_controller == null) return;
    final pos = _controller!.value.position;
    // Loop within the selected trim range.
    if (_total > Duration.zero && pos >= _endTime) {
      _controller!.seekTo(_startTime);
    }
    if (mounted) setState(() => _isPlaying = _controller!.value.isPlaying);
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
                            decoration: BoxDecoration(
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
          padding: EdgeInsets.fromLTRB(30.w, 20.h, 30.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Time labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(_startTime),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: _kPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Drag handles to trim',
                    style: TextStyle(fontSize: 11.sp, color: Colors.black38),
                  ),
                  Text(
                    _fmt(_endTime),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: _kPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              // Timeline
              LayoutBuilder(
                builder: (_, constraints) =>
                    _buildTimeline(constraints.maxWidth),
              ),
              SizedBox(height: 20.h),

              // Buttons
              Row(
                children: [
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
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _initialized
                          ? () => widget.onApply(_startTime, _endTime)
                          : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Apply Trim'),
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
              SizedBox(height: 16.h + MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Timeline widget
  // ---------------------------------------------------------------------------

  Widget _buildTimeline(double maxWidth) {
    final trackHeight = 50.h;
    final handleWidth = 20.w;
    final handleRadius = 10.r;

    final startX = _startFrac * maxWidth;
    final endX = _endFrac * maxWidth;

    // Current playback position indicator.
    double posX = 0;
    if (_total > Duration.zero && _controller != null) {
      final pos = _controller!.value.position;
      posX =
          (pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0) *
          maxWidth;
    }

    return SizedBox(
      height: trackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Full track background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
          ),

          // Selected (orange) range
          Positioned(
            left: startX,
            width: (endX - startX).clamp(0.0, maxWidth),
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.25),
                border: Border.symmetric(
                  horizontal: BorderSide(color: _kPrimary, width: 2),
                ),
              ),
            ),
          ),

          // Playback position indicator
          if (_initialized)
            Positioned(
              left: posX - 1,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: Colors.white70),
            ),

          // Start handle
          Positioned(
            left: startX - handleWidth / 2,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) {
                final delta = d.delta.dx / maxWidth;
                final next = (_startFrac + delta).clamp(0.0, _endFrac - 0.05);
                setState(() => _startFrac = next);
                _controller?.seekTo(_lerp(_total, next));
              },
              child: _Handle(
                width: handleWidth,
                radius: handleRadius,
                icon: Icons.chevron_left_rounded,
              ),
            ),
          ),

          // End handle
          Positioned(
            left: endX - handleWidth / 2,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) {
                final delta = d.delta.dx / maxWidth;
                final next = (_endFrac + delta).clamp(_startFrac + 0.05, 1.0);
                setState(() => _endFrac = next);
                _controller?.seekTo(_lerp(_total, next));
              },
              child: _Handle(
                width: handleWidth,
                radius: handleRadius,
                icon: Icons.chevron_right_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _togglePlay() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  /// Linearly interpolates a [Duration] by [t] (0.0 – 1.0).
  static Duration _lerp(Duration total, double t) =>
      Duration(milliseconds: (total.inMilliseconds * t).round());

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ---------------------------------------------------------------------------
// Handle widget
// ---------------------------------------------------------------------------

class _Handle extends StatelessWidget {
  const _Handle({
    required this.width,
    required this.radius,
    required this.icon,
  });

  final double width;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 16.w),
      ),
    );
  }
}
