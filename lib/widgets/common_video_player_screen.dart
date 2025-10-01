import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:jainverse/utils/video_cache_service.dart';

class CommonVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;

  const CommonVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
  });

  @override
  State<CommonVideoPlayerScreen> createState() =>
      _CommonVideoPlayerScreenState();
}

class _CommonVideoPlayerScreenState extends State<CommonVideoPlayerScreen> {
  Widget _buildVideoHeader() {
    // Use ScreenUtil for responsive sizing
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8.w,
            offset: Offset(0, 2.w),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.w),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              widget.videoTitle.isNotEmpty ? widget.videoTitle : 'Video',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 18.w,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? appColors().primaryColorApp : Colors.black,
              size: 24.w,
            ),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
        ],
      ),
    );
  }

  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  VoidCallback? _videoListener;
  bool _isFavorite = false;
  // Video cache service
  final VideoCacheService _videoCacheService = VideoCacheService();
  bool _usingCachedFile = false;
  bool _cacheDisabledDueToSize = false;

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    // TODO: Add favorite logic (API, local storage, etc.)
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    MusicPlayerStateManager().setNavigationVisibility(false);
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
        // Check whether we should cache this file (avoid huge files)
        final shouldCache = await _videoCacheService.shouldCache(url);
        if (shouldCache) {
          // Start background download to cache file for smoother seeks later
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
                        handleColor: appColors().primaryColorApp.withOpacity(
                          0.8,
                        ),
                        backgroundColor: Colors.white,
                        bufferedColor: Colors.grey,
                      ),
                      placeholder: Container(color: Colors.black),
                      autoInitialize: true,
                    );
                  });
                }
              })
              .catchError((_) {});
        } else {
          // Don't attempt to cache large files
          _cacheDisabledDueToSize = true;
        }
      }

      _videoListener = () {
        if (mounted) setState(() {});
      };
      _videoPlayerController.addListener(_videoListener!);
      await _videoPlayerController.initialize();
      setState(() {
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
            backgroundColor: Colors.white,
            bufferedColor: Colors.grey,
          ),
          placeholder: Container(color: Colors.black),
          autoInitialize: true,
        );
      });
    } catch (e) {
      // fallback to network
      _videoPlayerController = VideoPlayerController.network(widget.videoUrl)
        ..initialize().then((_) {
          _videoListener = () {
            if (mounted) setState(() {});
          };
          _videoPlayerController.addListener(_videoListener!);
          setState(() {
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
                backgroundColor: Colors.white,
                bufferedColor: Colors.grey,
              ),
              placeholder: Container(color: Colors.black),
              autoInitialize: true,
            );
          });
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    MusicPlayerStateManager().setNavigationVisibility(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVideoHeader(),
            // Video player below the header
            AspectRatio(
              aspectRatio:
                  _chewieController != null
                      ? _videoPlayerController.value.aspectRatio
                      : 16 / 9,
              child: Stack(
                children: [
                  _chewieController != null
                      ? Chewie(controller: _chewieController!)
                      : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                  if (_cacheDisabledDueToSize)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 6.w,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6.w),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 14.w,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Large file: streaming only',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.w,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Placeholder for video details (future)
            Expanded(
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Text(
                    'Video details will appear here.',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
