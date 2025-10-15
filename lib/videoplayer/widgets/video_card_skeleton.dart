import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Lightweight skeleton placeholder for `VideoCard` used while data is loading.
///
/// Keeps the same visual structure (thumbnail, avatar, title lines, metadata)
/// but uses neutral grey boxes and a subtle fade/pulse animation.
class VideoCardSkeleton extends StatefulWidget {
  final double? width;
  final bool animate;
  final BorderRadius? borderRadius;

  const VideoCardSkeleton({
    Key? key,
    this.width,
    this.animate = true,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<VideoCardSkeleton> createState() => _VideoCardSkeletonState();
}

class _VideoCardSkeletonState extends State<VideoCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box({double? height, double? width, BorderRadius? radius}) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: radius ?? BorderRadius.circular(4.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder (16:9)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(6.w),
              child: Container(color: Colors.grey.shade200),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                _box(
                  height: 36.w,
                  width: 36.w,
                  radius: BorderRadius.circular(36.w),
                ),
                SizedBox(width: 12.w),
                // Title and metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // two lines for title
                      _box(height: 14.h, width: double.infinity),
                      SizedBox(height: 8.h),
                      _box(
                        height: 14.h,
                        width: MediaQuery.of(context).size.width * 0.5,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                // menu dot
                _box(
                  height: 20.w,
                  width: 20.w,
                  radius: BorderRadius.circular(6.w),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
