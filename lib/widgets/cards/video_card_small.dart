import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Compact reusable video card used across Discover screen:
/// Layout: Thumbnail → Title → Channel Row → Views + Relative Time
class VideoCardSmall extends StatelessWidget {
  final String title;
  final String thumbnailUrl;
  final String duration;
  final String? channelName;
  final String? channelImageUrl;
  final int? totalViews;
  final String? publishedAt;
  final VoidCallback? onTap;
  final double width;

  const VideoCardSmall({
    super.key,
    required this.title,
    required this.thumbnailUrl,
    required this.duration,
    this.channelName,
    this.channelImageUrl,
    this.totalViews,
    this.publishedAt,
    this.onTap,
    this.width = 260,
  });

  // -----------------------------
  // FORMAT: Views → "125K views"
  // -----------------------------
  String _formatViews(int? views) {
    if (views == null || views <= 0) return "0 views";
    if (views < 1000) return "$views views";
    if (views < 1_000_000) {
      final v = (views / 1000).toStringAsFixed(1);
      return "${v.endsWith('.0') ? v.substring(0, v.length - 2) : v}K views";
    }
    final v = (views / 1_000_000).toStringAsFixed(1);
    return "${v.endsWith('.0') ? v.substring(0, v.length - 2) : v}M views";
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = width.w;
    final borderRadius = 18.w;

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

            /// CHANGED ORDER → Title comes before channel row (more standard)
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            SizedBox(height: 6.w),

            _buildChannelRow(),
            SizedBox(height: 4.w),

            /// Views · RelativeTime
            Text(
              [
                _formatViews(totalViews),
                _formatRelativeTime(publishedAt),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // THUMBNAIL + DURATION (Bottom-right)
  // ----------------------------------------------------
  Widget _buildThumbnail(double borderRadius) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            /// Image
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: Colors.grey.shade200),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.grey.shade600,
                    size: 32.w,
                  ),
                ),
              ),
            ),

            /// Bottom gradient for readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.35),
                    ],
                  ),
                ),
              ),
            ),

            /// Duration
            Positioned(
              right: 8.w,
              bottom: 8.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.w),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8.w),
                ),
                child: Text(
                  duration.isNotEmpty ? duration : "0:00",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // CHANNEL ROW → Avatar + Channel Name
  // ----------------------------------------------------
  Widget _buildChannelRow() {
    final hasAvatar = channelImageUrl != null && channelImageUrl!.isNotEmpty;

    return Row(
      children: [
        CircleAvatar(
          radius: 14.w,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: hasAvatar
              ? CachedNetworkImageProvider(channelImageUrl!)
              : null,
          child: !hasAvatar && (channelName?.isNotEmpty ?? false)
              ? Text(
                  _buildInitials(channelName!),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                )
              : Icon(
                  Icons.person_outline,
                  size: 16.w,
                  color: Colors.grey.shade700,
                ),
        ),
        SizedBox(width: 8.w),

        Expanded(
          child: Text(
            channelName ?? "Unknown channel",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  // Build initials from name
  String _buildInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return name[0].toUpperCase();

    return parts.take(2).map((e) => e[0].toUpperCase()).join();
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
