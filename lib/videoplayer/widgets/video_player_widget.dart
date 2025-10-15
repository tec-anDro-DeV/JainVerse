import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/video_cache_service.dart';
import 'package:video_player/video_player.dart';

/// A self-contained video player widget that handles caching, Chewie
/// controller creation and a double-tap skip overlay.
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final int overlayVisibleMs;
  final int fadeDurationMs;
  final int scaleDurationMs;
  final int skipSeconds;

  /// Notifies parent when the [VideoPlayerController] is initialized and ready.
  final ValueChanged<VideoPlayerController>? onControllerInitialized;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.overlayVisibleMs = 900,
    this.fadeDurationMs = 300,
    this.scaleDurationMs = 160,
    this.skipSeconds = 10,
    this.onControllerInitialized,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  VoidCallback? _videoListener;
  final VideoCacheService _videoCacheService = VideoCacheService();
  bool _usingCachedFile = false;
  bool _playbackError = false;
  String _errorMessage = '';
  bool _audioDisabled = false;

  // Double-tap skip state
  bool _showSkipOverlay = false;
  bool _skipForward = true;
  Timer? _skipOverlayTimer;
  TapDownDetails? _lastDoubleTapDownDetails;
  double _skipOverlayOpacity = 0.0;
  int _accumulatedSeconds = 0;
  double _skipOverlayScale = 0.9;

  @override
  void initState() {
    super.initState();
    _prepareControllerWithCache(widget.videoUrl);
  }

  Future<void> _prepareControllerWithCache(String url) async {
    setState(() {
      _playbackError = false;
      _errorMessage = '';
    });

    try {
      // Check for cached file first
      final cached = await _videoCacheService.getCachedFile(url);
      if (cached != null && cached.existsSync()) {
        _usingCachedFile = true;
        _videoPlayerController = VideoPlayerController.file(cached);
        if (kDebugMode) {
          debugPrint('[VideoPlayer] Using cached file');
        }
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(url),
        );
        if (kDebugMode) {
          debugPrint('[VideoPlayer] Using network URL');
        }

        // Start background caching
        _videoCacheService
            .cacheFile(url)
            .then((file) async {
              if (mounted &&
                  !_usingCachedFile &&
                  _videoPlayerController.value.isInitialized) {
                if (kDebugMode) {
                  debugPrint(
                    '[VideoPlayer] Cache completed, switching to cached file',
                  );
                }
                await _switchToCachedFile(file);
              }
            })
            .catchError((e) {
              if (kDebugMode) {
                debugPrint('[VideoPlayer] Cache error: $e');
              }
            });
      }

      // Add listener before initialization
      _videoListener = () {
        if (mounted) {
          // Check for errors but don't stop playback if it's just audio
          if (_videoPlayerController.value.hasError) {
            final error = _videoPlayerController.value.errorDescription ?? '';
            if (error.contains('audio') ||
                error.contains('AudioTrack') ||
                error.contains('AudioSink')) {
              // Audio error - mark as disabled but continue
              if (!_audioDisabled) {
                _audioDisabled = true;
                if (kDebugMode) {
                  debugPrint(
                    '[VideoPlayer] Audio disabled due to error: $error',
                  );
                }
              }
            }
          }
          setState(() {});
        }
      };
      _videoPlayerController.addListener(_videoListener!);

      // Initialize controller with error handling
      try {
        await _videoPlayerController.initialize();

        if (kDebugMode) {
          debugPrint('[VideoPlayer] Video initialized successfully');
          debugPrint(
            '[VideoPlayer] Size: ${_videoPlayerController.value.size}',
          );
          debugPrint(
            '[VideoPlayer] Duration: ${_videoPlayerController.value.duration}',
          );
        }

        // Check if initialization was successful
        if (!_videoPlayerController.value.hasError) {
          // Set volume to 0 to minimize audio issues
          try {
            await _videoPlayerController.setVolume(0.0);
          } catch (volumeError) {
            if (kDebugMode) {
              debugPrint(
                '[VideoPlayer] Volume control error (non-critical): $volumeError',
              );
            }
          }

          setState(() {
            _chewieController?.dispose();
            _chewieController = _createChewieController(true);
          });

          widget.onControllerInitialized?.call(_videoPlayerController);
        } else {
          throw Exception(
            'Video controller has error: ${_videoPlayerController.value.errorDescription}',
          );
        }
      } catch (initError) {
        if (kDebugMode) {
          debugPrint('[VideoPlayer] Initialization error: $initError');
        }
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoPlayer] Critical error: $e');
      }

      // Determine error message
      String errorMsg = 'Unable to play video';
      if (e.toString().contains('AudioTrack') ||
          e.toString().contains('AudioSink') ||
          e.toString().contains('audio')) {
        errorMsg =
            'Audio playback not supported on this device.\nVideo may still work on a physical device.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMsg = 'Network error. Please check your connection.';
      }

      setState(() {
        _playbackError = true;
        _errorMessage = errorMsg;
      });
    }
  }

  Future<void> _switchToCachedFile(File file) async {
    try {
      final currentPosition = _videoPlayerController.value.position;
      final wasPlaying = _videoPlayerController.value.isPlaying;

      if (_videoListener != null) {
        _videoPlayerController.removeListener(_videoListener!);
      }

      await _videoPlayerController.pause();
      await _videoPlayerController.dispose();

      _usingCachedFile = true;
      _videoPlayerController = VideoPlayerController.file(file);

      await _videoPlayerController.initialize();
      await _videoPlayerController.seekTo(currentPosition);

      if (wasPlaying) {
        await _videoPlayerController.play();
      }

      _videoListener = () {
        if (mounted) setState(() {});
      };
      _videoPlayerController.addListener(_videoListener!);

      setState(() {
        _chewieController?.dispose();
        _chewieController = _createChewieController(wasPlaying);
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[VideoPlayer] Error switching to cached file: $e');
      }
    }
  }

  ChewieController _createChewieController(bool autoPlay) {
    return ChewieController(
      videoPlayerController: _videoPlayerController,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      autoPlay: autoPlay,
      looping: false,
      showControls: true,
      allowFullScreen: true,
      deviceOrientationsOnEnterFullScreen: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
      fullScreenByDefault: false,
      allowMuting: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: appColors().primaryColorApp,
        handleColor: appColors().primaryColorApp.withOpacity(0.8),
        backgroundColor: Colors.white24,
        bufferedColor: Colors.white38,
      ),
      placeholder: Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: appColors().primaryColorApp),
        ),
      ),
      autoInitialize: true,
    );
  }

  Future<void> _retryInitialization() async {
    // dispose previous controller if any
    try {
      if (_videoListener != null) {
        _videoPlayerController.removeListener(_videoListener!);
      }
      await _videoPlayerController.dispose();
      _chewieController?.dispose();
      _chewieController = null;
    } catch (_) {}

    _usingCachedFile = false;
    await _prepareControllerWithCache(widget.videoUrl);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    if (_videoListener != null) {
      _videoPlayerController.removeListener(_videoListener!);
    }
    _videoPlayerController.dispose();
    _skipOverlayTimer?.cancel();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;
    final tappedRight = dx > (screenWidth / 2);
    if (_skipOverlayTimer == null || _skipForward != tappedRight) {
      _accumulatedSeconds = 0;
    }
    _skipForward = tappedRight;

    if (!_videoPlayerController.value.isInitialized) return;

    final current = _videoPlayerController.value.position;
    final total = _videoPlayerController.value.duration;
    Duration target;
    _accumulatedSeconds += widget.skipSeconds;

    if (tappedRight) {
      target = current + Duration(seconds: _accumulatedSeconds);
      if (target > total) target = total;
    } else {
      target = current - Duration(seconds: _accumulatedSeconds);
      if (target < Duration.zero) target = Duration.zero;
    }

    _videoPlayerController.seekTo(target);

    _skipOverlayTimer?.cancel();
    setState(() {
      _showSkipOverlay = true;
      _skipOverlayOpacity = 1.0;
      _skipOverlayScale = 1.05;
    });

    _skipOverlayTimer = Timer(
      Duration(milliseconds: widget.overlayVisibleMs),
      () {
        if (!mounted) return;
        setState(() {
          _skipOverlayOpacity = 0.0;
          _skipOverlayScale = 0.9;
        });
        Timer(Duration(milliseconds: widget.fadeDurationMs), () {
          if (mounted) {
            setState(() {
              _showSkipOverlay = false;
              _accumulatedSeconds = 0;
            });
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 16 / 9, child: _buildVideoContent());
  }

  Widget _buildVideoContent() {
    if (_playbackError) {
      return _buildErrorWidget();
    }

    if (_chewieController == null) {
      return _buildLoadingWidget();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: Chewie(controller: _chewieController!)),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTapDown: (details) => _lastDoubleTapDownDetails = details,
            onDoubleTap: () {
              if (_lastDoubleTapDownDetails != null) {
                _onDoubleTapDown(_lastDoubleTapDownDetails!);
              } else {
                final center = TapDownDetails(
                  globalPosition: Offset(
                    MediaQuery.of(context).size.width / 2,
                    MediaQuery.of(context).size.height / 2,
                  ),
                );
                _onDoubleTapDown(center);
              }
            },
          ),
        ),
        if (_showSkipOverlay) _buildSkipOverlay(),
        if (_audioDisabled) _buildAudioDisabledBanner(),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: appColors().primaryColorApp,
              strokeWidth: 3.w,
            ),
            SizedBox(height: 16.h),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.white70, size: 48.w),
              SizedBox(height: 16.h),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'Unable to play video',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14.sp),
              ),
              if (Platform.isAndroid) ...[
                SizedBox(height: 8.h),
                Text(
                  'Note: Emulators may have audio issues',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12.sp,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              SizedBox(height: 20.h),
              ElevatedButton.icon(
                onPressed: _retryInitialization,
                icon: Icon(Icons.refresh, size: 18.w),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors().primaryColorApp,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _skipOverlayOpacity,
          duration: Duration(milliseconds: widget.fadeDurationMs),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: _skipOverlayScale,
            duration: Duration(milliseconds: widget.scaleDurationMs),
            curve: Curves.easeOutBack,
            child: Container(
              alignment:
                  _skipForward ? Alignment.centerRight : Alignment.centerLeft,
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _skipForward ? Icons.fast_forward : Icons.fast_rewind,
                    color: Colors.white.withOpacity(0.95),
                    size: 36.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '${_accumulatedSeconds}s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioDisabledBanner() {
    return Positioned(
      top: 8.h,
      left: 8.w,
      right: 8.w,
      child: IgnorePointer(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_off, color: Colors.white70, size: 16.w),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  'Audio unavailable on emulator',
                  style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
