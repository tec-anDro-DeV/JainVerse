import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../videoplayer/services/video_player_theme_service.dart';
import '../managers/media_coordinator.dart';
import '../managers/music_manager.dart';
import '../videoplayer/models/video_item.dart';
import '../videoplayer/screens/video_player_view.dart';
import '../videoplayer/managers/video_player_state_provider.dart';

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
  // Ensure any active music playback is stopped, but don't block navigation.
  try {
    MusicManager.instance
        .stopAndDisposeAll(reason: 'video-player-launch')
        .catchError((_) {});
  } catch (_) {}

  // Get the ProviderContainer to access Riverpod providers
  final container = ProviderScope.containerOf(context);

  // Set video as active media (this will hide music mini player)
  container.read(mediaCoordinatorProvider.notifier).setVideoActive();

  // Extract data from VideoItem if provided
  final title = videoTitle ?? videoItem?.title ?? 'Unknown Video';
  final subtitle = videoSubtitle ?? videoItem?.channelName;
  final thumbnail = thumbnailUrl ?? videoItem?.thumbnailUrl;

  // Kick off pre-cache of the thumbnail (if present) but don't await it.
  // Blocking here harms perceived navigation performance on slow networks.
  if (thumbnail != null && thumbnail.isNotEmpty) {
    try {
      precacheImage(
        NetworkImage(thumbnail),
        context,
      ).timeout(const Duration(milliseconds: 1200)).catchError((_) {});
    } catch (_) {}
  }

  // Try to extract a theme from the thumbnail, but do it asynchronously
  // without blocking navigation. When the theme is ready we'll apply the
  // overlay style; failures or timeouts are ignored.
  if (thumbnail != null && thumbnail.isNotEmpty) {
    try {
      VideoPlayerThemeService()
          .generateThemeFromThumbnail(thumbnailUrl: thumbnail, context: context)
          .timeout(const Duration(milliseconds: 900))
          .then((theme) {
            try {
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
              SystemChrome.setSystemUIOverlayStyle(overlay);
            } catch (_) {}
          })
          .catchError((_) {});
    } catch (_) {}
  }
  final id = videoId.isNotEmpty ? videoId : (videoItem?.id.toString() ?? '');

  // Best-effort: prefetch video controller in background so the full-screen
  // player can attach quickly when the route opens. This is non-blocking.
  try {
    container
        .read(videoPlayerProvider.notifier)
        .prefetchVideo(videoUrl: videoUrl, videoId: id);
  } catch (_) {}

  // Navigate to new video player using a fade transition to avoid any
  // intermediate white frame during route transition. Use the root navigator
  // so the video player is shown as a top-level route and doesn't inherit
  // intermediate UI from nested navigators.
  debugPrint(
    'VIDEO_NAV_START push id:$id time:${DateTime.now().millisecondsSinceEpoch}',
  );
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => VideoPlayerView(
        videoUrl: videoUrl,
        videoId: id,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumbnail,
        channelId: videoItem?.channelId,
        channelAvatarUrl: videoItem?.channelImageUrl,
        isOwn: videoItem?.isOwn,
        videoItem: videoItem,
        playlist: playlist,
        playlistIndex: playlistIndex,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
  debugPrint(
    'VIDEO_NAV_AFTER_PUSH id:$id time:${DateTime.now().millisecondsSinceEpoch}',
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
  // Ensure any active music playback is stopped, but don't block navigation.
  try {
    MusicManager.instance
        .stopAndDisposeAll(reason: 'video-player-replace')
        .catchError((_) {});
  } catch (_) {}

  // Get the ProviderContainer to access Riverpod providers
  final container = ProviderScope.containerOf(context);

  // Set video as active media (this will hide music mini player)
  container.read(mediaCoordinatorProvider.notifier).setVideoActive();

  // Extract data from VideoItem if provided
  final title = videoTitle ?? videoItem?.title ?? 'Unknown Video';
  final subtitle = videoSubtitle ?? videoItem?.channelName;
  final thumbnail = thumbnailUrl ?? videoItem?.thumbnailUrl;

  // Kick off pre-cache of the thumbnail before replacing the route, but
  // don't await it so navigation remains snappy on slow networks.
  if (thumbnail != null && thumbnail.isNotEmpty) {
    try {
      precacheImage(
        NetworkImage(thumbnail),
        context,
      ).timeout(const Duration(milliseconds: 1200)).catchError((_) {});
    } catch (_) {}
  }
  final id = videoId.isNotEmpty ? videoId : (videoItem?.id.toString() ?? '');

  // Replace current route with new video player using a fade transition
  debugPrint(
    'VIDEO_NAV_START replace id:$id time:${DateTime.now().millisecondsSinceEpoch}',
  );
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => VideoPlayerView(
        videoUrl: videoUrl,
        videoId: id,
        title: title,
        subtitle: subtitle,
        thumbnailUrl: thumbnail,
        channelId: videoItem?.channelId,
        channelAvatarUrl: videoItem?.channelImageUrl,
        isOwn: videoItem?.isOwn,
        videoItem: videoItem,
        playlist: playlist,
        playlistIndex: playlistIndex,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
  debugPrint(
    'VIDEO_NAV_AFTER_REPLACE id:$id time:${DateTime.now().millisecondsSinceEpoch}',
  );
}
