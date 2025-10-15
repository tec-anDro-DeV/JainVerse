import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/videoplayer/models/channel_video_list_view_model.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/services/channel_video_service.dart';
import 'package:jainverse/videoplayer/screens/common_video_player_screen.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';
import 'package:jainverse/videoplayer/widgets/animated_subscribe_button.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/managers/like_dislike_state_manager.dart';
import 'package:jainverse/videoplayer/services/subscription_service.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/main.dart';

class ChannelVideosScreen extends StatefulWidget {
  final int channelId;
  final String? channelName;

  const ChannelVideosScreen({
    super.key,
    required this.channelId,
    this.channelName,
  });

  @override
  State<ChannelVideosScreen> createState() => _ChannelVideosScreenState();
}

class _ChannelVideosScreenState extends State<ChannelVideosScreen> {
  late final ChannelVideoListViewModel _vm;
  final ScrollController _scrollController = ScrollController();
  final SubscriptionService _subscriptionService = SubscriptionService();

  // Channel info from first video (all videos have same channel info)
  String? _channelName;
  String? _channelHandle;
  String? _channelImageUrl;
  bool? _isSubscribed;

  @override
  void initState() {
    super.initState();
    _vm = ChannelVideoListViewModel(
      service: ChannelVideoService(),
      perPage: 10,
    );
    _vm.addListener(_onVm);
    _scrollController.addListener(_onScroll);

    // Listen to subscription and like/dislike state changes
    SubscriptionStateManager().addListener(_onSubscriptionChanged);
    LikeDislikeStateManager().addListener(_onLikeDislikeChanged);

    _vm.refresh(channelId: widget.channelId);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVm);
    _vm.dispose();
    _scrollController.dispose();

    // Remove subscription and like/dislike listeners
    SubscriptionStateManager().removeListener(_onSubscriptionChanged);
    LikeDislikeStateManager().removeListener(_onLikeDislikeChanged);

    super.dispose();
  }

  void _onVm() {
    if (!mounted) return;

    // Extract channel info from first video if available
    if (_vm.items.isNotEmpty && _channelName == null) {
      final firstVideo = _vm.items.first;
      _channelName = firstVideo.channelName ?? widget.channelName;
      _channelHandle = firstVideo.channelHandle;
      _channelImageUrl = firstVideo.channelImageUrl;
      _isSubscribed = firstVideo.subscribed;
    }

    setState(() {});
  }

  // Handle subscription toggle with optimistic updates
  Future<void> _toggleSubscription() async {
    final previousState = _isSubscribed;

    // Optimistic update - change UI immediately
    setState(() {
      _isSubscribed = !(_isSubscribed ?? false);
    });

    // Update global state manager
    SubscriptionStateManager().updateSubscriptionState(
      widget.channelId,
      _isSubscribed!,
    );

    try {
      if (_isSubscribed == true) {
        await _subscriptionService.subscribeChannel(
          channelId: widget.channelId,
        );
      } else {
        await _subscriptionService.unsubscribeChannel(
          channelId: widget.channelId,
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isSubscribed = previousState;
        });
        SubscriptionStateManager().updateSubscriptionState(
          widget.channelId,
          previousState ?? false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subscription'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Callback when subscription state changes globally
  void _onSubscriptionChanged() {
    if (!mounted) return;
    // Trigger rebuild to sync video items with new subscription states
    setState(() {});
  }

  // Callback when like/dislike state changes globally
  void _onLikeDislikeChanged() {
    if (!mounted) return;
    // Trigger rebuild to sync video items with new like/dislike states
    setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _vm.loadNext(channelId: widget.channelId);
    }
  }

  Future<void> _onRefresh() async {
    await _vm.refresh(channelId: widget.channelId);
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
          _channelName ?? widget.channelName ?? 'Channel Videos',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(onRefresh: _onRefresh, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_vm.isLoading && _vm.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vm.hasError && _vm.items.isEmpty) {
      return _buildRetry();
    }

    // Get audio handler from main app
    final audioHandler = const MyApp().called();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        // Check if mini player is visible (music is playing)
        final hasMiniPlayer = snapshot.hasData;

        // Calculate bottom padding based on mini player and nav bar
        // Assuming navigation bar is always present, adjust if needed
        final bottomPadding =
            hasMiniPlayer
                ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 25.w
                : AppSizes.basePadding + 25.w;

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Channel header section
            if (_channelName != null || _channelImageUrl != null)
              SliverToBoxAdapter(child: _buildChannelHeader()),

            // Video list with bottom padding for mini player
            SliverPadding(
              padding: EdgeInsets.only(
                top: 12.h,
                left: 12.w,
                right: 12.w,
                bottom: bottomPadding, // Dynamic padding for mini player
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= _vm.items.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  final VideoItem v = _vm.items[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: VideoCard(
                      item: v.syncWithGlobalState().syncLikeWithGlobalState(),
                      onTap: () {
                        final nav = Navigator.of(context);
                        final route = MaterialPageRoute(
                          builder:
                              (_) => CommonVideoPlayerScreen(
                                videoUrl: v.videoUrl,
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
                      onMenuAction: (action) {
                        final messenger = ScaffoldMessenger.of(context);
                        switch (action) {
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
                      },
                    ),
                  );
                }, childCount: _vm.items.length + (_vm.isLoading ? 1 : 0)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChannelHeader() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8.w,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          // Channel avatar
          if (_channelImageUrl != null)
            CircleAvatar(
              radius: 36.w,
              backgroundImage: CachedNetworkImageProvider(_channelImageUrl!),
              backgroundColor: Colors.grey.shade200,
            )
          else
            CircleAvatar(
              radius: 36.w,
              backgroundColor: Colors.grey.shade300,
              child: Icon(Icons.person, size: 36.w, color: Colors.white),
            ),
          SizedBox(width: 16.w),

          // Channel info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _channelName ?? 'Channel',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_channelHandle != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '@$_channelHandle',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 12.h),

                // Subscribe button
                AnimatedSubscribeButton(
                  isSubscribed: _isSubscribed ?? false,
                  onPressed: _toggleSubscription,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetry() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Failed to load channel videos',
            style: TextStyle(fontSize: 14.sp),
          ),
          SizedBox(height: 12.h),
          ElevatedButton(
            onPressed: () => _vm.refresh(channelId: widget.channelId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
