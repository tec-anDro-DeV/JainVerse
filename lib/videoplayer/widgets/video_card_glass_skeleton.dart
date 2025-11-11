import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A fully transparent glass-style skeleton for `VideoCard`.
///
/// Visual features:
/// - Frosted glass blur background
/// - Soft gradient transparency with subtle white/black tint
/// - Animated shimmer overlay
/// - Works in both dark and light themes
class VideoCardGlassSkeleton extends StatefulWidget {
  final double? width;
  final bool animate;
  final BorderRadius? borderRadius;
  final Color? tint;

  const VideoCardGlassSkeleton({
    super.key,
    this.width,
    this.animate = true,
    this.borderRadius,
    this.tint,
  });

  @override
  State<VideoCardGlassSkeleton> createState() => _VideoCardGlassSkeletonState();
}

class _VideoCardGlassSkeletonState extends State<VideoCardGlassSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _shimmerAnim = Tween(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Glass-styled shimmer line placeholder
  Widget _metaLine({double height = 14, double? width}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: height.h,
          width: width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(4.r),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor =
        widget.tint ??
        (isDark ? Colors.white : Colors.black); // for shimmer direction
    final br = widget.borderRadius ?? BorderRadius.circular(8.w);

    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// -------------------- THUMBNAIL AREA --------------------
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: br,
              child: Stack(
                children: [
                  // Frosted glass background
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : Colors.black.withOpacity(0.08),
                              isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Moving shimmer highlight
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final animValue = _shimmerAnim.value;
                        return FractionalTranslation(
                          translation: Offset(animValue, 0),
                          child: child,
                        );
                      },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.45,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                baseColor.withOpacity(0.02),
                                baseColor.withOpacity(0.08),
                                baseColor.withOpacity(0.02),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Duration badge with glass effect
                  Positioned(
                    right: 10.w,
                    bottom: 10.w,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.w),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.12)
                                : Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8.w),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            '0:00',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// -------------------- METADATA AREA --------------------
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glass avatar placeholder
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      height: 36.w,
                      width: 36.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.18),
                            Colors.white.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 12.w),

                // Title and metadata lines
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metaLine(height: 14, width: double.infinity),
                      SizedBox(height: 8.h),
                      _metaLine(
                        height: 14,
                        width: MediaQuery.of(context).size.width * 0.5,
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8.w),

                // Menu icon placeholder with glass border
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.w),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      height: 20.w,
                      width: 20.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.18),
                            Colors.white.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6.w),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
