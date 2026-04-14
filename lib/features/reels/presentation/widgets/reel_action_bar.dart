import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import 'package:jainverse/features/reels/data/models/reel_item.dart';
import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';

/// Right-side column with like and share action buttons.
class ReelActionBar extends ConsumerWidget {
  final ReelItem reel;

  const ReelActionBar({super.key, required this.reel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likeEntry = ref
        .watch(reelLikeProvider)
        .entryFor(reel.id, fallbackLiked: reel.like, fallbackCount: reel.totalLikes);

    final isLiked = likeEntry.liked == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(isLiked),
              color: isLiked ? Colors.red : Colors.white,
              size: 30.w,
            ),
          ),
          label: _formatCount(likeEntry.count),
          onTap: () => ref.read(reelLikeProvider.notifier).toggleLike(reel.id),
        ),
        SizedBox(height: 20.h),
        _ActionButton(
          icon: Icon(
            Icons.share_rounded,
            color: Colors.white,
            size: 28.w,
          ),
          label: 'Share',
          onTap: () => Share.share(reel.videoUrl),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }
}
