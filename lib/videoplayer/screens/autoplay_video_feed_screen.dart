import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/models/video_list_view_model.dart';
import 'package:jainverse/videoplayer/widgets/autoplay_video_card.dart';
import 'package:jainverse/videoplayer/widgets/video_card_skeleton.dart';
import 'package:jainverse/videoplayer/screens/common_video_player_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/managers/like_dislike_state_manager.dart';

/// YouTube-style video feed with silent autoplay.
///
/// Features:
/// - Auto-plays the most visible video after 1.5s of scroll inactivity
/// - Muted playback (no sound)
/// - Single shared VideoPlayerController for memory efficiency
/// - Smooth thumbnail-to-video transitions
/// - Pauses on scroll and app lifecycle changes
class AutoplayVideoFeedScreen extends StatelessWidget {
  const AutoplayVideoFeedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors().colorBackground,
      appBar: AppBar(
        backgroundColor: appColors().colorBackground,
        elevation: 0,
        title: Text(
          'Videos',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: const AutoplayVideoFeedBody(),
    );
  }
}

/// Embeddable video feed widget (no scaffold).
class AutoplayVideoFeedBody extends StatefulWidget {
  const AutoplayVideoFeedBody({Key? key}) : super(key: key);

  @override
  State<AutoplayVideoFeedBody> createState() => _AutoplayVideoFeedBodyState();
}

class _AutoplayVideoFeedBodyState extends State<AutoplayVideoFeedBody>
    with WidgetsBindingObserver {
  late final VideoListViewModel _viewModel;
  late final ScrollController _scrollController;

  // Autoplay state
  VideoPlayerController? _sharedController;
  int? _currentlyPlayingIndex;
  Timer? _autoplayTimer;
  bool _isScrolling = false;

  // Visibility tracking
  final Map<int, double> _itemVisibility = {};

  // Configuration
  static const Duration _autoplayDelay = Duration(milliseconds: 1500);
  static const double _visibilityThreshold = 0.7;
  static const int _skeletonCount = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _viewModel = VideoListViewModel(perPage: 10);
    _scrollController = ScrollController();

    _scrollController.addListener(_onScroll);
    _viewModel.addListener(_onViewModelChanged);

    // Listen to subscription and like/dislike state changes
    SubscriptionStateManager().addListener(_onSubscriptionChanged);
    LikeDislikeStateManager().addListener(_onLikeDislikeChanged);

    // Load initial data
    _viewModel.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoplayTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _viewModel.removeListener(_onViewModelChanged);

    // Remove subscription and like/dislike listeners
    SubscriptionStateManager().removeListener(_onSubscriptionChanged);
    LikeDislikeStateManager().removeListener(_onLikeDislikeChanged);

    _scrollController.dispose();
    _sharedController?.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Pause video when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseCurrentVideo();
    }
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // Callback when subscription state changes globally
  void _onSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // Callback when like/dislike state changes globally
  void _onLikeDislikeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Mark as scrolling
    if (!_isScrolling) {
      setState(() => _isScrolling = true);
      _pauseCurrentVideo();
    }

    _autoplayTimer?.cancel();

    // Start autoplay timer after scroll stops
    _autoplayTimer = Timer(_autoplayDelay, () {
      if (!mounted) return;
      setState(() => _isScrolling = false);
      _checkAndPlayMostVisibleVideo();
    });

    // Load more items when near the end
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_viewModel.isLoading &&
        _viewModel.page < _viewModel.totalPages) {
      _viewModel.loadNext();
    }
  }

  Future<void> _refresh() async {
    _pauseCurrentVideo();
    _currentlyPlayingIndex = null;
    await _viewModel.refresh();
  }

  void _pauseCurrentVideo() {
    if (_sharedController != null &&
        _sharedController!.value.isInitialized &&
        _sharedController!.value.isPlaying) {
      _sharedController!.pause();
    }
  }

  /// Find the most visible video card and auto-play it.
  void _checkAndPlayMostVisibleVideo() {
    if (!mounted || _isScrolling) return;
    if (_itemVisibility.isEmpty) return;

    // Find item with highest visibility
    double maxVisibility = 0;
    int? mostVisibleIndex;

    _itemVisibility.forEach((index, visibility) {
      if (visibility > maxVisibility && visibility >= _visibilityThreshold) {
        maxVisibility = visibility;
        mostVisibleIndex = index;
      }
    });

    // If found a visible item and it's different from current
    if (mostVisibleIndex != null &&
        mostVisibleIndex != _currentlyPlayingIndex) {
      _playVideoAtIndex(mostVisibleIndex!);
    }
  }

  /// Initialize and play video at the given index.
  Future<void> _playVideoAtIndex(int index) async {
    if (!mounted) return;
    if (index >= _viewModel.items.length) return;

    final item = _viewModel.items[index];

    // Pause current if playing
    _pauseCurrentVideo();

    // Dispose old controller if it exists
    await _sharedController?.dispose();

    try {
      // Create new controller
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(item.videoUrl),
      );

      // Initialize
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      // Set volume to 0 (muted)
      await controller.setVolume(0.0);

      // Enable looping
      await controller.setLooping(true);

      setState(() {
        _sharedController = controller;
        _currentlyPlayingIndex = index;
      });

      // Start playing
      controller.play();
    } catch (e) {
      debugPrint('Error playing video at index $index: $e');
      setState(() {
        _sharedController = null;
        _currentlyPlayingIndex = null;
      });
    }
  }

  void _onItemVisibilityChanged(int index, double visibilityFraction) {
    _itemVisibility[index] = visibilityFraction;
  }

  void _openFullPlayer(VideoItem item) {
    // Pause autoplay
    _pauseCurrentVideo();

    // Navigate to full player
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => CommonVideoPlayerScreen(
              videoUrl: item.videoUrl,
              videoTitle: item.title,
              videoItem: item,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bottom padding for mini player and navigation bar
    // Using standard values: 70h for mini player + 75h for nav bar
    final bottomPadding = 70.h + 75.h;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            sliver: _buildVideoList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    // Loading state (first load)
    if (_viewModel.isLoading && _viewModel.items.isEmpty) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: const VideoCardSkeleton(),
          ),
          childCount: _skeletonCount,
        ),
      );
    }

    // Error state
    if (_viewModel.hasError && _viewModel.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64.w,
                color: Colors.grey.shade600,
              ),
              SizedBox(height: 16.h),
              Text(
                'Failed to load videos',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _viewModel.errorMessage,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.w),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Video list with items
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // Show actual video cards
        if (index < _viewModel.items.length) {
          final item = _viewModel.items[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: VisibilityDetector(
              key: Key('video_visibility_${item.id}'),
              onVisibilityChanged: (info) {
                _onItemVisibilityChanged(index, info.visibleFraction);
              },
              child: AutoplayVideoCard(
                item: item.syncWithGlobalState().syncLikeWithGlobalState(),
                shouldPlay: _currentlyPlayingIndex == index,
                sharedController: _sharedController,
                onTap: () => _openFullPlayer(item),
                onVisibilityChanged: () {
                  // Trigger autoplay check when visibility changes
                  if (!_isScrolling) {
                    _checkAndPlayMostVisibleVideo();
                  }
                },
              ),
            ),
          );
        }

        // Show loading indicator at the end
        if (_viewModel.isLoading) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Center(
              child: CircularProgressIndicator(
                color: appColors().primaryColorApp,
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      }, childCount: _viewModel.items.length + (_viewModel.isLoading ? 1 : 0)),
    );
  }
}
