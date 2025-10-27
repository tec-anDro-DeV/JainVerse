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
import 'package:jainverse/utils/SharedPref.dart';

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

  // Channel info from API response
  Map<String, dynamic>? _channelData;
  bool? _isSubscribed;
  int? _currentUserId;

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

    _loadCurrentUserId();
    _vm.refresh(channelId: widget.channelId);
  }

  /// Load the current logged-in user's ID
  Future<void> _loadCurrentUserId() async {
    try {
      final sharedPref = SharedPref();
      final userData = await sharedPref.getUserData();
      if (mounted && userData != null) {
        setState(() {
          _currentUserId = userData.id;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user ID: $e');
    }
  }

  /// Check if the channel belongs to the current user
  bool _isOwnChannel() {
    // Primary check: compare user IDs from channel data
    if (_currentUserId != null && _channelData != null) {
      final channelUserId = _channelData!['user_id'];
      if (_currentUserId == channelUserId) {
        return true;
      }
    }

    // Secondary check: if any video item has is_own flag, it's the user's channel
    if (_vm.items.isNotEmpty) {
      return _vm.items.any((video) => video.isOwn);
    }

    return false;
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

    // Extract channel info from ViewModel if available
    if (_vm.channelInfo != null && _channelData == null) {
      _channelData = _vm.channelInfo;
      _isSubscribed = _vm.channelInfo?['subscribed'] == 1;
    }

    // Also check if any video items have is_own flag set to determine channel ownership
    if (_vm.items.isNotEmpty && _currentUserId == null) {
      final firstVideo = _vm.items.first;
      if (firstVideo.isOwn) {
        // If any video is marked as own, this is the user's channel
        // No need to check user ID further
      }
    }

    setState(() {});
  }

  // Handle subscription toggle with optimistic updates
  Future<void> _toggleSubscription() async {
    // Don't allow subscription toggle if this is user's own channel
    if (_isOwnChannel()) {
      return;
    }

    final previousState =
        _isSubscribed; // Optimistic update - change UI immediately
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
          _channelData?['name'] ?? widget.channelName ?? 'Channel Videos',
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
        final bottomPadding = hasMiniPlayer
            ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 25.w
            : AppSizes.basePadding + 25.w;

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Channel header section
            if (_channelData != null)
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
                        // Sync video item with latest global state before navigation
                        final syncedItem = v
                            .syncWithGlobalState()
                            .syncLikeWithGlobalState();
                        final route = MaterialPageRoute(
                          builder: (_) => CommonVideoPlayerScreen(
                            videoUrl: syncedItem.videoUrl,
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
    if (_channelData == null) return const SizedBox.shrink();

    final String? bannerUrl = _channelData!['banner_url'];
    final String? imageUrl = _channelData!['image_url'];
    final String name = _channelData!['name'] ?? 'Channel';
    final String handle = _channelData!['handle'] ?? '';
    final String description = _channelData!['description'] ?? '';
    final String createdAt = _channelData!['created_at'] ?? '';

    // Check if this is the user's own channel by comparing user IDs
    final bool isOwn = _isOwnChannel();

    return Column(
      children: [
        // Banner Section with Avatar Overlay
        SizedBox(
          height: 180.w + 60.w, // Banner height + half avatar overlap
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner Image
              Container(
                height: 180.w,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8.w,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: bannerUrl != null && bannerUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: bannerUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2.w),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildPlaceholderBanner(),
                      )
                    : _buildPlaceholderBanner(),
              ),

              // Avatar overlapping the banner
              Positioned(
                bottom: 0,
                left: 16.w,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4.w),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12.w,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50.w,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(imageUrl)
                        : null,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? Icon(Icons.person, size: 50.w, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Channel Info Section
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.w, 16.w, 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Channel Name and Handle
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (handle.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            '@$handle',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Subscribe Button - only show if not own channel
                  if (!isOwn)
                    AnimatedSubscribeButton(
                      isSubscribed: _isSubscribed ?? false,
                      onPressed: _toggleSubscription,
                    ),
                ],
              ),

              // Description
              if (description.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Created Date
              if (createdAt.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14.w,
                      color: Colors.grey.shade500,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Joined ${_formatDate(createdAt)}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Divider
        Divider(height: 1.h, thickness: 1.w, color: Colors.grey.shade200),
      ],
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade300, Colors.purple.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image,
          size: 48.w,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
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
