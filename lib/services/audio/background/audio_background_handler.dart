import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';

import '../../audio_player_service.dart';
import '../queue/audio_queue_state.dart';

/// Bridges AudioService callbacks with the new modular playback stack by
/// delegating to the core [AudioPlayerHandler] while keeping a clean surface
/// for the background isolate.
class AudioBackgroundHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements AudioPlayerHandler {
  AudioBackgroundHandler(this._delegate) {
    _subscriptions.add(_delegate.playbackState.listen(playbackState.add));
    _subscriptions.add(_delegate.mediaItem.listen(mediaItem.add));
    _subscriptions.add(_delegate.queue.listen(queue.add));
  }

  final AudioPlayerHandler _delegate;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  Stream<QueueState> get queueState => _delegate.queueState;

  @override
  ValueStream<double> get volume => _delegate.volume;

  @override
  Future<void> setVolume(double volume) => _delegate.setVolume(volume);

  @override
  ValueStream<double> get speed => _delegate.speed;

  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) =>
      _delegate.moveQueueItem(currentIndex, newIndex);

  @override
  Future<void> playSingle(MediaItem mediaItem) =>
      _delegate.playSingle(mediaItem);

  @override
  Future<void> playInstantContext(List<MediaItem> mediaItems) =>
      _delegate.playInstantContext(mediaItems);

  @override
  Future<void> play() => _delegate.play();

  @override
  Future<void> pause() => _delegate.pause();

  @override
  Future<void> stop() => _delegate.stop();

  @override
  Future<void> fastForward() => _delegate.fastForward();

  @override
  Future<void> rewind() => _delegate.rewind();

  @override
  Future<void> seek(Duration position) => _delegate.seek(position);

  @override
  Future<void> skipToNext() => _delegate.skipToNext();

  @override
  Future<void> skipToPrevious() => _delegate.skipToPrevious();

  @override
  Future<void> skipToQueueItem(int index) => _delegate.skipToQueueItem(index);

  @override
  Future<void> addQueueItem(MediaItem mediaItem) =>
      _delegate.addQueueItem(mediaItem);

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) =>
      _delegate.addQueueItems(mediaItems);

  @override
  Future<void> updateQueue(List<MediaItem> queue) =>
      _delegate.updateQueue(queue);

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) =>
      _delegate.removeQueueItem(mediaItem);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      _delegate.setShuffleMode(shuffleMode);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      _delegate.setRepeatMode(repeatMode);

  @override
  Future<void> setSpeed(double speed) => _delegate.setSpeed(speed);

  @override
  Future<void> playMediaItem(MediaItem mediaItem) =>
      _delegate.playMediaItem(mediaItem);

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) => _delegate.playFromMediaId(mediaId, extras);

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) =>
      _delegate.playFromUri(uri, extras);

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) =>
      _delegate.customAction(name, extras);

  @override
  Future<void> prepare() => _delegate.prepare();

  @override
  Future<void> prepareFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) => _delegate.prepareFromMediaId(mediaId, extras);

  @override
  Future<void> prepareFromUri(Uri uri, [Map<String, dynamic>? extras]) =>
      _delegate.prepareFromUri(uri, extras);

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }
}
