import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:video_player/video_player.dart';

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
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  VoidCallback? _videoListener;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    MusicPlayerStateManager().setNavigationVisibility(false);
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
              playedColor: Colors.red,
              handleColor: Colors.redAccent,
              backgroundColor: Colors.white,
              bufferedColor: Colors.grey,
            ),
            placeholder: Container(color: Colors.black),
            autoInitialize: true,
          );
        });
      });
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video player at the top, full width
            AspectRatio(
              aspectRatio:
                  _chewieController != null
                      ? _videoPlayerController.value.aspectRatio
                      : 16 / 9,
              child:
                  _chewieController != null
                      ? Chewie(controller: _chewieController!)
                      : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
            ),
            // Placeholder for video details (future)
            Expanded(
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: Text(
                    'Video details will appear here.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
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
