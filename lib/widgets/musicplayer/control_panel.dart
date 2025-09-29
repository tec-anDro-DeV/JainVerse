import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/enhanced_audio_visualizer.dart';
import 'package:jainverse/widgets/musicplayer/integrated_lyrics_overlay.dart';
import 'package:jainverse/widgets/musicplayer/playback_controls.dart';
import 'package:jainverse/widgets/musicplayer/seek_bar.dart';
import 'package:jainverse/widgets/musicplayer/track_info.dart';
import 'package:jainverse/widgets/musicplayer/volume_slider_widget.dart';

/// Modern control panel widget containing track info, seek bar, and playback controls
class ModernControlPanel extends StatefulWidget {
  final MediaItem? mediaItem;
  final AudioPlayerHandler audioHandler;
  final ColorScheme? colorScheme;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onCreateStation;
  final VoidCallback? onShuffle;
  final VoidCallback? onQueue;
  final VoidCallback? onAutoPlay; // New auto play callback
  final bool isQueueVisible;
  final Function(int)? onSongSelected;
  final VoidCallback? onLyrics;
  final bool isLyricsVisible;
  final VoidCallback? onRepeat;

  const ModernControlPanel({
    super.key,
    this.mediaItem,
    required this.audioHandler,
    this.colorScheme,
    this.onFavoriteToggle,
    this.onShare,
    this.onDownload,
    this.onAddToPlaylist,
    this.onPlayNext,
    this.onAddToQueue,
    this.onCreateStation,
    this.onShuffle,
    this.onQueue,
    this.onAutoPlay, // Add auto play parameter
    this.isQueueVisible = false,
    this.onSongSelected,
    this.onLyrics,
    this.isLyricsVisible = false,
    this.onRepeat,
  });

  @override
  State<ModernControlPanel> createState() => _ModernControlPanelState();
}

