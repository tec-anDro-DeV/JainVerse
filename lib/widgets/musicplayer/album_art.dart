import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/widgets/common/smart_image_widget.dart';

/// Modern album art widget with enhanced image loading, error handling, and zoom animation
class ModernAlbumArt extends StatefulWidget {
  final MediaItem? mediaItem;
  final double? width;
  final double? height;
  final double borderRadius;
  final AudioPlayerHandler? audioHandler;
  final bool enableScaleAnimation; // Option to disable scaling animation

  const ModernAlbumArt({
    super.key,
    this.mediaItem,
    this.width,
    this.height,
    this.borderRadius = 20,
    this.audioHandler,
    this.enableScaleAnimation =
        true, // Default to enabled for backward compatibility
  });

  @override
  State<ModernAlbumArt> createState() => _ModernAlbumArtState();
}

class _ModernAlbumArtState extends State<ModernAlbumArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Define scale animation with much smaller range to prevent blurring
    _scaleAnimation = Tween<double>(
      begin: 1.1, // Paused state (normal size)
      end:
          1.45, // Playing state (slightly larger, minimal scaling to prevent blur)
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final screenHeight = mq.size.height;
    final shortestSide = mq.size.shortestSide;

    // Treat devices with shortestSide >= 600 as tablets (common heuristic).
    final bool isTablet = shortestSide >= 600;

    // Compute album art size with tablet-aware caps so iPads don't show an
    // overly large artwork. Respect explicit width/height if provided.
    double albumArtSize;
    if (widget.width != null) {
      albumArtSize = widget.width!;
    } else if (widget.height != null) {
      albumArtSize = widget.height!;
    } else {
      if (!isTablet) {
        // Phone: keep existing behavior
        albumArtSize = screenWidth * 0.6;
      } else {
        // Tablet: prefer a smaller proportion and clamp to a max size
        final double tabletPreferred =
            mq.orientation == Orientation.landscape
                ? screenHeight * 0.6
                : screenWidth * 0.45;
        // Clamp to a reasonable range so artwork isn't massive on large tablets
        albumArtSize = tabletPreferred.clamp(200.0, 540.0);
      }
    }

    // If scaling animation is disabled, return static image
    if (!widget.enableScaleAnimation) {
      return Center(child: _buildImageContent(albumArtSize));
    }

    // Listen to playback state if audioHandler is available
    if (widget.audioHandler != null) {
      return StreamBuilder<PlaybackState>(
        stream: widget.audioHandler!.playbackState,
        builder: (context, snapshot) {
          final playbackState = snapshot.data;
          final isPlaying = playbackState?.playing ?? false;

          // Animate based on playing state
          if (isPlaying) {
            _animationController.forward();
          } else {
            _animationController.reverse();
          }

          return Center(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  filterQuality: FilterQuality.high, // High quality scaling
                  child: _buildImageContent(albumArtSize),
                );
              },
            ),
          );
        },
      );
    }

    // Fallback without animation if no audioHandler
    return Center(child: _buildImageContent(albumArtSize));
  }

  Widget _buildImageContent(double size) {
    final imageUrl = widget.mediaItem?.artUri?.toString();

    // Calculate higher resolution cache size to prevent blurring during scaling
    // We multiply by 2 to account for scaling and high-DPI screens
    final cacheSize = (size * 2).toInt();

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius.w),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius.w),
          child:
              imageUrl != null && imageUrl.isNotEmpty
                  ? SmartImageWidget(
                    imageUrl: imageUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    placeholder: _buildLoadingPlaceholder(size),
                    errorWidget: _buildErrorPlaceholder(size),
                    memCacheWidth: cacheSize, // Higher resolution cache
                    memCacheHeight: cacheSize, // Higher resolution cache
                    filterQuality:
                        FilterQuality.high, // Highest quality filtering
                  )
                  : _buildErrorPlaceholder(size),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(widget.borderRadius.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: size * 0.3,
            color: Colors.white.withOpacity(0.3),
          ),
          Positioned(
            bottom: size * 0.2,
            child: SizedBox(
              width: size * 0.15,
              height: size * 0.15,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(widget.borderRadius.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: size * 0.25,
            color: Colors.white.withOpacity(0.6),
          ),
          SizedBox(height: size * 0.05),
          Icon(
            Icons.refresh,
            size: size * 0.12,
            color: Colors.white.withOpacity(0.4),
          ),
        ],
      ),
    );
  }
}
