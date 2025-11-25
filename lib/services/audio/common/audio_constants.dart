import 'package:jainverse/utils/AppConstant.dart';

/// Common constants shared across the audio stack.
class AudioConstants {
  const AudioConstants._();

  // Network assets
  static String get basePublicUrl => '${AppConstant.SiteUrl}public/';
  static const String placeholderImageUrl = '';
  static const Duration defaultSongDuration = Duration(minutes: 3);

  // Queue + playback timings
  static const Duration queueUpdateTimeout = Duration(seconds: 8);
  static const Duration skipPrefetchDelay = Duration(milliseconds: 500);
  static const Duration skipPostDelay = Duration(milliseconds: 1200);
  static const Duration skipFinalDelay = Duration(milliseconds: 1000);
  static const Duration skipEmergencyDelay = Duration(milliseconds: 800);

  // Retry + backoff
  static const int playbackMaxAttempts = 4;
  static const Duration playbackBaseBackoff = Duration(milliseconds: 200);
  static const Duration playbackMaxBackoff = Duration(seconds: 2);

  // Preload
  static const Duration preloadWarmupWindow = Duration(seconds: 6);
}