class _ModernControlPanelState extends State<ModernControlPanel>
    with TickerProviderStateMixin {
  // Add animation controller for queue section
  late AnimationController _queueAnimationController;
  late Animation<double> _queueHeightAnimation;

  // Add animation controller for lyrics section
  late AnimationController _lyricsAnimationController;
  late Animation<double> _lyricsHeightAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _queueAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize lyrics animation controller
    _lyricsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Define the height animation for queue section
    _queueHeightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0, // Will be multiplied by actual height
    ).animate(
      CurvedAnimation(
        parent: _queueAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Define the height animation for lyrics section
    _lyricsHeightAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0, // Will be multiplied by actual height
    ).animate(
      CurvedAnimation(
        parent: _lyricsAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animation if queue is already visible (with mutual exclusivity)
    if (widget.isQueueVisible) {
      _queueAnimationController.value = 1.0;
      // Ensure lyrics is closed if queue is open
      _lyricsAnimationController.value = 0.0;
    }

    // Start animation if lyrics is already visible (with mutual exclusivity)
    if (widget.isLyricsVisible) {
      _lyricsAnimationController.value = 1.0;
      // Ensure queue is closed if lyrics is open
      _queueAnimationController.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(ModernControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Ensure mutual exclusivity between queue and lyrics
    // If queue is being opened, close lyrics
    if (widget.isQueueVisible != oldWidget.isQueueVisible) {
      if (widget.isQueueVisible) {
        // Close lyrics if it's open when queue is being opened
        if (widget.isLyricsVisible) {
          _lyricsAnimationController.reverse();
        }
        _queueAnimationController.forward();
      } else {
        _queueAnimationController.reverse();
      }
    }

    // If lyrics is being opened, close queue
    if (widget.isLyricsVisible != oldWidget.isLyricsVisible) {
      if (widget.isLyricsVisible) {
        // Close queue if it's open when lyrics is being opened
        if (widget.isQueueVisible) {
          _queueAnimationController.reverse();
        }
        _lyricsAnimationController.forward();
      } else {
        _lyricsAnimationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _queueAnimationController.dispose();
    _lyricsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QueueState>(
      stream: widget.audioHandler.queueState,
      builder: (context, snapshot) {
        final queueState = snapshot.data;
        final originalQueue = queueState?.queue ?? [];
        final shuffleIndices = queueState?.shuffleIndices;
        final currentItem = widget.audioHandler.mediaItem.value;

        // Create the displayed queue based on shuffle state
        List<MediaItem> displayQueue;
        if (shuffleIndices != null && shuffleIndices.isNotEmpty) {
          // Show queue in shuffled order
          displayQueue =
              shuffleIndices
                  .where((index) => index >= 0 && index < originalQueue.length)
                  .map((index) => originalQueue[index])
                  .toList();
        } else {
          // Show queue in original order
          displayQueue = originalQueue;
        }

        int currentIndex = 0;
        if (currentItem != null) {
          currentIndex = displayQueue.indexWhere(
            (item) => item.id == currentItem.id,
          );
          if (currentIndex == -1) currentIndex = 0;
        }

        // Define target queue height - 40% of screen height
        final queueMaxHeight = MediaQuery.of(context).size.height * 0.4;

        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30.r),
            topRight: Radius.circular(30.r),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30.r),
                  topRight: Radius.circular(30.r),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      widget.colorScheme != null
                          ? [
                            widget.colorScheme!.surface.withOpacity(0.4),
                            widget.colorScheme!.surface.withOpacity(0.4),
                          ]
                          : [
                            Colors.grey.shade900.withOpacity(0.4),
                            Colors.black.withOpacity(0.4),
                          ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Queue section that animates expanding/collapsing ABOVE control panel
                  AnimatedBuilder(
                    animation: _queueAnimationController,
                    builder: (context, child) {
                      final animatedHeight =
                          _queueHeightAnimation.value * queueMaxHeight;
                      // Add minimum height constraint to prevent layout overflow
                      final constrainedHeight =
                          animatedHeight < 100.w ? 0.0 : animatedHeight;

                      return SizedBox(
                        height: constrainedHeight,
                        child:
                            constrainedHeight > 0
                                ? ClipRect(
                                  child: Opacity(
                                    opacity: _queueAnimationController.value,
                                    child: _buildQueueList(
                                      displayQueue,
                                      currentIndex,
                                    ),
                                  ),
                                )
                                : null,
                      );
                    },
                  ),

                  // Lyrics section that animates expanding/collapsing ABOVE control panel
                  AnimatedBuilder(
                    animation: _lyricsAnimationController,
                    builder: (context, child) {
                      final lyricsMaxHeight =
                          MediaQuery.of(context).size.height * 0.4;
                      final animatedHeight =
                          _lyricsHeightAnimation.value * lyricsMaxHeight;
                      // Add minimum height constraint to prevent layout overflow
                      final constrainedHeight =
                          animatedHeight < 100.w ? 0.0 : animatedHeight;

                      return SizedBox(
                        height: constrainedHeight,
                        child:
                            constrainedHeight > 0
                                ? ClipRect(
                                  child: Opacity(
                                    opacity: _lyricsAnimationController.value,
                                    child: IntegratedLyricsOverlay(
                                      mediaItem: widget.mediaItem,
                                      onClose: widget.onLyrics,
                                      isVisible: widget.isLyricsVisible,
                                      colorScheme: widget.colorScheme,
                                    ),
                                  ),
                                )
                                : null,
                      );
                    },
                  ),

                  // Static control panel content - always stays in same position
                  // Center and constrain width on larger screens (iPad/tablet)
                  Builder(
                    builder: (ctx) {
                      final screenWidth = MediaQuery.of(ctx).size.width;
                      // Threshold where layout should be constrained and centered
                      const tabletThreshold = 600.0;
                      // Max content width on large screens to keep widgets centered
                      final maxContentWidth = 540.0.w;

                      final horizontalPadding =
                          screenWidth >= tabletThreshold
                              ? ((screenWidth - maxContentWidth) / 2)
                                  .clamp(16.0.w, 64.0.w)
                                  .toDouble()
                              : 24.w;

                      return Padding(
                        padding: EdgeInsets.only(
                          top:
                              24.w, // Increased top padding since drag handle is removed
                          left: horizontalPadding,
                          right: horizontalPadding,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                screenWidth >= tabletThreshold
                                    ? maxContentWidth
                                    : double.infinity,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Track info
                              ModernTrackInfo(
                                mediaItem: widget.mediaItem,
                                onFavoriteToggle: widget.onFavoriteToggle,
                                onShare: widget.onShare,
                                onDownload: widget.onDownload,
                                onAddToPlaylist: widget.onAddToPlaylist,
                                onPlayNext: widget.onPlayNext,
                                onAddToQueue: widget.onAddToQueue,
                                onCreateStation: widget.onCreateStation,
                                onRepeat: widget.onRepeat,
                                colorScheme: widget.colorScheme,
                                audioHandler: widget.audioHandler,
                              ),

                              SizedBox(height: 16.w),

                              // Seek bar
                              ModernSeekBar(
                                audioHandler: widget.audioHandler,
                                colorScheme: widget.colorScheme,
                              ),

                              SizedBox(height: 16.w),

                              // Playback controls - always stay in the same position
                              ModernPlaybackControls(
                                audioHandler: widget.audioHandler,
                                colorScheme: widget.colorScheme,
                                onQueue: widget.onQueue,
                              ),

                              SizedBox(height: 2.w),

                              // Lyrics button centered
                              Container(
                                margin: EdgeInsets.only(top: 16.w),
                                width: double.infinity,
                                child: Center(
                                  child: ElevatedButton(
                                    onPressed: widget.onLyrics,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[600]!
                                          .withOpacity(0.8),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 24.w,
                                        vertical: 8.w,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          24.r,
                                        ),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(width: 4.w),
                                        Text(
                                          widget.isLyricsVisible
                                              ? 'Close Lyrics'
                                              : 'Open Lyrics',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: 16.w),

                              // Volume slider - only show on Android
                              if (Platform.isAndroid) ...[
                                MusicPlayerVolumeSlider(
                                  colorScheme: widget.colorScheme,
                                ),
                              ],
                            ],
                          ), // Column
                        ), // ConstrainedBox
                      ); // return Padding(...);
                    },
                  ),

                  // Bottom padding with safe area
                  SizedBox(height: 30.w),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQueueList(List<MediaItem> queue, int currentIndex) {
    final primaryColor = widget.colorScheme?.primary ?? Colors.blue;
    final textColor = widget.colorScheme?.onSurface ?? Colors.white;
    final secondaryTextColor =
        widget.colorScheme != null
            ? widget.colorScheme!.onSurface.withOpacity(0.7)
            : Colors.white.withOpacity(0.7);

    if (queue.isEmpty) {
      return Center(
        child: Text(
          'No songs in queue',
          style: TextStyle(color: secondaryTextColor, fontSize: 14.sp),
        ),
      );
    }

    // Center and constrain the queue content on larger screens (iPad/tablet)
    final screenWidth = MediaQuery.of(context).size.width;
    const tabletThreshold = 600.0;
    final maxContentWidth = 540.0.w;
    final horizontalPadding =
        screenWidth >= tabletThreshold
            ? ((screenWidth - maxContentWidth) / 2)
                .clamp(16.0.w, 64.0.w)
                .toDouble()
            : 20.w;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              screenWidth >= tabletThreshold
                  ? maxContentWidth
                  : double.infinity,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Queue header - make it flexible to fit small heights
            if (queue.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Playing Queue',
                      style: TextStyle(
                        color: textColor,
                        fontSize: AppSizes.fontMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        // Shuffle + AutoPlay buttons
                        Row(
                          children: [
                            _buildShuffleButton(primaryColor, textColor),
                            SizedBox(width: 8.w),
                            _buildAutoPlayButton(primaryColor, textColor),
                          ],
                        ),
                        SizedBox(width: 18.w),
                        // Close button
                        GestureDetector(
                          onTap: widget.onQueue,
                          child: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: textColor,
                              size: 24.w,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Queue tracks - use Expanded and handle small heights gracefully
            Expanded(
              child:
                  queue.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 8.w,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemCount: queue.length,
                        itemBuilder: (context, displayIndex) {
                          final mediaItem = queue[displayIndex];
                          final isCurrentSong = displayIndex == currentIndex;

                          // Find the original index of this media item for proper navigation
                          final originalQueue = widget.audioHandler.queue.value;
                          final originalIndex = originalQueue.indexWhere(
                            (item) => item.id == mediaItem.id,
                          );

                          return GestureDetector(
                            onTap:
                                () => widget.onSongSelected?.call(
                                  originalIndex >= 0
                                      ? originalIndex
                                      : displayIndex,
                                ),
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: 4.w),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 8.w,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isCurrentSong
                                        ? primaryColor.withOpacity(0.15)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(12.r),
                                border:
                                    isCurrentSong
                                        ? Border.all(
                                          color: primaryColor.withOpacity(0.3),
                                          width: 1.w,
                                        )
                                        : null,
                              ),
                              child: Row(
                                children: [
                                  // Album artwork with playing indicator overlay
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Album artwork
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                        child: SizedBox(
                                          width: 52.w,
                                          height: 52.w,
                                          child: StreamBuilder<PlaybackState>(
                                            stream:
                                                widget
                                                    .audioHandler
                                                    .playbackState,
                                            builder: (
                                              context,
                                              playbackSnapshot,
                                            ) {
                                              final isPlaying =
                                                  playbackSnapshot
                                                      .data
                                                      ?.playing ??
                                                  false;

                                              // Build a robust ImageProvider fallback depending on URI scheme
                                              final uri = mediaItem.artUri;
                                              ImageProvider imageProvider;
                                              if (uri == null) {
                                                imageProvider = const AssetImage(
                                                  'assets/images/song_placeholder.png',
                                                );
                                              } else if (uri.scheme == 'http' ||
                                                  uri.scheme == 'https') {
                                                imageProvider = NetworkImage(
                                                  uri.toString(),
                                                );
                                              } else if (uri.scheme == 'file') {
                                                imageProvider = FileImage(
                                                  File(uri.toFilePath()),
                                                );
                                              } else if (uri.scheme == 'data') {
                                                try {
                                                  final data = uri.data;
                                                  if (data != null) {
                                                    imageProvider = MemoryImage(
                                                      data.contentAsBytes(),
                                                    );
                                                  } else {
                                                    imageProvider =
                                                        const AssetImage(
                                                          'assets/images/song_placeholder.png',
                                                        );
                                                  }
                                                } catch (e) {
                                                  debugPrint(
                                                    'Failed to decode data URI artwork: $e',
                                                  );
                                                  imageProvider = const AssetImage(
                                                    'assets/images/song_placeholder.png',
                                                  );
                                                }
                                              } else {
                                                try {
                                                  imageProvider = NetworkImage(
                                                    uri.toString(),
                                                  );
                                                } catch (_) {
                                                  debugPrint(
                                                    'Unsupported artwork URI scheme: ${uri.scheme}',
                                                  );
                                                  imageProvider = const AssetImage(
                                                    'assets/images/song_placeholder.png',
                                                  );
                                                }
                                              }

                                              return EnhancedAlbumArtWithVisualizer(
                                                image: imageProvider,
                                                isCurrent: isCurrentSong,
                                                isPlaying:
                                                    isCurrentSong && isPlaying,
                                                size: 52.w,
                                                color: primaryColor,
                                                visualizerPadding:
                                                    EdgeInsets.all(6.w),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(width: 12.w),

                                  // Song info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mediaItem.title,
                                          style: TextStyle(
                                            color:
                                                isCurrentSong
                                                    ? primaryColor
                                                    : textColor,
                                            fontSize: 14.sp,
                                            fontWeight:
                                                isCurrentSong
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4.w),
                                        Text(
                                          mediaItem.artist ?? 'Unknown Artist',
                                          style: TextStyle(
                                            color: secondaryTextColor,
                                            fontSize: 12.sp,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Track duration
                                  Text(
                                    _formatDuration(mediaItem.duration),
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShuffleButton(Color primaryColor, Color textColor) {
    return StreamBuilder<PlaybackState>(
      stream: widget.audioHandler.playbackState,
      builder: (context, playbackSnapshot) {
        final isShuffleEnabled =
            playbackSnapshot.data?.shuffleMode == AudioServiceShuffleMode.all;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onShuffle?.call();
          },
          child: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color:
                  isShuffleEnabled
                      ? primaryColor.withOpacity(0.2)
                      : textColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                Icons.shuffle,
                key: ValueKey<bool>(isShuffleEnabled),
                color: isShuffleEnabled ? primaryColor : textColor,
                size: 24.w,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildAutoPlayButton(Color primaryColor, Color textColor) {
    final musicManager = MusicManager();

    return StreamBuilder<PlaybackState>(
      stream: widget.audioHandler.playbackState,
      builder: (context, playbackSnapshot) {
        final repeatMode =
            playbackSnapshot.data?.repeatMode ?? AudioServiceRepeatMode.none;
        final isAutoPlayEnabled = musicManager.autoPlayEnabled;
        final canToggleAutoPlay = repeatMode == AudioServiceRepeatMode.none;

        return GestureDetector(
          onTap:
              canToggleAutoPlay
                  ? () {
                    HapticFeedback.lightImpact();
                    widget.onAutoPlay?.call();
                  }
                  : null,
          child: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color:
                  isAutoPlayEnabled && canToggleAutoPlay
                      ? primaryColor.withOpacity(0.2)
                      : textColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: SvgPicture.asset(
                'assets/icons/autoplay_icon.svg',
                key: ValueKey<bool>(isAutoPlayEnabled),
                colorFilter: ColorFilter.mode(
                  canToggleAutoPlay
                      ? (isAutoPlayEnabled ? primaryColor : textColor)
                      : textColor.withOpacity(0.4),
                  BlendMode.srcIn,
                ),
                width: 28.w,
                height: 28.w,
              ),
            ),
          ),
        );
      },
    );
  }
}
