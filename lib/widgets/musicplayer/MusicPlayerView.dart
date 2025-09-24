import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/music_player_theme_service.dart';
import 'package:jainverse/widgets/musicplayer/visual_area.dart';
import 'package:jainverse/widgets/musicplayer/control_panel.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/utils/sharing_utils.dart'; // Import sharing utility
import 'package:jainverse/UI/MusicEntryPoint.dart' as entry_point;
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/widgets/playlist/add_to_playlist_bottom_sheet.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/services/station_service.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/hooks/favorites_hook.dart';

class MusicPlayerView extends StatefulWidget {
  final AudioPlayerHandler audioHandler;
  final ModelTheme sharedPreThemeData;
  final VoidCallback onBackPressed;
  final bool isFromBottomSlider;

  const MusicPlayerView({
    super.key,
    required this.audioHandler,
    required this.sharedPreThemeData,
    required this.onBackPressed,
    this.isFromBottomSlider = false,
  });

  @override
  State<MusicPlayerView> createState() => _ModernMusicPlayerState();
}

class _ModernMusicPlayerState extends State<MusicPlayerView>
    with TickerProviderStateMixin {
  // Services
  late MusicPlayerThemeService _themeService;

  // Queue overlay state
  bool _isQueueOverlayVisible = false;

  // Lyrics overlay state
  bool _isLyricsOverlayVisible = false;

  // Stream subscription for cleanup
  StreamSubscription<MediaItem?>? _mediaItemSubscription;

  // Gesture-based slide-down-to-dismiss functionality
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Gesture tracking variables
  double _dragStartY = 0.0;
  double _dragDistance = 0.0;
  bool _isDragging = false;
  bool _hasHorizontalMovement = false;

  // Configuration constants
  static const double _dismissThreshold = 120.0;
  static const double _velocityThreshold = 600.0;
  static const double _maxDragDistance = 250.0;
  static const double _horizontalTolerance = 30.0;
  static const Duration _animationDuration = Duration(milliseconds: 350);
  static const Curve _animationCurve = Curves.easeOutCubic;

  OverlayEntry? _currentOverlayEntry;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _listenToMediaChanges();
    _initializeSlideAnimation();
    _setupIOSDownloadCallback();
  }

  void _initializeServices() {
    _themeService = MusicPlayerThemeService();
    _themeService.initializeAnimations(this);
  }

  void _setupIOSDownloadCallback() {
    // Set up iOS UI callback for download progress messages (iOS only)
    if (Platform.isIOS) {
      final downloadController = DownloadController();
      downloadController.setIOSUICallback(_showDownloadMessage);
      debugPrint('iOS download UI callback set up successfully');
    } else {
      debugPrint('Android platform: Using notifications for download feedback');
    }
  }

  /// Show download message using the standard _showMessage method
  void _showDownloadMessage(String message) {
    if (Platform.isIOS && mounted) {
      _showMessage(message, Colors.black26, isDownload: true, fontSize: 15.w);
    }
  }

  void _initializeSlideAnimation() {
    _slideController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, 1.0),
    ).animate(
      CurvedAnimation(parent: _slideController, curve: _animationCurve),
    );
  }

  void _toggleQueueOverlay() {
    if (mounted) {
      setState(() {
        // If lyrics is currently open, close it first
        if (_isLyricsOverlayVisible) {
          _isLyricsOverlayVisible = false;
        }
        _isQueueOverlayVisible = !_isQueueOverlayVisible;
      });
    }
  }

  void _toggleLyricsOverlay() {
    if (mounted) {
      setState(() {
        // If queue is currently open, close it first
        if (_isQueueOverlayVisible) {
          _isQueueOverlayVisible = false;
        }
        _isLyricsOverlayVisible = !_isLyricsOverlayVisible;
      });
    }
  }

  void _onSongSelected(int index) async {
    await widget.audioHandler.skipToQueueItem(index);
    // Start playing the selected song
    await widget.audioHandler.play();
    // Hide queue overlay after selection only if it's visible
    if (_isQueueOverlayVisible) {
      _toggleQueueOverlay();
    }
  }

  // Simple handler methods (replacing complex controller)
  void _handleKeepSong([FavoritesHook? favoritesHook]) async {
    print(
      '🔥 MusicPlayerView: _handleKeepSong called with favoritesHook: ${favoritesHook != null}',
    );

    final currentSong = widget.audioHandler.mediaItem.value;
    if (currentSong?.extras?['audio_id'] != null) {
      try {
        final audioId = currentSong!.extras!['audio_id'].toString();

        print(
          '🔥 MusicPlayerView: Starting favorite toggle for audio ID: $audioId, favoritesHook available: ${favoritesHook != null}',
        );

        // Use global favorites provider if available
        if (favoritesHook != null) {
          print('🔥 MusicPlayerView: Using global favorites provider');
          try {
            // Try to find the DataMusic object for this song from global listCopy
            DataMusic? songData;
            try {
              songData = entry_point.listCopy.firstWhere(
                (song) => song.id.toString() == audioId,
              );
            } catch (e) {
              print(
                '🔥 MusicPlayerView: Song not found in listCopy, creating from MediaItem',
              );
              // Create DataMusic object from MediaItem as fallback
              songData = DataMusic(
                int.parse(audioId),
                currentSong.extras?['image'] ?? '',
                currentSong.extras?['actual_audio_url'] ?? currentSong.id,
                '3:00', // Default duration
                currentSong.title,
                currentSong.album ?? '',
                1, // Default audio_genre_id
                currentSong.extras?['artist_id']?.toString() ?? '0',
                currentSong.artist ?? '',
                'English', // Default language
                0, // Default listening_count
                0, // Default is_featured
                0, // Default is_trending
                DateTime.now().toString(), // Default created_at
                0, // Default is_recommended
                currentSong.extras?['favourite']?.toString() ?? '0',
                '0', // Default download_price
                '', // Default lyric
              );
            }

            // Toggle favorite using global provider
            final success = await favoritesHook.toggleSongFavorite(songData);
            if (success) {
              // Update the current media item's favorite status
              final newStatus = favoritesHook.isFavorite(audioId) ? '1' : '0';
              await _updateCurrentMediaItemFavoriteStatus(newStatus);
              print(
                '🔥 MusicPlayerView: Successfully toggled favorite via global provider',
              );
              return;
            }
          } catch (e) {
            print('🔥 MusicPlayerView: Error using global provider: $e');
            // Fall back to original method
          }
        }

        // Fallback to original implementation
        final currentStatus =
            currentSong.extras!['favourite']?.toString() ?? '0';
        print('🔥 MusicPlayerView: Current favorite status: $currentStatus');

        // Try to find the DataMusic object for this song from global listCopy
        DataMusic? songData;
        try {
          songData = entry_point.listCopy.firstWhere(
            (song) => song.id.toString() == audioId,
          );
        } catch (e) {
          print(
            '🔥 MusicPlayerView: Song not found in listCopy, creating from MediaItem',
          );
          // Create DataMusic object from MediaItem as fallback
          songData = DataMusic(
            int.parse(audioId),
            currentSong.extras?['image'] ?? '',
            currentSong.extras?['actual_audio_url'] ?? currentSong.id,
            '3:00', // Default duration
            currentSong.title,
            currentSong.album ?? '',
            1, // Default audio_genre_id
            currentSong.extras?['artist_id']?.toString() ?? '0',
            currentSong.artist ?? 'Unknown Artist',
            'English', // Default language
            0, // Default listening_count
            0, // Default is_featured
            0, // Default is_trending
            DateTime.now().toString(), // Default created_at
            0, // Default is_recommended
            currentStatus,
            '0', // Default download_price
            currentSong.extras?['lyrics'] ?? '',
          );
        }

        final favoriteService = FavoriteService();
        await favoriteService.toggleFavoriteOptimistic(songData, () {
          // Use a small delay to allow the menu to close naturally first
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {});
            }
          });
        });

        // CRITICAL: Update the MediaItem extras to reflect the new favorite status
        await _updateCurrentMediaItemFavoriteStatus(songData.favourite);

        print('🔥 MusicPlayerView: Favorite toggle completed');
      } catch (e) {
        print('🔥 ERROR MusicPlayerView: Error toggling favorite: $e');
      }
    } else {
      print(
        '🔥 ERROR MusicPlayerView: No audio ID available for favorite toggle',
      );
    }
  }

  void _handleShare() async {
    // Get the current media item from the audio handler
    final currentSong = widget.audioHandler.mediaItem.value;
    if (currentSong != null) {
      await SharingUtils.shareFromMediaItemSafe(currentSong, context: context);
    } else {
      debugPrint('No current song to share');
    }
  }

  void _handleDownload() async {
    print('Download song initiated from MusicPlayerView');

    final currentMediaItem = widget.audioHandler.mediaItem.value;
    if (currentMediaItem == null) {
      debugPrint('No media item available for download');
      return;
    }

    try {
      final downloadController = DownloadController();
      await downloadController.initialize();

      // Test notification feature (only in debug mode)
      // if (kDebugMode) {
      //   // Add a small delay then show test notification
      //   Future.delayed(const Duration(seconds: 2), () {
      //     downloadController.testDownloadNotification();
      //   });
      // }

      // Extract audio ID from MediaItem extras
      final audioId = currentMediaItem.extras?['audio_id']?.toString() ?? '';
      if (audioId.isEmpty) {
        debugPrint('No audio ID available for download');
        if (Platform.isIOS && mounted) {
          _showMessage(
            'Unable to download: Missing track ID',
            Colors.black26,
            isDownload: true,
            fontSize: 15.w,
          );
        }
        return;
      }

      // Show message for starting download at top (like other messages)
      if (Platform.isIOS && mounted) {
        _showMessage(
          'Starting download for ${currentMediaItem.title}',
          Colors.black26,
          isDownload: true,
          fontSize: 15.w,
        );
      }

      // Check if already downloaded
      if (downloadController.isTrackDownloaded(audioId)) {
        print('Track already downloaded');
        if (Platform.isIOS && mounted) {
          _showMessage(
            '${currentMediaItem.title} is already downloaded',
            Colors.black26,
            isDownload: true,
            fontSize: 15.w,
          );
        }
        return;
      }

      // Check if currently downloading
      if (downloadController.isDownloading(audioId)) {
        print('Track is currently downloading');
        if (Platform.isIOS && mounted) {
          _showMessage(
            '${currentMediaItem.title} is already downloading',
            Colors.black26,
            isDownload: true,
            fontSize: 15.w,
          );
        }
        return;
      }

      // Add to downloads
      final success = await downloadController.addToDownloads(audioId);
      if (success) {
        if (Platform.isIOS && mounted) {
          _showMessage(
            '${currentMediaItem.title} added to downloads',
            Colors.black26,
            isDownload: true,
            fontSize: 15.w,
          );
        }
      } else {
        if (Platform.isIOS && mounted) {
          _showMessage(
            'Failed to add ${currentMediaItem.title} to downloads',
            Colors.black26,
            isDownload: true,
            fontSize: 15.w,
          );
        }
      }
    } catch (e) {
      print('Download error: $e');
      if (Platform.isIOS && mounted) {
        _showMessage(
          'Download error: $e',
          Colors.black26,
          isDownload: true,
          fontSize: 15.w,
        );
      }
    }
  }

  void _handleAddToPlaylist() {
    final currentMediaItem = widget.audioHandler.mediaItem.value;
    if (currentMediaItem == null) {
      debugPrint('No media item available for playlist addition');
      return;
    }

    final songId = currentMediaItem.extras?['audio_id']?.toString() ?? '';
    if (songId.isEmpty) {
      debugPrint('No audio ID available for playlist addition');
      return;
    }

    // Extract song image from MediaItem's artUri
    String? songImage;
    if (currentMediaItem.artUri != null) {
      final artUriString = currentMediaItem.artUri.toString();
      // Extract just the filename from the full image URL
      if (artUriString.contains('/thumb/')) {
        songImage = artUriString.split('/thumb/').last;
      } else if (artUriString.contains('images/audio/thumb/')) {
        songImage = artUriString.split('images/audio/thumb/').last;
      }
    }

    // Show the playlist selection bottom sheet with root context
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    AddToPlaylistBottomSheet.show(
      rootContext,
      songId: songId,
      songTitle: currentMediaItem.title,
      artistName: currentMediaItem.artist ?? 'Unknown Artist',
      songImage: songImage,
      forceRefresh: true, // Force refresh for updated playlist data
      onPlaylistAdded: () {
        // Optional callback when song is added to playlist
        debugPrint('Song added to playlist successfully');
      },
    );
  }

  void _handlePlayNext() {
    // Add haptic feedback for better UX
    HapticFeedback.lightImpact();

    // Skip to next track using audio handler
    widget.audioHandler.skipToNext();
    debugPrint('Skipped to next track via audio handler');
  }

  void _handleAddToQueue() => debugPrint('Add to queue');
  void _handleShuffle() {
    // Add haptic feedback for better UX
    HapticFeedback.lightImpact();

    // Use MusicManager to toggle shuffle mode
    final musicManager = MusicManager();
    musicManager.toggleShuffle();
  }

  void _handleAutoPlay() {
    // Add haptic feedback for better UX
    HapticFeedback.lightImpact();

    // Use MusicManager to toggle auto play mode
    final musicManager = MusicManager();
    musicManager.toggleAutoPlay();
  }

  void _handleQueue() => _toggleQueueOverlay();
  void _handleLyrics() => _toggleLyricsOverlay();
  void _handleRepeat() {
    // Use MusicManager to toggle repeat mode
    final musicManager = MusicManager();
    final currentRepeatMode = musicManager.repeatMode;

    AudioServiceRepeatMode newMode =
        AudioServiceRepeatMode.none; // Default value

    switch (currentRepeatMode) {
      case AudioServiceRepeatMode.none:
        newMode = AudioServiceRepeatMode.all;
        debugPrint('Repeat mode: None -> All');
        break;
      case AudioServiceRepeatMode.all:
        newMode = AudioServiceRepeatMode.one;
        debugPrint('Repeat mode: All -> One');
        break;
      case AudioServiceRepeatMode.one:
        newMode = AudioServiceRepeatMode.none;
        debugPrint('Repeat mode: One -> None');
        break;
      case AudioServiceRepeatMode.group:
        newMode = AudioServiceRepeatMode.none;
        debugPrint('Repeat mode: Group -> None');
        break;
    }

    musicManager.setRepeatMode(newMode);
  }

  void _listenToMediaChanges() {
    _mediaItemSubscription = widget.audioHandler.mediaItem.listen((mediaItem) {
      if (mounted && !_themeService.isDisposed) {
        _themeService.updateMediaItem(mediaItem);
      }
    });
  }

  // Gesture handling methods
  void _onPanStart(DragStartDetails details) {
    // Only allow gesture from top 50% of screen
    final screenHeight = MediaQuery.of(context).size.height;
    final gestureStartY = details.globalPosition.dy;

    if (gestureStartY <= screenHeight * 0.5) {
      _isDragging = true;
      _dragStartY = gestureStartY;
      _dragDistance = 0.0;
      _hasHorizontalMovement = false;

      // Stop any ongoing animation
      _slideController.stop();

      // Light haptic feedback on drag start
      HapticFeedback.lightImpact();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final currentY = details.globalPosition.dy;
    final deltaY = currentY - _dragStartY;
    final deltaX = (details.globalPosition.dx - details.localPosition.dx).abs();

    // Check for significant horizontal movement to avoid conflicts with horizontal gestures
    if (deltaX > _horizontalTolerance && !_hasHorizontalMovement) {
      _hasHorizontalMovement = true;
      return; // Don't handle vertical gesture if user is swiping horizontally
    }

    // Only proceed if no significant horizontal movement
    if (!_hasHorizontalMovement && deltaY > 0) {
      if (mounted) {
        setState(() {
          // Apply resistance for smooth feel
          _dragDistance = _applyResistance(deltaY);
        });
      }

      // Provide subtle haptic feedback at quarter points
      if (_dragDistance > _dismissThreshold * 0.25 &&
          _dragDistance < _dismissThreshold * 0.3) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    _isDragging = false;

    // Don't dismiss if there was significant horizontal movement
    if (_hasHorizontalMovement) {
      _animateBack();
      return;
    }

    final velocity = details.velocity.pixelsPerSecond.dy;
    final shouldDismiss = _shouldDismissScreen(velocity);

    if (shouldDismiss) {
      // Strong haptic feedback on dismiss
      HapticFeedback.mediumImpact();
      _animateAndDismiss();
    } else {
      // Light haptic feedback on snap back
      HapticFeedback.lightImpact();
      _animateBack();
    }
  }

  double _applyResistance(double distance) {
    if (distance <= _maxDragDistance) {
      // Linear movement for normal range
      return distance;
    } else {
      // Apply exponential resistance beyond max distance
      final excess = distance - _maxDragDistance;
      final resistance =
          _maxDragDistance + (excess * 0.2); // Stronger resistance
      return resistance;
    }
  }

  bool _shouldDismissScreen(double velocity) {
    // More sophisticated dismissal logic
    final velocityFactor = velocity > _velocityThreshold;
    final distanceFactor = _dragDistance > _dismissThreshold;
    final strongGesture =
        velocity > _velocityThreshold * 1.5; // Very fast swipe

    // Dismiss if:
    // 1. Fast velocity regardless of distance (for quick swipes)
    // 2. Sufficient distance with any downward movement
    // 3. Very strong gesture (immediate dismiss)
    return strongGesture || velocityFactor || distanceFactor;
  }

  void _animateAndDismiss() async {
    try {
      // Animate slide out smoothly
      await _slideController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInQuart,
      );

      if (mounted) {
        widget.onBackPressed();
      }
    } catch (e) {
      // Fallback if animation fails
      if (mounted) {
        widget.onBackPressed();
      }
    }
  }

  void _animateBack() async {
    try {
      // Smooth spring-back animation
      if (mounted) {
        setState(() {
          _dragDistance = 0.0;
        });
      }

      await _slideController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
      );
    } catch (e) {
      // Fallback - just reset the state
      if (mounted) {
        setState(() {
          _dragDistance = 0.0;
        });
      }
    }
  }

  /// Update the current MediaItem's favorite status in the audio handler
  /// This ensures the UI stays consistent after favorite toggle
  Future<void> _updateCurrentMediaItemFavoriteStatus(
    String newFavoriteStatus,
  ) async {
    try {
      final currentMediaItem = widget.audioHandler.mediaItem.value;
      if (currentMediaItem == null) {
        print('🔥 MusicPlayerView: No current MediaItem to update');
        return;
      }

      print(
        '🔥 MusicPlayerView: Updating MediaItem favorite status to: $newFavoriteStatus',
      );

      // Create updated extras with new favorite status
      final updatedExtras = Map<String, dynamic>.from(
        currentMediaItem.extras ?? {},
      );
      updatedExtras['favourite'] = newFavoriteStatus;

      // Update the queue item with new extras
      // Note: We don't use updateQueue here as it would interrupt playback
      // Instead, we rely on the MusicManager's updateCurrentSongFavoriteStatus method
      // which handles this more efficiently
      final musicManager = MusicManager();
      musicManager.updateCurrentSongFavoriteStatus(newFavoriteStatus);

      print(
        '🔥 MusicPlayerView: Successfully updated MediaItem favorite status',
      );
    } catch (e) {
      print(
        '🔥 ERROR MusicPlayerView: Failed to update MediaItem favorite status: $e',
      );
    }
  }

  @override
  void dispose() {
    // Cancel the media item subscription first
    _mediaItemSubscription?.cancel();
    _mediaItemSubscription = null;

    // Dispose slide controller
    _slideController.dispose();

    // Then dispose the theme service
    _themeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FavoritesConsumer(
      builder: (context, favoritesHook, child) {
        // If theme service is disposed, return a simple fallback UI
        if (_themeService.isDisposed) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Theme.of(context).primaryColor, Colors.black],
                ),
              ),
              child: const Center(
                child: Text(
                  'Loading...',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: StreamBuilder<MediaItem?>(
            stream: widget.audioHandler.mediaItem,
            builder: (context, snapshot) {
              final mediaItem = snapshot.data;

              // Prevent flashing empty player: show loader or nothing if mediaItem is null
              if (mediaItem == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return AnimatedBuilder(
                animation: _themeService,
                builder: (context, child) {
                  return AnimatedBuilder(
                    animation:
                        _themeService.backgroundAnimation ??
                        kAlwaysCompleteAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: _themeService.buildBackgroundDecoration(),
                        child: SafeArea(
                          bottom: false, // Remove bottom padding
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            behavior: HitTestBehavior.translucent,
                            child: AnimatedBuilder(
                              animation: _slideAnimation,
                              builder: (context, child) {
                                final progress = (_dragDistance /
                                        _maxDragDistance)
                                    .clamp(0.0, 1.0);
                                final fadeOpacity = (1.0 - (progress * 0.3))
                                    .clamp(0.7, 1.0);

                                return Transform.translate(
                                  offset: Offset(
                                    0.0,
                                    _slideAnimation.value.dy *
                                            MediaQuery.of(context).size.height +
                                        _dragDistance,
                                  ),
                                  child: Opacity(
                                    opacity: fadeOpacity,
                                    child: Stack(
                                      children: [
                                        // Visual feedback indicator at top
                                        if (_isDragging) _buildDragIndicator(),

                                        // Visual area takes the full height
                                        ModernVisualArea(
                                          mediaItem: mediaItem,
                                          onBackPressed: widget.onBackPressed,
                                          onAnimatedBackPressed:
                                              _animateAndDismiss, // Add animated dismiss
                                          audioHandler: widget.audioHandler,
                                        ),

                                        // Position the control panel at the bottom with no extra padding
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          child: ModernControlPanel(
                                            mediaItem: mediaItem,
                                            audioHandler: widget.audioHandler,
                                            colorScheme:
                                                _themeService
                                                    .currentColorScheme,
                                            onFavoriteToggle:
                                                () => _handleKeepSong(
                                                  favoritesHook,
                                                ),
                                            onShare: _handleShare,
                                            onDownload: _handleDownload,
                                            onAddToPlaylist:
                                                _handleAddToPlaylist,
                                            onPlayNext: _handlePlayNext,
                                            onAddToQueue: _handleAddToQueue,
                                            onShuffle: _handleShuffle,
                                            onQueue: _handleQueue,
                                            onAutoPlay:
                                                _handleAutoPlay, // Add auto play handler
                                            isQueueVisible:
                                                _isQueueOverlayVisible,
                                            onSongSelected: _onSongSelected,
                                            onLyrics: _handleLyrics,
                                            isLyricsVisible:
                                                _isLyricsOverlayVisible,
                                            onRepeat: _handleRepeat,
                                            onCreateStation:
                                                _handleCreateStation, // Add create station handler
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Builds a visual indicator showing drag progress
  Widget _buildDragIndicator() {
    final progress = (_dragDistance / _dismissThreshold).clamp(0.0, 1.0);
    final indicatorColor = progress > 0.7 ? Colors.green : Colors.white;

    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 50,
          height: 4,
          decoration: BoxDecoration(
            color: indicatorColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  /// Helper method to show messages to the user at top with transparent background
  /// This method is specifically for iOS platform only
  void _showMessage(
    String message,
    Color backgroundColor, {
    bool isDownload = false,
    double fontSize = 15,
  }) {
    // Only show UI messages on iOS platform
    if (!Platform.isIOS || !mounted) return;

    final overlay = Overlay.of(context);

    // Remove previous overlay entry if exists
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;

    final overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 45.w,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 1,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(overlayEntry);
    _currentOverlayEntry = overlayEntry;

    // Auto-dismiss after 3 seconds for download messages, 2 seconds for others
    final dismissDuration =
        isDownload ? const Duration(seconds: 3) : const Duration(seconds: 2);
    Future.delayed(dismissDuration, () {
      if (_currentOverlayEntry == overlayEntry) {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
        _currentOverlayEntry = null;
      }
    });
  }

  void _handleCreateStation() async {
    print('Create station initiated from MusicPlayerView');

    final currentMediaItem = widget.audioHandler.mediaItem.value;
    if (currentMediaItem == null) {
      debugPrint('No media item available for station creation');
      return;
    }

    try {
      // Extract audio ID from MediaItem extras
      final audioId = currentMediaItem.extras?['audio_id']?.toString() ?? '';
      if (audioId.isEmpty) {
        debugPrint('No audio ID available for station creation');
        if (mounted) {
          _showMessage(
            'Unable to create station: Missing track ID',
            Colors.red,
          );
        }
        return;
      }

      // Find the current song in the global data
      DataMusic? currentSong;
      try {
        currentSong = entry_point.listCopy.firstWhere(
          (song) => song.id.toString() == audioId,
        );
      } catch (e) {
        debugPrint(
          'Current song not found in listCopy, creating from MediaItem',
        );
        // Create DataMusic object from MediaItem as fallback
        currentSong = DataMusic(
          int.parse(audioId),
          currentMediaItem.extras?['image'] ?? '',
          currentMediaItem.extras?['actual_audio_url'] ?? '',
          currentMediaItem.duration?.inMinutes.toString() ?? '3:00',
          currentMediaItem.title,
          currentMediaItem.album ?? '',
          0,
          currentMediaItem.extras?['artist_id'] ?? '',
          currentMediaItem.artist ?? 'Unknown Artist',
          '',
          0,
          0,
          0,
          '',
          0,
          currentMediaItem.extras?['favourite'] ?? '0',
          '',
          currentMediaItem.extras?['lyrics'] ?? '',
        );
      }

      // Use StationService to create the station
      final stationService = StationService();
      final success = await stationService.createStation(currentSong);

      if (mounted) {
        if (success) {
          Fluttertoast.showToast(
            msg: 'Station created!',
            backgroundColor: appColors().gray[600],
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        } else {
          Fluttertoast.showToast(
            msg: 'Failed to create station. Please try again.',
            backgroundColor: Colors.red,
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      }
    } catch (e) {
      debugPrint('Station creation error: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Station creation error: $e',
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }
}

/// Compatibility wrapper for older code paths that expect `MusicPlayerUI`.
///
/// Many parts of the codebase (for example `MusicEntryPoint` and the mini
/// player) instantiate `MusicPlayerUI(...)`. The project now has a
/// `MusicPlayerView` widget. To avoid changing many call sites, provide a
/// lightweight adapter that accepts the original parameter list and forwards
/// the call to `MusicPlayerView` with conservative defaults.
class MusicPlayerUI extends StatelessWidget {
  final AudioPlayerHandler audioHandler;
  final String pathImage;
  final String audioPath;
  final List<DataMusic> listData;
  final String catImages;
  final int index;
  final bool isOffline;
  final String audioPathMain;
  final bool isOpn;
  final VoidCallback? ontap;
  final bool skipQueueSetup;
  final bool queueAlreadySetup;

  const MusicPlayerUI(
    this.audioHandler,
    this.pathImage,
    this.audioPath,
    this.listData,
    this.catImages,
    this.index,
    this.isOffline,
    this.audioPathMain, {
    this.isOpn = false,
    this.ontap,
    this.skipQueueSetup = false,
    this.queueAlreadySetup = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Try to provide a reasonable ModelTheme instance; callers that
    // need more specialized theme can obtain it from providers or
    // SharedPref inside MusicPlayerView.
    final sharedTheme = ModelTheme('', '', '', '', '', '');

    return MusicPlayerView(
      audioHandler: audioHandler,
      sharedPreThemeData: sharedTheme,
      onBackPressed: ontap ?? () => Navigator.of(context).maybePop(),
      isFromBottomSlider: false,
    );
  }
}
