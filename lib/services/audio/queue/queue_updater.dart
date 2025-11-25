import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:jainverse/services/audio/android/auto_media_browser.dart';
import 'package:jainverse/services/audio/analytics/playback_history_tracker.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:jainverse/services/audio/queue/queue_synchronizer.dart';
import 'package:jainverse/services/audio/queue/shuffle_manager.dart';
import 'package:jainverse/services/audio/source/audio_source_factory.dart';

/// Encapsulates queue replacement logic for [AudioPlayerHandlerImpl].
class QueueUpdater {
  QueueUpdater({
    required AudioPlayer player,
    required QueueSynchronizer queueSynchronizer,
    required AudioSourceFactory audioSourceFactory,
    required MediaLibrary mediaLibrary,
    required PlaybackHistoryTracker historyTracker,
    required ShuffleManager shuffleManager,
    required ValueStream<List<MediaItem>> queueStream,
    required void Function(List<MediaItem>) emitQueue,
    required ConcatenatingAudioSource Function() playlistGetter,
  }) : _player = player,
       _queueSynchronizer = queueSynchronizer,
       _audioSourceFactory = audioSourceFactory,
       _mediaLibrary = mediaLibrary,
       _historyTracker = historyTracker,
       _shuffleManager = shuffleManager,
       _queueStream = queueStream,
       _emitQueue = emitQueue,
       _playlistGetter = playlistGetter;

  final AudioPlayer _player;
  final QueueSynchronizer _queueSynchronizer;
  final AudioSourceFactory _audioSourceFactory;
  final MediaLibrary _mediaLibrary;
  final PlaybackHistoryTracker _historyTracker;
  final ShuffleManager _shuffleManager;
  final ValueStream<List<MediaItem>> _queueStream;
  final void Function(List<MediaItem>) _emitQueue;
  final ConcatenatingAudioSource Function() _playlistGetter;

