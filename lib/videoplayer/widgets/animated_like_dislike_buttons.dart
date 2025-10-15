import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Animated like/dislike buttons with state management
/// States: 0 = neutral, 1 = liked, 2 = disliked
class AnimatedLikeDislikeButtons extends StatefulWidget {
  final int likeState; // 0=neutral, 1=liked, 2=disliked
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final double? iconSize;
  final Color? activeColor;
  final Color? inactiveColor;

  const AnimatedLikeDislikeButtons({
    super.key,
    required this.likeState,
    required this.onLike,
    required this.onDislike,
    this.iconSize,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<AnimatedLikeDislikeButtons> createState() =>
      _AnimatedLikeDislikeButtonsState();
}

class _AnimatedLikeDislikeButtonsState extends State<AnimatedLikeDislikeButtons>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedLikeDislikeButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger animation when state changes
    if (oldWidget.likeState != widget.likeState) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.iconSize ?? 24.w;
    final activeColor = widget.activeColor ?? Colors.green.shade600;
    final inactiveColor = widget.inactiveColor ?? Colors.grey.shade600;

    final isLiked = widget.likeState == 1;
    final isDisliked = widget.likeState == 2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like button
        _buildButton(
          icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
          isActive: isLiked,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          iconSize: iconSize,
          onPressed: widget.onLike,
        ),
        SizedBox(width: 8.w),
        // Dislike button
        _buildButton(
          icon: isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
          isActive: isDisliked,
          activeColor: Colors.red.shade600,
          inactiveColor: inactiveColor,
          iconSize: iconSize,
          onPressed: widget.onDislike,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required double iconSize,
    required VoidCallback onPressed,
  }) {
    return ScaleTransition(
      scale: isActive ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20.w),
          child: Padding(
            padding: EdgeInsets.all(8.w),
            child: Icon(
              icon,
              size: iconSize,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}
