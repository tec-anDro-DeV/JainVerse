import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:volume_controller/volume_controller.dart';
import 'dart:developer' as developer;

/// Cross-platform volume slider widget for the music player
///
/// Features:
/// - Android: Full volume control (read/write)
/// - iOS: Read-only volume display (due to Apple limitations)
/// - Real-time volume change detection
/// - Responsive UI updates
/// - Haptic feedback on interaction
/// - Visual feedback for platform limitations
class VolumeSliderWidget extends StatefulWidget {
  final ColorScheme? colorScheme;
  final double? width;
  final double? height;
  final bool showVolumeIcon;
  final EdgeInsetsGeometry? padding;
  final bool showPercentage;

  const VolumeSliderWidget({
    super.key,
    this.colorScheme,
    this.width,
    this.height,
    this.showVolumeIcon = true,
    this.padding,
    this.showPercentage = true,
  });

  @override
  State<VolumeSliderWidget> createState() => _VolumeSliderWidgetState();
}

class _VolumeSliderWidgetState extends State<VolumeSliderWidget> {
  double _currentVolume = 0.5; // Initial volume (0.0 to 1.0)
  bool _isInitialized = false;
  final bool _isAndroid = Platform.isAndroid;
  final bool _isIOS = Platform.isIOS;
  bool _isListenerActive = false;

  @override
  void initState() {
    super.initState();
    _initializeVolumeController();
  }

