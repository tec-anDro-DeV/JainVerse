import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shared track info widget for both music and video players
///
/// Displays:
/// - Title (track name or video title)
/// - Subtitle (artist name or channel name)
/// - Optional icon
class MediaTrackInfo extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Color? subtitleColor;
  final TextAlign textAlign;
  final int maxLines;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  const MediaTrackInfo({
    super.key,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.subtitleColor,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              title,
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor ?? Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 6.h),

            // Subtitle with optional icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16.w,
                    color: iconColor ?? subtitleColor ?? Colors.white70,
                  ),
                  SizedBox(width: 6.w),
                ],
                Flexible(
                  child: Text(
                    subtitle,
                    textAlign: textAlign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtitleColor ?? Colors.white70,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
