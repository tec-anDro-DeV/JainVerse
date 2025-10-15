import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Skeleton placeholder for `CompactVideoCard` used while data is loading.
///
/// Displays a horizontal layout: thumbnail on the left, content on the right.
class CompactVideoCardSkeleton extends StatefulWidget {
  final bool animate;
  final double? thumbnailWidth;
  final double? thumbnailHeight;

  const CompactVideoCardSkeleton({
    Key? key,
    this.animate = true,
    this.thumbnailWidth,
    this.thumbnailHeight,
  }) : super(key: key);

  @override
  State<CompactVideoCardSkeleton> createState() =>
      _CompactVideoCardSkeletonState();
}

class _CompactVideoCardSkeletonState extends State<CompactVideoCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box({double? width, double? height, BorderRadius? radius}) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: radius ?? BorderRadius.circular(6.w),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tw = widget.thumbnailWidth ?? 160.w;
    final th = widget.thumbnailHeight ?? 90.h;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder
          Container(
            width: tw,
            height: th,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.w),
              color: Colors.grey.shade200,
            ),
            child: Center(
              child: Icon(
                Icons.video_library_rounded,
                size: 28.w,
                color: Colors.grey.shade400,
              ),
            ),
          ),

          SizedBox(width: 14.w),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(height: 14.h, width: double.infinity),
                SizedBox(height: 8.h),
                _box(
                  height: 14.h,
                  width: MediaQuery.of(context).size.width * 0.35,
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    // small avatar
                    _box(
                      width: 24.w,
                      height: 24.w,
                      radius: BorderRadius.circular(24.w),
                    ),
                    SizedBox(width: 8.w),
                    _box(width: 120.w, height: 12.h),
                  ],
                ),
                SizedBox(height: 8.h),
                _box(width: 80.w, height: 12.h),
              ],
            ),
          ),

          SizedBox(width: 8.w),

          // More menu placeholder
          _box(width: 20.w, height: 20.w, radius: BorderRadius.circular(8.w)),
        ],
      ),
    );
  }
}
