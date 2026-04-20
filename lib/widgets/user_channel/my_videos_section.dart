import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';
import 'package:jainverse/videoplayer/widgets/video_card_skeleton.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';

class MyVideosSection extends StatelessWidget {
  final List<VideoItem> videos;
  final List<ReelItem> shorts;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final Function(VideoItem) onTap;
  final Function(String, VideoItem) onMenuAction;
  final Function(ReelItem)? onShortTap;
  final Function(String, ReelItem)? onShortMenuAction;

  const MyVideosSection({
    super.key,
    required this.videos,
    this.shorts = const [],
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onTap,
    required this.onMenuAction,
    this.onShortTap,
    this.onShortMenuAction,
  });

  Widget _buildLoading() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: 16.w),
          child: const VideoCardSkeleton(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12.w),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48.w, color: Colors.red.shade400),
          SizedBox(height: 16.w),
          Text(
            'Failed to load videos',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8.w),
          Text(
            error ?? 'Unknown error',
            style: TextStyle(fontSize: 13.sp, color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.w),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.w),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64.w,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16.w),
          Text(
            'No Video or Song Found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8.w),
          Text(
            'Check back later or add new content to your channel',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _buildLoading();
    if (error != null) return _buildError();
    if (videos.isEmpty && shorts.isEmpty) return _buildEmpty();

    final children = <Widget>[];

    if (shorts.isNotEmpty) {
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.w),
              child: Text(
                'Shorts',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12.w,
              crossAxisSpacing: 12.w,
              childAspectRatio: 9 / 16,
              children: shorts.map((reel) {
                return GestureDetector(
                  onTap: onShortTap != null ? () => onShortTap!(reel) : null,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.w),
                        child: Image.network(
                          reel.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey.shade200),
                        ),
                      ),
                      Positioned(
                        left: 8.w,
                        top: 8.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.w,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6.w),
                          ),
                          child: Text(
                            reel.duration,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4.w,
                        top: 4.w,
                        child: reel.isOwn == 1 && onShortMenuAction != null
                            ? PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                onSelected: (v) => onShortMenuAction!(v, reel),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                                icon: Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                  size: 18.w,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16.w),
          ],
        ),
      );
    }

    if (videos.isNotEmpty) {
      children.addAll(
        videos.map((video) {
          return Padding(
            padding: EdgeInsets.only(bottom: 16.w),
            child: VideoCard(
              item: video,
              onTap: () => onTap(video),
              showPopupMenu: true,
              onMenuAction: (action) => onMenuAction(action, video),
            ),
          );
        }).toList(),
      );
    }

    return Column(children: children);
  }
}
