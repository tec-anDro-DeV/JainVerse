import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Animated like/dislike buttons with state management
/// States: 0 = neutral, 1 = liked, 2 = disliked
class AnimatedLikeDislikeButtons extends StatefulWidget {
  final int likeState; // 0=neutral, 1=liked, 2=disliked
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final int? totalLikes;
  final VoidCallback? onReport;
  final double? iconSize;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showReportButton;

  const AnimatedLikeDislikeButtons({
    super.key,
    required this.likeState,
    required this.onLike,
    required this.onDislike,
    this.totalLikes,
    this.onReport,
    this.iconSize,
    this.activeColor,
    this.inactiveColor,
    this.showReportButton = true,
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
    final inactiveColor = widget.inactiveColor ?? Colors.white;

    final isLiked = widget.likeState == 1;
    final isDisliked = widget.likeState == 2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Like button (icon + count) inside a transparent rounded container (same as dislike)
        _buildButton(
          icon: isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
          label: (widget.totalLikes ?? 0).toString(),
          isActive: isLiked,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          iconSize: iconSize,
          onPressed: widget.onLike,
          backgroundColor: Colors.transparent,
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),

        SizedBox(width: 8.w),

        // Dislike button in its own transparent rounded container
        _buildButton(
          icon: isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
          isActive: isDisliked,
          activeColor: Colors.red.shade600,
          inactiveColor: inactiveColor,
          iconSize: iconSize,
          onPressed: widget.onDislike,
          backgroundColor: Colors.transparent,
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),

        // Report button (icon + text) inside a transparent rounded container (same as dislike)
        if (widget.showReportButton && widget.onReport != null) ...[
          SizedBox(width: 8.w),
          _buildButton(
            icon: Icons.flag_outlined,
            label: 'Report',
            isActive: false,
            activeColor: Colors.orange.shade600,
            inactiveColor: inactiveColor,
            iconSize: iconSize,
            onPressed: widget.onReport!,
            backgroundColor: Colors.transparent,
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
        ],
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    String? label,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required double iconSize,
    required VoidCallback onPressed,
    Color? backgroundColor,
    BoxBorder? border,
  }) {
    final content = label == null
        ? Icon(
            icon,
            size: iconSize,
            color: isActive ? activeColor : inactiveColor,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: isActive ? activeColor : inactiveColor,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  // Smaller label to keep the button compact
                  fontSize: 14.sp,
                  color: isActive ? activeColor : inactiveColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    // Determine effective colors for content when inside a dark background
    final effectiveContentColor = isActive ? activeColor : inactiveColor;

    return ScaleTransition(
      scale: isActive ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20.w),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? 10.w : 14.w,
              vertical: 8.w,
            ),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(20.w),
              border: border,
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: effectiveContentColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              child: IconTheme(
                data: IconThemeData(
                  size: iconSize,
                  color: isActive ? activeColor : inactiveColor,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
