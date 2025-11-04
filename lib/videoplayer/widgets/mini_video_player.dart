import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../managers/video_player_state_provider.dart';
import '../screens/video_player_view.dart';

/// Configuration constants for the mini video player
class _MiniVideoPlayerConfig {
  static const String placeholderImage = 'assets/images/placeholder.png';
  static const Color backgroundColor = Colors.white;
  static const Duration animationDuration = Duration(milliseconds: 400);

  // Size constants
  static double get height => 90.w;
  static double get borderRadius => 12.w;
  static double get marginHorizontal => 18.w;
  static double get paddingHorizontal => 15.w;
  static double get paddingVertical => 10.w;
  static double get spacing => 10.w;
  static double get thumbnailSize => 70.w;
  static double get thumbnailRadius => 16.w;
  static double get playButtonSize => 56.w;
  static double get playIconSize => 36.w;
  static double get progressBarHeight => 5.w;
}

/// Mini video player widget that appears at the bottom of the screen
/// Shows video thumbnail (not live video) with controls
/// Similar to mini music player but optimized for video
class MiniVideoPlayer extends ConsumerStatefulWidget {
  const MiniVideoPlayer({super.key});

  @override
  ConsumerState<MiniVideoPlayer> createState() => _MiniVideoPlayerState();
}

class _MiniVideoPlayerState extends ConsumerState<MiniVideoPlayer>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _slideAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // State tracking
  bool _isVisible = false;
  bool _hasVideo = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Slide animation controller
    _slideAnimationController = AnimationController(
      duration: _MiniVideoPlayerConfig.animationDuration,
      vsync: this,
    );

    // Fade animation controller
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Slide animation (from bottom to top)
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0.0, 1.0), // Start from bottom (off-screen)
          end: Offset.zero, // End at normal position
        ).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeOut),
    );
  }

  void _showMiniPlayer() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });

      // Stagger the animations
      _slideAnimationController.forward();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _fadeAnimationController.forward();
        }
      });

      // Add haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  void _hideMiniPlayer() {
    if (_isVisible) {
      _fadeAnimationController.reverse();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _slideAnimationController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isVisible = false;
              });
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoPlayerProvider);
    final shouldShow = videoState.currentVideoId != null;

    // Update visibility based on video state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldShow && !_hasVideo) {
        _showMiniPlayer();
      } else if (!shouldShow && _hasVideo) {
        _hideMiniPlayer();
      }
      _hasVideo = shouldShow;
    });

    // Don't render if not visible
    if (!_isVisible && !shouldShow) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildMiniPlayerContent(context, videoState),
      ),
    );
  }

  Widget _buildMiniPlayerContent(BuildContext context, videoState) {
    final videoNotifier = ref.read(videoPlayerProvider.notifier);

    return GestureDetector(
      onTap: () => _openFullPlayer(context),
      child: Container(
        height: _MiniVideoPlayerConfig.height,
        margin: EdgeInsets.only(
          left: _MiniVideoPlayerConfig.marginHorizontal,
          right: _MiniVideoPlayerConfig.marginHorizontal,
          bottom: 8.h,
        ),
        decoration: BoxDecoration(
          color: _MiniVideoPlayerConfig.backgroundColor,
          borderRadius: BorderRadius.circular(
            _MiniVideoPlayerConfig.borderRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10.0,
              offset: const Offset(0, 4.0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            _MiniVideoPlayerConfig.borderRadius,
          ),
          child: Stack(
            children: [
              // Progress bar at the top
              _buildProgressBar(videoState),

              // Main content
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _MiniVideoPlayerConfig.paddingHorizontal,
                  vertical: _MiniVideoPlayerConfig.paddingVertical,
                ),
                child: Row(
                  children: [
                    // Video thumbnail
                    _buildThumbnail(videoState),

                    SizedBox(width: _MiniVideoPlayerConfig.spacing),

                    // Video info
                    Expanded(child: _buildVideoInfo(videoState)),

                    SizedBox(width: _MiniVideoPlayerConfig.spacing),

                    // Play/Pause button
                    _buildPlayPauseButton(videoState, videoNotifier),

                    SizedBox(width: 8.w),

                    // Close button
                    _buildCloseButton(videoNotifier),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(videoState) {
    final progress = videoState.duration.inMilliseconds > 0
        ? videoState.position.inMilliseconds /
              videoState.duration.inMilliseconds
        : 0.0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: _MiniVideoPlayerConfig.progressBarHeight,
        color: Colors.grey[300],
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }

  Widget _buildThumbnail(videoState) {
    return Container(
      width: _MiniVideoPlayerConfig.thumbnailSize,
      height: _MiniVideoPlayerConfig.thumbnailSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          _MiniVideoPlayerConfig.thumbnailRadius,
        ),
        color: Colors.grey[900],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          _MiniVideoPlayerConfig.thumbnailRadius,
        ),
        child: videoState.thumbnailUrl != null
            ? CachedNetworkImage(
                imageUrl: videoState.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      color: Colors.white54,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    _buildPlaceholderThumbnail(),
              )
            : _buildPlaceholderThumbnail(),
      ),
    );
  }

  Widget _buildPlaceholderThumbnail() {
    return Container(
      color: Colors.grey[800],
      child: Icon(Icons.videocam_rounded, size: 32.w, color: Colors.white54),
    );
  }

  Widget _buildVideoInfo(videoState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          videoState.currentVideoTitle ?? 'Unknown Video',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 4.h),
        Text(
          videoState.currentVideoSubtitle ?? '',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: Colors.black54,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton(videoState, videoNotifier) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        videoNotifier.togglePlayPause();
      },
      child: Container(
        width: _MiniVideoPlayerConfig.playButtonSize,
        height: _MiniVideoPlayerConfig.playButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).primaryColor,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              blurRadius: 8.w,
              offset: Offset(0, 2.w),
            ),
          ],
        ),
        child: videoState.isLoading
            ? Padding(
                padding: EdgeInsets.all(16.w),
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                videoState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: _MiniVideoPlayerConfig.playIconSize,
                color: Colors.white,
              ),
      ),
    );
  }

  Widget _buildCloseButton(videoNotifier) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        videoNotifier.disposeVideo();
      },
      child: Container(
        width: 32.w,
        height: 32.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
        ),
        child: Icon(Icons.close_rounded, size: 20.w, color: Colors.black54),
      ),
    );
  }

  void _openFullPlayer(BuildContext context) {
    final videoState = ref.read(videoPlayerProvider);

    if (videoState.currentVideoId == null) return;

    HapticFeedback.lightImpact();

    // Navigate to full video player
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerView(
          videoUrl: '', // Will use existing controller
          videoId: videoState.currentVideoId!,
          title: videoState.currentVideoTitle,
          subtitle: videoState.currentVideoSubtitle,
          thumbnailUrl: videoState.thumbnailUrl,
          playlist: videoState.playlist,
          playlistIndex: videoState.currentIndex,
        ),
      ),
    );
  }
}
