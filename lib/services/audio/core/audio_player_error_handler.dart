import 'package:just_audio/just_audio.dart';

import '../common/audio_logger.dart';

/// Maps low-level just_audio exceptions into higher-level error signals the
/// rest of the stack can understand (recoverable vs fatal, retry hints, etc.).
class AudioPlayerErrorHandler {
  const AudioPlayerErrorHandler();

  AudioErrorResult classify(Object error) {
    if (error is PlayerInterruptedException) {
      return const AudioErrorResult(AudioErrorType.interrupted);
    }
    if (error is PlayerException &&
        error.message?.toLowerCase().contains('codec') == true) {
      return const AudioErrorResult(AudioErrorType.codec);
    }
    if (error is PlayerException &&
        error.message?.toLowerCase().contains('network') == true) {
      return const AudioErrorResult(AudioErrorType.network, retryable: true);
    }
    return const AudioErrorResult(AudioErrorType.unknown);
  }

  void report(
    AudioErrorResult result, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    AudioLogger.log(
      '[ERROR][AudioPlayerErrorHandler] ${result.type}',
      error: error,
      stackTrace: stackTrace,
      isError: true,
    );
  }
}

/// High-level error categories consumed by retry + UI layers.
enum AudioErrorType { interrupted, codec, network, unknown }

class AudioErrorResult {
  const AudioErrorResult(this.type, {this.retryable = false});

  final AudioErrorType type;
  final bool retryable;
}
