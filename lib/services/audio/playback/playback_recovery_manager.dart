import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';

/// Handles playback error recovery and circuit breaker logic.
class PlaybackRecoveryManager {
  PlaybackRecoveryManager({
    required AudioPlayer player,
    required ValueStream<List<MediaItem>> queueStream,
    required Future<void> Function() reloadCurrentItem,
    required Future<void> Function(int index) skipToQueueItem,
  }) : _player = player,
       _queueStream = queueStream,
       _reloadCurrentItem = reloadCurrentItem,
       _skipToQueueItem = skipToQueueItem;

  final AudioPlayer _player;
  final ValueStream<List<MediaItem>> _queueStream;
  final Future<void> Function() _reloadCurrentItem;
  final Future<void> Function(int index) _skipToQueueItem;

  bool _circuitBreakerOpen = false;
  DateTime _lastFailureTime = DateTime(0);
  int _failureCount = 0;

  static const int _maxFailureCount = 5;
  static const Duration _circuitBreakerTimeout = Duration(minutes: 2);

  bool get isCircuitBreakerOpen => _circuitBreakerOpen;

  void checkCircuitBreaker() {
    if (_circuitBreakerOpen &&
        DateTime.now().difference(_lastFailureTime) > _circuitBreakerTimeout) {
      _circuitBreakerOpen = false;
      _failureCount = 0;
      AudioLogger.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Circuit breaker reset',
        name: 'PlaybackRecoveryManager',
      );
    }
  }

  Future<void> handlePlaybackError(dynamic error) async {
    try {
      final errorString = error.toString().toLowerCase();
      _failureCount++;
      _lastFailureTime = DateTime.now();

      AudioLogger.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Handling playback error (failure count: $_failureCount): $error',
        name: 'PlaybackRecoveryManager',
        error: error,
      );

      if (_failureCount >= _maxFailureCount) {
        _circuitBreakerOpen = true;
        AudioLogger.log(
          '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Circuit breaker opened - too many failures',
          name: 'PlaybackRecoveryManager',
        );
        return;
      }

      if (errorString.contains('mediacodec') ||
          errorString.contains('exoplayer') ||
          errorString.contains('codec')) {
        await _recoverFromCodecError();
      } else if (errorString.contains('network') ||
          errorString.contains('connection') ||
          errorString.contains('timeout')) {
        await _recoverFromNetworkError();
      } else if (errorString.contains('format') ||
          errorString.contains('source')) {
        await _recoverFromSourceError();
      } else {
        await _performGenericRecovery();
      }
    } catch (recoveryError) {
      AudioLogger.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Recovery failed: $recoveryError',
        name: 'PlaybackRecoveryManager',
        error: recoveryError,
      );
    }
  }

  Future<void> _recoverFromCodecError() async {
    AudioLogger.log(
      '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Recovering from codec error',
      name: 'PlaybackRecoveryManager',
    );

    try {
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 500));
      await _reloadCurrentItem();
      await Future.delayed(const Duration(milliseconds: 300));
      await _player.play();
    } catch (e) {
      AudioLogger.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Codec error recovery failed: $e',
        name: 'PlaybackRecoveryManager',
      );
    }
  }

  Future<void> _recoverFromNetworkError() async {
    AudioLogger.log(
      '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Recovering from network error',
      name: 'PlaybackRecoveryManager',
    );

    try {
      await Future.delayed(const Duration(seconds: 2));
      await _reloadCurrentItem();
      await Future.delayed(const Duration(milliseconds: 500));
      await _player.play().timeout(const Duration(seconds: 3));
    } catch (e) {
      AudioLogger.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Network error recovery failed: $e',
        name: 'PlaybackRecoveryManager',
      );
    }
  }

  Future<void> _recoverFromSourceError() async {
    AudioLogger.log(
      '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Recovering from source error',
      name: 'PlaybackRecoveryManager',
    );

    try {
      final queueSnapshot = _queueStream.hasValue
          ? _queueStream.value
          : const <MediaItem>[];
      final currentIndex = _player.currentIndex;
      if (currentIndex != null && currentIndex < queueSnapshot.length) {
        if (currentIndex + 1 < queueSnapshot.length) {
          await _skipToQueueItem(currentIndex + 1);
        } else {
          await _skipToQueueItem(0);
        }
      }
    } catch (e) {
      AudioLogger.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Source error recovery failed: $e',
        name: 'PlaybackRecoveryManager',
      );
    }
  }

  Future<void> _performGenericRecovery() async {
    AudioLogger.log(
      '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Performing generic recovery',
      name: 'PlaybackRecoveryManager',
    );

    try {
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 1000));
      await _player.play();
    } catch (e) {
      AudioLogger.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Generic recovery failed: $e',
        name: 'PlaybackRecoveryManager',
      );
    }
  }
}
