import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../managers/video_player_state_provider.dart';

class VideoPipOverlay extends ConsumerWidget {
  const VideoPipOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    final controller = videoState.controller;
    final showOverlay =
        videoState.isInPictureInPicture &&
        controller != null &&
        _isControllerInitialized(controller);

    return Stack(
      children: [
        child,
        IgnorePointer(
          ignoring: true,
          child: AnimatedOpacity(
            opacity: showOverlay ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            child: showOverlay
                ? Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: AspectRatio(
                      aspectRatio: _safeAspectRatio(controller),
                      child: _buildVideoTexture(controller),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoTexture(VideoPlayerController controller) {
    try {
      return VideoPlayer(controller);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  bool _isControllerInitialized(VideoPlayerController controller) {
    try {
      return controller.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  double _safeAspectRatio(VideoPlayerController controller) {
    try {
      final ratio = controller.value.aspectRatio;
      if (ratio.isFinite && ratio > 0) {
        return ratio;
      }
    } catch (_) {}
    return 16 / 9;
  }
}
