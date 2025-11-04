import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shared playback controls widget for both music and video players
///
/// Features:
/// - Play/Pause button (large, centered)
/// - Skip previous/next buttons
/// - Optional shuffle and repeat buttons
/// - Customizable icons and colors
/// - Haptic feedback
class MediaPlaybackControls extends StatelessWidget {
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
  final bool showShuffle;
  final bool showRepeat;
  final double iconSize;
  final double playPauseIconSize;

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
    this.showShuffle = true,
    this.showRepeat = true,
    this.iconSize = 36.0,
    this.playPauseIconSize = 56.0,
  });

  @override
  Widget build(BuildContext context) {
    final defaultIconColor = iconColor ?? Colors.white;
    final defaultAccentColor = accentColor ?? Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          // Shuffle button (left)
          if (showShuffle)
            _buildControlButton(
              icon: Icons.shuffle,
              onPressed: onShuffle,
              isActive: isShuffleEnabled ?? false,
              activeColor: defaultAccentColor,
              inactiveColor: defaultIconColor,
              size: iconSize,
            )
          else
            SizedBox(width: iconSize.w),

          // Push the main controls to center
          Spacer(),

          // Main controls: previous, play/pause, next (kept together and centered)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Skip previous button
              _buildControlButton(
                icon: Icons.skip_previous_rounded,
                onPressed: onSkipPrevious,
                color: defaultAccentColor,
                size: iconSize,
              ),

              SizedBox(width: 24.w),

              // Play/Pause button
              _buildPlayPauseButton(
                isPlaying: isPlaying,
                isLoading: isLoading,
                onPlay: onPlay,
                onPause: onPause,
                color: defaultIconColor,
                accentColor: defaultAccentColor,
              ),

              SizedBox(width: 24.w),

              // Skip next button
              _buildControlButton(
                icon: Icons.skip_next_rounded,
                onPressed: onSkipNext,
                color: defaultAccentColor,
                size: iconSize,
              ),
            ],
          ),

          // Push repeat to the far right
          Spacer(),

          // Repeat button (right)
          if (showRepeat)
            _buildRepeatButton(
              onPressed: onRepeat,
              repeatMode: repeatMode ?? 'none',
              activeColor: defaultAccentColor,
              inactiveColor: defaultIconColor,
              size: iconSize,
            )
          else
            SizedBox(width: iconSize.w),
        ],
      ),
    );
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

    // Ensure the visual icon size and the button's tap target scale with `size`
    return IconButton(
      icon: SizedBox(
        width: size.w,
        height: size.w,
        child: Icon(icon, size: size.w, color: effectiveColor),
      ),
      iconSize: size.w,
      padding: EdgeInsets.all(8.w),
      constraints: BoxConstraints(
        minWidth: (size.w + 16.w),
        minHeight: (size.w + 16.w),
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

  Widget _buildPlayPauseButton({
    required bool isPlaying,
    required bool isLoading,
    required VoidCallback? onPlay,
    required VoidCallback? onPause,
    required Color color,
    required Color accentColor,
  }) {
    return Container(
      width: playPauseIconSize.w,
      height: playPauseIconSize.w,
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
          borderRadius: BorderRadius.circular(playPauseIconSize.w / 2),
          onTap: () {
            HapticFeedback.mediumImpact();
            if (isPlaying) {
              onPause?.call();
            } else {
              onPlay?.call();
            }
          },
          child: Center(
            child: isLoading
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
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey<bool>(isPlaying),
                      size: (playPauseIconSize * 0.64).w,
                      color: accentColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
