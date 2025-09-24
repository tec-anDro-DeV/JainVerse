import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:ui' as ui;
import 'dart:async';

/// Modern seek bar widget for audio playback control
class ModernSeekBar extends StatefulWidget {
  final AudioPlayerHandler audioHandler;
  final ColorScheme? colorScheme;

  const ModernSeekBar({
    super.key,
    required this.audioHandler,
    this.colorScheme,
  });

  @override
  State<ModernSeekBar> createState() => _ModernSeekBarState();
}

class _ModernSeekBarState extends State<ModernSeekBar> {
  double? _dragValue; // For smooth dragging
  bool _isDragging = false;
  // Notifier for slider value (0.0 - 1.0). Updates are throttled so only the
  // slider and related labels repaint instead of the whole widget tree.
  late final ValueNotifier<double> _positionNotifier;

  // Keep current duration to convert between position and slider value.
  Duration _currentDuration = Duration.zero;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<MediaItem?>? _mediaItemSub;
  // Keep last known position for synchronous access when needed
  Duration _lastPosition = Duration.zero;

  @override
  Widget build(BuildContext context) {
    // Only rebuild when the current media item (and thus duration) changes.
    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final duration = mediaSnapshot.data?.duration ?? Duration.zero;

        // Ensure duration is tracked for subscription updates
        _currentDuration = duration;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: -0.0, end: _isDragging ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, lift, child) {
                // Interpolated values for the lifted state
                final thumbRadius = ui.lerpDouble(8.w, 12.w, lift)!;
                final overlayRadius = ui.lerpDouble(2.w, 12.w, lift)!;
                final trackHeight = ui.lerpDouble(4.w, 6.w, lift)!;
                final liftOffset = ui.lerpDouble(0.0, -6.w, lift)!;
                final shadowSize = ui.lerpDouble(12.w, 20.w, lift)!;

                final sliderPadding = EdgeInsets.symmetric(horizontal: 4.w);
                final labelsPadding = EdgeInsets.fromLTRB(8.w, 0, 12.w, 0);

                final innerWidth = (width - sliderPadding.horizontal).clamp(
                  0.0,
                  width,
                );

                return Column(
                  children: [
                    Padding(
                      padding: sliderPadding,
                      child: SizedBox(
                        height: 40.w,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Position the animated shadow based on notifier value
                            ValueListenableBuilder<double>(
                              valueListenable: _positionNotifier,
                              builder: (context, sliderValue, _) {
                                final thumbCenterX =
                                    (sliderValue * innerWidth).clamp(
                                      0.0,
                                      innerWidth,
                                    ) +
                                    sliderPadding.left;
                                final shadowLeft =
                                    (thumbCenterX - shadowSize / 2).clamp(
                                      0.0,
                                      innerWidth - shadowSize,
                                    ) +
                                    sliderPadding.left;

                                return Positioned(
                                  left: shadowLeft,
                                  top: 18.w,
                                  child: Opacity(
                                    opacity: (0.9 * lift).clamp(0.0, 1.0),
                                    child: Container(
                                      width: shadowSize,
                                      height: shadowSize / 2,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.rectangle,
                                        borderRadius: BorderRadius.circular(
                                          shadowSize / 4,
                                        ),
                                        color: Colors.black.withOpacity(
                                          0.15 * lift,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.35 * lift,
                                            ),
                                            blurRadius: 8.w * lift,
                                            spreadRadius: 1.w * lift,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // the slider itself, slightly translated up when lifted
                            Transform.translate(
                              offset: Offset(0, liftOffset),
                              child: ValueListenableBuilder<double>(
                                valueListenable: _positionNotifier,
                                builder: (context, sliderValue, _) {
                                  return SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: trackHeight,
                                      thumbShape: RoundSliderThumbShape(
                                        enabledThumbRadius: thumbRadius,
                                      ),
                                      overlayShape: RoundSliderOverlayShape(
                                        overlayRadius: overlayRadius,
                                      ),
                                      activeTrackColor:
                                          widget.colorScheme?.primary ??
                                          Colors.white,
                                      inactiveTrackColor: Colors.white
                                          .withOpacity(0.3),
                                      thumbColor:
                                          widget.colorScheme?.primary ??
                                          Colors.white,
                                      overlayColor: (widget
                                                  .colorScheme
                                                  ?.primary ??
                                              Colors.white)
                                          .withOpacity(0.2),
                                    ),
                                    child: Slider(
                                      value: sliderValue,
                                      onChanged: (value) {
                                        setState(() {
                                          _isDragging = true;
                                          _dragValue = value;
                                          _positionNotifier.value = value;
                                        });
                                      },
                                      onChangeStart: (_) {
                                        setState(() {
                                          _isDragging = true;
                                        });
                                      },
                                      onChangeEnd: (value) {
                                        final newPosition = Duration(
                                          milliseconds:
                                              (value *
                                                      _currentDuration
                                                          .inMilliseconds)
                                                  .round(),
                                        );
                                        widget.audioHandler.seek(newPosition);
                                        setState(() {
                                          _isDragging = false;
                                          _dragValue = null;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 8.w),
                    // Time labels (use different padding than the slider)
                    Padding(
                      padding: labelsPadding,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ValueListenableBuilder<double>(
                            valueListenable: _positionNotifier,
                            builder: (context, sliderValue, _) {
                              final current =
                                  _isDragging
                                      ? Duration(
                                        milliseconds:
                                            ((_dragValue ?? 0.0) *
                                                    _currentDuration
                                                        .inMilliseconds)
                                                .round(),
                                      )
                                      : Duration(
                                        milliseconds:
                                            (sliderValue *
                                                    _currentDuration
                                                        .inMilliseconds)
                                                .round(),
                                      );

                              return Text(
                                _formatDuration(current),
                                style: TextStyle(
                                  fontSize: AppSizes.fontSmall,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              );
                            },
                          ),
                          Text(
                            _formatDuration(_currentDuration),
                            style: TextStyle(
                              fontSize: AppSizes.fontSmall,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _positionNotifier = ValueNotifier<double>(0.0);

    // Subscribe to position updates and update the notifier (throttled).
    _positionSub = AudioService.position
        .throttleTime(const Duration(milliseconds: 200))
        .distinct(
          (previous, next) =>
              (previous.inMilliseconds ~/ 100) == (next.inMilliseconds ~/ 100),
        )
        .listen((pos) {
          _lastPosition = pos;
          if (!_isDragging && _currentDuration.inMilliseconds > 0) {
            final ratio =
                (_currentDuration.inMilliseconds > 0)
                    ? pos.inMilliseconds / _currentDuration.inMilliseconds
                    : 0.0;
            final v = ratio.clamp(0.0, 1.0).toDouble();
            _positionNotifier.value = v;
          }
        });

    // Keep track of media item duration changes to compute slider values.
    _mediaItemSub = widget.audioHandler.mediaItem.listen((media) {
      _currentDuration = media?.duration ?? Duration.zero;
      // If duration becomes available, attempt to update notifier immediately
      if (!_isDragging && _currentDuration.inMilliseconds > 0) {
        final pos = _lastPosition;
        final ratio =
            (_currentDuration.inMilliseconds > 0)
                ? pos.inMilliseconds / _currentDuration.inMilliseconds
                : 0.0;
        final v = ratio.clamp(0.0, 1.0).toDouble();
        _positionNotifier.value = v;
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mediaItemSub?.cancel();
    _positionNotifier.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
