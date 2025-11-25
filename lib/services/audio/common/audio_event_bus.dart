import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

/// Lightweight event hub that surfaces the most important playback streams
/// without forcing UI code to depend on low-level handler classes.
class AudioEventBus {
  AudioEventBus._(this._playbackState, this._mediaItem, this._queue);

  factory AudioEventBus.duplex() {
    return AudioEventBus._(
      BehaviorSubject.seeded(PlaybackState()),
      BehaviorSubject<MediaItem?>.seeded(null),
      BehaviorSubject.seeded(<MediaItem>[]),
    );
  }

  final BehaviorSubject<PlaybackState> _playbackState;
  final BehaviorSubject<MediaItem?> _mediaItem;
  final BehaviorSubject<List<MediaItem>> _queue;

  ValueStream<PlaybackState> get playbackState => _playbackState;
  ValueStream<MediaItem?> get mediaItem => _mediaItem;
  ValueStream<List<MediaItem>> get queue => _queue;

  void emitPlaybackState(PlaybackState state) => _playbackState.add(state);
  void emitMediaItem(MediaItem? item) => _mediaItem.add(item);
  void emitQueue(List<MediaItem> items) => _queue.add(List.unmodifiable(items));

  StreamSubscription<T> forward<T>(Stream<T> source, void Function(T) sink) {
    return source.listen(
      sink,
      onError: (error, stackTrace) {
        // Swallow errors for now to keep the bus resilient.
      },
    );
  }

  Future<void> dispose() async {
    await _playbackState.close();
    await _mediaItem.close();
    await _queue.close();
  }
}
