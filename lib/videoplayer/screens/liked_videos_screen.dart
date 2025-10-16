import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/services/liked_videos_service.dart';
import 'package:jainverse/videoplayer/screens/common_video_player_screen.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';
import 'package:jainverse/videoplayer/widgets/video_card_skeleton.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/main.dart';

class LikedVideosScreen extends StatefulWidget {
  const LikedVideosScreen({super.key});

  @override
  State<LikedVideosScreen> createState() => _LikedVideosScreenState();
}

class _LikedVideosScreenState extends State<LikedVideosScreen> {
  final LikedVideosService _service = LikedVideosService();
  List<VideoItem> _videos = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadLikedVideos();
  }

  Future<void> _loadLikedVideos() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final videos = await _service.getLikedVideos();
      if (mounted) {
        setState(() {
          _videos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My Liked Videos',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.black87),
              onPressed: _loadLikedVideos,
            ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadLikedVideos, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    // Get audio handler from main app
    final audioHandler = const MyApp().called();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        // Check if mini player is visible (music is playing)
        final hasMiniPlayer = snapshot.hasData;

        // Calculate bottom padding based on mini player and nav bar
        final bottomPadding =
            hasMiniPlayer
                ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 25.w
                : AppSizes.basePadding + 25.w;

        if (_isLoading) {
          return ListView.builder(
            padding: EdgeInsets.only(
              top: 16.w,
              left: 16.w,
              right: 16.w,
              bottom: bottomPadding,
            ),
            itemCount: 6,
            itemBuilder:
                (context, index) => Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: VideoCardSkeleton(),
                ),
          );
        }

        if (_hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64.w,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Failed to load liked videos',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _errorMessage,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: _loadLikedVideos,
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (_videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.thumb_up_outlined,
                  size: 64.w,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16.h),
                Text(
                  'No liked videos yet',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Videos you like will appear here',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            top: 16.w,
            left: 16.w,
            right: 16.w,
            bottom: bottomPadding, // Dynamic padding for mini player
          ),
          itemCount: _videos.length,
          itemBuilder: (context, index) {
            final video = _videos[index];
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: VideoCard(
                item: video.syncWithGlobalState().syncLikeWithGlobalState(),
                showPopupMenu: true,
                onTap: () {
                  // Sync video item with latest global state before navigation
                  final syncedItem =
                      video.syncWithGlobalState().syncLikeWithGlobalState();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => CommonVideoPlayerScreen(
                            videoUrl: syncedItem.videoUrl,
                            videoTitle: syncedItem.title,
                            videoItem: syncedItem,
                          ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
