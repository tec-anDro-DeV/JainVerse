import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/enhanced_audio_visualizer.dart';
import 'package:jainverse/utils/performance_debouncer.dart';
import 'package:jainverse/widgets/common/smart_image_widget.dart';
// ...existing code...
import 'package:jainverse/widgets/musicplayer/MusicPlayerView.dart';
import 'package:rxdart/rxdart.dart';

import '../../UI/MusicEntryPoint.dart'
    show Music, listCopy, idTag, type, indixes;

/// Configuration constants for the mini music player
class _MiniPlayerConfig {
  static const String placeholderImage = 'assets/images/song_placeholder.png';
  static Color primaryColor = appColors().primaryColorApp;
  static const Color backgroundColor = Colors.white;
  static const Duration animationDuration = Duration(milliseconds: 200);

  // Size constants for mini music player
  static double get height => 90.w;
  static double get borderRadius => 12.w;
  static double get marginHorizontal => 18.w;
  static double get paddingHorizontal => 15.w;
  static double get paddingVertical => 10.w;
  static double get spacing => 10.w;
  static double get albumArtSize => 70.w;
  static double get albumArtRadius => 16.w;
  static double get playButtonSize => 56.w;
  static double get playIconSize => 36.w;
  static double get progressBarHeight => 5.w;
}

/// Handles the mini music player functionality and UI with slide-up animation
class MiniMusicPlayer {
  final AudioPlayerHandler? _audioHandler;
  final MusicManager _musicManager = MusicManager();

  // Static properties for maintaining state
  static String musicName = '';
  static String musicImage = '';
  static String artistName = '';
  static double mainPosition = 0.0;
  static double maxDuration = 0.0;

  MiniMusicPlayer(this._audioHandler) {
    // Set the audio handler in the music manager if needed
    if (_audioHandler != null) {
      _musicManager.setAudioHandler(_audioHandler);
    }
  }

  /// Main widget builder for the mini music player with animation
  Widget buildMiniPlayer(BuildContext context) {
    return AnimatedMiniMusicPlayer(
      audioHandler: _audioHandler,
      musicManager: _musicManager,
    );
  }

  // Keep the legacy method for backward compatibility
  @Deprecated('Use buildMiniPlayer instead')
  Widget getNaviagtion(BuildContext context) => buildMiniPlayer(context);
}

/// Animated Mini Music Player Widget with slide-up animation
class AnimatedMiniMusicPlayer extends StatefulWidget {
  final AudioPlayerHandler? audioHandler;
  final MusicManager musicManager;

  const AnimatedMiniMusicPlayer({
    super.key,
    required this.audioHandler,
    required this.musicManager,
  });

  @override
  State<AnimatedMiniMusicPlayer> createState() =>
      _AnimatedMiniMusicPlayerState();
}

