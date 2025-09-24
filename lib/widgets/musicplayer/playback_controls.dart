/// Animated tap feedback for buttons
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:rxdart/rxdart.dart' as rxdart;
import 'package:jainverse/ThemeMain/appColors.dart';

class _AnimatedTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _AnimatedTapButton({required this.child, this.onTap, super.key});

  @override
  State<_AnimatedTapButton> createState() => _AnimatedTapButtonState();
}

/// Direction for the nudge animation used by previous/next buttons
enum _NudgeDirection { none, left, right }

/// Button that animates scale on press and also nudges its child in a
/// given horizontal direction. Intended for skip previous/next micro-interaction.
class _DirectionalTapButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final _NudgeDirection direction;
  final double nudgeDistance; // in logical pixels

  const _DirectionalTapButton({
    required this.child,
    this.onTap,
    this.direction = _NudgeDirection.none,
    this.nudgeDistance = 12.0,
    super.key,
  });

  @override
  State<_DirectionalTapButton> createState() => _DirectionalTapButtonState();
}

class _DirectionalTapButtonState extends State<_DirectionalTapButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _offsetController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
      duration: const Duration(milliseconds: 90),
    );
    _offsetController = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnim = _scaleController;
    // offset goes 0 -> 1 for the nudge, we will multiply by distance
    _offsetAnim = CurvedAnimation(
      parent: _offsetController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    // Press feedback: shrink + quick nudge
    if (widget.onTap == null) return;
    _scaleController.animateTo(0.9, duration: const Duration(milliseconds: 70));
    _offsetController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 100),
    );
  }

  void _onTapUp(TapUpDetails details) async {
    if (widget.onTap == null) return;
    // release: scale back, snap offset back with a spring-like curve
    _scaleController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 100),
    );
    _offsetController.animateBack(
      0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
    );
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (widget.onTap == null) return;
    _scaleController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 100),
    );
    _offsetController.animateBack(
      0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dxSign =
        widget.direction == _NudgeDirection.right
            ? 1.0
            : (widget.direction == _NudgeDirection.left ? -1.0 : 0.0);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnim, _offsetAnim]),
        builder: (context, child) {
          final dx = dxSign * widget.nudgeDistance * _offsetAnim.value;
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: _scaleAnim.value, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _AnimatedTapButtonState extends State<_AnimatedTapButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.85;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Animated tap feedback for buttons

/// Combined state for playback controls to reduce stream rebuilds
class PlaybackControlsState {
  final List<MediaItem> queue;
  final PlaybackState playbackState;
  final int? currentIndex;

  const PlaybackControlsState(
    this.queue,
    this.playbackState,
    this.currentIndex,
  );

  bool get canSkipToPrevious =>
      // Keep previous enabled even when we're at the first track so that
      // tapping previous will restart the current song (seek to start).
      // Only disable when there is no queue at all and repeat mode is none.
      queue.isNotEmpty ||
      playbackState.repeatMode != AudioServiceRepeatMode.none;
  bool get canSkipToNext =>
      playbackState.repeatMode != AudioServiceRepeatMode.none ||
      (currentIndex != null && currentIndex! < queue.length - 1);
  bool get isPlaying => playbackState.playing;
  AudioProcessingState? get processingState => playbackState.processingState;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackControlsState &&
          runtimeType == other.runtimeType &&
          queue.length == other.queue.length &&
          playbackState.playing == other.playbackState.playing &&
          currentIndex == other.currentIndex &&
          playbackState.processingState == other.playbackState.processingState;

  @override
  int get hashCode =>
      queue.length.hashCode ^
      playbackState.playing.hashCode ^
      (currentIndex?.hashCode ?? 0) ^
      playbackState.processingState.hashCode;
}

/// Animated tap feedback for buttons

/// Modern playback controls widget for the music player
class ModernPlaybackControls extends StatelessWidget {
  final AudioPlayerHandler audioHandler;
  final ColorScheme? colorScheme;
  final VoidCallback? onQueue;

  const ModernPlaybackControls({
    super.key,
    required this.audioHandler,
    this.colorScheme,
    this.onQueue,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackControlsState>(
      stream: rxdart.Rx.combineLatest3<
        List<MediaItem>,
        PlaybackState,
        MediaItem?,
        PlaybackControlsState
      >(
        audioHandler.queue,
        audioHandler.playbackState,
        audioHandler.mediaItem,
        (queue, playbackState, currentItem) {
          // Find current index in queue
          int? currentIndex;
          if (currentItem != null) {
            currentIndex = queue.indexWhere(
              (item) => item.id == currentItem.id,
            );
            if (currentIndex == -1) currentIndex = null;
          }
          return PlaybackControlsState(queue, playbackState, currentIndex);
        },
      ),
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) {
          return _buildDefaultControls();
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Queue - moved from shuffle position
            _buildQueueButton(),
            SizedBox(width: 20.w),

            // Previous
            _buildControlButton(
              icon: Icons.skip_previous,
              onTap: () {
                // If we have a valid previous track, skip to it. Otherwise,
                // restart the current track by seeking to position zero.
                final currentIndex = state.currentIndex;
                if (currentIndex != null && currentIndex > 0) {
                  audioHandler.skipToPrevious();
                } else {
                  // Seek to start of current media
                  audioHandler.seek(Duration.zero);
                }
              },
              isEnabled: state.canSkipToPrevious,
              direction: _NudgeDirection.left,
            ),
            SizedBox(width: 20.w),

            // Play/Pause - Central larger button
            _buildPlayPauseButton(state.isPlaying, state.processingState),
            SizedBox(width: 20.w),

            // Forward (Next)
            _buildControlButton(
              icon: Icons.skip_next,
              onTap: () => audioHandler.skipToNext(),
              isEnabled: state.canSkipToNext,
              direction: _NudgeDirection.right,
            ),
            SizedBox(width: 20.w),

            // Repeat - staying in same position
            _buildRepeatButton(),
          ],
        );
      },
    );
  }

  /// Fallback widget when stream data is not available
  Widget _buildDefaultControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.queue_music,
          onTap: () => onQueue?.call(),
        ),
        SizedBox(width: 20.w),
        _buildControlButton(
          icon: Icons.skip_previous,
          onTap: () {
            // Fallback: seek to start of current track if no state is available
            audioHandler.seek(Duration.zero);
          },
          isEnabled: true,
          direction: _NudgeDirection.left,
        ),
        SizedBox(width: 20.w),
        _buildPlayPauseButton(false, null),
        SizedBox(width: 20.w),
        _buildControlButton(
          icon: Icons.skip_next,
          onTap: () {},
          isEnabled: false,
          direction: _NudgeDirection.right,
        ),
        SizedBox(width: 20.w),
        _buildRepeatButton(),
      ],
    );
  }

  Widget _buildPlayPauseButton(
    bool isPlaying,
    AudioProcessingState? processingState,
  ) {
    return _AnimatedTapButton(
      onTap: () {
        final musicManager = MusicManager();
        if (isPlaying) {
          musicManager.pause();
        } else {
          musicManager.play();
        }
      },
      child: Container(
        width: 72.w,
        height: 72.w,
        decoration: BoxDecoration(
          color: colorScheme?.primary ?? Colors.white,
          borderRadius: BorderRadius.circular(36.w),
        ),
        child: Icon(
          processingState == AudioProcessingState.loading ||
                  processingState == AudioProcessingState.buffering
              ? Icons.hourglass_empty
              : isPlaying
              ? Icons.pause
              : Icons.play_arrow,
          color: colorScheme?.onPrimary ?? appColors().black,
          size: 48.w,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isEnabled = true,
    bool isActive = false,
    _NudgeDirection direction = _NudgeDirection.none,
  }) {
    final child = SizedBox(
      width: 56.w,
      height: 56.w,
      child: Icon(
        icon,
        color:
            isEnabled
                ? (isActive
                    ? (colorScheme?.primary ?? const Color(0xFFE84625))
                    : Colors.white)
                : Colors.white.withOpacity(0.3),
        size: 42.w,
      ),
    );

    return _DirectionalTapButton(
      onTap: isEnabled ? onTap : null,
      direction: direction,
      nudgeDistance: 12.0,
      child: child,
    );
  }

  Widget _buildQueueButton() {
    return _AnimatedTapButton(
      onTap: () {
        HapticFeedback.lightImpact();
        onQueue?.call();
      },
      child: Container(
        padding: EdgeInsets.all(8.w),
        child: Icon(
          Icons.queue_music,
          color: Colors.white.withOpacity(0.8),
          size: 42.w,
        ),
      ),
    );
  }

  /// Animated tap feedback for buttons

  Widget _buildRepeatButton() {
    return StreamBuilder<AudioServiceRepeatMode>(
      stream:
          audioHandler.playbackState
              .map((state) => state.repeatMode)
              .distinct(),
      builder: (context, snapshot) {
        final repeatMode = snapshot.data ?? AudioServiceRepeatMode.none;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact(); // Add haptic feedback
            _handleRepeat();
          },
          child: Container(
            padding: EdgeInsets.all(8.w),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                _getRepeatIcon(repeatMode),
                key: ValueKey<AudioServiceRepeatMode>(repeatMode),
                color: _getRepeatIconColor(repeatMode),
                size: 42.w,
              ),
            ),
          ),
        );
      },
    );
  }

  // Handler methods
  void _handleRepeat() {
    // Use MusicManager to toggle repeat mode
    final musicManager = MusicManager();
    final currentRepeatMode = musicManager.repeatMode;

    AudioServiceRepeatMode newMode;

    switch (currentRepeatMode) {
      case AudioServiceRepeatMode.none:
        newMode = AudioServiceRepeatMode.all;
        break;
      case AudioServiceRepeatMode.all:
        newMode = AudioServiceRepeatMode.one;
        break;
      case AudioServiceRepeatMode.one:
        newMode = AudioServiceRepeatMode.none;
        break;
      case AudioServiceRepeatMode.group:
        newMode = AudioServiceRepeatMode.none;
        break;
    }

    musicManager.setRepeatMode(newMode);
  }

  // Helper methods for repeat icon display
  IconData _getRepeatIcon(AudioServiceRepeatMode repeatMode) {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        return Icons.repeat;
      case AudioServiceRepeatMode.all:
        return Icons.repeat;
      case AudioServiceRepeatMode.one:
        return Icons.repeat_one;
      case AudioServiceRepeatMode.group:
        return Icons.repeat;
    }
  }

  Color _getRepeatIconColor(AudioServiceRepeatMode repeatMode) {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        return Colors.white.withOpacity(0.4); // Inactive icon color
      case AudioServiceRepeatMode.all:
        return colorScheme?.primary ??
            Colors.white; // Use extracted primary color for active state
      case AudioServiceRepeatMode.one:
        return colorScheme?.primary ??
            Colors.white; // Use extracted primary color for active state
      case AudioServiceRepeatMode.group:
        return colorScheme?.primary ??
            Colors.white; // Use extracted primary color for active state
    }
  }
}
