import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/widgets/user_channel/my_videos_section.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';
import 'package:jainverse/videoplayer/widgets/video_card_skeleton.dart';

class UserChannelVideosSection extends StatelessWidget {
  final List<VideoItem> videos;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRetry;
  final void Function(VideoItem) onTap;
  final void Function(String, VideoItem) onMenuAction;

  const UserChannelVideosSection({
    Key? key,
    required this.videos,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onTap,
    required this.onMenuAction,
  }) : super(key: key);

  List<VideoItem> get blockedVideos =>
      videos.where((v) => (v.block ?? 0) == 1).toList();

  List<VideoItem> get unblockedVideos =>
      videos.where((v) => (v.block ?? 0) != 1).toList();

  Widget _buildLoadingVideos() {
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

  Widget _buildErrorState(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // My Videos (unblocked)
        MyVideosSection(
          videos: unblockedVideos,
          isLoading: isLoading,
          error: error,
          onRetry: onRetry,
          onTap: onTap,
          onMenuAction: onMenuAction,
        ),

        // Blocked videos (if any)
        if (blockedVideos.isNotEmpty) SizedBox(height: 24.w),
        if (blockedVideos.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.block, size: 24.w, color: Colors.redAccent),
                  SizedBox(width: 12.w),
                  Text(
                    'Blocked Videos',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: appColors().colorTextHead,
                    ),
                  ),
                ],
              ),
              if (blockedVideos.isNotEmpty)
                Text(
                  '${blockedVideos.length} ${blockedVideos.length == 1 ? 'video' : 'videos'}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),

          SizedBox(height: 16.w),

          // Render blocked videos list
          if (isLoading)
            _buildLoadingVideos()
          else if (error != null)
            _buildErrorState(context)
          else
            Column(
              children: blockedVideos.map((video) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 16.w),
                  child: VideoCard(
                    item: video,
                    onTap: () => onTap(video),
                    showPopupMenu: true,
                    blockedReason: video.reason ?? 'Blocked by moderation',
                    onMenuAction: (action) => onMenuAction(action, video),
                  ),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }
}
