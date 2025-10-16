import 'dart:math';
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
import 'package:jainverse/videoplayer/widgets/video_card_skeleton.dart';
import 'package:jainverse/videoplayer/widgets/compact_video_card_skeleton.dart';
import 'package:jainverse/videoplayer/widgets/animated_subscribe_button.dart';
import 'package:jainverse/videoplayer/services/subscription_service.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/widgets/animated_like_dislike_buttons.dart';
import 'package:jainverse/videoplayer/services/like_dislike_service.dart';
import 'package:jainverse/videoplayer/managers/like_dislike_state_manager.dart';
import 'package:jainverse/videoplayer/services/watch_history_service.dart';

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
  int? _channelSkeletonCount;
  int? _recommendedSkeletonCount;

  // Subscription state
  late final SubscriptionService _subscriptionService;
  bool _isSubscribed = false;

  // Like/Dislike state
  late final LikeDislikeService _likeDislikeService;
  int _likeState = 0; // 0=neutral, 1=liked, 2=disliked

  // Watch history service
  late final WatchHistoryService _watchHistoryService;
  bool _watchHistoryMarked = false; // Track if we've already marked this video

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
    _subscriptionService = SubscriptionService();
    _likeDislikeService = LikeDislikeService();
    _watchHistoryService = WatchHistoryService();

    // Initialize subscription status from video item or global state
    final channelId = widget.videoItem?.channelId;
    if (channelId != null) {
      // Check global state first, fallback to video item value
      final globalState = SubscriptionStateManager().getSubscriptionState(
        channelId,
      );
      _isSubscribed = globalState ?? widget.videoItem?.subscribed ?? false;
    } else {
      _isSubscribed = widget.videoItem?.subscribed ?? false;
    }

    // Initialize like/dislike state from video item or global state
    final videoId = widget.videoItem?.id;
    if (videoId != null) {
      final globalLikeState = LikeDislikeStateManager().getLikeState(videoId);
      _likeState = globalLikeState ?? widget.videoItem?.like ?? 0;
    } else {
      _likeState = widget.videoItem?.like ?? 0;
    }

    // Listen to global state changes
    SubscriptionStateManager().addListener(_onGlobalSubscriptionChanged);
    LikeDislikeStateManager().addListener(_onGlobalLikeDislikeChanged);

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

    // Remove global state listeners
    SubscriptionStateManager().removeListener(_onGlobalSubscriptionChanged);
    LikeDislikeStateManager().removeListener(_onGlobalLikeDislikeChanged);

    _channelVideosViewModel.dispose();
    _videoListViewModel.dispose();
    super.dispose();
  }

  // Callback when global subscription state changes
  void _onGlobalSubscriptionChanged() {
    if (!mounted) return;
    final channelId = widget.videoItem?.channelId;
    if (channelId == null) return;

    final globalState = SubscriptionStateManager().getSubscriptionState(
      channelId,
    );
    if (globalState != null && globalState != _isSubscribed) {
      setState(() => _isSubscribed = globalState);
    }
  }

  // Callback when global like/dislike state changes
  void _onGlobalLikeDislikeChanged() {
    if (!mounted) return;
    final videoId = widget.videoItem?.id;
    if (videoId == null) return;

    final globalLikeState = LikeDislikeStateManager().getLikeState(videoId);
    if (globalLikeState != null && globalLikeState != _likeState) {
      setState(() => _likeState = globalLikeState);
    }
  }

  // Double-tap skip handling is now contained in the CommonVideoPlayer widget.

  Future<void> _toggleSubscription() async {
    final channelId = widget.videoItem?.channelId;
    if (channelId == null) return;

    // Optimistically update UI immediately
    final previousState = _isSubscribed;
    setState(() => _isSubscribed = !_isSubscribed);

    try {
      final success =
          previousState
              ? await _subscriptionService.unsubscribeChannel(
                channelId: channelId,
              )
              : await _subscriptionService.subscribeChannel(
                channelId: channelId,
              );

      // If failed, revert the UI
      if (!success && mounted) {
        setState(() => _isSubscribed = previousState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${previousState ? "unsubscribe" : "subscribe"}. Please try again.',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() => _isSubscribed = previousState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${previousState ? "unsubscribe" : "subscribe"}. Please try again.',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    final videoId = widget.videoItem?.id;
    if (videoId == null) return;

    // Optimistically update UI immediately
    final previousState = _likeState;
    final newState = _likeState == 1 ? 0 : 1;
    setState(() => _likeState = newState);

    try {
      final success = await _likeDislikeService.likeVideo(
        videoId: videoId,
        currentState: previousState,
      );

      // If failed, revert the UI
      if (!success && mounted) {
        setState(() => _likeState = previousState);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() => _likeState = previousState);
      }
    }
  }

  Future<void> _toggleDislike() async {
    final videoId = widget.videoItem?.id;
    if (videoId == null) return;

    // Optimistically update UI immediately
    final previousState = _likeState;
    final newState = _likeState == 2 ? 0 : 2;
    setState(() => _likeState = newState);

    try {
      final success = await _likeDislikeService.dislikeVideo(
        videoId: videoId,
        currentState: previousState,
      );

      // If failed, revert the UI
      if (!success && mounted) {
        setState(() => _likeState = previousState);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() => _likeState = previousState);
      }
    }
  }

  /// Mark the video as watched in watch history
  /// This is called when video starts playing (not for autoplay)
  Future<void> _markVideoAsWatched() async {
    // Don't mark if already marked or if video item is null
    if (_watchHistoryMarked || widget.videoItem?.id == null) return;

    final videoId = widget.videoItem!.id;
    _watchHistoryMarked = true; // Mark immediately to prevent duplicate calls

    try {
      final success = await _watchHistoryService.markVideoAsWatched(
        videoId: videoId,
      );

      if (!success && mounted) {
        // Reset flag if failed, so user can retry
        _watchHistoryMarked = false;
      }
    } catch (e) {
      // Watch history is not critical, just log and continue
      debugPrint('Failed to mark video as watched: $e');
      if (mounted) {
        _watchHistoryMarked = false;
      }
    }
  }

  /// Navigate to the full channel videos screen for the current video's channel
  void _openChannel() {
    final channelId = widget.videoItem?.channelId;
    if (channelId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ChannelVideosScreen(
              channelId: channelId,
              channelName: widget.videoItem?.channelName,
            ),
      ),
    );
  }

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
                      key: ValueKey(
                        widget.videoUrl,
                      ), // Prevent unnecessary widget recreation
                      videoUrl: widget.videoUrl,
                      overlayVisibleMs: widget.overlayVisibleMs,
                      fadeDurationMs: widget.fadeDurationMs,
                      scaleDurationMs: widget.scaleDurationMs,
                      onControllerInitialized: (controller) {
                        // store controller reference so the screen can show duration
                        setState(() {
                          _videoPlayerController = controller;
                        });
                        // Mark video as watched when it starts playing
                        _markVideoAsWatched();
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

                  // Row: views  •  duration  •  uploaded ago
                  Row(
                    children: [
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 18.w,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _formatViews(widget.videoItem?.totalViews),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
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
                      SizedBox(width: 12.w),
                      if (widget.videoItem?.createdAt != null)
                        Text(
                          '• ${_formatTimeAgo(widget.videoItem!.createdAt)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14.sp,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8.h),

                  // Channel info row below: avatar + channel name + subscribe button
                  Row(
                    children: [
                      if (widget.videoItem?.channelImageUrl != null &&
                          widget.videoItem!.channelImageUrl!.isNotEmpty)
                        GestureDetector(
                          onTap: _openChannel,
                          child: CircleAvatar(
                            radius: 24.w,
                            backgroundImage: CachedNetworkImageProvider(
                              widget.videoItem!.channelImageUrl!,
                            ),
                          ),
                        ),
                      SizedBox(width: 8.w),
                      if (widget.videoItem?.channelName != null)
                        Expanded(
                          child: GestureDetector(
                            onTap: _openChannel,
                            child: Text(
                              widget.videoItem!.channelName!,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      SizedBox(width: 8.w),
                      // Subscribe button on the right
                      if (widget.videoItem?.channelId != null)
                        AnimatedSubscribeButton(
                          isSubscribed: _isSubscribed,
                          onPressed: _toggleSubscription,
                        ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Like/Dislike buttons row
                  Row(
                    children: [
                      AnimatedLikeDislikeButtons(
                        likeState: _likeState,
                        onLike: _toggleLike,
                        onDislike: _toggleDislike,
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

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    final months = (diff.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
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

  void _maybeLoadChannelVideos() {
    final channelId = widget.videoItem?.channelId;
    if (channelId == null) return;
    if (_channelVideosViewModel.items.isNotEmpty) return;

    setState(() => _loadingChannelVideos = true);
    _channelVideosViewModel.refresh(channelId: channelId).whenComplete(() {
      if (mounted) {
        setState(() {
          _loadingChannelVideos = false;
          // Reset skeleton count when data arrives
          if (_channelVideosViewModel.items.isNotEmpty) {
            _channelSkeletonCount = null;
          }
        });
      }
    });
  }

  void _loadVideoList() {
    if (_videoListViewModel.items.isNotEmpty) return;

    setState(() => _loadingVideoList = true);
    _videoListViewModel.refresh().whenComplete(() {
      if (mounted) {
        setState(() {
          _loadingVideoList = false;
          // Reset skeleton count when data arrives
          if (_videoListViewModel.items.isNotEmpty) {
            _recommendedSkeletonCount = null;
          }
        });
      }
    });
  }

  Widget _buildChannelVideosList() {
    // show loading, error or horizontal list
    if (_loadingChannelVideos && _channelVideosViewModel.items.isEmpty) {
      // Show 4-8 skeleton cards (compute once per loading session)
      final skeletonCount = _channelSkeletonCount ??= (Random().nextInt(5) + 4);
      return Column(
        children: List.generate(
          skeletonCount,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: VideoCardSkeleton(),
          ),
        ),
      );
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
                  item:
                      v
                          .syncWithGlobalState()
                          .syncLikeWithGlobalState(), // Sync with global subscription and like state
                  showPopupMenu: true, // Show popup menu in vertical layout
                  onTap: () {
                    final nav = Navigator.of(context);
                    // Sync video item with latest global state before navigation
                    final syncedItem =
                        v.syncWithGlobalState().syncLikeWithGlobalState();
                    final route = MaterialPageRoute(
                      builder:
                          (_) => CommonVideoPlayerScreen(
                            videoUrl:
                                syncedItem.videoUrl.isNotEmpty
                                    ? syncedItem.videoUrl
                                    : widget.videoUrl,
                            videoTitle: syncedItem.title,
                            videoItem: syncedItem,
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
      // Show 4-8 compact skeleton cards (compute once per loading session)
      final skeletonCount =
          _recommendedSkeletonCount ??= (Random().nextInt(5) + 4);
      return Column(
        children: List.generate(
          skeletonCount,
          (index) => Column(
            children: [
              CompactVideoCardSkeleton(),
              if (index < skeletonCount - 1)
                Divider(height: 1.h, color: Colors.grey.shade200),
            ],
          ),
        ),
      );
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
                item:
                    item
                        .syncWithGlobalState()
                        .syncLikeWithGlobalState(), // Sync with global subscription and like state
                showPopupMenu: true,
                onTap: () {
                  final nav = Navigator.of(context);
                  // Sync video item with latest global state before navigation
                  final syncedItem =
                      item.syncWithGlobalState().syncLikeWithGlobalState();
                  final route = MaterialPageRoute(
                    builder:
                        (_) => CommonVideoPlayerScreen(
                          videoUrl:
                              syncedItem.videoUrl.isNotEmpty
                                  ? syncedItem.videoUrl
                                  : widget.videoUrl,
                          videoTitle: syncedItem.title,
                          videoItem: syncedItem,
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
