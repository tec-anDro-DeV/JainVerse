import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Compact reusable video card with overlay-style thumbnail, play badge, and metadata.
class ModernVideoCard extends StatelessWidget {
  final String title;
  final String thumbnailUrl;
  final String duration;
  final String? channelName;
  final int? totalViews;
  final String? publishedAt;
  final VoidCallback? onTap;
  final double width;

  const ModernVideoCard({
    super.key,
    required this.title,
    required this.thumbnailUrl,
    required this.duration,
    this.channelName,
    this.totalViews,
    this.publishedAt,
    this.onTap,
    this.width = 340,
  });

  // (long views formatter removed; using short format only)

  // Short numeric views string without the word 'views', e.g. "125K" or "1.2M"
  String _formatViewsShort(int? views) {
    if (views == null || views <= 0) return "0";
    if (views < 1000) return "$views";
    if (views < 1_000_000) {
      final v = (views / 1000).toStringAsFixed(1);
      return v.endsWith('.0') ? v.substring(0, v.length - 2) + 'K' : v + 'K';
    }
    final v = (views / 1_000_000).toStringAsFixed(1);
    return v.endsWith('.0') ? v.substring(0, v.length - 2) + 'M' : v + 'M';
  }

  // (metadata assembly helper removed — not used)

  @override
  Widget build(BuildContext context) {
    final cardWidth = width.w;
    final borderRadius = 25.w;

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(borderRadius),
            SizedBox(height: 8.w),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // THUMBNAIL + OVERLAY
  // ----------------------------------------------------
  Widget _buildThumbnail(double borderRadius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey.shade200),
                errorWidget: (_, __, ___) => Image.asset(
                  'assets/images/video_placeholder.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Full-image subtle gradient (keeps highlights intact)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.40),
                    ],
                  ),
                ),
              ),
            ),

            // Additional stronger bottom gradient to separate image and overlay text
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 74.w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.65),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40.w),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      // glass effect: semi-transparent white + subtle border
                      color: Colors.black.withOpacity(0.03),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8.w,
                          offset: Offset(0, 2.w),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(6.w),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 36.w,
                    ),
                  ),
                ),
              ),
            ),
            // Title (above metadata)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 38.w,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                ),
              ),
            ),

            // Metadata row split: channel (30% width) | views · time | duration badge
            Positioned(
              left: 14.w,
              right: 14.w,
              bottom: 12.w,
              child: Builder(
                builder: (_) {
                  final channelBoxWidth = (width * 0.35).w;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Channel name - flexible up to ~35% of the card width
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: channelBoxWidth),
                        child: Text(
                          (channelName?.isNotEmpty ?? false)
                              ? channelName!
                              : 'Unknown channel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      SizedBox(width: 6.w),

                      // Views (icon + number) · Relative time - occupies remaining space before duration
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.remove_red_eye_outlined,
                              size: 14.w,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            SizedBox(width: 6.w),
                            Flexible(
                              child: Text(
                                '${_formatViewsShort(totalViews)}  ·  ${_formatRelativeTime(publishedAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 9.w),

                      // Duration badge (glass effect)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32.w),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.w,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(32.w),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              duration.isNotEmpty ? duration : '0:00',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // RELATIVE TIME
  // ----------------------------------------------------
  String _formatRelativeTime(String? publishedAt) {
    if (publishedAt == null || publishedAt.isEmpty) return "Just now";

    final parsed = DateTime.tryParse(publishedAt);
    if (parsed == null) return "Just now";

    final diff = DateTime.now().difference(parsed.toLocal());

    // Seconds
    final seconds = diff.inSeconds;
    if (seconds < 5) return "Just now";
    if (seconds < 60) {
      return seconds == 1 ? "1 second ago" : "$seconds seconds ago";
    }

    // Minutes
    final minutes = diff.inMinutes;
    if (minutes < 60) {
      return minutes == 1 ? "1 minute ago" : "$minutes minutes ago";
    }

    // Hours (use 'hr' / 'hrs')
    final hours = diff.inHours;
    if (hours < 24) return hours == 1 ? "1 hr ago" : "$hours hrs ago";

    // Days
    final days = diff.inDays;
    if (days < 7) return days == 1 ? "1 day ago" : "$days days ago";

    // Weeks (less than ~30 days)
    if (days < 30) {
      final weeks = (days / 7).floor();
      return weeks == 1 ? "1 week ago" : "$weeks weeks ago";
    }

    // Months (approximate, less than a year)
    if (days < 365) {
      final months = (days / 30).floor();
      return months <= 1 ? "1 month ago" : "$months months ago";
    }

    // Years (approximate)
    final years = (days / 365).floor();
    return years <= 1 ? "1 year ago" : "$years years ago";
  }
}
