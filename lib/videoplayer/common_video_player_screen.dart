import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:jainverse/videoplayer/video_player_widget.dart';

class CommonVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  // overlay timing configuration (ms)
  final int overlayVisibleMs;
  final int fadeDurationMs;
  final int scaleDurationMs;

  const CommonVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
    this.overlayVisibleMs = 900,
    this.fadeDurationMs = 300,
    this.scaleDurationMs = 160,
  });

  @override
  State<CommonVideoPlayerScreen> createState() =>
      _CommonVideoPlayerScreenState();
}

class _CommonVideoPlayerScreenState extends State<CommonVideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  bool _isFavorite = false;

  Widget _buildVideoHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4.w,
            offset: Offset(0, 2.w),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black87,
              size: 20.w,
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
            padding: EdgeInsets.all(8.w),
            constraints: BoxConstraints(),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              widget.videoTitle.isNotEmpty ? widget.videoTitle : 'Video',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 17.sp,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? appColors().primaryColorApp : Colors.black54,
              size: 22.w,
            ),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
            padding: EdgeInsets.all(8.w),
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

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
    // Controller will be provided by the child CommonVideoPlayer via
    // the onControllerInitialized callback.
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    MusicPlayerStateManager().setNavigationVisibility(true);
    super.dispose();
  }

  // Double-tap skip handling is now contained in the CommonVideoPlayer widget.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVideoHeader(),
            // Fixed 16:9 video container (uses extracted CommonVideoPlayer)
            Container(
              width: double.infinity,
              color: Colors.black,
              child: VideoPlayerWidget(
                videoUrl: widget.videoUrl,
                overlayVisibleMs: widget.overlayVisibleMs,
                fadeDurationMs: widget.fadeDurationMs,
                scaleDurationMs: widget.scaleDurationMs,
                onControllerInitialized: (controller) {
                  // store controller reference so the screen can show duration
                  setState(() {
                    _videoPlayerController = controller;
                  });
                },
              ),
            ),
            // Enhanced video details section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video info section
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.videoTitle.isNotEmpty
                                ? widget.videoTitle
                                : 'Video Title',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 18.sp,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Icon(
                                Icons.remove_red_eye_outlined,
                                size: 18.w,
                                color: Colors.grey.shade600,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                '0 views',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14.sp,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Icon(
                                Icons.access_time,
                                size: 18.w,
                                color: Colors.grey.shade600,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                _videoPlayerController != null &&
                                        _videoPlayerController!
                                            .value
                                            .isInitialized
                                    ? _formatDuration(
                                      _videoPlayerController!.value.duration,
                                    )
                                    : '--:--',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Placeholder for more content
                    SizedBox(height: 8.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Video description will appear here. You can add detailed information about the video content.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14.sp,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
