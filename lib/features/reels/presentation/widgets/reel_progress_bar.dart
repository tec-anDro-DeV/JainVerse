import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

/// Seekable video progress bar pinned at the very bottom of a reel page.
/// Drag horizontally to jump to any position; expands and shows a thumb while dragging.
class ReelProgressBar extends StatefulWidget {
  final VideoPlayerController controller;

  const ReelProgressBar({super.key, required this.controller});

  @override
  State<ReelProgressBar> createState() => _ReelProgressBarState();
}

class _ReelProgressBarState extends State<ReelProgressBar> {
  bool _isDragging = false;
  double _dragProgress = 0.0;
  bool _wasPlayingBeforeDrag = false;

  VideoPlayerController get _ctrl => widget.controller;

  double get _currentProgress {
    if (_isDragging) return _dragProgress;
    final duration = _ctrl.value.duration;
    final position = _ctrl.value.position;
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  void _onDragStart(DragStartDetails details, double totalWidth) {
    _wasPlayingBeforeDrag = _ctrl.value.isPlaying;
    _ctrl.pause();
    final progress = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
    setState(() {
      _isDragging = true;
      _dragProgress = progress;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double totalWidth) {
    final progress = (details.localPosition.dx / totalWidth).clamp(0.0, 1.0);
    setState(() => _dragProgress = progress);
    final dur = _ctrl.value.duration;
    if (dur.inMilliseconds > 0) {
      _ctrl.seekTo(
        Duration(milliseconds: (progress * dur.inMilliseconds).round()),
      );
    }
  }

  void _onDragEnd(DragEndDetails _) {
    setState(() => _isDragging = false);
    if (_wasPlayingBeforeDrag) _ctrl.play();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _onDragStart(d, totalWidth),
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, totalWidth),
          onHorizontalDragEnd: _onDragEnd,
          // Absorb long-press in the progress bar area so the parent's
          // hold-to-pause handler doesn't fire while the user is seeking.
          onLongPress: () {},
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final progress = _currentProgress;
              final barH = _isDragging ? 4.h : 2.h;
              final containerH = _isDragging ? 24.h : 14.h;
              final thumbR = 7.w;

              return SizedBox(
                width: totalWidth,
                height: containerH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background track
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(height: barH, color: Colors.white24),
                    ),
                    // Progress fill
                    Positioned(
                      bottom: 0,
                      left: 0,
                      width: totalWidth * progress,
                      child: Container(height: barH, color: Colors.white),
                    ),
                    // Thumb — only visible while dragging
                    if (_isDragging)
                      Positioned(
                        bottom: barH / 2 - thumbR,
                        left: (totalWidth * progress - thumbR)
                            .clamp(0, totalWidth - thumbR * 2),
                        child: Container(
                          width: thumbR * 2,
                          height: thumbR * 2,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
