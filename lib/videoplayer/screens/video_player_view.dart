import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../managers/video_player_state_provider.dart';
import '../services/video_player_theme_service.dart';
import '../widgets/video_visual_area.dart';
import '../widgets/video_control_panel.dart';
import '../widgets/video_title_channel_row.dart';
import '../widgets/video_more_sheet.dart';
import 'channel_videos_screen.dart';
import '../../utils/music_player_state_manager.dart';
import 'package:jainverse/services/tab_navigation_service.dart';
import '../utils/landscape_video_launcher.dart';
import '../managers/subscription_state_manager.dart';
import '../managers/like_dislike_state_manager.dart';
import '../managers/report_state_manager.dart';
import '../services/like_dislike_service.dart';
import '../widgets/animated_like_dislike_buttons.dart';
import '../widgets/video_report_modal.dart';
import '../models/video_item.dart';
import '../services/subscription_service.dart';
import '../../managers/music_manager.dart';
import '../utils/orientation_helper.dart';
import '../services/related_videos_service.dart';
import '../widgets/video_card_inside.dart';
import '../widgets/video_card_glass_skeleton.dart';

/// Full-screen video player view
/// Mirrors the MusicPlayerView design with video-specific adaptations
class VideoPlayerView extends ConsumerStatefulWidget {
  final String videoUrl;
  final String videoId;
  final String? title;
  final String? subtitle;
  final String? thumbnailUrl;
  // Optional channel information to render channel row (avatar + subscribe)
  final int? channelId;
  final String? channelAvatarUrl;
  final int? channelSubscriberCount;
  final VideoItem? videoItem;
  final List<String>? playlist;
  final int? playlistIndex;
  final bool? isOwn;

  const VideoPlayerView({
    super.key,
    required this.videoUrl,
    required this.videoId,
    this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.channelId,
    this.channelAvatarUrl,
    this.channelSubscriberCount,
    this.playlist,
    this.playlistIndex,
    this.isOwn,
    this.videoItem,
  });

  @override
  ConsumerState<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView>
    with TickerProviderStateMixin {
  VideoPlayerTheme? _theme;
  // Track which thumbnail URLs we've precached to avoid redundant work
  final Set<String> _precachedThumbnails = <String>{};
  // Track last known orientation so we can react to device rotation
  Orientation? _lastOrientation;
  // Track the last seen provider thumbnail so we can detect changes during
  // rebuild and react (extract theme + precache) without using ref.listen
  // from initState (which Riverpod disallows in this context).
  String? _lastSeenProviderThumbnail;
  // Guard to avoid concurrent theme extraction tasks
  bool _isHandlingThumbnailChange = false;
  // Guard to ensure we only launch landscape player once per rotation event
  bool _rotationLaunched = false;
  DateTime? _landscapeCooldownUntil;

  // Drag gesture state
  late AnimationController _dragAnimationController;
  late Animation<Offset> _dragAnimation;
  // Controller used to animate a smooth snap-back when the user cancels a
  // header drag (drags but doesn't pass the dismiss threshold).
  late AnimationController _snapBackController;
  double _snapStartDistance = 0.0;
  double _dragDistance = 0.0;
  bool _isProgrammaticPop = false;
  bool _isMinimizeInProgress = false;
  bool _headerDragActive = false;
  // Subscription management
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isSubscribed = false;
  bool _isSubscriptionInProgress = false;
  // Like / Dislike / Report services
  final LikeDislikeService _likeDislikeService = LikeDislikeService();
  // Local like count used to display and optimistically update totalLikes
  int? _localTotalLikes;
  // Related videos state
  final RelatedVideosService _relatedVideosService = RelatedVideosService();
  List<VideoItem> _relatedVideos = [];
  bool _isRelatedLoading = false;
  String? _relatedError;

  void initState() {
    super.initState();
    // We don't attempt to capture the prior overlay style (not reliably
    // available across platforms). Instead we restore a safe default on exit.

    // Apply an initial (safe) overlay immediately so the status bar doesn't
    // flash the system default while we extract colors. We'll update it once
    // the thumbnail-derived theme is ready.
    _theme = VideoPlayerTheme.defaultTheme();
    _updateSystemUI(_theme!);
    unawaited(_enableVideoScreenOrientations());

    // Initialize drag animation controller
    _dragAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _dragAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1))
        .animate(
          CurvedAnimation(
            parent: _dragAnimationController,
            curve: Curves.easeOut,
          ),
        );

    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _snapBackController.addListener(() {
      // Animate dragDistance back to zero smoothly
      final t = _snapBackController.value;
      setState(() {
        _dragDistance = ui.lerpDouble(_snapStartDistance, 0.0, t) ?? 0.0;
      });
    });

    // Defer heavy initialization until after first frame so the full-screen
    // UI can render immediately. We still perform any long-running work in
    // the background so the user perceives the player as opening instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _initializeVideoPlayer();
      // Notify global state manager to hide mini players/navigation while full player is shown
      MusicPlayerStateManager().showFullPlayer();

