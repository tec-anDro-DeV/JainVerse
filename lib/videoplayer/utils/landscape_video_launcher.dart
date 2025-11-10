import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/landscape_video_player.dart';

/// Utility class for launching the landscape video player
class LandscapeVideoLauncher {
  /// Launch the landscape video player in full-screen mode
  ///
  /// This will push a new route with the landscape player and automatically
  /// handle orientation changes and system UI configuration.
  ///
  /// Example:
  /// ```dart
  /// LandscapeVideoLauncher.launch(
  ///   context: context,
  ///   videoUrl: 'https://example.com/video.mp4',
  ///   videoId: 'video123',
  ///   title: 'My Video',
  ///   channelName: 'My Channel',
  /// );
  /// ```
  static Future<void> launch({
    required BuildContext context,
    required String videoUrl,
    required String videoId,
    String? title,
    String? channelName,
    String? thumbnailUrl,
  }) {
    // Ensure the system UI and device orientation are set to landscape
    // before pushing the route so we avoid an extra rotation/flicker.
    return () async {
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } catch (_) {}

      return Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LandscapeVideoPlayer(
            videoUrl: videoUrl,
            videoId: videoId,
            title: title,
            channelName: channelName,
            thumbnailUrl: thumbnailUrl,
          ),
          fullscreenDialog: true,
        ),
      );
    }();
  }

  /// Replace the current route with the landscape video player
  ///
  /// Use this when you want to replace the current screen instead of
  /// pushing a new route on the navigation stack.
  static Future<void> replace({
    required BuildContext context,
    required String videoUrl,
    required String videoId,
    String? title,
    String? channelName,
    String? thumbnailUrl,
  }) {
    return () async {
      try {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } catch (_) {}

      return Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LandscapeVideoPlayer(
            videoUrl: videoUrl,
            videoId: videoId,
            title: title,
            channelName: channelName,
            thumbnailUrl: thumbnailUrl,
          ),
          fullscreenDialog: true,
        ),
      );
    }();
  }
}
