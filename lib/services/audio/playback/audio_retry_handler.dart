import 'dart:async';
import 'dart:math';

import '../common/audio_constants.dart';
import '../common/audio_logger.dart';
import '../core/audio_player_error_handler.dart';

/// Wraps playback operations with retry + exponential backoff semantics.
class AudioRetryHandler {
  AudioRetryHandler(this._errorHandler);

  final AudioPlayerErrorHandler _errorHandler;

  Future<void> runWithRetry(Future<void> Function() operation) async {
    int attempt = 0;
    while (true) {
      try {
        await operation();
        return;
      } catch (error, stackTrace) {
        attempt++;
        final classification = _errorHandler.classify(error);
        _errorHandler.report(
          classification,
          error: error,
          stackTrace: stackTrace,
        );
        if (!classification.retryable ||
            attempt >= AudioConstants.playbackMaxAttempts) {
          rethrow;
        }
        final delay = _calculateBackoff(attempt);
        AudioLogger.log(
          '[WARN][AudioRetryHandler] Retry #$attempt in ${delay.inMilliseconds}ms',
        );
        await Future.delayed(delay);
      }
    }
  }

  Duration _calculateBackoff(int attempt) {
    final millis =
        AudioConstants.playbackBaseBackoff.inMilliseconds * pow(2, attempt - 1);
    return Duration(
      milliseconds: min(
        millis.toInt(),
        AudioConstants.playbackMaxBackoff.inMilliseconds,
      ),
    );
  }
}
