import 'dart:async';

import 'package:chewie/chewie.dart';
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
    Key? key,
    required this.videoUrl,
    this.overlayVisibleMs = 900,
    this.fadeDurationMs = 300,
    this.scaleDurationMs = 160,
    this.skipSeconds = 10,
    this.onControllerInitialized,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  VoidCallback? _videoListener;
  final VideoCacheService _videoCacheService = VideoCacheService();
  bool _usingCachedFile = false;

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
    try {
      final cached = await _videoCacheService.getCachedFile(url);
      if (cached != null && cached.existsSync()) {
        _usingCachedFile = true;
        _videoPlayerController = VideoPlayerController.file(cached);
      } else {
        _videoPlayerController = VideoPlayerController.network(url);
        // background cache
        _videoCacheService
            .cacheFile(url)
            .then((file) async {
              if (mounted && !_usingCachedFile) {
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
                if (wasPlaying) await _videoPlayerController.play();
                _videoListener = () {
                  if (mounted) setState(() {});
                };
                _videoPlayerController.addListener(_videoListener!);
                setState(() {
                  // dispose previous ChewieController to avoid resource leaks
                  _chewieController?.dispose();
                  _chewieController = ChewieController(
                    videoPlayerController: _videoPlayerController,
                    aspectRatio: _videoPlayerController.value.aspectRatio,
                    autoPlay: wasPlaying,
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
                        child: CircularProgressIndicator(
                          color: appColors().primaryColorApp,
                        ),
                      ),
                    ),
                    autoInitialize: true,
                  );
                });
              }
            })
            .catchError((_) {});
      }

      _videoListener = () {
        if (mounted) setState(() {});
      };
      _videoPlayerController.addListener(_videoListener!);
      await _videoPlayerController.initialize();
      setState(() {
        // dispose previous ChewieController to avoid resource leaks
        _chewieController?.dispose();
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          aspectRatio: _videoPlayerController.value.aspectRatio,
          autoPlay: true,
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
              child: CircularProgressIndicator(
                color: appColors().primaryColorApp,
              ),
            ),
          ),
          autoInitialize: true,
        );
      });

      // notify parent that controller is ready
      widget.onControllerInitialized?.call(_videoPlayerController);
    } catch (e) {
      _videoPlayerController = VideoPlayerController.network(widget.videoUrl)
        ..initialize().then((_) {
          _videoListener = () {
            if (mounted) setState(() {});
          };
          _videoPlayerController.addListener(_videoListener!);
          setState(() {
            // dispose previous ChewieController to avoid resource leaks
            _chewieController?.dispose();
            _chewieController = ChewieController(
              videoPlayerController: _videoPlayerController,
              aspectRatio: _videoPlayerController.value.aspectRatio,
              autoPlay: true,
              looping: false,
              showControls: true,
              allowFullScreen: true,
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
                  child: CircularProgressIndicator(
                    color: appColors().primaryColorApp,
                  ),
                ),
              ),
              autoInitialize: true,
            );
          });

          widget.onControllerInitialized?.call(_videoPlayerController);
        });
    }
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
    return AspectRatio(
      aspectRatio: 16 / 9,
      child:
          _chewieController != null
              ? Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Chewie(controller: _chewieController!),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTapDown:
                          (details) => _lastDoubleTapDownDetails = details,
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
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _showSkipOverlay ? _skipOverlayOpacity : 0.0,
                        duration: Duration(milliseconds: widget.fadeDurationMs),
                        curve: Curves.easeOut,
                        child: AnimatedScale(
                          scale: _skipOverlayScale,
                          duration: Duration(
                            milliseconds: widget.scaleDurationMs,
                          ),
                          curve: Curves.easeOutBack,
                          child: Container(
                            alignment:
                                _skipForward
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            padding: EdgeInsets.symmetric(horizontal: 40.w),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _skipForward
                                      ? Icons.fast_forward
                                      : Icons.fast_rewind,
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
                  ),
                ],
              )
              : Container(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    color: appColors().primaryColorApp,
                    strokeWidth: 3.w,
                  ),
                ),
              ),
    );
  }
}
