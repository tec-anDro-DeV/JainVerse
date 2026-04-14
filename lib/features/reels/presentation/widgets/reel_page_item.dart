import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import 'package:jainverse/features/reels/data/models/reel_item.dart';
import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_action_bar.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_info_overlay.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_progress_bar.dart';

/// Full-screen single page inside the reels [PageView].
///
/// Each item is self-contained: it reads only its own slice of [reelPlayerProvider]
/// so unrelated index changes don't cause unnecessary rebuilds.
class ReelPageItem extends ConsumerWidget {
  final ReelItem reel;
  final int index;

  const ReelPageItem({super.key, required this.reel, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(
      reelPlayerProvider.select((s) => s.controllers[index]),
    );
    final isBuffering = ref.watch(
      reelPlayerProvider.select((s) => s.bufferingIndices.contains(index)),
    );
    final isInitialized = ref.watch(
      reelPlayerProvider.select((s) => s.initializedIndices.contains(index)),
    );
    final isMuted = ref.watch(
      reelPlayerProvider.select((s) => s.isMuted),
    );

    return GestureDetector(
      onTap: () => ref.read(reelPlayerProvider.notifier).toggleMute(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _VideoLayer(
            reel: reel,
            controller: controller,
            isInitialized: isInitialized,
          ),

          if (isBuffering)
            Center(
              child: CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2.5.w,
              ),
            ),

          if (isMuted)
            const Align(
              alignment: Alignment.center,
              child: _MuteIndicator(),
            ),

          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomGradient(),
          ),

          Positioned(
            bottom: 16.h,
            left: 16.w,
            right: 72.w,
            child: ReelInfoOverlay(reel: reel),
          ),

          Positioned(
            bottom: 16.h,
            right: 12.w,
            child: ReelActionBar(reel: reel),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: controller != null && isInitialized
                ? ReelProgressBar(controller: controller)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _VideoLayer extends StatelessWidget {
  final ReelItem reel;
  final VideoPlayerController? controller;
  final bool isInitialized;

  const _VideoLayer({
    required this.reel,
    required this.controller,
    required this.isInitialized,
  });

  @override
  Widget build(BuildContext context) {
    if (isInitialized && controller != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: VideoPlayer(controller!),
          ),
        ),
      );
    }

    return reel.thumbnailUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: reel.thumbnailUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, __) => const ColoredBox(color: Colors.black),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Colors.black12),
          )
        : const ColoredBox(color: Colors.black);
  }
}

class _BottomGradient extends StatelessWidget {
  const _BottomGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.85),
          ],
        ),
      ),
    );
  }
}

class _MuteIndicator extends StatelessWidget {
  const _MuteIndicator();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.volume_off_rounded, color: Colors.white, size: 32.w),
      ),
    );
  }
}
