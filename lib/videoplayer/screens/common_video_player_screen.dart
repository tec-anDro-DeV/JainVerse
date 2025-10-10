import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// appColors import removed — header moved as floating button over video.
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:jainverse/videoplayer/widgets/video_player_widget.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jainverse/videoplayer/models/channel_video_list_view_model.dart';
import 'package:jainverse/videoplayer/services/channel_video_service.dart';
import 'package:jainverse/videoplayer/screens/channel_videos_screen.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';
import 'package:jainverse/videoplayer/widgets/compact_video_card.dart';
import 'package:jainverse/videoplayer/models/video_list_view_model.dart';
import 'package:jainverse/videoplayer/screens/video_list_screen.dart';

class CommonVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  final VideoItem? videoItem;
  // overlay timing configuration (ms)
  final int overlayVisibleMs;
  final int fadeDurationMs;
  final int scaleDurationMs;

  const CommonVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
    this.videoItem,
    this.overlayVisibleMs = 900,
    this.fadeDurationMs = 300,
    this.scaleDurationMs = 160,
  });

  @override
  State<CommonVideoPlayerScreen> createState() =>
      _CommonVideoPlayerScreenState();
}

class _CommonVideoPlayerScreenState extends State<CommonVideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  bool _descExpanded = false;
  late final ChannelVideoListViewModel _channelVideosViewModel;
  bool _loadingChannelVideos = false;
  late final VideoListViewModel _videoListViewModel;
  bool _loadingVideoList = false;

  // The top header UI has been removed. A floating back button will be
  // drawn over the video player using a Stack. Favorite toggle remains
  // available elsewhere in the UI.

  // Favorite functionality removed from header; implement later if needed.

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    MusicPlayerStateManager().setNavigationVisibility(false);
    // Controller will be provided by the child CommonVideoPlayer via
    // the onControllerInitialized callback.
    _channelVideosViewModel = ChannelVideoListViewModel(
      service: ChannelVideoService(),
      perPage: 10,
    );
    _videoListViewModel = VideoListViewModel(perPage: 10);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeLoadChannelVideos();
      _loadVideoList();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    MusicPlayerStateManager().setNavigationVisibility(true);
    _channelVideosViewModel.dispose();
    _videoListViewModel.dispose();
    super.dispose();
  }

  // Double-tap skip handling is now contained in the CommonVideoPlayer widget.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed 16:9 video container with floating back button.
            // The VideoPlayerWidget is wrapped in an AspectRatio inside a
            // Stack so we can overlay UI on top of the video.
            Container(
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: VideoPlayerWidget(
                      videoUrl: widget.videoUrl,
                      overlayVisibleMs: widget.overlayVisibleMs,
                      fadeDurationMs: widget.fadeDurationMs,
                      scaleDurationMs: widget.scaleDurationMs,
                      onControllerInitialized: (controller) {
                        // store controller reference so the screen can show duration
                        setState(() {
                          _videoPlayerController = controller;
                        });
                      },
                    ),
                  ),

                  // Floating back button positioned over the video.
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(8.w),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.black38,
                          shape: CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            child: SizedBox(
                              width: 40.w,
                              height: 40.w,
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 20.w,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Video info section - Sticky header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4.w,
                    offset: Offset(0, 2.w),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.videoTitle.isNotEmpty
                        ? widget.videoTitle
                        : 'Video Title',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 18.sp,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      // channel avatar + name when available
                      if (widget.videoItem?.channelImageUrl != null &&
                          widget.videoItem!.channelImageUrl!.isNotEmpty)
                        CircleAvatar(
                          radius: 12.w,
                          backgroundImage: CachedNetworkImageProvider(
                            widget.videoItem!.channelImageUrl!,
                          ),
                        ),
                      if (widget.videoItem?.channelName != null)
                        Padding(
                          padding: EdgeInsets.only(left: 8.w, right: 8.w),
                          child: Text(
                            widget.videoItem!.channelName!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 18.w,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        '0 views',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Icon(
                        Icons.access_time,
                        size: 18.w,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _videoPlayerController != null &&
                                _videoPlayerController!.value.isInitialized
                            ? _formatDuration(
                              _videoPlayerController!.value.duration,
                            )
                            : '--:--',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Scrollable content section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description container
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Builder(
                            builder: (context) {
                              final desc = widget.videoItem?.description ?? '';
                              final hasDesc = desc.trim().isNotEmpty;
                              if (!hasDesc) {
                                return Text(
                                  'Video description will appear here. You can add detailed information about the video content.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14.sp,
                                    height: 1.5,
                                  ),
                                );
                              }

                              // Show collapsed/expanded description with preserve newlines
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    desc,
                                    maxLines: _descExpanded ? null : 3,
                                    overflow:
                                        _descExpanded
                                            ? TextOverflow.visible
                                            : TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14.sp,
                                      height: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _descExpanded = !_descExpanded;
                                      });
                                    },
                                    child: Text(
                                      _descExpanded ? 'Show less' : 'Show more',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Recommended Videos Section
                    Padding(
                      padding: EdgeInsets.only(top: 12.h, left: 0, right: 0),
                      child: Container(
                        width: double.infinity,
                        color: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Recommended videos (compact cards only)
                            _buildRecommendedVideosList(),
                          ],
                        ),
                      ),
                    ),

                    // More from this channel
                    if (widget.videoItem?.channelId != null)
                      Padding(
                        padding: EdgeInsets.only(top: 12.h, left: 0, right: 0),
                        child: Container(
                          width: double.infinity,
                          color: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 12.h,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'More from this channel',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      // navigate to full channel page
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => ChannelVideosScreen(
                                                channelId:
                                                    widget
                                                        .videoItem!
                                                        .channelId!,
                                                channelName:
                                                    widget
                                                        .videoItem!
                                                        .channelName,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'See all',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              // Show vertical list of channel videos
                              _buildChannelVideosList(),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _maybeLoadChannelVideos() {
    final channelId = widget.videoItem?.channelId;
    if (channelId == null) return;
    if (_channelVideosViewModel.items.isNotEmpty) return;

    setState(() => _loadingChannelVideos = true);
    _channelVideosViewModel.refresh(channelId: channelId).whenComplete(() {
      if (mounted) setState(() => _loadingChannelVideos = false);
    });
  }

  void _loadVideoList() {
    if (_videoListViewModel.items.isNotEmpty) return;

    setState(() => _loadingVideoList = true);
    _videoListViewModel.refresh().whenComplete(() {
      if (mounted) setState(() => _loadingVideoList = false);
    });
  }

  Widget _buildChannelVideosList() {
    // show loading, error or horizontal list
    if (_loadingChannelVideos && _channelVideosViewModel.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_channelVideosViewModel.hasError &&
        _channelVideosViewModel.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load videos',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () {
                final channelId = widget.videoItem?.channelId;
                if (channelId != null)
                  _channelVideosViewModel.refresh(channelId: channelId);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final items = _channelVideosViewModel.items;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No other videos',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () {
                final channelId = widget.videoItem?.channelId;
                if (channelId != null)
                  _channelVideosViewModel.refresh(channelId: channelId);
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Show first few videos (limit to 3-4 for better UX)
        ...items
            .take(4)
            .map(
              (v) => Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: VideoCard(
                  item: v,
                  showPopupMenu: true, // Show popup menu in vertical layout
                  onTap: () {
                    final nav = Navigator.of(context);
                    final route = MaterialPageRoute(
                      builder:
                          (_) => CommonVideoPlayerScreen(
                            videoUrl:
                                v.videoUrl.isNotEmpty
                                    ? v.videoUrl
                                    : widget.videoUrl,
                            videoTitle: v.title,
                            videoItem: v,
                          ),
                    );
                    if (nav.canPop()) {
                      nav.pushReplacement(route);
                    } else {
                      nav.push(route);
                    }
                  },
                ),
              ),
            )
            .toList(),

        // Show "View More" button if there are more videos
        if (items.length > 4)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => ChannelVideosScreen(
                          channelId: widget.videoItem!.channelId!,
                          channelName: widget.videoItem!.channelName,
                        ),
                  ),
                );
              },
              child: Text(
                'View ${items.length - 4} more videos',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendedVideosList() {
    // Show loading, error or vertical list
    if (_loadingVideoList && _videoListViewModel.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videoListViewModel.hasError && _videoListViewModel.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load recommended videos',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () {
                _loadVideoList();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final items = _videoListViewModel.items;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No recommended videos',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () {
                _loadVideoList();
              },
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // Non-scrolling column: render a limited number of CompactVideoCard
    final displayCount = items.length > 6 ? 6 : items.length;
    return Column(
      children: [
        ...List.generate(displayCount, (index) {
          final item = items[index];
          return Column(
            children: [
              CompactVideoCard(
                item: item,
                showPopupMenu: true,
                onTap: () {
                  final nav = Navigator.of(context);
                  final route = MaterialPageRoute(
                    builder:
                        (_) => CommonVideoPlayerScreen(
                          videoUrl:
                              item.videoUrl.isNotEmpty
                                  ? item.videoUrl
                                  : widget.videoUrl,
                          videoTitle: item.title,
                          videoItem: item,
                        ),
                  );
                  if (nav.canPop()) {
                    nav.pushReplacement(route);
                  } else {
                    nav.push(route);
                  }
                },
              ),
              if (index < displayCount - 1)
                Divider(height: 1.h, color: Colors.grey.shade200),
            ],
          );
        }),

        // Show "View more" button if there are more videos than displayed
        if (items.length > displayCount)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: TextButton(
              onPressed: () {
                // Navigate to full video list screen
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VideoListScreen()),
                );
              },
              child: Text(
                'View ${items.length - displayCount} more videos',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
