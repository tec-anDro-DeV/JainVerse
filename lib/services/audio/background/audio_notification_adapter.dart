import 'package:audio_service/audio_service.dart';

import '../common/audio_logger.dart';

/// Helper that builds consistent [MediaItem] metadata for foreground and
/// background notifications, including artwork fallbacks.
class AudioNotificationAdapter {
  const AudioNotificationAdapter();

  MediaItem applyArtwork(MediaItem baseItem, {Uri? artUri}) {
    if (artUri == null) return baseItem;
    final updated = baseItem.copyWith(artUri: artUri);
    AudioLogger.log(
      '[DEBUG][AudioNotificationAdapter] Artwork applied for ${baseItem.id}',
    );
    return updated;
  }
}
