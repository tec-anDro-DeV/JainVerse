import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio/analytics/playback_history_tracker.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Handles track completion, repeat behavior, and queue wrap-around.
class TrackCompletionHandler {
  TrackCompletionHandler({
    required AudioPlayer player,
    required BehaviorSubject<List<MediaItem>> queueStream,
    required ValueStream<PlaybackState> playbackState,
    required PlaybackHistoryTracker historyTracker,
    required Future<void> Function() skipToNext,
    required Future<void> Function() play,
    required Future<void> Function() stop,
    required void Function(Object error, [StackTrace? stackTrace]) reportError,
  }) : _player = player,
       _queueStream = queueStream,
       _playbackState = playbackState,
       _historyTracker = historyTracker,
       _skipToNext = skipToNext,
       _play = play,
       _stop = stop,
       _reportError = reportError;

  final AudioPlayer _player;
  final BehaviorSubject<List<MediaItem>> _queueStream;
  final ValueStream<PlaybackState> _playbackState;
  final PlaybackHistoryTracker _historyTracker;
  final Future<void> Function() _skipToNext;
  final Future<void> Function() _play;
  final Future<void> Function() _stop;
  final void Function(Object error, [StackTrace? stackTrace]) _reportError;

  Future<void> handleTrackCompletion() async {
    try {
      final currentQueue = _queueStream.value;
      final currentIndex = _player.currentIndex ?? 0;

      if (currentQueue.length > 1 && currentIndex < currentQueue.length - 1) {
        await _skipToNext();
        return;
      }

      final repeatMode = _playbackState.value.repeatMode;
      if (repeatMode == AudioServiceRepeatMode.all) {
        await _player.seek(Duration.zero, index: 0);
        if (currentQueue.isNotEmpty) {
          _historyTracker.track(currentQueue[0]);
        }
        await _play();
      } else if (repeatMode == AudioServiceRepeatMode.one) {
        await _player.seek(Duration.zero);
        if (currentIndex < currentQueue.length) {
          _historyTracker.track(currentQueue[currentIndex]);
        }
        await _play();
      } else {
        await _handleQueueEnd(currentQueue);
      }
    } catch (e, stackTrace) {
      AudioLogger.log(
        '[ERROR][TrackCompletionHandler] Track completion handling failed: $e',
        name: 'TrackCompletionHandler',
        error: e,
        stackTrace: stackTrace,
      );
      _reportError(e, stackTrace);
    }
  }

  Future<void> _handleQueueEnd(List<MediaItem> currentQueue) async {
    try {
      await _stop();
      if (currentQueue.isNotEmpty) {
        final lastIndex = currentQueue.length - 1;
        await _player.seek(Duration.zero, index: lastIndex);
      }
    } catch (e, stackTrace) {
      AudioLogger.log(
        '[ERROR][TrackCompletionHandler] Failed to stop and keep last track selected: $e',
        name: 'TrackCompletionHandler',
        error: e,
        stackTrace: stackTrace,
      );
      _reportError(e, stackTrace);
    }
  }
}
