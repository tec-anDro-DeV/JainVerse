import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'media_volume_slider.dart';

/// Shared playback controls widget for both music and video players
///
/// Features:
/// - Play/Pause button (large, centered)
/// - Skip previous/next buttons
/// - Optional shuffle and repeat buttons
/// - Expandable system volume slider
/// - Customizable icons and colors
/// - Haptic feedback
class MediaPlaybackControls extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onSkipPrevious;
  final VoidCallback? onSkipNext;
  final VoidCallback? onShuffle;
  final VoidCallback? onRepeat;
  final bool? isShuffleEnabled;
  final bool? isRepeatEnabled;
  final String? repeatMode; // 'none', 'all', 'one'
  final Color? iconColor;
  final Color? accentColor;
  final IconData? skipPreviousIcon;
  final IconData? skipNextIcon;
  final bool showShuffle;
  final bool showRepeat;

  /// Optional override for the repeat icon size. If null, falls back to [iconSize].
  final double? repeatIconSize;

  /// Optional override for the volume icon size. If null, falls back to [iconSize].
  final double? volumeIconSize;
  final double iconSize;
  final double playPauseIconSize;
  final bool volumeEnabled;

  const MediaPlaybackControls({
    super.key,
    required this.isPlaying,
    this.isLoading = false,
    this.onPlay,
    this.onPause,
    this.onSkipPrevious,
    this.onSkipNext,
    this.onShuffle,
    this.onRepeat,
    this.isShuffleEnabled,
    this.isRepeatEnabled,
    this.repeatMode,
    this.iconColor,
    this.accentColor,
    this.skipPreviousIcon,
    this.skipNextIcon,
    this.showShuffle = true,
    this.showRepeat = true,
    this.iconSize = 32.0,
    this.repeatIconSize,
    this.volumeIconSize,
    this.playPauseIconSize = 56.0,
    this.volumeEnabled = true,
  });

  @override
  State<MediaPlaybackControls> createState() => _MediaPlaybackControlsState();
}

class _MediaPlaybackControlsState extends State<MediaPlaybackControls> {
  static const _volumeAutoCloseDuration = Duration(seconds: 4);

  bool _isVolumeExpanded = false;
  Timer? _volumeCloseTimer;
  final FocusNode _volumeFocusNode = FocusNode(debugLabel: 'mediaVolumeFocus');

