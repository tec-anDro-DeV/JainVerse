import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';

/// Serializes queue mutations and adds resilience helpers for playlist edits.
class QueueSynchronizer {
  QueueSynchronizer({
    required AudioPlayer player,
    required ConcatenatingAudioSource Function() playlistGetter,
    required void Function(ConcatenatingAudioSource newPlaylist) playlistSetter,
  }) : _player = player,
       _getPlaylist = playlistGetter,
       _setPlaylist = playlistSetter;

  final AudioPlayer _player;
  final ConcatenatingAudioSource Function() _getPlaylist;
  final void Function(ConcatenatingAudioSource newPlaylist) _setPlaylist;

  bool _isOperationInProgress = false;
  final List<Future<void> Function()> _operationQueue = [];
  Completer<void>? _currentOperation;

  /// Runs [operation] once the queue lock is available, preserving order.
  Future<T> synchronize<T>(Future<T> Function() operation) async {
    if (_isOperationInProgress) {
      final completer = Completer<T>();
      _operationQueue.add(() async {
        try {
          completer.complete(await operation());
        } catch (error) {
          completer.completeError(error);
        }
      });
      return completer.future;
    }

    _isOperationInProgress = true;
    _currentOperation = Completer<void>();

    try {
      return await operation();
    } catch (error) {
      AudioLogger.log(
        '[QueueSynchronizer] Queue operation failed: $error',
        name: 'QueueSynchronizer',
        error: error,
      );
      rethrow;
    } finally {
      _isOperationInProgress = false;
      _currentOperation?.complete();
      _currentOperation = null;

      if (_operationQueue.isNotEmpty) {
        final next = _operationQueue.removeAt(0);
        next().catchError((error) {
          AudioLogger.log(
            '[QueueSynchronizer] Queued operation failed: $error',
            name: 'QueueSynchronizer',
            error: error,
          );
        });
      }
    }
  }

  /// Clears playlist safely, working around concurrent addStream mutations.
  Future<void> safeClearPlaylist({int maxAttempts = 4}) async {
    int attempt = 0;
    while (true) {
      final playlist = _getPlaylist();
      try {
        await playlist.clear().timeout(const Duration(seconds: 2));
        return;
      } catch (error) {
        attempt++;
        final message = error.toString().toLowerCase();
        final isConcurrentAdd =
            message.contains('addstream') ||
            message.contains('you cannot add items');

        if (attempt < maxAttempts && isConcurrentAdd) {
          AudioLogger.log(
            '[QueueSynchronizer] clear() concurrent modification detected, retry #$attempt',
            name: 'QueueSynchronizer',
          );
          await Future.delayed(const Duration(milliseconds: 120));
          continue;
        }

        try {
          AudioLogger.log(
            '[QueueSynchronizer] replacing playlist after failed clear',
            name: 'QueueSynchronizer',
          );
          final newPlaylist = ConcatenatingAudioSource(children: []);
          _setPlaylist(newPlaylist);
          await _player
              .setAudioSource(newPlaylist, preload: false)
              .timeout(const Duration(seconds: 3));
          return;
        } catch (inner) {
          AudioLogger.log(
            '[QueueSynchronizer] failed to replace playlist: $inner',
            name: 'QueueSynchronizer',
            error: inner,
          );
          rethrow;
        }
      }
    }
  }

  /// Adds a batch of sources while retrying transient concurrent modification errors.
  Future<void> safeAddAllToPlaylist(
    List<AudioSource> sources, {
    int maxAttempts = 10,
  }) async {
    int attempt = 0;
    while (true) {
      final playlist = _getPlaylist();
      try {
        await playlist.addAll(sources).timeout(const Duration(seconds: 4));
        return;
      } catch (error) {
        attempt++;
        final message = error.toString().toLowerCase();
        final isConcurrentError =
            message.contains('addstream') ||
            message.contains('add stream') ||
            message.contains('you cannot add items');

        if (attempt < maxAttempts && isConcurrentError) {
          AudioLogger.log(
            '[QueueSynchronizer] addAll concurrent modification detected, retry #$attempt',
            name: 'QueueSynchronizer',
          );
          final baseDelay = 80 * attempt * attempt;
          final clampedDelay = baseDelay < 80
              ? 80
              : (baseDelay > 800 ? 800 : baseDelay);
          await Future.delayed(Duration(milliseconds: clampedDelay));
          continue;
        }
        rethrow;
      }
    }
  }

  bool isConcurrentQueueError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('addstream') ||
        message.contains('add stream') ||
        message.contains('you cannot add items') ||
        message.contains('bad state');
  }
}
