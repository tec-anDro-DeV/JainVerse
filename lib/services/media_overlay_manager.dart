import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:jainverse/ThemeMain/sizes.dart';

/// Types of overlays that may affect layout (audio mini-player, video mini-player, none)
enum MediaOverlayType { none, audioMini, videoMini }

/// Global manager for UI overlays that affect bottom padding (mini players, etc.).
///
/// Usage:
/// - Show: MediaOverlayManager.instance.showMiniPlayer(height: 70.0, type: ...)
/// - Hide: MediaOverlayManager.instance.hideMiniPlayer()
/// - Listen: MediaOverlayManager.instance.miniPlayerHeight (ValueListenable)
class MediaOverlayManager {
  MediaOverlayManager._();

  static final MediaOverlayManager instance = MediaOverlayManager._();

  /// Current mini player height in logical pixels. 0.0 when hidden.
  final ValueNotifier<double> miniPlayerHeight = ValueNotifier<double>(0.0);

  /// Overlay type (audio / video / none).
  final ValueNotifier<MediaOverlayType> overlayType = ValueNotifier(
    MediaOverlayType.none,
  );

  /// Show the mini player overlay. If [height] is omitted, it defaults to
  /// a sensible height based on [type] (audio/video). Use [type] to allow
  /// the rest of the app to react differently to audio vs video overlays.
  void showMiniPlayer({
    double? height,
    MediaOverlayType type = MediaOverlayType.audioMini,
  }) {
    overlayType.value = type;
    // If caller didn't supply a custom height, pick a default based on type.
    final h =
        height ??
        (type == MediaOverlayType.audioMini
            ? AppSizes.audioMiniPlayerHeight
            : AppSizes.videoMiniPlayerHeight);
    developer.log(
      '[MediaOverlayManager] showMiniPlayer: height=$h, type=$type',
    );
    miniPlayerHeight.value = h;
    developer.log(
      '[MediaOverlayManager] showMiniPlayer: miniPlayerHeight now=${miniPlayerHeight.value}',
    );
  }

  void hideMiniPlayer() {
    developer.log(
      '[MediaOverlayManager] hideMiniPlayer: clearing mini player height (was=${miniPlayerHeight.value})',
    );
    overlayType.value = MediaOverlayType.none;
    miniPlayerHeight.value = 0.0;
    developer.log(
      '[MediaOverlayManager] hideMiniPlayer: miniPlayerHeight now=${miniPlayerHeight.value}',
    );
  }
}