  Future<void> replaceQueue(List<MediaItem> newQueue) async {
    AudioLogger.log(
      '[AudioPlayer] Updating queue with ${newQueue.length} items',
      name: 'QueueUpdater',
    );

    if (newQueue.isEmpty) {
      await _clearQueue();
      return;
    }

    final currentQueue = _queueStream.hasValue
        ? _queueStream.value
        : const <MediaItem>[];
    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl] Current queue has ${currentQueue.length} items',
      name: 'QueueUpdater',
    );

    final validQueue = _validateQueueItems(newQueue);
    if (validQueue.isEmpty) {
      AudioLogger.log(
        '[ERROR][AudioPlayerHandlerImpl] No valid items in queue',
        name: 'QueueUpdater',
      );
      return;
    }

    await _replaceWith(validQueue);
  }

  Future<void> _clearQueue() async {
    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl] Clearing queue - stopping playback and clearing playlist',
      name: 'QueueUpdater',
    );

    try {
      if (_player.playing) {
        await _player.stop();
        AudioLogger.log(
          '[DEBUG][AudioPlayerHandlerImpl] Stopped playbook for queue clearing',
          name: 'QueueUpdater',
        );
      }

      await _queueSynchronizer.safeClearPlaylist();
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] Playlist cleared successfully',
        name: 'QueueUpdater',
      );

      _mediaLibrary.updateQueue(const []);
      _emitQueue(const []);

      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] Queue successfully cleared',
        name: 'QueueUpdater',
      );
    } catch (e) {
      AudioLogger.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to clear queue: $e',
        name: 'QueueUpdater',
        error: e,
      );
    }
  }

  List<MediaItem> _validateQueueItems(List<MediaItem> newQueue) {
    final validQueue = <MediaItem>[];
    for (final item in newQueue) {
      try {
        final audioUrl = item.extras?['actual_audio_url'] as String? ?? item.id;
        if (audioUrl.startsWith('http') ||
            audioUrl.startsWith('file') ||
            audioUrl.contains('.mp3') ||
            audioUrl.contains('.wav') ||
            audioUrl.contains('.m4a') ||
            audioUrl.contains('.aac')) {
          validQueue.add(item);
        } else {
          AudioLogger.log(
            '[WARNING][AudioPlayerHandlerImpl] Invalid audio URL for ${item.title}: $audioUrl',
            name: 'QueueUpdater',
          );
        }
      } catch (e) {
        AudioLogger.log(
          '[ERROR][AudioPlayerHandlerImpl] Error validating URL for ${item.title}: $e',
          name: 'QueueUpdater',
          error: e,
        );
      }
    }
    return validQueue;
  }

  Future<void> _replaceWith(List<MediaItem> validQueue) async {
    try {
      if (_player.playing) {
        try {
          await _player.stop().timeout(const Duration(seconds: 2));
        } on TimeoutException {
          AudioLogger.log(
            '[WARN][AudioPlayerHandlerImpl] Stop operation timed out during queue replacement',
            name: 'QueueUpdater',
          );
        }
        AudioLogger.log(
          '[DEBUG][AudioPlayerHandlerImpl] Stopped current playback for queue replacement',
          name: 'QueueUpdater',
        );
        await Future.delayed(const Duration(milliseconds: 25));
      }

      try {
        await _queueSynchronizer.safeClearPlaylist();
      } on TimeoutException {
        AudioLogger.log(
          '[WARN][AudioPlayerHandlerImpl] Playlist clear timed out',
          name: 'QueueUpdater',
        );
      }
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] Cleared existing playlist',
        name: 'QueueUpdater',
      );

      final validSources = await _createSources(validQueue);
      if (validSources.isEmpty) {
        return;
      }

      await _addSourcesWithRecovery(validSources);
      await _ensureIdleState();

      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] Successfully replaced queue with ${validSources.length} audio sources',
        name: 'QueueUpdater',
      );

      _mediaLibrary.updateQueue(validQueue);
      _shuffleManager.regenerateIndicesIfNeeded(
        queueLength: validQueue.length,
        currentIndex: _player.currentIndex ?? 0,
      );
      if (validQueue.isNotEmpty) {
        _historyTracker.track(validQueue[0]);
      }

      for (int i = 0; i < validQueue.length && i < 3; i++) {
        AudioLogger.log(
          '[DEBUG][AudioPlayerHandlerImpl] Queue item $i: ${validQueue[i].title}',
          name: 'QueueUpdater',
        );
      }
    } catch (e) {
      AudioLogger.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to replace queue: $e',
        name: 'QueueUpdater',
        error: e,
      );
      rethrow;
    }
  }

  Future<List<AudioSource>> _createSources(List<MediaItem> validQueue) async {
    const batchSize = 3;
    final validSources = <AudioSource>[];

    for (int i = 0; i < validQueue.length; i += batchSize) {
      final batch = validQueue.skip(i).take(batchSize);
      final batchSources = await Future.wait(
        batch.map((item) async {
          try {
            final audioSource = _audioSourceFactory.create(item);
            AudioLogger.log(
              '[DEBUG][AudioPlayerHandlerImpl] Created audio source for: ${item.title}',
              name: 'QueueUpdater',
            );
            return audioSource;
          } catch (e) {
            final errorString = e.toString().toLowerCase();
            if (errorString.contains('connection') &&
                errorString.contains('abort')) {
              AudioLogger.log(
                '[INFO][AudioPlayerHandlerImpl] Connection abort for ${item.title} - normal for network streams',
                name: 'QueueUpdater',
              );
            } else {
              AudioLogger.log(
                '[ERROR][AudioPlayerHandlerImpl] Failed to create source for ${item.title}: $e',
                name: 'QueueUpdater',
                error: e,
              );
            }
            return null;
          }
        }),
        eagerError: false,
      );

      validSources.addAll(batchSources.whereType<AudioSource>());
      await Future.delayed(const Duration(milliseconds: 1));
    }

    return validSources;
  }

  Future<void> _addSourcesWithRecovery(List<AudioSource> sources) async {
    if (sources.isEmpty) return;

    try {
      await _queueSynchronizer.safeAddAllToPlaylist(sources);
    } on TimeoutException {
      AudioLogger.log(
        '[WARN][AudioPlayerHandlerImpl] Adding sources to playlist timed out',
        name: 'QueueUpdater',
      );
    }

    try {
      await _player
          .setAudioSource(_playlistGetter(), preload: false)
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      AudioLogger.log(
        '[WARN][AudioPlayerHandlerImpl] setAudioSource timed out during queue replacement',
        name: 'QueueUpdater',
      );
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('connection') && errorString.contains('abort')) {
        AudioLogger.log(
          '[INFO][AudioPlayerHandlerImpl] Connection abort during setAudioSource - normal for network streams',
          name: 'QueueUpdater',
        );
      } else {
        AudioLogger.log(
          '[WARN][AudioPlayerHandlerImpl] setAudioSource failed: $e, continuing anyway',
          name: 'QueueUpdater',
        );
      }
    }
  }

  Future<void> _ensureIdleState() async {
    if (_player.processingState == ProcessingState.idle) {
      return;
    }

    try {
      await _player.stop().timeout(const Duration(seconds: 1));
    } on TimeoutException {
      AudioLogger.log(
        '[WARN][AudioPlayerHandlerImpl] Final stop operation timed out',
        name: 'QueueUpdater',
      );
    } catch (e) {
      AudioLogger.log(
        '[WARN][AudioPlayerHandlerImpl] Final stop failed: $e',
        name: 'QueueUpdater',
      );
    }
  }
}
