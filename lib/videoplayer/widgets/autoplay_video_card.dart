import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// YouTube-style video card that auto-plays (muted) when visible.
/// Transitions smoothly from thumbnail to video.
class AutoplayVideoCard extends StatefulWidget {
  final VideoItem item;
  final VoidCallback? onTap;
  final bool shouldPlay;
  final VideoPlayerController? sharedController;
  final VoidCallback? onVisibilityChanged;
  final double? width;

  const AutoplayVideoCard({
    Key? key,
    required this.item,
    this.onTap,
    this.shouldPlay = false,
    this.sharedController,
    this.onVisibilityChanged,
    this.width,
  }) : super(key: key);

  @override
  State<AutoplayVideoCard> createState() => _AutoplayVideoCardState();
}

class _AutoplayVideoCardState extends State<AutoplayVideoCard>
    with AutomaticKeepAliveClientMixin {
  bool _isVideoVisible = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(AutoplayVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle play/pause state changes
    if (widget.shouldPlay != oldWidget.shouldPlay) {
      _updatePlaybackState();
    }

    // If controller changed, update visibility state
    if (widget.sharedController != oldWidget.sharedController) {
      if (!widget.shouldPlay || widget.sharedController == null) {
        setState(() => _isVideoVisible = false);
      }
    }
  }

  void _updatePlaybackState() {
    if (!mounted) return;

    final controller = widget.sharedController;
    if (controller == null || !controller.value.isInitialized) {
      setState(() => _isVideoVisible = false);
      return;
    }

    if (widget.shouldPlay) {
      // Fade in video and start playback
      setState(() => _isVideoVisible = true);
      if (!controller.value.isPlaying) {
        controller.play();
      }
    } else {
      // Pause and fade back to thumbnail
      if (controller.value.isPlaying) {
        controller.pause();
      }
      setState(() => _isVideoVisible = false);
    }
  }

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
    super.build(context);

    return VisibilityDetector(
      key: Key('video_${widget.item.id}'),
      onVisibilityChanged: (info) {
        widget.onVisibilityChanged?.call();
      },
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video/Thumbnail container
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      // Background thumbnail (always visible)
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: widget.item.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Container(
                                color: Colors.grey.shade900,
                                child: Center(
                                  child: Icon(
                                    Icons.video_library_rounded,
                                    size: 48.w,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                color: Colors.grey.shade900,
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  size: 48.w,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                        ),
                      ),

                      // Video player layer (instant replace when playing)
                      if (_isVideoVisible &&
                          widget.sharedController != null &&
                          widget.sharedController!.value.isInitialized)
                        Positioned.fill(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: widget.sharedController!.value.size.width,
                              height:
                                  widget.sharedController!.value.size.height,
                              child: VideoPlayer(widget.sharedController!),
                            ),
                          ),
                        ),

                      // Duration badge (bottom right)
                      if (widget.item.duration.isNotEmpty)
                        Positioned(
                          bottom: 8.h,
                          right: 8.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4.w),
                            ),
                            child: Text(
                              widget.item.duration,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      // Muted indicator (when auto-playing)
                      if (_isVideoVisible)
                        Positioned(
                          top: 8.h,
                          right: 8.w,
                          child: Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.volume_off_rounded,
                              color: Colors.white,
                              size: 16.w,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Metadata section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel avatar
                    if (widget.item.channelImageUrl != null &&
                        widget.item.channelImageUrl!.isNotEmpty)
                      CircleAvatar(
                        radius: 18.w,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: CachedNetworkImageProvider(
                          widget.item.channelImageUrl!,
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 18.w,
                        backgroundColor: Colors.grey.shade800,
                        child: Icon(
                          Icons.person,
                          size: 18.w,
                          color: Colors.grey.shade600,
                        ),
                      ),

                    SizedBox(width: 12.w),

                    // Title and metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            [
                              if (widget.item.channelName != null &&
                                  widget.item.channelName!.isNotEmpty)
                                widget.item.channelName!,
                              _formatViews(widget.item.totalViews),
                              _getTimeAgo(widget.item.createdAt),
                            ].where((s) => s.isNotEmpty).join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 8.w),

                    // Three-dot menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20.w,
                        color: Colors.grey.shade700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.w),
                      ),
                      offset: Offset(0, 8.h),
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share_rounded, size: 20.w),
                                  SizedBox(width: 12.w),
                                  const Text('Share'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'save',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bookmark_outline_rounded,
                                    size: 20.w,
                                  ),
                                  SizedBox(width: 12.w),
                                  const Text('Save to playlist'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'not_interested',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.not_interested_rounded,
                                    size: 20.w,
                                  ),
                                  SizedBox(width: 12.w),
                                  const Text('Not interested'),
                                ],
                              ),
                            ),
                          ],
                      onSelected: (value) {
                        // Handle menu actions
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
