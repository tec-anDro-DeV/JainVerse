import 'package:audio_service/audio_service.dart';

import '../common/audio_logger.dart';
import '../sources/preload_source.dart';

/// Handles lightweight preloading (metadata and optional warm media cache)
/// so instant play feels snappy when users tap from feeds.
class AudioPreloadManager {
  AudioPreloadManager(this._preloadSource);

  final PreloadSource _preloadSource;

  Future<void> preload(MediaItem item) async {
    try {
      await _preloadSource.ensureCached(item);
    } catch (error, stackTrace) {
      AudioLogger.log(
        '[WARN][AudioPreloadManager] Failed to preload ${item.id}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
