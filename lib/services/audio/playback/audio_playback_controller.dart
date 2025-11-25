import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../../models/song_playback_payload.dart';
import '../common/audio_logger.dart';
import '../queue/audio_queue_manager.dart';
import '../queue/audio_queue_state.dart';
import 'audio_preload_manager.dart';
import 'audio_retry_handler.dart';

/// High-level orchestration layer that coordinates queue mutations, preloading,
/// and playback retries. This keeps `MusicManager` thin.
class AudioPlaybackController {
  AudioPlaybackController({
    required AudioQueueManager queueManager,
    required AudioPreloadManager preloadManager,
    required AudioRetryHandler retryHandler,
    required AudioHandler audioHandler,
  }) : _queueManager = queueManager,
       _preloadManager = preloadManager,
       _retryHandler = retryHandler,
       _audioHandler = audioHandler;

  final AudioQueueManager _queueManager;
  final AudioPreloadManager _preloadManager;
  final AudioRetryHandler _retryHandler;
  final AudioHandler _audioHandler;

  AudioQueueState get queueState => _queueManager.state;

  Future<void> playPayloads(
    List<SongPlaybackPayload> payloads,
    int index,
  ) async {
    AudioLogger.log(
      '[DEBUG][AudioPlaybackController] playPayloads size=${payloads.length} index=$index',
    );
    await _queueManager.replaceQueue(payloads, index);
    await _retryHandler.runWithRetry(() async {
      await _audioHandler.skipToQueueItem(index);
      await _audioHandler.play();
    });
  }

  Future<void> playMediaItems(
    List<MediaItem> items,
    int index, {
    Duration? resumePosition,
    bool autostart = true,
  }) async {
    if (items.isEmpty) {
      AudioLogger.log(
        '[WARN][AudioPlaybackController] playMediaItems called with empty list',
      );
      await _queueManager.replaceWithMediaItems(const <MediaItem>[], 0);
      return;
    }

    final normalizedIndex = index.clamp(0, items.length - 1);
    AudioLogger.log(
      '[DEBUG][AudioPlaybackController] playMediaItems count=${items.length} index=$normalizedIndex',
    );

    await _queueManager.replaceWithMediaItems(items, normalizedIndex);
    await _retryHandler.runWithRetry(() async {
      await _audioHandler.skipToQueueItem(normalizedIndex);
      if (resumePosition != null) {
        await _audioHandler.seek(resumePosition);
      }
      if (autostart) {
        await _audioHandler.play();
      } else {
        await _audioHandler.pause();
      }
    });
  }

  Future<void> preloadAroundIndex(int index) async {
    final queue = queueState.queue;
    if (queue.isEmpty || index >= queue.length) return;
    AudioLogger.log('[DEBUG][AudioPlaybackController] Preloading index=$index');
    await _preloadManager.preload(queue[index]);
  }
}
