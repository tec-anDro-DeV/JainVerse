import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:volume_controller/volume_controller.dart';

/// Shared volume slider widget for both music and video players (Android only)
///
/// Features:
/// - System volume integration
/// - Mute/unmute button
/// - Smooth drag interaction
/// - Android-only (returns empty widget on iOS)
class MediaVolumeSlider extends StatefulWidget {
  final Color? iconColor;
  final Color? sliderColor;
  final Color? backgroundColor;
  final bool enabled;

  const MediaVolumeSlider({
    super.key,
    this.iconColor,
    this.sliderColor,
    this.backgroundColor,
    this.enabled = true,
  });

  @override
  State<MediaVolumeSlider> createState() => _MediaVolumeSliderState();
}

class _MediaVolumeSliderState extends State<MediaVolumeSlider> {
  double _currentVolume = 0.5;
  double _previousVolume = 0.5;
  VolumeController? _volumeController;

  @override
  void initState() {
    super.initState();

    // Only initialize on Android
    if (Platform.isAndroid) {
      _initializeVolumeController();
    }
  }

  Future<void> _initializeVolumeController() async {
    try {
      _volumeController = VolumeController();

      // Get initial volume
      final volume = await _volumeController!.getVolume();
      if (mounted) {
        setState(() {
          _currentVolume = volume;
          _previousVolume = volume;
        });
      }

      // Listen to volume changes
      _volumeController!.listener((volume) {
        if (mounted) {
          setState(() {
            _currentVolume = volume;
            if (volume > 0) {
              _previousVolume = volume;
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing volume controller: $e');
    }
  }

  @override
  void dispose() {
    _volumeController?.removeListener();
    super.dispose();
  }

  Future<void> _setVolume(double volume) async {
    try {
      _volumeController?.setVolume(volume);
      if (mounted) {
        setState(() {
          _currentVolume = volume;
          if (volume > 0) {
            _previousVolume = volume;
          }
        });
      }
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  Future<void> _toggleMute() async {
    if (_currentVolume > 0) {
      // Mute
      await _setVolume(0);
    } else {
      // Unmute to previous volume
      await _setVolume(_previousVolume > 0 ? _previousVolume : 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return empty widget on iOS
    if (!Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    final effectiveIconColor = widget.iconColor ?? Colors.white;
    final effectiveSliderColor =
        widget.sliderColor ?? Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          // Volume icon / mute button
          IconButton(
            icon: Icon(_getVolumeIcon()),
            iconSize: 24.w,
            color: effectiveIconColor,
            onPressed: widget.enabled ? _toggleMute : null,
            splashRadius: 20.w,
          ),

          SizedBox(width: 8.w),

          // Volume slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.w,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: 6.w,
                  elevation: 0,
                ),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 12.w),
                activeTrackColor: effectiveSliderColor,
                inactiveTrackColor: widget.backgroundColor ?? Colors.white24,
                thumbColor: effectiveSliderColor,
                overlayColor: effectiveSliderColor.withOpacity(0.2),
              ),
              child: Slider(
                value: _currentVolume,
                min: 0.0,
                max: 1.0,
                onChanged: widget.enabled
                    ? (value) {
                        _setVolume(value);
                      }
                    : null,
              ),
            ),
          ),

          SizedBox(width: 8.w),

          // Volume percentage
          SizedBox(
            width: 32.w,
            child: Text(
              '${(_currentVolume * 100).round()}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: effectiveIconColor.withOpacity(0.7),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getVolumeIcon() {
    if (_currentVolume == 0) {
      return Icons.volume_off_rounded;
    } else if (_currentVolume < 0.3) {
      return Icons.volume_mute_rounded;
    } else if (_currentVolume < 0.7) {
      return Icons.volume_down_rounded;
    } else {
      return Icons.volume_up_rounded;
    }
  }
}