      // Clear mini player flags now that full player is showing
      try {
        final videoNotifier = ref.read(videoPlayerProvider.notifier);
        final videoState = ref.read(videoPlayerProvider);
        if (videoState.showMiniPlayer) {
          videoNotifier.clearMiniPlayerFlag();
        }
      } catch (e) {
        debugPrint('[VideoPlayerView] Error clearing mini player flag: $e');
      }

      _fetchRelatedVideos();
    });
    // Initialize local counts from originating VideoItem when available
    _localTotalLikes = widget.videoItem?.totalLikes;
    // Subscription listener & initial value will be registered after we
    // initialize the provider state (below) so we catch cases where the
    // mini-player expansion didn't pass channel metadata in the widget
    // constructor but the provider holds it.
    _loadTheme();
    // Note: provider change detection (thumbnail -> theme updates) is
    // handled during build by comparing the provider thumbnail to
    // `_lastSeenProviderThumbnail`. Riverpod disallows calling
    // `ref.listen` here for ConsumerState; doing it in initState triggers an
    // assertion in some Riverpod versions. See build() for the change
    // detection logic.
  }

  // Safe check to see if a controller is initialized without throwing when
  // the controller is disposed concurrently.
  bool controllerIsInitializedSafely(VideoPlayerController? c) {
    try {
      return c?.value.isInitialized ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeVideoPlayer() async {
    // Check if widget is still mounted
    if (!mounted) return;

    try {
      await MusicManager.instance.stopAndDisposeAll(
        reason: 'video-player-view-init',
      );
    } catch (e) {
      debugPrint('[VideoPlayerView] Failed to stop music before init: $e');
    }

    final videoNotifier = ref.read(videoPlayerProvider.notifier);
    final videoState = ref.read(videoPlayerProvider);
    final controller = videoState.controller;
    final hasInitializedController =
        controller != null &&
        !videoNotifier.isControllerDisposed(controller) &&
        !videoNotifier.isControllerScheduledForDisposal(controller) &&
        controllerIsInitializedSafely(controller);
    final hasStableId = widget.videoId.isNotEmpty;
    final isSameVideo =
        hasInitializedController &&
        hasStableId &&
        videoState.currentVideoId == widget.videoId;

    // Reuse controller only when we're expanding the exact same video from the mini player.
    if (isSameVideo) {
      debugPrint(
        '[VideoPlayerView] Using existing controller from mini player',
      );
      if (mounted) {
        videoNotifier.expandToFullScreen();
        if (videoState.showMiniPlayer) {
          videoNotifier.clearMiniPlayerFlag();
        }
      }
      return;
    }
    // Ensure mini-player flags are cleared before loading a new video.
    if (videoState.isMinimized) {
      videoNotifier.expandToFullScreen();
    }
    if (videoState.showMiniPlayer) {
      videoNotifier.clearMiniPlayerFlag();
    }

    // Start initialization in background so the UI isn't blocked. If a
    // controller was prefetched it will be attached quickly in the provider.
    if (mounted) {
      // fire-and-forget initialization to avoid blocking the first frame
      unawaited(
        videoNotifier.initializeVideo(
          videoUrl: widget.videoUrl,
          videoId: widget.videoId,
          title: widget.title,
          subtitle: widget.subtitle,
          thumbnailUrl: widget.thumbnailUrl,
          channelId: widget.channelId,
          channelAvatarUrl: widget.channelAvatarUrl,
          playlist: widget.playlist,
          playlistIndex: widget.playlistIndex,
        ),
      );
    }
  }

  Future<void> _loadTheme() async {
    if (widget.thumbnailUrl == null) {
      setState(() {
        _theme = VideoPlayerTheme.defaultTheme();
        _updateSystemUI(_theme!);
      });
      return;
    }

    try {
      final theme = await VideoPlayerThemeService().generateThemeFromThumbnail(
        thumbnailUrl: widget.thumbnailUrl!,
        context: context,
      );

      if (mounted) {
        setState(() {
          _theme = theme;
          _updateSystemUI(theme);
        });
        // Precache thumbnail image into cached_network_image's provider so
        // disk+memory cache is populated and subsequent opens are fast.
        if (widget.thumbnailUrl != null) {
          final url = widget.thumbnailUrl!;
          if (!_precachedThumbnails.contains(url)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              try {
                precacheImage(CachedNetworkImageProvider(url), context);
              } catch (_) {}
              _precachedThumbnails.add(url);
            });
          }
        }
        // After provider init we may have channel metadata in the provider
        // (for example when expanding the mini-player). If widget didn't
        // provide a channelId, use the provider value and register the
        // global subscription listener so _isSubscribed is correct.
        try {
          final videoState = ref.read(videoPlayerProvider);
          final cid = widget.channelId ?? videoState.channelId;
          if (cid != null) {
            final global = SubscriptionStateManager().getSubscriptionState(cid);
            if (mounted) {
              setState(() {
                _isSubscribed = global ?? false;
              });
            }
            SubscriptionStateManager().addListener(
              _onGlobalSubscriptionChanged,
            );
          }
        } catch (e) {
          debugPrint(
            '[VideoPlayerView] Error initializing subscription state: $e',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _theme = VideoPlayerTheme.defaultTheme();
          _updateSystemUI(_theme!);
        });
        // Even if theme extraction failed, ensure thumbnail is precached so
        // returning to this screen uses the cached provider (disk+memory).
        if (widget.thumbnailUrl != null) {
          final url = widget.thumbnailUrl!;
          if (!_precachedThumbnails.contains(url)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              try {
                precacheImage(CachedNetworkImageProvider(url), context);
              } catch (_) {}
              _precachedThumbnails.add(url);
            });
          }
        }
      }
    }
  }

  /// Handle provider thumbnail changes triggered from build-time detection.
  Future<void> _handleProviderThumbnailChanged(String newThumb) async {
    if (_isHandlingThumbnailChange) return;
    _isHandlingThumbnailChange = true;

    try {
      final theme = await VideoPlayerThemeService().generateThemeFromThumbnail(
        thumbnailUrl: newThumb,
        context: context,
      );

      if (!mounted) return;

      setState(() {
        _theme = theme;
        _updateSystemUI(theme);
      });

      if (!_precachedThumbnails.contains(newThumb)) {
        try {
          await precacheImage(CachedNetworkImageProvider(newThumb), context);
        } catch (_) {}
        _precachedThumbnails.add(newThumb);
      }
    } catch (e) {
      debugPrint('[VideoPlayerView] Error extracting theme for thumbnail: $e');
    } finally {
      _isHandlingThumbnailChange = false;
    }
  }

  Future<void> _fetchRelatedVideos() async {
    if (!mounted) return;

    final currentIdString =
        ref.read(videoPlayerProvider).currentVideoId ?? widget.videoId;
    final int? excludeId = int.tryParse(currentIdString);

    setState(() {
      _isRelatedLoading = true;
      _relatedError = null;
    });

    try {
      final fetched = await _relatedVideosService.fetchRandomVideos(
        limit: 10,
        excludeVideoId: excludeId,
      );

      if (!mounted) return;

      setState(() {
        _relatedVideos = fetched
            .map(
              (video) => video.syncWithGlobalState().syncLikeWithGlobalState(),
            )
            .toList(growable: false);
        _isRelatedLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _relatedError = e.toString();
        _isRelatedLoading = false;
      });
    }
  }

  Future<void> _playRelatedVideo(VideoItem item) async {
    // Avoid reloading the same video
    final currentId = ref.read(videoPlayerProvider).currentVideoId;
    if (currentId != null && currentId == item.id.toString()) {
      return;
    }

    final subscriptionManager = SubscriptionStateManager();
    final bool computedSubscription = item.channelId != null
        ? (subscriptionManager.getSubscriptionState(item.channelId!) ??
              item.subscribed ??
              false)
        : false;

    setState(() {
      _localTotalLikes = item.totalLikes;
      _isSubscribed = computedSubscription;
    });

    if (item.channelId != null && item.subscribed != null) {
      subscriptionManager.updateSubscriptionState(
        item.channelId!,
        item.subscribed!,
      );
    }

    if (item.like != null) {
      LikeDislikeStateManager().updateLikeState(item.id, item.like!);
    }

    if (item.report == 1) {
      ReportStateManager().markReported(item.id);
    } else {
      ReportStateManager().unmarkReported(item.id);
    }

    final videoNotifier = ref.read(videoPlayerProvider.notifier);
    await videoNotifier.initializeVideo(
      videoUrl: item.videoUrl,
      videoId: item.id.toString(),
      title: item.title,
      subtitle: item.channelName,
      thumbnailUrl: item.thumbnailUrl,
      channelId: item.channelId,
      channelAvatarUrl: item.channelImageUrl,
    );

    if (!mounted) return;

    unawaited(_fetchRelatedVideos());
  }

  Future<void> _launchLandscapePlayer() async {
    if (_rotationLaunched) {
      return;
    }

    _rotationLaunched = true;

    try {
      await LandscapeVideoLauncher.launch(
        context: context,
        videoUrl: widget.videoUrl,
        videoId: widget.videoId,
        title: widget.title,
        channelName: widget.subtitle,
        thumbnailUrl: widget.thumbnailUrl,
      );
    } finally {
      final cooldownExpiry = DateTime.now().add(
        const Duration(milliseconds: 700),
      );

      if (!mounted) {
        _rotationLaunched = false;
        _landscapeCooldownUntil = cooldownExpiry;
        return;
      }

      setState(() {
        _rotationLaunched = false;
        _landscapeCooldownUntil = cooldownExpiry;
      });

      unawaited(_enableVideoScreenOrientations());
    }
  }

  Future<void> _setPreferredOrientations(
    List<DeviceOrientation> orientations,
  ) async {
    try {
      await SystemChrome.setPreferredOrientations(orientations);
    } catch (_) {}
  }

  Future<void> _enableVideoScreenOrientations() async {
    await _setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    try {
      await OrientationHelper.setAll();
    } catch (_) {}
  }

  Future<void> _lockAppToPortrait() async {
    await _setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    try {
      await OrientationHelper.setPortrait();
    } catch (_) {}
  }

  void _updateSystemUI(VideoPlayerTheme theme) {
    final statusBarColor = theme.primaryColor;

    // Force light status bar icons/text for better visibility over the
    // extracted primary color. On iOS `statusBarBrightness` should be the
    // inverse of the icon brightness.
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    // Apply overlay after the current frame to reduce chances of being
    // immediately overridden by other widgets or route changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        SystemChrome.setSystemUIOverlayStyle(overlayStyle);
      } catch (_) {
        // Ignore any platform/version incompatibilities
      }
    });
  }

  Widget _buildScrollableContent({
    required BuildContext context,
    required dynamic videoState,
    required dynamic videoNotifier,
    required VideoPlayerTheme theme,
    required int? currentVideoIdInt,
  }) {
    return SafeArea(
      top: true,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => videoNotifier.toggleControls(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildStickyVideoHeader(context: context, theme: theme),
                  SliverToBoxAdapter(
                    child: _buildPostPlayerContent(
                      context: context,
                      videoState: videoState,
                      videoNotifier: videoNotifier,
                      theme: theme,
                      currentVideoIdInt: currentVideoIdInt,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverPersistentHeader _buildStickyVideoHeader({
    required BuildContext context,
    required VideoPlayerTheme theme,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final videoWidth = screenWidth;
    final videoHeight = videoWidth * (9 / 16);
    final headerHeight = videoHeight;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _VideoPlayerHeaderDelegate(
        minExtentHeight: headerHeight,
        maxExtentHeight: headerHeight,
        child: Container(
          color: theme.backgroundColor.withOpacity(0.94),
          // Only the header area (video visual area) should handle the
          // swipe-to-exit gesture. We wrap the visual area with a
          // GestureDetector that activates the drag only when the touch
          // starts within the top 30% of the screen.
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (details) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final allowedZone = screenHeight * 0.3; // top 30%
                  if (details.globalPosition.dy <= allowedZone) {
                    _headerDragActive = true;
                    _onVerticalDragStart(details);
                  } else {
                    _headerDragActive = false;
                  }
                },
                onVerticalDragUpdate: (details) {
                  if (!_headerDragActive) return;
                  _onVerticalDragUpdate(details);
                },
                onVerticalDragEnd: (details) {
                  if (!_headerDragActive) return;
                  _onVerticalDragEnd(details);
                },
                child: VideoVisualArea(
                  onFullscreen: () => unawaited(_launchLandscapePlayer()),
                  onMinimize: _minimizeToMiniPlayer,
                  theme: theme,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPostPlayerContent({
    required BuildContext context,
    required dynamic videoState,
    required dynamic videoNotifier,
    required VideoPlayerTheme theme,
    required int? currentVideoIdInt,
  }) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(2.w, 12.h, 2.w, bottomPadding + 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2.h),
          VideoControlPanel(
            textColor: theme.textColor,
            accentColor: theme.primaryColor,
            showTrackInfo: false,
            showSeekBar: false,
          ),
          SizedBox(height: 12.h),
          VideoTitleChannelRow(
            title: videoState.currentVideoTitle ?? widget.title ?? '',
            channelName:
                videoState.currentVideoSubtitle ?? widget.subtitle ?? '',
            // Prefer provider value so avatar updates when provider changes
            avatarUrl: videoState.channelAvatarUrl ?? widget.channelAvatarUrl,
            subscriberCount: widget.channelSubscriberCount,
            isSubscribed: _isSubscribed,
            isSubscriptionInProgress: _isSubscriptionInProgress,
            onSubscribePressed: _toggleSubscription,
            onMorePressed: () {
              // compute sheet height so the sheet's top aligns with the
              // bottom of the video visual area (9:16 aspect)
              final screenWidth = MediaQuery.of(context).size.width;
              final videoHeaderHeight = screenWidth * (9 / 16);
              final topPadding = MediaQuery.of(context).padding.top;
              final desiredHeight =
                  MediaQuery.of(context).size.height -
                  (videoHeaderHeight + topPadding);

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: true,
                backgroundColor: Colors.transparent,
                barrierColor: Colors.transparent,
                builder: (sheetContext) => VideoMoreSheet(
                  theme: theme,
                  videoIdString: videoState.currentVideoId ?? widget.videoId,
                  videoIdInt: currentVideoIdInt,
                  videoTitle:
                      videoState.currentVideoTitle ?? widget.title ?? '',
                  // pass the originating VideoItem (may be null) so the sheet
                  // can render description, views, createdAt etc.
                  videoItem: widget.videoItem,
                  // pass explicit channel id so the sheet can listen/update
                  // even when widget.videoItem is null (e.g. after minimize)
                  channelId: widget.channelId ?? videoState.channelId,
                  parentContext: context,
                  sheetHeight: desiredHeight.clamp(
                    120.0,
                    MediaQuery.of(context).size.height,
                  ),
                  onReport: currentVideoIdInt != null
                      ? () => _handleReportPressed(
                          currentVideoIdInt,
                          videoState.currentVideoTitle ?? widget.title ?? '',
                        )
                      : null,
                  // subscription state + handler
                  isSubscribed: _isSubscribed,
                  isSubscriptionInProgress: _isSubscriptionInProgress,
                  onSubscribePressed: _toggleSubscription,
                  // channel footer handlers/data
                  onChannelTap: () {
                    final cid = widget.channelId ?? videoState.channelId;
                    if (cid != null) {
                      _minimizeAndNavigateTo(
                        ChannelVideosScreen(
                          channelId: cid,
                          channelName:
                              videoState.currentVideoSubtitle ??
                              widget.subtitle,
                        ),
                      );
                    }
                  },
                  localTotalLikes: _localTotalLikes,
                  channelSubscriberCount: widget.channelSubscriberCount,
                  // Prefer provider avatar when available so the modal shows
                  // the up-to-date channel avatar after a video change.
                  channelAvatarUrl:
                      videoState.channelAvatarUrl ?? widget.channelAvatarUrl,
                  channelName:
                      videoState.currentVideoSubtitle ?? widget.subtitle,
                ),
              );
            },
            showSubscribe: !(widget.isOwn ?? false),
            onChannelTap: () {
              final cid = widget.channelId ?? videoState.channelId;
              if (cid != null) {
                _minimizeAndNavigateTo(
                  ChannelVideosScreen(
                    channelId: cid,
                    channelName:
                        videoState.currentVideoSubtitle ?? widget.subtitle,
                  ),
                );
              }
            },
            theme: theme,
          ),
          SizedBox(height: 2.h),
          if (currentVideoIdInt != null)
            Builder(
              builder: (context) {
                final likeState =
                    LikeDislikeStateManager().getLikeState(currentVideoIdInt) ??
                    0;
                final isReported = ReportStateManager().isReported(
                  currentVideoIdInt,
                );

                return Row(
                  children: [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 6.w)),
                    AnimatedLikeDislikeButtons(
                      likeState: likeState,
                      onLike: () => _handleLikePressed(currentVideoIdInt),
                      onDislike: () => _handleDislikePressed(currentVideoIdInt),
                      totalLikes:
                          _localTotalLikes ?? widget.videoItem?.totalLikes,
                      onReport: isReported
                          ? null
                          : () => _handleReportPressed(
                              currentVideoIdInt,
                              videoState.currentVideoTitle ??
                                  widget.title ??
                                  '',
                            ),
                      showReportButton: !isReported,
                    ),
                    SizedBox(width: 12.w),
                    if (isReported)
                      Text(
                        'Reported',
                        style: TextStyle(
                          color: theme.textColor.withOpacity(0.8),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                );
              },
            ),
          SizedBox(height: 24.h),
          _buildRelatedVideosSection(theme),
        ],
      ),
    );
  }

  Widget _buildRelatedVideosSection(VideoPlayerTheme theme) {
    final textColor = theme.textColor;

    List<Widget> buildSkeletons() {
      return List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(
            left: 6.w,
            right: 6.w,
            bottom: index == 2 ? 0 : 16.h,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.w),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  // subtle glass gradient
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.06),
                      Colors.white.withOpacity(0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12.w),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8.0,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // small transparent round accent in top-left
                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                    // the skeleton itself (no inner padding)
                    VideoCardGlassSkeleton(),
                  ],
                ),
              ),
            ),
          ),
        );
      });
    }

    List<Widget> buildVideoCards() {
      return _relatedVideos.map((video) {
        final synced = video.syncWithGlobalState().syncLikeWithGlobalState();
        final blockedReason =
            (synced.block == 1 && (synced.reason?.isNotEmpty ?? false))
            ? synced.reason
            : null;

        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.w),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12.w),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8.0,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // transparent round accent
                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                    // the actual video card (no inner padding)
                    VideoCardInside(
                      item: synced,
                      onTap: () => _playRelatedVideo(synced),
                      showPopupMenu: true,
                      blockedReason: blockedReason,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList();
    }

    Widget buildError() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load related videos right now.',
            style: TextStyle(
              color: textColor.withOpacity(0.72),
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 12.h),
          OutlinedButton.icon(
            onPressed: _fetchRelatedVideos,
            icon: Icon(
              Icons.refresh_rounded,
              size: 18.w,
              color: theme.primaryColor,
            ),
            label: Text(
              'Try again',
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.primaryColor.withOpacity(0.5)),
              foregroundColor: theme.primaryColor,
            ),
          ),
        ],
      );
    }

    Widget buildEmptyState() {
      return Text(
        'No related videos available at the moment.',
        style: TextStyle(color: textColor.withOpacity(0.72), fontSize: 14.sp),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related Videos',
            style: TextStyle(
              color: textColor,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          if (_isRelatedLoading)
            ...buildSkeletons()
          else if (_relatedError != null)
            buildError()
          else if (_relatedVideos.isEmpty)
            buildEmptyState()
          else
            ...buildVideoCards(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('[VideoPlayerView] dispose() called');

    // Dispose drag animation controller
    _dragAnimationController.dispose();
    // Dispose snap-back controller
    try {
      _snapBackController.dispose();
    } catch (_) {}

    // Restore previous overlay style
    // Restore a safe default: white background with dark icons.
    // Some Flutter versions don't expose the currently-active overlay style,
    // so we proactively set a normal (white) status bar here to ensure the
    // app returns to the expected look when leaving the full-screen player.
    try {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          // On iOS the `statusBarBrightness` should be the inverse of the
          // icon brightness.
          statusBarBrightness: Brightness.light,
        ),
      );
    } catch (_) {
      // Ignore any platform/version incompatibilities
    }

    // Restore global UI (navigation & mini player)
    MusicPlayerStateManager().hideFullPlayer();

    unawaited(_lockAppToPortrait());

    // Remove subscription listener (ok to call even if not previously added)
    try {
      SubscriptionStateManager().removeListener(_onGlobalSubscriptionChanged);
    } catch (_) {}

    debugPrint('[VideoPlayerView] dispose() complete');

    // Note: Video controller disposal is handled by the VideoPlayerStateNotifier
    // We don't dispose it here to avoid "ref after unmount" errors
    // When minimizing, the controller is reused by the mini player
    // When closing without minimizing, the provider will handle cleanup when appropriate

    super.dispose();
  }

  Future<bool> _handleWillPop() async {
    if (_isProgrammaticPop) {
      return true;
    }

    if (!mounted) {
      return true;
    }

    final videoState = ref.read(videoPlayerProvider);

    if (_isMinimizeInProgress || videoState.isMinimized) {
      return true;
    }

    // If there is no active controller yet (loading/error), allow the pop so
    // the user can exit cleanly.
    if (videoState.controller == null) {
      return true;
    }

    _minimizeToMiniPlayer();
    return false;
  }

  // Back handling removed: top-bar back button was moved into the visual
  // area so this helper is no longer required.

  /// Handle vertical drag start
  void _onVerticalDragStart(DragStartDetails details) {
    // Legacy: keep for programmatic/other usages. Only reset when header drag
    // is active - otherwise ignore vertical drags started outside header.
    if (!_headerDragActive) return;
    _dragDistance = 0.0;
  }

  /// Handle vertical drag update
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_headerDragActive) return;
    setState(() {
      _dragDistance += details.delta.dy;
      // Clamp to prevent upward drag
      if (_dragDistance < 0) _dragDistance = 0;
    });
  }

  /// Handle vertical drag end
  void _onVerticalDragEnd(DragEndDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (!_headerDragActive) return;

    final headerZoneHeight = screenHeight * 0.3; // top 30% is the active zone
    final dragPercentage = _dragDistance / headerZoneHeight;

    // Threshold: require 40% of the header zone or a fast downward fling.
    const headerDismissThreshold = 0.4;
    if (dragPercentage > headerDismissThreshold ||
        details.velocity.pixelsPerSecond.dy > 800) {
      _minimizeToMiniPlayer();
    } else {
      // Animate snap-back for smooth UX
      _snapStartDistance = _dragDistance;
      try {
        _snapBackController.forward(from: 0.0);
      } catch (_) {
        setState(() {
          _dragDistance = 0.0;
        });
      }
    }

    _headerDragActive = false;
  }

  /// Minimize to mini player with animation
  void _minimizeToMiniPlayer() async {
    debugPrint('[VideoPlayerView] _minimizeToMiniPlayer called');

    if (_isMinimizeInProgress || _isProgrammaticPop) {
      debugPrint('[VideoPlayerView] Minimize request ignored (in progress)');
      return;
    }

    _isMinimizeInProgress = true;
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    // Set minimized state first
    videoNotifier.minimizeToMiniPlayer();

    debugPrint(
      '[VideoPlayerView] State after minimizeToMiniPlayer: ${ref.read(videoPlayerProvider).isMinimized}, ${ref.read(videoPlayerProvider).showMiniPlayer}',
    );

    // Animate out
    try {
      await _dragAnimationController.forward(from: 0.0);
    } catch (_) {
      // Controller may be disposed during rapid pops; ignore.
    }

    debugPrint('[VideoPlayerView] Animation complete, about to pop');

    // Pop the route after animation
    if (mounted) {
      _isProgrammaticPop = true;
      Navigator.of(context).pop();
      debugPrint('[VideoPlayerView] Navigator.pop() called');
    }
  }

  /// Minimize to mini player with animation, then navigate to [destination].
  ///
  /// This coordinates the same visual minimize animation used by
  /// `_minimizeToMiniPlayer` but, instead of popping the route, it replaces
  /// the current full-screen player with the provided destination route so
  /// the mini player and the app's main navigation remain visible beneath
  /// the new screen.
  Future<void> _minimizeAndNavigateTo(Widget destination) async {
    debugPrint('[VideoPlayerView] _minimizeAndNavigateTo called');

    if (_isMinimizeInProgress || _isProgrammaticPop) {
      debugPrint('[VideoPlayerView] Minimize request ignored (in progress)');
      return;
    }

    _isMinimizeInProgress = true;
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    // Set minimized state first so underlying UI (mini player) becomes
    // available while we animate the full-screen route out.
    videoNotifier.minimizeToMiniPlayer();

    // Animate out the full-screen player visually
    try {
      await _dragAnimationController.forward(from: 0.0);
    } catch (_) {
      // Controller may be disposed during rapid transitions; ignore.
    }

    debugPrint('[VideoPlayerView] Animation complete, about to replace route');

    if (!mounted) return;

    // Mark programmatic navigation so any willPop handlers know this is
    // intentional and avoid trying to minimize again.
    _isProgrammaticPop = true;

    // Pop this full-screen route first so the underlying app UI becomes
    // visible (mini player/main nav). Wait for the pop to complete.
    await Navigator.of(context).maybePop();
    await Future.delayed(const Duration(milliseconds: 50));

    // Try to push into the current tab's nested navigator so the new screen
    // is shown inside the MainNavigation shell (keeping bottom nav & mini
    // player visible). Fall back to the root navigator if the tab service
    // isn't initialized.
    try {
      final pushed = TabNavigationService().pushOnCurrentTab(
        MaterialPageRoute(builder: (_) => destination),
      );

      if (pushed == null) {
        // Fallback to pushing on root navigator
        final rootNav = Navigator.of(context, rootNavigator: true);
        await rootNav.push(MaterialPageRoute(builder: (_) => destination));
      }

      debugPrint('[VideoPlayerView] Navigation complete (tab or root)');
    } catch (e) {
      debugPrint('[VideoPlayerView] Navigation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoPlayerProvider);
    final videoNotifier = ref.read(videoPlayerProvider.notifier);
    final theme = _theme ?? VideoPlayerTheme.defaultTheme();

    // Apply status bar style using extracted primary color
    final statusBarColor = theme.primaryColor;

    // Use light status bar icons/text for consistent visibility over the
    // extracted control color.
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    // Prefer provider thumbnail (updates when provider changes). Fall back to
    // the initially-passed widget.thumbnailUrl when provider hasn't set one.
    final thumbnail = videoState.thumbnailUrl ?? widget.thumbnailUrl;

    // Detect provider-driven thumbnail changes and handle them asynchronously
    // after the current frame so we don't call setState during build.
    if (thumbnail != _lastSeenProviderThumbnail) {
      _lastSeenProviderThumbnail = thumbnail;
      if (thumbnail != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_handleProviderThumbnailChanged(thumbnail));
        });
      } else {
        // Thumbnail was removed; ensure we reset to the default theme.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _theme = VideoPlayerTheme.defaultTheme();
            _updateSystemUI(_theme!);
          });
        });
      }
    }

    Widget content;

    // Try to convert the current video id (provider may expose it as String)
    final currentVideoIdString = videoState.currentVideoId ?? widget.videoId;
    final int? currentVideoIdInt = int.tryParse(currentVideoIdString);

    final now = DateTime.now();
    final cooldownActive =
        _landscapeCooldownUntil != null &&
        now.isBefore(_landscapeCooldownUntil!);

    // Auto-launch landscape player when device orientation becomes landscape.
    final currentOrientation = MediaQuery.of(context).orientation;
    if (_lastOrientation != currentOrientation) {
      final isLandscape = currentOrientation == Orientation.landscape;

      if (isLandscape && !cooldownActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _launchLandscapePlayer();
        });
      } else if (!isLandscape) {
        _rotationLaunched = false;
      }

      _lastOrientation = currentOrientation;
    }

    if (thumbnail != null) {
      content = AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: GestureDetector(
          child: AnimatedBuilder(
            animation: _dragAnimation,
            builder: (context, child) {
              final screenHeight = MediaQuery.of(context).size.height;
              // Combine the user drag offset with any in-flight minimize
              // animation (mapped from _dragAnimation which runs 0->1).
              final animOffset = _dragAnimation.value.dy * screenHeight;
              final effectiveOffset = _dragDistance + animOffset;
              final opacity =
                  1.0 - (effectiveOffset / screenHeight).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(0, effectiveOffset),
                child: Opacity(opacity: opacity, child: child),
              );
            },
            child: Scaffold(
              backgroundColor: theme.backgroundColor,
              body: Stack(
                children: [
                  if (MediaQuery.of(context).padding.top > 0)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: MediaQuery.of(context).padding.top,
                      child: Container(color: statusBarColor),
                    ),
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: thumbnail,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (c, url) =>
                          Container(color: theme.backgroundColor),
                      errorWidget: (c, url, error) =>
                          Container(color: theme.backgroundColor),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                      child: Container(
                        color: theme.backgroundColor.withOpacity(0.4),
                      ),
                    ),
                  ),
                  _buildScrollableContent(
                    context: context,
                    videoState: videoState,
                    videoNotifier: videoNotifier,
                    theme: theme,
                    currentVideoIdInt: currentVideoIdInt,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // Fallback when no thumbnail available
      content = AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: GestureDetector(
          child: AnimatedBuilder(
            animation: _dragAnimation,
            builder: (context, child) {
              final screenHeight = MediaQuery.of(context).size.height;
              final opacity =
                  1.0 - (_dragDistance / screenHeight).clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(0, _dragDistance),
                child: Opacity(opacity: opacity, child: child),
              );
            },
            child: Scaffold(
              backgroundColor: theme.backgroundColor,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(gradient: theme.gradient),
                    ),
                  ),
                  if (MediaQuery.of(context).padding.top > 0)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: MediaQuery.of(context).padding.top,
                      child: Container(color: statusBarColor),
                    ),
                  _buildScrollableContent(
                    context: context,
                    videoState: videoState,
                    videoNotifier: videoNotifier,
                    theme: theme,
                    currentVideoIdInt: currentVideoIdInt,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return WillPopScope(onWillPop: _handleWillPop, child: content);
  }

  // Top bar removed: controls (back/minimize) moved into the visual area.

  /// Handle global subscription state changes
  void _onGlobalSubscriptionChanged() {
    if (!mounted) return;
    final cid = widget.channelId ?? ref.read(videoPlayerProvider).channelId;
    if (cid == null) return;
    final global = SubscriptionStateManager().getSubscriptionState(cid);
    if (global != null && global != _isSubscribed) {
      setState(() => _isSubscribed = global);
    }
  }

  /// Optimistic like handler
  Future<void> _handleLikePressed(int videoId) async {
    final manager = LikeDislikeStateManager();
    final previous = manager.getLikeState(videoId) ?? 0;
    final newState = previous == 1 ? 0 : 1;

    // Determine a reasonable base like count from the originating VideoItem
    // or previously stored local count.
    final base = widget.videoItem?.totalLikes ?? _localTotalLikes ?? 0;
    int updatedLikes = base;

    if (previous == 1 && newState != 1) {
      updatedLikes = base - 1;
      if (updatedLikes < 0) updatedLikes = 0;
    } else if (previous != 1 && newState == 1) {
      updatedLikes = base + 1;
    }

    // Optimistically update global state and local UI count so lists/screens
    // update immediately.
    manager.updateLikeState(videoId, newState);
    if (mounted) {
      setState(() {
        _localTotalLikes = updatedLikes;
      });
    }

    try {
      final success = await _likeDislikeService.likeVideo(
        videoId: videoId,
        currentState: previous,
      );

      if (!success) {
        // rollback both global state and local UI count
        manager.updateLikeState(videoId, previous);
        if (mounted) {
          setState(() {
            _localTotalLikes = base;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update like.')),
          );
        }
      }
    } catch (e) {
      // rollback
      manager.updateLikeState(videoId, previous);
      if (mounted) {
        setState(() {
          _localTotalLikes = base;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update like.')));
      }
    }
  }

  /// Optimistic dislike handler
  Future<void> _handleDislikePressed(int videoId) async {
    final manager = LikeDislikeStateManager();
    final previous = manager.getLikeState(videoId) ?? 0;
    final newState = previous == 2 ? 0 : 2;

    final base = widget.videoItem?.totalLikes ?? _localTotalLikes ?? 0;
    int updatedLikes = base;

    // If we're moving away from a liked state, decrement the like count.
    if (previous == 1 && newState != 1) {
      updatedLikes = base - 1;
      if (updatedLikes < 0) updatedLikes = 0;
    }

    // Optimistically update
    manager.updateLikeState(videoId, newState);
    if (mounted) {
      setState(() {
        _localTotalLikes = updatedLikes;
      });
    }

    try {
      final success = await _likeDislikeService.dislikeVideo(
        videoId: videoId,
        currentState: previous,
      );

      if (!success) {
        // rollback
        manager.updateLikeState(videoId, previous);
        if (mounted) {
          setState(() {
            _localTotalLikes = base;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update dislike.')),
          );
        }
      }
    } catch (e) {
      manager.updateLikeState(videoId, previous);
      if (mounted) {
        setState(() {
          _localTotalLikes = base;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update dislike.')),
        );
      }
    }
  }

  /// Show report modal and mark reported on success
  void _handleReportPressed(int videoId, String videoTitle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
            child: Material(
              color: Colors.white,
              child: VideoReportModal(
                videoId: videoId,
                videoTitle: videoTitle,
                onReported: () {
                  // Mark reported in global state so lists update
                  try {
                    ReportStateManager().markReported(videoId);
                  } catch (_) {}

                  // Also ensure local UI updates
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSubscription() async {
    final cid = widget.channelId ?? ref.read(videoPlayerProvider).channelId;
    if (cid == null) return;
    if (_isSubscriptionInProgress) return;

    final previous = _isSubscribed;
    setState(() {
      _isSubscribed = !_isSubscribed;
      _isSubscriptionInProgress = true;
    });

    try {
      final success = previous
          ? await _subscriptionService.unsubscribeChannel(channelId: cid)
          : await _subscriptionService.subscribeChannel(channelId: cid);

      if (!success && mounted) {
        // revert optimistic change
        setState(() {
          _isSubscribed = previous;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update subscription')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubscribed = previous;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update subscription')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubscriptionInProgress = false;
        });
      }
    }
  }

  // Title+channel UI extracted to VideoTitleChannelRow widget.

  // More/options menu removed — three-dot UI and its modal are no longer used

  // Helper for building options removed with the three-dot menu.

  // Video info dialog removed — unused after removing options menu.

  // Removed video info helpers: info modal was removed along with the
  // three-dot options menu.
}

class _VideoPlayerHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _VideoPlayerHeaderDelegate({
    required this.child,
    required this.minExtentHeight,
    required this.maxExtentHeight,
  });

  final Widget child;
  final double minExtentHeight;
  final double maxExtentHeight;

  @override
  double get minExtent => minExtentHeight;

  @override
  double get maxExtent => maxExtentHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _VideoPlayerHeaderDelegate oldDelegate) {
    return minExtentHeight != oldDelegate.minExtentHeight ||
        maxExtentHeight != oldDelegate.maxExtentHeight ||
        oldDelegate.child != child;
  }
}