  /// Initialize the volume controller and set up listeners
  Future<void> _initializeVolumeController() async {
    try {
      // Initialize volume controller
      VolumeController().showSystemUI = false;

      // Get initial volume
      final initialVolume = await VolumeController().getVolume();

      if (mounted) {
        setState(() {
          _currentVolume = initialVolume;
          _isInitialized = true;
        });
      }

      // Set up volume change listener for real-time updates
      VolumeController().listener((volume) {
        if (mounted) {
          setState(() {
            _currentVolume = volume;
          });
        }

        developer.log(
          'Volume changed: ${(volume * 100).toStringAsFixed(0)}%',
          name: 'VolumeSlider',
        );
      });

      _isListenerActive = true;

      developer.log(
        'Volume controller initialized successfully. Platform: ${_isAndroid
            ? 'Android'
            : _isIOS
            ? 'iOS'
            : 'Other'}',
        name: 'VolumeSlider',
      );
    } catch (e) {
      developer.log(
        'Failed to initialize volume controller: $e',
        name: 'VolumeSlider',
        error: e,
      );

      // Fallback to default volume if initialization fails
      if (mounted) {
        setState(() {
          _currentVolume = 0.5;
          _isInitialized = true;
        });
      }
    }
  }

  /// Handle volume change from slider (Android only)
  Future<void> _onVolumeChanged(double newVolume) async {
    if (!_isAndroid) {
      // On iOS, volume changes are handled by the system
      return;
    }

    try {
      // Add light haptic feedback for better UX
      // HapticFeedback.lightImpact();

      VolumeController().setVolume(newVolume);

      setState(() {
        _currentVolume = newVolume;
      });

      developer.log(
        'Volume set to: ${(newVolume * 100).toStringAsFixed(0)}%',
        name: 'VolumeSlider',
      );
    } catch (e) {
      developer.log('Failed to set volume: $e', name: 'VolumeSlider', error: e);
    }
  }

  /// Handle volume change start (Android only)
  void _onVolumeChangeStart(double value) {
    if (_isAndroid) {
      // Light haptic feedback when starting to drag
      HapticFeedback.selectionClick();
    }
  }

  /// Handle volume change end (Android only)
  void _onVolumeChangeEnd(double value) {
    if (_isAndroid) {
      // Medium haptic feedback when finishing drag
      // HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    // Remove volume listener to prevent memory leaks
    try {
      if (_isListenerActive) {
        VolumeController().removeListener();
        _isListenerActive = false;
        developer.log('Volume listener removed', name: 'VolumeSlider');
      }
    } catch (e) {
      developer.log('Error removing volume listener: $e', name: 'VolumeSlider');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't render anything until initialized
    if (!_isInitialized) {
      return SizedBox(
        width: widget.width ?? 200.w,
        height: widget.height ?? 40.w,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      width: widget.width ?? 200.w,
      height: widget.height ?? 40.w,
      padding: widget.padding ?? EdgeInsets.symmetric(horizontal: 8.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Volume icon (optional)
          if (widget.showVolumeIcon) ...[
            Stack(
              children: [
                Icon(
                  _getVolumeIcon(),
                  color:
                      widget.colorScheme?.onSurface ??
                      Colors.white.withValues(alpha: 0.8),
                  size: 20.w,
                ),
                // Add a small iOS indicator if on iOS
                if (_isIOS)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock, color: Colors.white, size: 6.w),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 8.w),
          ],

          // Volume slider
          Expanded(
            child: Tooltip(
              message: _getTooltipText(),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.w,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.w),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 12.w),
                  activeTrackColor: widget.colorScheme?.primary ?? Colors.white,
                  inactiveTrackColor: (widget.colorScheme?.onSurface ??
                          Colors.white)
                      .withValues(alpha: 0.3),
                  thumbColor: widget.colorScheme?.primary ?? Colors.white,
                  overlayColor: (widget.colorScheme?.primary ?? Colors.white)
                      .withValues(alpha: 0.2),
                  // Disable visual feedback on iOS since it's read-only
                  disabledActiveTrackColor:
                      _isIOS
                          ? (widget.colorScheme?.primary ?? Colors.white)
                              .withValues(alpha: 0.6)
                          : null,
                  disabledInactiveTrackColor:
                      _isIOS
                          ? (widget.colorScheme?.onSurface ?? Colors.white)
                              .withValues(alpha: 0.2)
                          : null,
                  disabledThumbColor:
                      _isIOS
                          ? (widget.colorScheme?.primary ?? Colors.white)
                              .withValues(alpha: 0.6)
                          : null,
                ),
                child: Slider(
                  value: _currentVolume.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  // On iOS, disable interaction due to Apple limitations
                  onChanged: _isAndroid ? _onVolumeChanged : null,
                  // Add haptic feedback for interaction (Android only)
                  onChangeStart: _isAndroid ? _onVolumeChangeStart : null,
                  onChangeEnd: _isAndroid ? _onVolumeChangeEnd : null,
                ),
              ),
            ),
          ),

          // Volume percentage text (optional)
          if (widget.showPercentage) ...[
            SizedBox(width: 8.w),
            SizedBox(
              width: 32.w,
              child: Text(
                '${(_currentVolume * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color:
                      widget.colorScheme?.onSurface ??
                      Colors.white.withValues(alpha: 0.8),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Get appropriate volume icon based on current volume level
  IconData _getVolumeIcon() {
    if (_currentVolume == 0.0) {
      return Icons.volume_off;
    } else if (_currentVolume < 0.3) {
      return Icons.volume_down;
    } else if (_currentVolume < 0.7) {
      return Icons.volume_up;
    } else {
      return Icons.volume_up;
    }
  }

  /// Get tooltip text based on platform
  String _getTooltipText() {
    if (_isIOS) {
      return 'Volume control is managed by iOS system. Use hardware buttons to adjust volume.';
    } else if (_isAndroid) {
      return 'Drag to adjust volume';
    } else {
      return 'Volume Control';
    }
  }
}

/// Compact version of the volume slider for mini players
class CompactVolumeSlider extends StatelessWidget {
  final ColorScheme? colorScheme;
  final double? width;

  const CompactVolumeSlider({super.key, this.colorScheme, this.width});

  @override
  Widget build(BuildContext context) {
    return VolumeSliderWidget(
      colorScheme: colorScheme,
      width: width ?? 120.w,
      height: 24.w,
      showVolumeIcon: false,
      padding: EdgeInsets.symmetric(horizontal: 4.w),
    );
  }
}

/// Platform-aware volume slider that automatically adapts to device capabilities
class PlatformVolumeSlider extends StatelessWidget {
  final ColorScheme? colorScheme;
  final double? width;
  final double? height;

  const PlatformVolumeSlider({
    super.key,
    this.colorScheme,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return VolumeSliderWidget(
      colorScheme: colorScheme,
      width: width ?? double.infinity,
      height: height ?? 40.w,
      showVolumeIcon: true,
      showPercentage:
          !Platform.isIOS, // Hide percentage on iOS for cleaner look
      padding: EdgeInsets.symmetric(horizontal: 8.w),
    );
  }
}

/// Volume slider specifically designed for the music player screen
class MusicPlayerVolumeSlider extends StatelessWidget {
  final ColorScheme? colorScheme;

  const MusicPlayerVolumeSlider({super.key, this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.w),
      child: VolumeSliderWidget(
        colorScheme: colorScheme,
        width: double.infinity,
        height: 44.w,
        showVolumeIcon: true,
        showPercentage: true,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
      ),
    );
  }
}