class _AnimatedMiniMusicPlayerState extends State<AnimatedMiniMusicPlayer>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _slideAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Animation configuration
  static const Duration _slideInDuration = Duration(milliseconds: 400);
  static const Duration _fadeInDuration = Duration(milliseconds: 300);
  static const Curve _slideInCurve = Curves.easeOutCubic;
  static const Curve _fadeInCurve = Curves.easeOut;

  // State tracking
  bool _hasMediaItem = false;
  bool _isVisible = false;
  // Lightweight notifier to request small UI refreshes without full setState
  final ValueNotifier<int> _refreshNotifier = ValueNotifier<int>(0);
  double _rawHorizontalDragOffset = 0.0;
  double _horizontalDragOffset = 0.0;
  double _dismissThreshold = 120.0;
  AnimationController? _dragAnimationController;
  Animation<double>? _dragAnimation;
  bool _isDismissing = false;
  double _screenWidth = 0.0;
  bool _awaitingNewPlaybackAfterDismiss = false;
  String? _lastDismissedMediaToken;
  Timer? _showDelayTimer;
  // Interactive seeking state for the progress bar
  double? _interactiveSeekingMs;
  bool _isInteractingWithProgress = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupMediaListener();
    // Listen for optimistic processing audio id to trigger mini-player immediately
    widget.musicManager.processingAudioId.addListener(() {
      if (!mounted) return;
      final processingId = widget.musicManager.processingAudioId.value;
      if (processingId != null && !_isVisible) {
        // Show optimistic mini player when a play is processing
        _showMiniPlayer();
        _refreshNotifier.value = _refreshNotifier.value + 1;
      }
      if (processingId == null) {
        // Let stream updates hide later if needed
        _refreshNotifier.value = _refreshNotifier.value + 1;
      }
    });
  }

  void _initializeAnimations() {
    // Slide animation controller
    _slideAnimationController = AnimationController(
      duration: _slideInDuration,
      vsync: this,
    );

    // Fade animation controller
    _fadeAnimationController = AnimationController(
      duration: _fadeInDuration,
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
            curve: _slideInCurve,
          ),
        );

    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: _fadeInCurve),
    );

    // Drag animation controller for swipe-to-dismiss interactions
    _dragAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _setupMediaListener() {
    // Listen to media changes to trigger animations
    widget.audioHandler?.mediaItem.listen((mediaItem) {
      if (mounted) {
        final shouldShow =
            mediaItem != null || MiniMusicPlayer.musicName.isNotEmpty;

        if (shouldShow && !_hasMediaItem) {
          // New media item detected, show with animation
          _showMiniPlayer();
        } else if (!shouldShow && _hasMediaItem) {
          // No media item, hide with animation
          _hideMiniPlayer();
        }

        _hasMediaItem = shouldShow;
      }
    });
  }

  void _showMiniPlayer() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
        _horizontalDragOffset = 0.0;
        _rawHorizontalDragOffset = 0.0;
        _isDismissing = false;
      });

      // Stagger the animations for a more polished look
      _slideAnimationController.forward();

      // Start fade animation slightly after slide animation begins
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _fadeAnimationController.forward();
        }
      });

      // Add haptic feedback for better UX
      HapticFeedback.lightImpact();
    }
  }

  void _hideMiniPlayer() {
    if (_isVisible) {
      _showDelayTimer?.cancel();
      // Reverse animations
      _fadeAnimationController.reverse();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _slideAnimationController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isVisible = false;
                _horizontalDragOffset = 0.0;
                _rawHorizontalDragOffset = 0.0;
                if (!_awaitingNewPlaybackAfterDismiss) {
                  _lastDismissedMediaToken = null;
                }
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
    _dragAnimationController?.dispose();
    _refreshNotifier.dispose();
    _showDelayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler?.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        bool shouldShow =
            mediaItem != null || MiniMusicPlayer.musicName.isNotEmpty;

        if (_awaitingNewPlaybackAfterDismiss) {
          final bool isPlaying = widget.musicManager.isPlaying;
          final bool hasMedia = mediaItem != null;
          final String? currentToken = _mediaToken(mediaItem);
          final bool matchesDismissedToken =
              currentToken != null && currentToken == _lastDismissedMediaToken;

          final bool restartedSameMedia =
              matchesDismissedToken &&
              widget.musicManager.position.inMilliseconds <= 1500;
          final bool differentMedia =
              hasMedia &&
              currentToken != null &&
              currentToken != _lastDismissedMediaToken;

          final bool isNewPlayback =
              isPlaying &&
              hasMedia &&
              (differentMedia ||
                  restartedSameMedia ||
                  _lastDismissedMediaToken == null);

          if (isNewPlayback) {
            _handleNewPlaybackDetected();
            shouldShow = false;
          } else {
            shouldShow = false;
          }
        }

        // Update visibility state. Use a short debounce when showing to avoid
        // micro-flashes when UI toggles rapidly (e.g., stop -> immediate new play).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Cancel any pending show timer when visibility decisions change
          _showDelayTimer?.cancel();

          if (shouldShow && !_hasMediaItem) {
            // Debounce the show slightly so transient states don't flash the UI.
            _showDelayTimer = Timer(const Duration(milliseconds: 150), () {
              if (!mounted) return;
              // If we had an explicit manual dismiss and we're still awaiting a
              // new playback session, don't auto-show until _handleNewPlaybackDetected
              if (_awaitingNewPlaybackAfterDismiss) return;
              _showMiniPlayer();
            });
          } else if (!shouldShow && _hasMediaItem) {
            // If we need to hide, cancel pending show and hide immediately.
            _showDelayTimer?.cancel();
            _hideMiniPlayer();
          }

          _hasMediaItem = shouldShow;
        });

        // Don't render anything if not visible
        if (!_isVisible && !shouldShow) {
          return const SizedBox.shrink();
        }

        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildMiniPlayerContent(context),
          ),
        );
      },
    );
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_dragAnimationController?.isAnimating ?? false) {
      _dragAnimationController!.stop();
    }

    _rawHorizontalDragOffset = 0.0;
    _horizontalDragOffset = 0.0;
    _isDismissing = false;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _rawHorizontalDragOffset += details.delta.dx;
    final mapped = _mapDragWithResistance(_rawHorizontalDragOffset);

    setState(() {
      _horizontalDragOffset = mapped;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final rawAbs = _rawHorizontalDragOffset.abs();
    final velocityAbs = details.velocity.pixelsPerSecond.dx.abs();

    final resistanceWindow = _dismissThreshold * 0.4;

    if (rawAbs < resistanceWindow && velocityAbs < 650) {
      _animateHorizontalOffsetTo(0.0);
      return;
    }

    final shouldDismiss = rawAbs >= _dismissThreshold || velocityAbs > 850;

    if (shouldDismiss) {
      final sign = _rawHorizontalDragOffset.sign == 0
          ? 1.0
          : _rawHorizontalDragOffset.sign;
      final screenWidth = _screenWidth > 0 && _screenWidth.isFinite
          ? _screenWidth
          : (mounted ? MediaQuery.of(context).size.width : 0.0);
      final target = sign * (screenWidth + 120.0);
      _animateHorizontalOffsetTo(target);
    } else {
      _animateHorizontalOffsetTo(0.0);
    }
  }

  void _handleNewPlaybackDetected() {
    if (!_awaitingNewPlaybackAfterDismiss) return;

    _awaitingNewPlaybackAfterDismiss = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _awaitingNewPlaybackAfterDismiss = false;
        _lastDismissedMediaToken = null;
        _hasMediaItem = false;
        _isVisible = false;
        _horizontalDragOffset = 0.0;
        _rawHorizontalDragOffset = 0.0;
      });
    });
  }

  String? _mediaToken(MediaItem? item) {
    if (item == null) return null;
    if (item.id.isNotEmpty) return item.id;
    if (item.title.isNotEmpty) return 'title:${item.title}';
    return null;
  }

  double _mapDragWithResistance(double rawDx) {
    final sign = rawDx.sign == 0 ? 1.0 : rawDx.sign;
    final absRaw = rawDx.abs();

    final resistanceWindow = _dismissThreshold * 0.4;

    const firstFactor = 0.12;
    const midFactor = 0.6;

    if (absRaw <= resistanceWindow) {
      return sign * absRaw * firstFactor;
    }

    if (absRaw <= _dismissThreshold) {
      final firstDisplayed = resistanceWindow * firstFactor;
      final extra = absRaw - resistanceWindow;
      return sign * (firstDisplayed + extra * midFactor);
    }

    final firstDisplayed = resistanceWindow * firstFactor;
    final midDisplayed = (_dismissThreshold - resistanceWindow) * midFactor;
    final overflow = absRaw - _dismissThreshold;
    return sign * (firstDisplayed + midDisplayed + overflow);
  }

  void _animateHorizontalOffsetTo(double target, {Duration? duration}) {
    final controller = _dragAnimationController ??= AnimationController(
      duration: duration ?? const Duration(milliseconds: 300),
      vsync: this,
    );

    if (controller.isAnimating) {
      controller.stop();
    }

    controller.duration = duration ?? const Duration(milliseconds: 300);

    _dragAnimation =
        Tween<double>(begin: _horizontalDragOffset, end: target).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
        )..addListener(() {
          if (!mounted) return;
          setState(() {
            _horizontalDragOffset = _dragAnimation!.value;
          });
        });

    controller
      ..reset()
      ..forward().whenComplete(() async {
        if (!mounted) {
          return;
        }

        final sw = _screenWidth > 0 && _screenWidth.isFinite
            ? _screenWidth
            : MediaQuery.of(context).size.width;

        if (!_isDismissing && target.abs() > sw) {
          _isDismissing = true;
          await _dismissMiniPlayer();
        } else if (target == 0.0) {
          _rawHorizontalDragOffset = 0.0;
          _horizontalDragOffset = 0.0;
        }
      });
  }

  Future<void> _dismissMiniPlayer() async {
    final dismissedMedia = widget.musicManager.getCurrentMediaItem();
    String? dismissedToken;
    if (dismissedMedia != null && dismissedMedia.id.isNotEmpty) {
      dismissedToken = dismissedMedia.id;
    } else if (MiniMusicPlayer.musicName.isNotEmpty) {
      dismissedToken = 'title:${MiniMusicPlayer.musicName}';
    }

    if (mounted) {
      setState(() {
        _awaitingNewPlaybackAfterDismiss = true;
        _lastDismissedMediaToken = dismissedToken;
      });
    } else {
      _awaitingNewPlaybackAfterDismiss = true;
      _lastDismissedMediaToken = dismissedToken;
    }

    _hideMiniPlayer();

    try {
      await widget.musicManager.stopAndDisposeAll(reason: 'mini-dismiss');
    } catch (error, stackTrace) {
      developer.log(
        '[MiniMusicPlayer] Failed to stop audio during dismiss: $error',
        name: 'MiniMusicPlayer',
        error: error,
        stackTrace: stackTrace,
      );
    }

    widget.musicManager.clearProcessingAudioId();
    MiniMusicPlayer.musicName = '';
    MiniMusicPlayer.artistName = '';
    MiniMusicPlayer.musicImage = '';
    MiniMusicPlayer.mainPosition = 0.0;
    MiniMusicPlayer.maxDuration = 0.0;

    if (mounted) {
      setState(() {
        _hasMediaItem = false;
        _horizontalDragOffset = 0.0;
        _rawHorizontalDragOffset = 0.0;
      });
    }

    _isDismissing = false;
  }

  Widget _buildMiniPlayerContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _screenWidth = screenWidth;
    _dismissThreshold = (screenWidth * 0.25).clamp(100.0, screenWidth);
    final opacity = (1.0 - (_horizontalDragOffset.abs() / screenWidth)).clamp(
      0.0,
      1.0,
    );

    final miniPlayerCard = Container(
      height: _MiniPlayerConfig.height,
      margin: EdgeInsets.only(
        left: _MiniPlayerConfig.marginHorizontal,
        right: _MiniPlayerConfig.marginHorizontal,
      ),
      decoration: BoxDecoration(
        color: _MiniPlayerConfig.backgroundColor,
        borderRadius: BorderRadius.circular(_MiniPlayerConfig.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10.0,
            offset: const Offset(0, 4.0),
          ),
        ],
      ),
      child: StreamBuilder<MediaState>(
        stream: _mediaStateStream,
        initialData: MediaState(
          // Provide cached data as initial state
          MiniMusicPlayer.musicName.isNotEmpty
              ? MediaItem(
                  id: 'cached',
                  title: MiniMusicPlayer.musicName,
                  artist: MiniMusicPlayer.artistName,
                  artUri: MiniMusicPlayer.musicImage.isNotEmpty
                      ? Uri.parse(MiniMusicPlayer.musicImage)
                      : null,
                )
              : null,
          Duration(milliseconds: MiniMusicPlayer.mainPosition.toInt()),
          isPlaying: widget.musicManager.isPlaying,
        ),
        builder: (context, snapshot) {
          final mediaState = snapshot.data;

          // Always use the latest state or fallback to cached data
          final currentMediaItem =
              mediaState?.mediaItem ??
              widget.musicManager.getCurrentMediaItem();
          final currentPosition =
              mediaState?.position ??
              Duration(milliseconds: MiniMusicPlayer.mainPosition.toInt());
          final isCurrentlyPlaying =
              mediaState?.isPlaying ?? widget.musicManager.isPlaying;

          // If no media is available at all, don't show the mini player
          if (currentMediaItem == null && MiniMusicPlayer.musicName.isEmpty) {
            return const SizedBox.shrink();
          }

          // Calculate progress with enhanced fallback logic
          final (currentPositionMs, maxDurationMs) =
              _calculateProgressWithFallback(currentMediaItem, currentPosition);

          // Update static properties for persistent state
          if (currentMediaItem != null) {
            _updateStaticProperties(
              MediaState(
                currentMediaItem,
                currentPosition,
                isPlaying: isCurrentlyPlaying,
              ),
            );
          }

          return ValueListenableBuilder<int>(
            valueListenable: _refreshNotifier,
            builder: (context, _, __) => Stack(
              children: [
                // If there is an optimistic processing audio id but no media item yet,
                // render a lightweight optimistic skeleton so user knows the tap worked.
                if (widget.musicManager.processingAudioId.value != null &&
                    currentMediaItem == null)
                  _buildOptimisticMiniPlayer(
                    context,
                    widget.musicManager.processingAudioId.value!,
                  )
                else
                  _buildMainContent(
                    context,
                    MediaState(
                      currentMediaItem,
                      currentPosition,
                      isPlaying: isCurrentlyPlaying,
                    ),
                  ),
                _buildProgressBar(currentPositionMs, maxDurationMs),
              ],
            ),
          );
        },
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Transform.translate(
        offset: Offset(_horizontalDragOffset, 0),
        child: Opacity(opacity: opacity, child: miniPlayerCard),
      ),
    );
  }

  /// Optimistic mini player UI shown while the play request is processing
  Widget _buildOptimisticMiniPlayer(BuildContext context, String audioId) {
    return Container(
      height: _MiniPlayerConfig.height,
      padding: EdgeInsets.symmetric(
        horizontal: _MiniPlayerConfig.paddingHorizontal,
        vertical: _MiniPlayerConfig.paddingVertical,
      ),
      child: Row(
        children: [
          // Placeholder album art
          Container(
            width: _MiniPlayerConfig.albumArtSize,
            height: _MiniPlayerConfig.albumArtSize,
            decoration: BoxDecoration(
              color: appColors().gray[100],
              borderRadius: BorderRadius.circular(
                _MiniPlayerConfig.albumArtRadius,
              ),
            ),
            child: Center(
              child: Icon(Icons.music_note, color: appColors().gray[300]),
            ),
          ),
          SizedBox(width: _MiniPlayerConfig.spacing),
          // Textual skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 14.w,
                  width: double.infinity,
                  color: appColors().gray[200],
                ),
                SizedBox(height: 6.w),
                Container(
                  height: 12.w,
                  width: MediaQuery.of(context).size.width * 0.4,
                  color: appColors().gray[200],
                ),
              ],
            ),
          ),
          SizedBox(width: _MiniPlayerConfig.spacing),
          // Loading indicator + cancel
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 28.w,
                height: 28.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _MiniPlayerConfig.primaryColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Clear optimistic UI and any inflight processing flag
                  widget.musicManager.clearProcessingAudioId();
                },
                child: Text('Cancel', style: TextStyle(fontSize: 12.sp)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Combines media item and position streams for UI updates with enhanced state persistence
  Stream<MediaState> get _mediaStateStream =>
      Rx.combineLatest4<MediaItem?, Duration, bool, PlaybackState, MediaState>(
            // Enhanced media item stream that ensures state persistence
            _buildEnhancedMediaItemStream(),
            // Enhanced position stream that works for both playing and paused states
            _buildEnhancedPositionStream(),
            // Enhanced playing state stream
            _buildEnhancedPlayingStateStream(),
            // Include full playback state for comprehensive updates
            widget.musicManager.audioHandler?.playbackState ??
                Stream.value(PlaybackState()),
            (mediaItem, position, isPlaying, playbackState) {
              // Update static properties immediately for state persistence
              if (mediaItem != null) {
                MiniMusicPlayer.musicName = mediaItem.title;
                MiniMusicPlayer.artistName = mediaItem.artist ?? '';
                MiniMusicPlayer.musicImage = mediaItem.artUri?.toString() ?? '';
                MiniMusicPlayer.mainPosition = position.inMilliseconds
                    .toDouble();
                if (mediaItem.duration != null) {
                  MiniMusicPlayer.maxDuration = mediaItem
                      .duration!
                      .inMilliseconds
                      .toDouble();
                }
              }

              return MediaState(mediaItem, position, isPlaying: isPlaying);
            },
          )
          .distinct(
            (previous, next) =>
                // Use millisecond resolution so UI (progress bar) updates smoothly
                previous.mediaItem?.id == next.mediaItem?.id &&
                (previous.position.inMilliseconds ==
                    next.position.inMilliseconds) &&
                previous.isPlaying == next.isPlaying,
          )
          .handleError((error) {
            // Handle stream errors gracefully
            developer.log(
              '[ERROR][MiniMusicPlayer] Media state stream error: $error',
              name: 'MiniMusicPlayer',
              error: error,
            );
            // Return a fallback state based on cached data
            return MediaState(
              MiniMusicPlayer.musicName.isNotEmpty
                  ? MediaItem(
                      id: 'cached',
                      title: MiniMusicPlayer.musicName,
                      artist: MiniMusicPlayer.artistName,
                      artUri: MiniMusicPlayer.musicImage.isNotEmpty
                          ? Uri.parse(MiniMusicPlayer.musicImage)
                          : null,
                    )
                  : null,
              Duration(milliseconds: MiniMusicPlayer.mainPosition.toInt()),
              isPlaying: false,
            );
          });

  /// Enhanced media item stream that ensures persistence across states
  Stream<MediaItem?> _buildEnhancedMediaItemStream() {
    return Rx.merge([
      // Primary source: audio handler media item
      widget.musicManager.audioHandler?.mediaItem ?? Stream<MediaItem?>.empty(),
      // Fallback: simplified music manager current media item
      Stream.periodic(const Duration(milliseconds: 2000))
          .map((_) => widget.musicManager.getCurrentMediaItem())
          .where((item) => item != null),
      // Emergency fallback: static cached data
      Stream.periodic(const Duration(milliseconds: 5000))
          .map(
            (_) => MiniMusicPlayer.musicName.isNotEmpty
                ? MediaItem(
                    id: 'cached',
                    title: MiniMusicPlayer.musicName,
                    artist: MiniMusicPlayer.artistName,
                    artUri: MiniMusicPlayer.musicImage.isNotEmpty
                        ? Uri.parse(MiniMusicPlayer.musicImage)
                        : null,
                  )
                : null,
          )
          .where((item) => item != null),
    ]).distinct((prev, next) => prev?.id == next?.id);
  }

  /// Enhanced position stream that works for both playing and paused states
  Stream<Duration> _buildEnhancedPositionStream() {
    return Rx.merge([
      // Primary: AudioService position (works in all states)
      AudioService.position,
      // Secondary: Music manager position (with fallback)
      Stream.periodic(const Duration(milliseconds: 1000)).asyncMap((_) async {
        try {
          return await widget.musicManager.getCurrentPosition();
        } catch (e) {
          // Fallback to cached position
          return Duration(milliseconds: MiniMusicPlayer.mainPosition.toInt());
        }
      }),
      // Tertiary: Static cached position when all else fails
      Stream.periodic(const Duration(milliseconds: 2000)).map(
        (_) => Duration(milliseconds: MiniMusicPlayer.mainPosition.toInt()),
      ),
    ]).distinct((prev, next) => prev.inMilliseconds == next.inMilliseconds);
  }

  /// Enhanced playing state stream that ensures accurate state reporting
  Stream<bool> _buildEnhancedPlayingStateStream() {
    return Rx.merge([
      // Primary: audio handler playback state
      widget.musicManager.audioHandler?.playbackState.map(
            (state) => state.playing,
          ) ??
          Stream<bool>.empty(),
      // Secondary: simplified music manager state
      Stream.periodic(
        const Duration(milliseconds: 1000),
      ).map((_) => widget.musicManager.isPlaying),
    ]).distinct();
  }

  /// Calculates progress values for the progress bar with enhanced fallback
  (double, double) _calculateProgressWithFallback(
    MediaItem? mediaItem,
    Duration position,
  ) {
    // Primary source: current media item duration
    if (mediaItem?.duration != null) {
      final maxMs = mediaItem!.duration!.inMilliseconds.toDouble();
      final posMs = position.inMilliseconds.toDouble();

      // Update cached values for future fallback
      MiniMusicPlayer.maxDuration = maxMs;
      MiniMusicPlayer.mainPosition = posMs <= maxMs ? posMs : maxMs;

      return (MiniMusicPlayer.mainPosition, maxMs);
    }

    // Fallback: use cached values
    final posMs = position.inMilliseconds.toDouble();
    final cachedMax = MiniMusicPlayer.maxDuration > 0
        ? MiniMusicPlayer.maxDuration
        : posMs + 30000; // Default to 30s ahead if no duration

    MiniMusicPlayer.mainPosition = posMs <= cachedMax ? posMs : cachedMax;

    return (MiniMusicPlayer.mainPosition, cachedMax);
  }

  /// Updates static properties from media state
  void _updateStaticProperties(MediaState mediaState) {
    final mediaItem = mediaState.mediaItem;
    if (mediaItem != null) {
      MiniMusicPlayer.musicName = mediaItem.title;
      MiniMusicPlayer.artistName = mediaItem.artist ?? '';
      MiniMusicPlayer.musicImage = mediaItem.artUri?.toString() ?? '';
      MiniMusicPlayer.mainPosition = mediaState.position.inMilliseconds
          .toDouble();
    }
  }

  /// Builds the progress bar at the bottom with improved positioning
  Widget _buildProgressBar(double value, double maxValue) {
    return Positioned(
      bottom: 0.5.w,
      left: 0,
      right: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          // If user is actively dragging the progress, show the interactive value
          final displayedMs =
              _isInteractingWithProgress && _interactiveSeekingMs != null
              ? _interactiveSeekingMs!.clamp(0.0, maxValue)
              : value.clamp(0.0, maxValue);

          final progressRatio = (maxValue > 0)
              ? (displayedMs / maxValue).clamp(0.0, 1.0)
              : 0.0;

          // Account for the horizontal padding when positioning thumbs/dot.
          final paddingH = _MiniPlayerConfig.paddingHorizontal;
          final innerTrackWidth = (width - (2 * paddingH)).clamp(0.0, width);

          void performSeekFromOffset(Offset localPos) {
            final dx = localPos.dx.clamp(0.0, width);
            final ratio = width <= 0 ? 0.0 : (dx / width).clamp(0.0, 1.0);
            final targetMs = (ratio * maxValue).round();
            final target = Duration(milliseconds: targetMs);

            // Prefer the MusicManager wrapper; fallback to audioHandler.
            try {
              widget.musicManager.seek(target);
            } catch (e) {
              try {
                widget.musicManager.audioHandler?.seek(target);
              } catch (_) {}
            }

            // Update immediate UI cache for responsiveness
            MiniMusicPlayer.mainPosition = targetMs.toDouble();
            _refreshNotifier.value = _refreshNotifier.value + 1;
          }

          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) {
                  performSeekFromOffset(details.localPosition);
                },
                onHorizontalDragStart: (details) {
                  setState(() {
                    _isInteractingWithProgress = true;
                    // initialize with the current value
                    _interactiveSeekingMs = value;
                  });
                },
                onHorizontalDragUpdate: (details) {
                  final dx = details.localPosition.dx.clamp(0.0, width);
                  final ratio = width <= 0 ? 0.0 : (dx / width).clamp(0.0, 1.0);
                  final seekMs = (ratio * maxValue).toDouble();
                  setState(() {
                    _interactiveSeekingMs = seekMs;
                    MiniMusicPlayer.mainPosition = seekMs;
                  });
                  _refreshNotifier.value = _refreshNotifier.value + 1;
                },
                onHorizontalDragEnd: (details) {
                  if (_interactiveSeekingMs != null) {
                    final target = Duration(
                      milliseconds: _interactiveSeekingMs!.round(),
                    );
                    try {
                      widget.musicManager.seek(target);
                    } catch (e) {
                      widget.musicManager.audioHandler?.seek(target);
                    }
                  }
                  setState(() {
                    _isInteractingWithProgress = false;
                    _interactiveSeekingMs = null;
                  });
                },
                child: Container(
                  height: _MiniPlayerConfig.progressBarHeight + 6.w,
                  padding: EdgeInsets.symmetric(
                    horizontal: _MiniPlayerConfig.paddingHorizontal,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    children: [
                      // Background track
                      Container(
                        height: _MiniPlayerConfig.progressBarHeight,
                        decoration: BoxDecoration(
                          color: appColors().gray[100],
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                      ),
                      // Active progress (uses inner track width)
                      SizedBox(
                        width: innerTrackWidth,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progressRatio,
                          child: Container(
                            height: _MiniPlayerConfig.progressBarHeight,
                            decoration: BoxDecoration(
                              color: _MiniPlayerConfig.primaryColor,
                              borderRadius: BorderRadius.circular(4.w),
                            ),
                          ),
                        ),
                      ),

                      // Thumb indicator (positioned within the inner track)
                      Positioned(
                        left: ((innerTrackWidth * progressRatio) - (6.w / 2))
                            .clamp(0.0, innerTrackWidth - 6.w),
                        top: -((6.w - _MiniPlayerConfig.progressBarHeight) / 2),
                        child: Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 4.w,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Overlay dot similar to video mini player
              Builder(
                builder: (ctx) {
                  final dotSize = 12.w;
                  // filled width inside the padded track
                  final filledWidth = innerTrackWidth * progressRatio;
                  // left boundaries for the dot (respect padding)
                  final minLeft = _MiniPlayerConfig.paddingHorizontal;
                  final maxLeft =
                      _MiniPlayerConfig.paddingHorizontal +
                      innerTrackWidth -
                      dotSize;
                  final dotLeft = (minLeft + (filledWidth - dotSize / 2)).clamp(
                    minLeft,
                    maxLeft,
                  );

                  return Positioned(
                    left: dotLeft,
                    bottom:
                        3.w +
                        (_MiniPlayerConfig.progressBarHeight - dotSize) / 2,
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: _MiniPlayerConfig.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2.w,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: dotSize * 0.58,
                          height: dotSize * 0.58,
                          decoration: BoxDecoration(
                            color: _MiniPlayerConfig.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the main clickable content area
  Widget _buildMainContent(BuildContext context, MediaState? mediaState) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToFullPlayer(context),
        borderRadius: BorderRadius.circular(_MiniPlayerConfig.borderRadius),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.w, 5.w, 10.w, 10.w),
          child: Row(
            children: [
              _buildAlbumArt(mediaState),
              SizedBox(width: _MiniPlayerConfig.spacing),
              Expanded(child: _buildSongInfo(mediaState)),
              SizedBox(width: _MiniPlayerConfig.spacing),
              _buildPlayButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the album art widget
  Widget _buildAlbumArt(MediaState? mediaState) {
    final imageUrl =
        mediaState?.mediaItem?.artUri?.toString() ?? MiniMusicPlayer.musicImage;

    return Container(
      width: _MiniPlayerConfig.albumArtSize,
      height: _MiniPlayerConfig.albumArtSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_MiniPlayerConfig.albumArtRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2.0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_MiniPlayerConfig.albumArtRadius),
        child: RepaintBoundary(
          child: SmartImageWidget(
            imageUrl: imageUrl,
            width: _MiniPlayerConfig.albumArtSize,
            height: _MiniPlayerConfig.albumArtSize,
            fit: BoxFit.cover,
            placeholder: _buildImagePlaceholder(),
            errorWidget: _buildPlaceholderImage(),
          ),
        ),
      ),
    );
  }

  /// Builds placeholder for loading images
  Widget _buildImagePlaceholder() {
    return Container(
      color: appColors().gray[50],
      child: Icon(
        Icons.music_note_rounded,
        color: appColors().gray[300],
        size: 24.0,
      ),
    );
  }

  /// Builds the default placeholder image
  Widget _buildPlaceholderImage() {
    return Image.asset(_MiniPlayerConfig.placeholderImage, fit: BoxFit.cover);
  }

  /// Builds the song information section
  Widget _buildSongInfo(MediaState? mediaState) {
    final title = mediaState?.mediaItem?.title ?? MiniMusicPlayer.musicName;
    final artist = mediaState?.mediaItem?.artist ?? MiniMusicPlayer.artistName;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available height and adjust font sizes accordingly
        final availableHeight = constraints.maxHeight;
        final shouldUseCompactLayout = availableHeight < 50.w;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: shouldUseCompactLayout
                    ? AppSizes.fontMedium * 0.9
                    : AppSizes.fontMedium,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontFamily: 'Poppins',
                letterSpacing: -0.2,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: shouldUseCompactLayout ? 1.0 : 2.0),
            Text(
              artist,
              style: TextStyle(
                fontSize: shouldUseCompactLayout
                    ? AppSizes.fontSmall * 0.9
                    : AppSizes.fontSmall,
                color: appColors().gray[700],
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }

  /// Builds the play/pause button with hybrid state management for maximum responsiveness
  Widget _buildPlayButton() {
    return StreamBuilder<PlaybackState>(
      stream: widget.audioHandler?.playbackState,
      builder: (context, playbackSnapshot) {
        return ListenableBuilder(
          listenable: widget.musicManager,
          builder: (context, child) {
            // Use the most immediate source for play/pause state
            final streamIsPlaying = playbackSnapshot.data?.playing ?? false;
            final managerIsPlaying = widget.musicManager.isPlaying;

            // Prefer stream data if available, fallback to manager
            final isPlaying = playbackSnapshot.hasData
                ? streamIsPlaying
                : managerIsPlaying;

            final streamProcessingState =
                playbackSnapshot.data?.processingState;
            final isLoading =
                streamProcessingState == AudioProcessingState.loading ||
                streamProcessingState == AudioProcessingState.buffering ||
                widget.musicManager.isLoading ||
                widget.musicManager.isBuffering;

            return Container(
              width: _MiniPlayerConfig.playButtonSize,
              height: _MiniPlayerConfig.playButtonSize,
              decoration: _buildButtonDecoration(),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    _MiniPlayerConfig.playButtonSize / 2,
                  ),
                  onTap: () => _handlePlayPause(isPlaying),
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _MiniPlayerConfig.primaryColor,
                              ),
                            ),
                          )
                        : _buildPlayIcon(isPlaying),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Creates the button decoration
  BoxDecoration _buildButtonDecoration() {
    return BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: Colors.grey[200]!, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8.0,
          offset: const Offset(0, 2.0),
        ),
      ],
    );
  }

  /// Builds the animated play/pause icon
  Widget _buildPlayIcon(bool isPlaying) {
    return AnimatedSwitcher(
      duration: _MiniPlayerConfig.animationDuration,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        key: ValueKey<bool>(isPlaying),
        color: _MiniPlayerConfig.primaryColor,
        size: _MiniPlayerConfig.playIconSize,
      ),
    );
  }

  /// Handles play/pause button tap with enhanced state management
  void _handlePlayPause(bool isPlaying) {
    HapticFeedback.lightImpact();

    developer.log(
      '[MiniMusicPlayer] Play/Pause tapped - Current state: $isPlaying',
      name: 'MiniMusicPlayer',
    );

    // Enhanced state management: Use ONLY MusicManager for consistency
    try {
      if (isPlaying) {
        widget.musicManager.pause();
        developer.log('[MiniMusicPlayer] Pause command sent');
      } else {
        widget.musicManager.play();
        developer.log('[MiniMusicPlayer] Play command sent');
      }
      // Request a lightweight refresh for a small number of listeners (e.g. button)
      _refreshNotifier.value = _refreshNotifier.value + 1;
    } catch (e) {
      developer.log(
        '[MiniMusicPlayer] Error in play/pause action: $e',
        name: 'MiniMusicPlayer',
      );
    }
  }

  /// Navigates to the full music player with proper navigation context
  void _navigateToFullPlayer(BuildContext context) async {
    HapticFeedback.lightImpact();

    // Use navigation guard to prevent duplicate navigation
    if (!PerformanceDebouncer.canNavigate('mini_player_to_full')) {
      return;
    }

    // Null safety checks for audio handler
    if (widget.audioHandler == null) {
      return;
    }

    // Get current queue and media info from audio handler
    final currentQueue = widget.audioHandler!.queue.value;
    final currentMediaItem = widget.audioHandler!.mediaItem.value;
    final currentIndex = currentQueue.indexWhere(
      (item) => item.id == currentMediaItem?.id,
    );

    // Convert MediaItems back to DataMusic format using existing global data
    List<DataMusic> currentMusicList = [];
    int currentIndexToUse = 0;

    // Use existing global variables if available to avoid API calls
    if (listCopy.isNotEmpty && currentQueue.isNotEmpty) {
      currentMusicList = listCopy;
      currentIndexToUse = currentIndex >= 0 ? currentIndex : indixes;
    } else if (currentQueue.isNotEmpty) {
      // Fallback: create minimal DataMusic objects from MediaItems
      currentMusicList = currentQueue.map((mediaItem) {
        return DataMusic(
          int.tryParse(mediaItem.id) ?? 0, // id
          mediaItem.artUri?.toString() ?? '', // image
          mediaItem.id, // audio (URL)
          '00:00', // audio_duration - default
          mediaItem.title, // audio_title
          '', // audio_slug
          0, // audio_genre_id
          '', // artist_id
          mediaItem.artist ?? '', // artists_name
          '', // audio_language
          0, // listening_count
          0, // is_featured
          0, // is_trending
          '', // created_at
          0, // is_recommended
          '0', // favourite
          '', // download_price
          '', // lyrics
        );
      }).toList();
      currentIndexToUse = currentIndex >= 0 ? currentIndex : 0;
    }

    // Navigate directly to MusicPlayerUI to prevent queue reinitialization
    if (currentMusicList.isNotEmpty) {
      // Explicitly pause the visualizer during the transition to ensure the
      // original screen doesn't remain in a paused visual state when we
      // return. We'll resume after the route is popped.
      debugPrint(
        '[MiniMusicPlayer] Preparing to navigate to full player (mini_player_to_full)',
      );
      debugPrint('[MiniMusicPlayer] Calling pauseVisualizer()');
      await EnhancedAudioVisualizerService.pauseVisualizer();
      debugPrint('[MiniMusicPlayer] pauseVisualizer() completed');
      debugPrint(
        '[MiniMusicPlayer] Calling PerformanceDebouncer.safePush for mini_player_to_full',
      );
      PerformanceDebouncer.safePush(
        context,
        MaterialPageRoute(
          builder: (context) => MusicPlayerUI(
            widget.audioHandler!,
            MiniMusicPlayer.musicImage.isNotEmpty
                ? MiniMusicPlayer.musicImage
                : 'assets/images/song_placeholder.png', // pathImage
            "miniPlayer", // audioPath - source identifier
            currentMusicList, // listData
            '', // catImages - not needed for mini player navigation
            currentIndexToUse, // index
            false, // isOffline
            "miniPlayer", // audioPathMain - source identifier
            isOpn: true, // for proper modal behavior
            ontap: () {
              // Simple back navigation - just pop the full screen
              Navigator.of(context).pop();
            },
            skipQueueSetup:
                true, // CRITICAL: Skip queue setup to prevent song restart
            queueAlreadySetup: true, // Queue is already set up and playing
          ),
          // Make it a fullscreen modal
          fullscreenDialog: true,
          settings: const RouteSettings(name: '/mini_player_to_full'),
        ),
        navigationKey: 'mini_player_to_full',
      ).whenComplete(() async {
        debugPrint(
          '[MiniMusicPlayer] safePush completed for mini_player_to_full',
        );
        // Resume visualizer after returning from the full player
        debugPrint('[MiniMusicPlayer] Full player popped, resuming visualizer');
        await EnhancedAudioVisualizerService.resumeVisualizer();
        debugPrint('[MiniMusicPlayer] resumeVisualizer() completed');
      });
    } else {
      // Fallback to Music widget if no data available (shouldn't happen in normal flow)
      debugPrint(
        '[MiniMusicPlayer] Preparing to navigate to full player (mini_player_to_full_fallback)',
      );
      debugPrint('[MiniMusicPlayer] Calling pauseVisualizer() (fallback)');
      await EnhancedAudioVisualizerService.pauseVisualizer();
      debugPrint('[MiniMusicPlayer] pauseVisualizer() completed (fallback)');
      debugPrint(
        '[MiniMusicPlayer] Calling PerformanceDebouncer.safePush for mini_player_to_full_fallback',
      );
      PerformanceDebouncer.safePush(
        context,
        MaterialPageRoute(
          builder: (context) => Music(
            widget.audioHandler!,
            idTag,
            type,
            currentMusicList,
            "miniPlayer", // Source identifier
            currentIndexToUse,
            true, // isOpn = true for proper modal behavior
            () {
              // Simple back navigation - just pop the full screen
              Navigator.of(context).pop();
            },
          ),
          fullscreenDialog: true,
          settings: const RouteSettings(name: '/mini_player_to_full_fallback'),
        ),
        navigationKey: 'mini_player_to_full_fallback',
      ).whenComplete(() async {
        debugPrint(
          '[MiniMusicPlayer] safePush completed for mini_player_to_full_fallback',
        );
        debugPrint(
          '[MiniMusicPlayer] Full player (fallback) popped, resuming visualizer',
        );
        await EnhancedAudioVisualizerService.resumeVisualizer();
        debugPrint('[MiniMusicPlayer] resumeVisualizer() completed (fallback)');
      });
    }
  }
}

/// Represents the current media state combining media item and position
class MediaState {
  final MediaItem? mediaItem;
  final Duration position;
  final bool isPlaying;

  const MediaState(this.mediaItem, this.position, {this.isPlaying = false});
}
