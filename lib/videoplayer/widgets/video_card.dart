import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';

/// Common video card widget that can be used in both vertical lists
/// and horizontal lists. Follows YouTube-style design with thumbnail,
/// channel avatar, title, and metadata.
class VideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback? onTap;
  final bool showPopupMenu;
  final double? width;
  final Function(String)? onMenuAction;
  final String? blockedReason;

  const VideoCard({
    Key? key,
    required this.item,
    this.onTap,
    this.showPopupMenu = true,
    this.width,
    this.onMenuAction,
    this.blockedReason,
  }) : super(key: key);

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 365) {
      final years = (diff.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  String _formatViews(int? views) {
    if (views == null || views == 0) return '0 views';

    if (views < 1000) {
      return '$views ${views == 1 ? 'view' : 'views'}';
    } else if (views < 1000000) {
      final k = (views / 1000).toStringAsFixed(1);
      return '${k.endsWith('.0') ? k.substring(0, k.length - 2) : k}K views';
    } else {
      final m = (views / 1000000).toStringAsFixed(1);
      return '${m.endsWith('.0') ? m.substring(0, m.length - 2) : m}M views';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Full-width thumbnail with improved UX (play overlay + gradient)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.grey.shade200,
                child: Stack(
                  children: [
                    // Thumbnail (rounded) for subtle polish
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6.w),
                        child: CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) =>
                              Container(color: Colors.grey.shade200),
                          errorWidget: (c, u, e) => Container(
                            color: Colors.grey.shade300,
                            child: Icon(
                              Icons.broken_image,
                              size: 48.w,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom gradient to improve contrast for overlay elements
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 64.h,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.36),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // (Removed center play overlay - tap is still handled by InkWell)

                    // Duration badge (bottom-right) with rounded pill and shadow
                    Positioned(
                      right: 10.w,
                      bottom: 10.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(8.w),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          item.duration.isNotEmpty ? item.duration : '0:00',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Metadata row (avatar + title/channel/stats + menu)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel avatar (left)
                  CircleAvatar(
                    radius: 18.w,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage:
                        item.channelImageUrl != null &&
                            item.channelImageUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(item.channelImageUrl!)
                              as ImageProvider?
                        : null,
                    child:
                        (item.channelImageUrl == null ||
                            item.channelImageUrl!.isEmpty)
                        ? Text(
                            // show initials fallback if name available
                            (item.channelName != null &&
                                    item.channelName!.isNotEmpty)
                                ? item.channelName!
                                      .split(' ')
                                      .map((s) => s.isNotEmpty ? s[0] : '')
                                      .take(2)
                                      .join()
                                : 'C',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          )
                        : null,
                  ),

                  SizedBox(width: 12.w),

                  // Title + channel name + stats (middle)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Video title
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.25,
                          ),
                        ),

                        SizedBox(height: 4.h),

                        // Channel name · views · time ago
                        Text(
                          [
                            (item.channelName != null &&
                                    item.channelName!.isNotEmpty)
                                ? item.channelName!
                                : 'Unknown channel',
                            _formatViews(item.totalViews),
                            _getTimeAgo(item.createdAt),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                        ),
                        // If the video is blocked, show a small reason line under metadata
                        if (blockedReason != null &&
                            blockedReason!.isNotEmpty) ...[
                          SizedBox(height: 6.h),
                          Text(
                            blockedReason!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(width: 8.w),

                  // Three-dot floating menu (right) using PopupMenuButton
                  if (showPopupMenu)
                    Tooltip(
                      message: 'More',
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 24.w,
                          minHeight: 24.w,
                        ),
                        icon: Icon(
                          Icons.more_vert,
                          size: 20.w,
                          color: Colors.grey.shade700,
                        ),
                        elevation: 6,
                        offset: Offset(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.w),
                        ),
                        onSelected: (value) {
                          if (onMenuAction != null) {
                            onMenuAction!(value);
                          } else {
                            // Default lightweight feedback
                            final messenger = ScaffoldMessenger.of(context);
                            switch (value) {
                              case 'watch_later':
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Saved to Watch Later'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                break;
                              case 'add_playlist':
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Added to Playlist'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                break;
                              case 'share':
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Share dialog opened'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                break;
                              case 'not_interested':
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Marked not interested'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                break;
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.share,
                                  size: 18.w,
                                  color: Colors.grey.shade800,
                                ),
                                SizedBox(width: 12.w),
                                Text('Share'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'not_interested',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.not_interested,
                                  size: 18.w,
                                  color: Colors.grey.shade800,
                                ),
                                SizedBox(width: 12.w),
                                Text('Not interested'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
