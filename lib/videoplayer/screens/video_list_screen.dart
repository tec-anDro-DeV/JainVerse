import 'dart:async';
import 'dart:math';
// existing imports
import 'package:jainverse/videoplayer/widgets/video_card_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/videoplayer/screens/common_video_player_screen.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/models/video_list_view_model.dart';
import 'package:jainverse/videoplayer/widgets/autoplay_video_card.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/managers/like_dislike_state_manager.dart';

class VideoListScreen extends StatelessWidget {
  const VideoListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Videos')),
      body: const VideoListBody(),
    );
  }
}

/// Embeddable video list widget (no scaffold) so it can be placed inside other screens.
class VideoListBody extends StatefulWidget {
  const VideoListBody({Key? key}) : super(key: key);

  @override
  State<VideoListBody> createState() => _VideoListBodyState();
}

class _VideoListBodyState extends State<VideoListBody>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  ScrollController? _scrollController;
  bool _ownsScrollController = false;
  late final VideoListViewModel _viewModel;
  int? _skeletonCount;

  // Autoplay state
  VideoPlayerController? _sharedController;
  int? _currentlyPlayingIndex;
  Timer? _autoplayTimer;
  bool _isScrolling = false;

  // Visibility tracking
  final Map<int, double> _itemVisibility = {};

  // Configuration
  static const Duration _autoplayDelay = Duration(milliseconds: 1000);
  static const double _visibilityThreshold = 0.7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _viewModel = VideoListViewModel(perPage: 10);
    // scroll controller will be assigned in didChangeDependencies so we
    // don't add the listener here. This ensures NestedScrollView can
    // provide the inner PrimaryScrollController when embedding this widget.
    _viewModel.addListener(_onViewModel);

    // Listen to subscription and like/dislike state changes
    SubscriptionStateManager().addListener(_onSubscriptionChanged);
    LikeDislikeStateManager().addListener(_onLikeDislikeChanged);

    _viewModel.refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Use PrimaryScrollController if available (e.g. when inside
    // a NestedScrollView). Otherwise create and own a controller.
    final primary = PrimaryScrollController.maybeOf(context);
    if (primary != _scrollController) {
      if (primary != null) {
        _scrollController = primary;
        _ownsScrollController = false;
      } else {
        _scrollController ??= ScrollController();
        _ownsScrollController = true;
      }
    }

    // Ensure listener is attached exactly once
    _scrollController?.removeListener(_onScroll);
    _scrollController?.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoplayTimer?.cancel();
    _scrollController?.removeListener(_onScroll);
    _viewModel.removeListener(_onViewModel);

    // Remove subscription and like/dislike listeners
    SubscriptionStateManager().removeListener(_onSubscriptionChanged);
    LikeDislikeStateManager().removeListener(_onLikeDislikeChanged);

    if (_ownsScrollController) {
      try {
        _scrollController?.dispose();
      } catch (_) {}
    }
    _sharedController?.dispose();
    _viewModel.dispose();
    super.dispose();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Pause video when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseCurrentVideo();
    }
  }

  void _onViewModel() {
    if (!mounted) return;
    // Reset skeleton count when real data arrives or when not loading
    if (!_viewModel.isLoading && _viewModel.items.isNotEmpty) {
      _skeletonCount = null;
    }
    setState(() {});
  }

  void _onScroll() {
    if (_scrollController == null || !_scrollController!.hasClients) return;

    // Mark as scrolling and pause current video
    if (!_isScrolling) {
      if (mounted) {
        setState(() => _isScrolling = true);
      }
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
    if (_scrollController != null &&
        _scrollController!.position.pixels >=
            _scrollController!.position.maxScrollExtent - 200 &&
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

    // Play if we found a visible item and either:
    // 1. No video is currently playing, OR
    // 2. It's a different video than the current one
    if (mostVisibleIndex != null) {
      if (_currentlyPlayingIndex == null ||
          mostVisibleIndex != _currentlyPlayingIndex) {
        _playVideoAtIndex(mostVisibleIndex!);
      }
    } else {
      // No video is visible enough - pause current if playing
      if (_currentlyPlayingIndex != null) {
        _pauseCurrentVideo();
        if (mounted) {
          setState(() {
            _currentlyPlayingIndex = null;
          });
        }
      }
    }
  }

  /// Initialize and play video at the given index.
  Future<void> _playVideoAtIndex(int index) async {
    if (!mounted) return;
    if (index >= _viewModel.items.length) return;

    final item = _viewModel.items[index];

    // Pause current if playing
    _pauseCurrentVideo();

    // Store the old controller to dispose it later
    final oldController = _sharedController;

    // Clear state immediately to prevent stale UI
    if (mounted) {
      setState(() {
        _sharedController = null;
        _currentlyPlayingIndex = null;
      });
    }

    // Dispose old controller asynchronously (don't block)
    oldController?.dispose().catchError((e) {
      debugPrint('Error disposing old controller: $e');
    });

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

      // Update state with new controller
      if (mounted) {
        setState(() {
          _sharedController = controller;
          _currentlyPlayingIndex = index;
        });
      }

      // Start playing
      await controller.play();
    } catch (e) {
      debugPrint('Error playing video at index $index: $e');
      if (mounted) {
        setState(() {
          _sharedController = null;
          _currentlyPlayingIndex = null;
        });
      }
    }
  }

  void _onItemVisibilityChanged(int index, double visibilityFraction) {
    if (!mounted) return; // Guard against disposed state

    _itemVisibility[index] = visibilityFraction;

    // If currently playing video becomes less visible, pause it immediately
    if (index == _currentlyPlayingIndex &&
        visibilityFraction < _visibilityThreshold) {
      _pauseCurrentVideo();
      // Clear the playing index so new video can start
      if (mounted) {
        setState(() {
          _currentlyPlayingIndex = null;
        });
      }
    }
  }

  void _openPlayer(VideoItem item) {
    // Try to replace the current player if possible, otherwise push.
    final nav = Navigator.of(context);
    // Sync video item with latest global state before navigation
    final syncedItem = item.syncWithGlobalState().syncLikeWithGlobalState();
    final route = MaterialPageRoute(
      builder:
          (_) => CommonVideoPlayerScreen(
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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Must call super for AutomaticKeepAliveClientMixin
    // Add bottom padding so list content isn't hidden behind the
    // app's bottom navigation or the mini player. We reuse AppSizes
    // to keep sizing consistent across the app.
    return RefreshIndicator(
      onRefresh: _refresh,
      // Use a CustomScrollView so padding becomes part of the scrollable area
      // and the RefreshIndicator works reliably for both the list and the
      // empty/error state.
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              12.w,
              20.h,
              12.w,
              (AppSizes.basePadding + AppSizes.miniPlayerPadding + 8.w),
            ),
            sliver:
                _viewModel.hasError && _viewModel.items.isEmpty
                    ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 60.h),
                          Center(
                            child: Text('Error: ${_viewModel.errorMessage}'),
                          ),
                          SizedBox(height: 8.h),
                          Center(
                            child: ElevatedButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ),
                        ],
                      ),
                    )
                    : (_viewModel.isLoading && _viewModel.items.isEmpty)
                    // Initial loading: show skeleton placeholders (4-8 random)
                    ? Builder(
                      builder: (context) {
                        // compute skeleton count once per loading session
                        final randCount =
                            _skeletonCount ??= (Random().nextInt(5) + 4);
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 6.h,
                                horizontal: 8.w,
                              ),
                              child: VideoCardSkeleton(),
                            ),
                            childCount: randCount,
                          ),
                        );
                      },
                    )
                    : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index >= _viewModel.items.length) {
                          // footer slot: show loader while loading, otherwise
                          // provide some spacing so content isn't flush to bottom.
                          if (_viewModel.isLoading) {
                            // show a single skeleton card as a footer placeholder
                            return Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 6.h,
                                horizontal: 8.w,
                              ),
                              child: VideoCardSkeleton(),
                            );
                          }
                          return SizedBox(height: 40.h);
                        }

                        final item = _viewModel.items[index];
                        return Container(
                          padding: EdgeInsets.only(bottom: 16.h),
                          child: VisibilityDetector(
                            key: Key('video_visibility_${item.id}'),
                            onVisibilityChanged: (info) {
                              _onItemVisibilityChanged(
                                index,
                                info.visibleFraction,
                              );
                              // Trigger autoplay check when visibility changes
                              if (!_isScrolling) {
                                _checkAndPlayMostVisibleVideo();
                              }
                            },
                            child: AutoplayVideoCard(
                              item:
                                  item
                                      .syncWithGlobalState()
                                      .syncLikeWithGlobalState(), // Sync with global subscription and like state
                              shouldPlay: _currentlyPlayingIndex == index,
                              sharedController: _sharedController,
                              onTap: () => _openPlayer(item),
                            ),
                          ),
                        );
                      }, childCount: _viewModel.items.length + 1),
                    ),
          ),
        ],
      ),
    );
  }
}
