import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:synchronized/synchronized.dart';

import '../../../models/song_playback_payload.dart';
import '../../../services/audio_player_service.dart';
import '../common/audio_logger.dart';
import 'audio_queue_builder.dart';
import 'audio_queue_state.dart';

/// Centralized queue mutation coordinator. Ensures only one queue mutation runs
/// at a time to avoid just_audio race conditions.
class AudioQueueManager {
  AudioQueueManager({
    required AudioQueueBuilder builder,
    required Lock queueLock,
    required AudioPlayerHandler audioHandler,
  }) : _builder = builder,
       _lock = queueLock,
       _audioHandler = audioHandler;

  final AudioQueueBuilder _builder;
  final Lock _lock;
  final AudioPlayerHandler _audioHandler;
  AudioQueueState _state = const AudioQueueState(
    queue: <MediaItem>[],
    queueIndex: 0,
  );

  AudioQueueState get state => _state;

  /// Replace the current queue with the provided payloads while holding the
  /// shared queue lock. Shifts the handler queue and local cache in sync.
  Future<void> replaceQueue(
    List<SongPlaybackPayload> payloads,
    int startIndex,
  ) async {
    AudioLogger.log(
      '[DEBUG][AudioQueueManager] Replacing queue with ${payloads.length} payloads',
    );
    final items = await _builder.buildFromPayloads(payloads);
    await replaceWithMediaItems(items, startIndex);
  }

  /// Replace the queue with fully built [MediaItem]s. Used by higher-level
  /// flows that already resolved local/offline sources and only need a safe
  /// queue swap + playback jump.
  Future<void> replaceWithMediaItems(
    List<MediaItem> items,
    int startIndex,
  ) async {
    await _lock.synchronized(() async {
      await _setQueueLocked(items, startIndex);
    });
  }

  Future<void> _setQueueLocked(List<MediaItem> items, int startIndex) async {
    AudioLogger.log(
      '[DEBUG][AudioQueueManager] Applying queue with ${items.length} items',
    );
    await _audioHandler.updateQueue(items);

    final normalizedIndex = items.isEmpty
        ? 0
        : startIndex.clamp(0, items.length - 1);
    _state = AudioQueueState(queue: items, queueIndex: normalizedIndex);
    await _syncStateFromHandler();
  }

  Future<void> insertAfterCurrent(MediaItem item) async {
    await _lock.synchronized(() async {
      await _audioHandler.addQueueItem(item);
      final playbackIndex = _audioHandler.playbackState.value.queueIndex ?? 0;
      final insertPosition = playbackIndex + 1;
      final queueLength = _audioHandler.queue.value.length;
      final addedIndex = queueLength - 1;
      if (addedIndex > insertPosition) {
        await _audioHandler.moveQueueItem(addedIndex, insertPosition);
      }
      await _syncStateFromHandler();
    });
  }

  Future<void> appendItems(List<MediaItem> items) async {
    if (items.isEmpty) return;
    await _lock.synchronized(() async {
      await _audioHandler.addQueueItems(items);
      await _syncStateFromHandler();
    });
  }

  Future<void> _syncStateFromHandler() async {
    final queueSnapshot = List<MediaItem>.from(_audioHandler.queue.value);
    final queueIndex = _audioHandler.playbackState.value.queueIndex;
    _state = AudioQueueState(queue: queueSnapshot, queueIndex: queueIndex);
  }

  Future<void> skipToNext() async {
    await _audioHandler.skipToNext();
  }

  Future<void> skipToPrevious() async {
    await _audioHandler.skipToPrevious();
  }
}
