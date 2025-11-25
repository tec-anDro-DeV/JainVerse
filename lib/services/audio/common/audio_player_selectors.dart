import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

/// Snapshot utilities for reading the latest audio handler state when streams
/// are not already observed in the widget tree. Prefer consuming the exposed
/// streams (`playbackState`, `mediaItem`, `queue`) whenever possible and use
/// these helpers only for transitional/legacy code paths.
class AudioPlayerSelectors {
  const AudioPlayerSelectors._();

  /// Returns the most recent [MediaItem] emitted by [handler.mediaItem] without
  /// forcing a synchronous query on the `MusicManager`. Falls back to the
  /// provided [fallback] (typically the UI cache) when no value is available.
  static MediaItem? currentMediaItemSnapshot(
    AudioHandler? handler, {
    MediaItem? fallback,
  }) {
    if (handler == null) return fallback;
    final Stream<MediaItem?> mediaStream = handler.mediaItem;
    if (mediaStream is ValueStream<MediaItem?>) {
      return mediaStream.valueOrNull ?? fallback;
    }
    return fallback;
  }

  /// Returns the latest known playback position. Prefer listening to
  /// `playbackState` instead of polling for updates.
  static Duration currentPositionSnapshot(
    AudioHandler? handler, {
    Duration fallback = Duration.zero,
  }) {
    if (handler == null) return fallback;
    final Stream<PlaybackState> playbackStream = handler.playbackState;
    if (playbackStream is ValueStream<PlaybackState>) {
      return playbackStream.valueOrNull?.updatePosition ?? fallback;
    }
    return fallback;
  }
}
