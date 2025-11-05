import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../videoplayer/services/video_player_theme_service.dart';
import '../managers/media_coordinator.dart';
import '../managers/music_manager.dart';
import '../videoplayer/models/video_item.dart';
import '../videoplayer/screens/video_player_view.dart';

/// Helper function to launch the new video player
/// This replaces the old CommonVideoPlayerScreen navigation
Future<void> launchVideoPlayer(
  BuildContext context, {
  required String videoUrl,
  required String videoId,
  String? videoTitle,
  String? videoSubtitle,
  String? thumbnailUrl,
  VideoItem? videoItem,
  List<String>? playlist,
  int? playlistIndex,
}) async {
  // Ensure any active music playback is fully stopped before launching video
  try {
    await MusicManager.instance.stopAndDisposeAll(
      reason: 'video-player-launch',
    );
  } catch (_) {}

  // Get the ProviderContainer to access Riverpod providers
  final container = ProviderScope.containerOf(context);

  // Set video as active media (this will hide music mini player)
  container.read(mediaCoordinatorProvider.notifier).setVideoActive();

  // Extract data from VideoItem if provided
  final title = videoTitle ?? videoItem?.title ?? 'Unknown Video';
  final subtitle = videoSubtitle ?? videoItem?.channelName;
  final thumbnail = thumbnailUrl ?? videoItem?.thumbnailUrl;

  // Pre-cache thumbnail (if present) so VideoPlayerView background does not
  // show a white flash while the image downloads. We keep a short timeout so
  // navigation isn't blocked indefinitely on slow networks.
  if (thumbnail != null && thumbnail.isNotEmpty) {
    try {
      await precacheImage(
        NetworkImage(thumbnail),
        context,
      ).timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      // Ignore errors/timeouts - we'll fall back to theme gradient in the view
    }
  }
  // Try to extract a theme from the thumbnail synchronously (short timeout)
  // and apply the overlay style immediately before navigation. This helps
  // prevent the system status bar from showing the previous route's color.
  try {
    if (thumbnail != null && thumbnail.isNotEmpty) {
      final theme = await VideoPlayerThemeService()
          .generateThemeFromThumbnail(thumbnailUrl: thumbnail, context: context)
          .timeout(const Duration(milliseconds: 900));

      final statusBarColor = theme.primaryColor;
      final statusBarIsLight =
          ThemeData.estimateBrightnessForColor(statusBarColor) ==
          Brightness.light;
      final overlay = SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: statusBarIsLight
            ? Brightness.dark
            : Brightness.light,
        statusBarBrightness: statusBarIsLight
            ? Brightness.light
            : Brightness.dark,
      );

      // Apply right before navigation to increase likelihood the system will
      // honor it for the incoming route.
      try {
        SystemChrome.setSystemUIOverlayStyle(overlay);
      } catch (_) {}
    }
  } catch (_) {
    // Ignore extraction failures/timeouts and continue to navigate.
  }
  final id = videoId.isNotEmpty ? videoId : (videoItem?.id.toString() ?? '');

  // Navigate to new video player using a fade transition to avoid any
  // intermediate white frame during route transition. Use the root navigator
  // so the video player is shown as a top-level route and doesn't inherit
  // intermediate UI from nested navigators.
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => VideoPlayerView(
        videoUrl: videoUrl,
        videoId: id,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumbnail,
        playlist: playlist,
        playlistIndex: playlistIndex,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

/// Helper function to replace current route with video player
/// Similar to pushReplacement but for video player
Future<void> replaceWithVideoPlayer(
  BuildContext context, {
  required String videoUrl,
  required String videoId,
  String? videoTitle,
  String? videoSubtitle,
  String? thumbnailUrl,
  VideoItem? videoItem,
  List<String>? playlist,
  int? playlistIndex,
}) async {
  // Ensure any active music playback is fully stopped before launching video
  try {
    await MusicManager.instance.stopAndDisposeAll(
      reason: 'video-player-replace',
    );
  } catch (_) {}

  // Get the ProviderContainer to access Riverpod providers
  final container = ProviderScope.containerOf(context);

  // Set video as active media (this will hide music mini player)
  container.read(mediaCoordinatorProvider.notifier).setVideoActive();

  // Extract data from VideoItem if provided
  final title = videoTitle ?? videoItem?.title ?? 'Unknown Video';
  final subtitle = videoSubtitle ?? videoItem?.channelName;
  final thumbnail = thumbnailUrl ?? videoItem?.thumbnailUrl;

  // Pre-cache thumbnail before replacing route to avoid initial white flash
  if (thumbnail != null && thumbnail.isNotEmpty) {
    try {
      await precacheImage(
        NetworkImage(thumbnail),
        context,
      ).timeout(const Duration(milliseconds: 1200));
    } catch (_) {}
  }
  final id = videoId.isNotEmpty ? videoId : (videoItem?.id.toString() ?? '');

  // Replace current route with new video player using a fade transition
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => VideoPlayerView(
        videoUrl: videoUrl,
        videoId: id,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumbnail,
        playlist: playlist,
        playlistIndex: playlistIndex,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}
