import 'dart:developer' as dart_developer;

/// Thin logging shim that suppresses noisy info logs in release builds.
/// Existing calls to `developer.log` should go through this wrapper so
/// we can centralize filtering and enrichment later.
class AudioLogger {
  const AudioLogger._();

  /// Logs [message] when [isError] is true or when verbose logging is enabled.
  static void log(
    String message, {
    String name = 'Audio',
    Object? error,
    StackTrace? stackTrace,
    bool isError = false,
  }) {
    if (isError || error != null || message.startsWith('[ERROR')) {
      dart_developer.log(
        message,
        name: name,
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    // TODO: Wire up runtime flag for debug verbosity once diagnostics module lands.
  }
}
