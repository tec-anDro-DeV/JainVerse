import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shared seek bar widget for both music and video players
///
/// Features:
/// - Smooth drag interaction
/// - Current position and duration display
/// - Customizable colors
/// - Performance optimized with RepaintBoundary
class MediaSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color? progressColor;
  final Color? backgroundColor;
  final Color? handleColor;
  final Color? textColor;
  final bool enabled;

  const MediaSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.progressColor,
    this.backgroundColor,
    this.handleColor,
    this.textColor,
    this.enabled = true,
  });

  @override
  State<MediaSeekBar> createState() => _MediaSeekBarState();
}

class _MediaSeekBarState extends State<MediaSeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final position = widget.position;
    final duration = widget.duration;
    final value = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.w,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: 6.w,
                  elevation: 0,
                ),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 14.w),
                activeTrackColor:
                    widget.progressColor ?? Theme.of(context).primaryColor,
                inactiveTrackColor: widget.backgroundColor ?? Colors.white24,
                thumbColor:
                    widget.handleColor ??
                    widget.progressColor ??
                    Theme.of(context).primaryColor,
                overlayColor:
                    (widget.progressColor ?? Theme.of(context).primaryColor)
                        .withOpacity(0.2),
              ),
              child: Slider(
                value: _dragValue ?? value.clamp(0.0, 1.0),
                onChanged: widget.enabled
                    ? (value) {
                        setState(() {
                          _dragValue = value;
                        });
                      }
                    : null,
                onChangeEnd: widget.enabled
                    ? (value) {
                        final newPosition = Duration(
                          milliseconds: (value * duration.inMilliseconds)
                              .round(),
                        );
                        widget.onSeek(newPosition);
                        setState(() {
                          _dragValue = null;
                        });
                      }
                    : null,
              ),
            ),
            // Minor vertical space between slider and time labels. Reduced
            // from 4.h to 2.h to tighten spacing under the seek bar.
            SizedBox(height: 2.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 0.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(
                      _dragValue != null
                          ? Duration(
                              milliseconds:
                                  (_dragValue! * duration.inMilliseconds)
                                      .round(),
                            )
                          : position,
                    ),
                    style: TextStyle(
                      color: widget.textColor ?? Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: widget.textColor ?? Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
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
