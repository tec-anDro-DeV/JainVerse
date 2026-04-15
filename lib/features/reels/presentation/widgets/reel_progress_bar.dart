import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

/// Thin video progress bar pinned at the very bottom of a reel page.
class ReelProgressBar extends StatelessWidget {
  final VideoPlayerController controller;

  const ReelProgressBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final duration = controller.value.duration;
        final position = controller.value.position;
        final progress = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return LinearProgressIndicator(
          value: progress,
          minHeight: 2.h,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        );
      },
    );
  }
}
