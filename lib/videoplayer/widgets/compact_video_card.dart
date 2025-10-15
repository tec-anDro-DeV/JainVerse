import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';

/// Enhanced compact video card with improved visual hierarchy and spacing.
/// Features a horizontal layout with larger thumbnail and better typography.
class CompactVideoCard extends StatelessWidget {
  final VideoItem item;
  final VoidCallback? onTap;
  final bool showPopupMenu;
  final Function(String)? onMenuAction;

  const CompactVideoCard({
    Key? key,
    required this.item,
    this.onTap,
    this.showPopupMenu = true,
    this.onMenuAction,
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced thumbnail with shadow
            Container(
              width: 160.w,
              height: 90.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.w),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Thumbnail
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.w),
                      child: CachedNetworkImage(
                        imageUrl: item.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder:
                            (c, u) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey.shade100,
                                    Colors.grey.shade200,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.video_library_rounded,
                                  size: 32.w,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                        errorWidget:
                            (c, u, e) => Container(
                              color: Colors.grey.shade300,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  size: 32.w,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),

                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.w),
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // (Removed center play overlay - tap is still handled by InkWell)

                  // Duration badge
                  if (item.duration.isNotEmpty)
                    Positioned(
                      right: 6.w,
                      bottom: 6.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                        child: Text(
                          item.duration,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(width: 14.w),

            // Content section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
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
                      height: 1.35,
                      letterSpacing: -0.2,
                    ),
                  ),

                  SizedBox(height: 6.h),

                  // Channel info row
                  Row(
                    children: [
                      // Channel avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 12.w,
                          backgroundColor: Colors.grey.shade100,
                          backgroundImage:
                              item.channelImageUrl != null &&
                                      item.channelImageUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                        item.channelImageUrl!,
                                      )
                                      as ImageProvider?
                                  : null,
                          child:
                              (item.channelImageUrl == null ||
                                      item.channelImageUrl!.isEmpty)
                                  ? Text(
                                    (item.channelName != null &&
                                            item.channelName!.isNotEmpty)
                                        ? item.channelName!
                                            .split(' ')
                                            .map(
                                              (s) => s.isNotEmpty ? s[0] : '',
                                            )
                                            .take(2)
                                            .join()
                                            .toUpperCase()
                                        : 'C',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade600,
                                    ),
                                  )
                                  : null,
                        ),
                      ),

                      SizedBox(width: 8.w),

                      // Channel name
                      Expanded(
                        child: Text(
                          (item.channelName != null &&
                                  item.channelName!.isNotEmpty)
                              ? item.channelName!
                              : 'Unknown channel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4.h),

                  // Time ago
                  Text(
                    _getTimeAgo(item.createdAt),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Three-dot menu
            if (showPopupMenu)
              Padding(
                padding: EdgeInsets.only(left: 4.w),
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 24.w, minHeight: 24.w),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20.w,
                    color: Colors.grey.shade600,
                  ),
                  elevation: 8,
                  offset: Offset(-120, 35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.w),
                  ),
                  onSelected: (value) {
                    if (onMenuAction != null) {
                      onMenuAction!(value);
                    } else {
                      final messenger = ScaffoldMessenger.of(context);
                      switch (value) {
                        case 'watch_later':
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Saved to Watch Later'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          break;
                        case 'add_playlist':
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Added to Playlist'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          break;
                        case 'share':
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Share dialog opened'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          break;
                        case 'not_interested':
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Marked not interested'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          break;
                      }
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'watch_later',
                          height: 44.h,
                          child: Row(
                            children: [
                              Icon(
                                Icons.watch_later_outlined,
                                size: 18.w,
                                color: Colors.grey.shade800,
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Save to Watch Later',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'add_playlist',
                          height: 44.h,
                          child: Row(
                            children: [
                              Icon(
                                Icons.playlist_add,
                                size: 18.w,
                                color: Colors.grey.shade800,
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Add to Playlist',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'share',
                          height: 44.h,
                          child: Row(
                            children: [
                              Icon(
                                Icons.share_rounded,
                                size: 18.w,
                                color: Colors.grey.shade800,
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Share',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'not_interested',
                          height: 44.h,
                          child: Row(
                            children: [
                              Icon(
                                Icons.not_interested_rounded,
                                size: 18.w,
                                color: Colors.grey.shade800,
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Not interested',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
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