  @override
  void dispose() {
    _cancelAutoCloseTimer();
    _volumeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultIconColor = widget.iconColor ?? Colors.white;
    final defaultAccentColor =
        widget.accentColor ?? Theme.of(context).primaryColor;

    return TapRegion(
      onTapOutside: (_) => _collapseVolumePanel(),
      child: Focus(
        focusNode: _volumeFocusNode,
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            _collapseVolumePanel();
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: math.max(widget.playPauseIconSize.w, widget.iconSize.w),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: _buildRepeatButtonOrPlaceholder(
                          defaultAccentColor,
                          defaultIconColor,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildControlButton(
                            icon:
                                widget.skipPreviousIcon ??
                                Icons.skip_previous_rounded,
                            onPressed: widget.onSkipPrevious,
                            color: defaultAccentColor,
                            size: widget.iconSize,
                          ),
                          SizedBox(width: 24.w),
                          _buildPlayPauseButton(defaultAccentColor),
                          SizedBox(width: 24.w),
                          _buildControlButton(
                            icon:
                                widget.skipNextIcon ?? Icons.skip_next_rounded,
                            onPressed: widget.onSkipNext,
                            color: defaultAccentColor,
                            size: widget.iconSize,
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 15.w),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showShuffle)
                              _buildControlButton(
                                icon: Icons.shuffle,
                                onPressed: widget.onShuffle,
                                isActive: widget.isShuffleEnabled ?? false,
                                activeColor: defaultAccentColor,
                                inactiveColor: defaultIconColor,
                                size: widget.iconSize,
                              ),
                            if (widget.showShuffle) SizedBox(width: 12.w),
                            // Volume controls are Android-only: hide on other platforms
                            if (defaultTargetPlatform == TargetPlatform.android)
                              _buildVolumeToggle(defaultIconColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child:
                      (_isVolumeExpanded &&
                          defaultTargetPlatform == TargetPlatform.android)
                      ? Padding(
                          padding: EdgeInsets.only(top: 12.h),
                          child: MediaVolumeSlider(
                            iconColor: widget.iconColor ?? Colors.white,
                            sliderColor: defaultAccentColor,
                            backgroundColor: (widget.iconColor ?? Colors.white)
                                .withOpacity(0.2),
                            enabled: widget.volumeEnabled,
                            padding: EdgeInsets.zero,
                            onInteraction: _restartAutoCloseTimer,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatButtonOrPlaceholder(
    Color activeColor,
    Color inactiveColor,
  ) {
    if (!widget.showRepeat) {
      final repeatSize = widget.repeatIconSize ?? widget.iconSize;
      return SizedBox(width: repeatSize.w + 16.w);
    }

    return _buildRepeatButton(
      onPressed: widget.onRepeat,
      repeatMode: widget.repeatMode ?? 'none',
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      size: widget.repeatIconSize ?? widget.iconSize,
    );
  }

  Widget _buildVolumeToggle(Color iconColor) {
    return IconButton(
      key: const ValueKey('volumeToggle'),
      icon: Icon(
        Icons.volume_up_rounded,
        color: iconColor,
        size: (widget.volumeIconSize ?? widget.iconSize).w,
      ),
      padding: EdgeInsets.all(8.w),
      constraints: BoxConstraints(
        minWidth: (widget.volumeIconSize ?? widget.iconSize).w + 16.w,
        minHeight: (widget.volumeIconSize ?? widget.iconSize).w + 16.w,
      ),
      splashRadius: 24.w,
      tooltip: 'Adjust volume',
      onPressed: _toggleVolumePanel,
    );
  }

  void _toggleVolumePanel() {
    final shouldExpand = !_isVolumeExpanded;
    setState(() {
      _isVolumeExpanded = shouldExpand;
    });

    if (shouldExpand) {
      _volumeFocusNode.requestFocus();
      HapticFeedback.lightImpact();
      _restartAutoCloseTimer();
    } else {
      _volumeFocusNode.unfocus();
      _cancelAutoCloseTimer();
    }
  }

  void _collapseVolumePanel() {
    if (!_isVolumeExpanded) return;
    setState(() {
      _isVolumeExpanded = false;
    });
    _volumeFocusNode.unfocus();
    _cancelAutoCloseTimer();
  }

  void _restartAutoCloseTimer() {
    _cancelAutoCloseTimer();
    _volumeCloseTimer = Timer(_volumeAutoCloseDuration, () {
      if (mounted) {
        _collapseVolumePanel();
      }
    });
  }

  void _cancelAutoCloseTimer() {
    _volumeCloseTimer?.cancel();
    _volumeCloseTimer = null;
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
    bool isActive = false,
    Color? activeColor,
    Color? inactiveColor,
    double size = 32.0,
  }) {
    final effectiveColor = isActive
        ? (activeColor ?? color ?? Colors.white)
        : (color ?? inactiveColor ?? Colors.white70);

    return IconButton(
      icon: SizedBox(
        width: size.w,
        height: size.w,
        child: Icon(icon, size: size.w, color: effectiveColor),
      ),
      iconSize: size.w,
      padding: EdgeInsets.all(8.w),
      constraints: BoxConstraints(
        minWidth: size.w + 16.w,
        minHeight: size.w + 16.w,
      ),
      color: effectiveColor,
      disabledColor: effectiveColor,
      onPressed: onPressed != null
          ? () {
              HapticFeedback.lightImpact();
              onPressed();
            }
          : null,
      splashRadius: 24.w,
    );
  }

  Widget _buildRepeatButton({
    required VoidCallback? onPressed,
    required String repeatMode,
    required Color activeColor,
    required Color inactiveColor,
    double size = 32.0,
  }) {
    IconData icon;
    bool isActive = repeatMode != 'none';

    switch (repeatMode) {
      case 'all':
        icon = Icons.repeat;
        break;
      case 'one':
        icon = Icons.repeat_one;
        break;
      default:
        icon = Icons.repeat;
        isActive = false;
    }

    return _buildControlButton(
      icon: icon,
      onPressed: onPressed,
      isActive: isActive,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      size: size,
    );
  }

  Widget _buildPlayPauseButton(Color accentColor) {
    return Container(
      width: widget.playPauseIconSize.w,
      height: widget.playPauseIconSize.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!, width: 1.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8.w,
            offset: Offset(0, 2.w),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.playPauseIconSize.w / 2),
          onTap: () {
            HapticFeedback.mediumImpact();
            if (widget.isPlaying) {
              widget.onPause?.call();
            } else {
              widget.onPlay?.call();
            }
          },
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Icon(
                      widget.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey<bool>(widget.isPlaying),
                      size: (widget.playPauseIconSize * 0.64).w,
                      color: accentColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
