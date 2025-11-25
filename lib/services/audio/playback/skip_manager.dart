import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio/analytics/playback_history_tracker.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:jainverse/services/audio/queue/shuffle_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Handles next/previous skip behavior including repeat rules.
class SkipManager {
  SkipManager({
    required AudioPlayer player,
    required BehaviorSubject<List<MediaItem>> queueStream,
    required PlaybackHistoryTracker historyTracker,
    required ShuffleManager shuffleManager,
    required ValueStream<PlaybackState> playbackState,
    required Future<void> Function(AudioServiceRepeatMode mode) setRepeatMode,
    required Future<void> Function() normalizeCurrentMediaImage,
  }) : _player = player,
       _queueStream = queueStream,
       _historyTracker = historyTracker,
       _shuffleManager = shuffleManager,
       _playbackState = playbackState,
       _setRepeatMode = setRepeatMode,
       _normalizeCurrentMediaImage = normalizeCurrentMediaImage;

  final AudioPlayer _player;
  final BehaviorSubject<List<MediaItem>> _queueStream;
  final PlaybackHistoryTracker _historyTracker;
  final ShuffleManager _shuffleManager;
  final ValueStream<PlaybackState> _playbackState;
  final Future<void> Function(AudioServiceRepeatMode mode) _setRepeatMode;
  final Future<void> Function() _normalizeCurrentMediaImage;

  Future<void> skipToNext() async {
    try {
      AudioLogger.log(
        '[DEBUG][SkipManager] Attempting to skip to next track',
        name: 'SkipManager',
      );

      final repeatMode = _playbackState.value.repeatMode;
      final currentIndex = _player.currentIndex ?? 0;
      final nextIndex = _getNextIndex(currentIndex);

      if (repeatMode == AudioServiceRepeatMode.one) {
        await _setRepeatMode(AudioServiceRepeatMode.all);
        AudioLogger.log(
          '[DEBUG][SkipManager] Changed repeat mode from "one" to "all" due to manual skip',
          name: 'SkipManager',
        );
      }

      if (nextIndex == null) {
        if (repeatMode == AudioServiceRepeatMode.all) {
          final shuffleIndices = _shuffleManager.indicesStream.valueOrNull;
          final firstIndex =
              _shuffleManager.isShuffleEnabled &&
                  shuffleIndices != null &&
                  shuffleIndices.isNotEmpty
              ? shuffleIndices.first
              : 0;
          await _player.seek(Duration.zero, index: firstIndex);
          if (_queueStream.value.isNotEmpty &&
              firstIndex < _queueStream.value.length) {
            _historyTracker.track(_queueStream.value[firstIndex]);
          }
          await _normalizeCurrentMediaImage();
        } else {
          return;
        }
      } else {
        await _player.seek(Duration.zero, index: nextIndex);
        if (nextIndex < _queueStream.value.length) {
          _historyTracker.track(_queueStream.value[nextIndex]);
        }
        await _normalizeCurrentMediaImage();
      }
    } catch (e) {
      AudioLogger.log(
        '[ERROR][SkipManager] Failed to skip to next: $e',
        name: 'SkipManager',
        error: e,
      );
    }
  }

  Future<void> skipToPrevious() async {
    try {
      AudioLogger.log(
        '[DEBUG][SkipManager] Attempting to skip to previous track',
        name: 'SkipManager',
      );

      final currentPosition = _player.position;
      const fourSeconds = Duration(seconds: 4);

      if (currentPosition <= fourSeconds) {
        await _skipToPreviousTrack();
      } else {
        await _restartCurrentSong();
      }
    } catch (e) {
      AudioLogger.log(
        '[ERROR][SkipManager] Failed to skip to previous: $e',
        name: 'SkipManager',
        error: e,
      );
    }
  }

  Future<void> _restartCurrentSong() async {
    try {
      AudioLogger.log(
        '[DEBUG][SkipManager] Restarting current song from beginning',
        name: 'SkipManager',
      );

      await _player.seek(Duration.zero);
      final currentIndex = _player.currentIndex ?? 0;
      if (currentIndex < _queueStream.value.length) {
        _historyTracker.track(_queueStream.value[currentIndex]);
      }
      await _normalizeCurrentMediaImage();
    } catch (e) {
      AudioLogger.log(
        '[ERROR][SkipManager] Failed to restart current song: $e',
        name: 'SkipManager',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> _skipToPreviousTrack() async {
    try {
      final repeatMode = _playbackState.value.repeatMode;
      final currentIndex = _player.currentIndex ?? 0;
      final previousIndex = _getPreviousIndex(currentIndex);

      if (repeatMode == AudioServiceRepeatMode.one) {
        await _setRepeatMode(AudioServiceRepeatMode.all);
        AudioLogger.log(
          '[DEBUG][SkipManager] Changed repeat mode from "one" to "all" due to manual skip',
          name: 'SkipManager',
        );
      }

      if (previousIndex == null) {
        if (repeatMode == AudioServiceRepeatMode.all) {
          final shuffleIndices = _shuffleManager.indicesStream.valueOrNull;
          final defaultLastIndex = _queueStream.value.isNotEmpty
              ? _queueStream.value.length - 1
              : 0;
          final lastIndex =
              _shuffleManager.isShuffleEnabled &&
                  shuffleIndices != null &&
                  shuffleIndices.isNotEmpty
              ? shuffleIndices.last
              : defaultLastIndex;
          await _player.seek(Duration.zero, index: lastIndex);
          if (_queueStream.value.isNotEmpty &&
              lastIndex < _queueStream.value.length) {
            _historyTracker.track(_queueStream.value[lastIndex]);
          }
          await _normalizeCurrentMediaImage();
        } else {
          return;
        }
      } else {
        await _player.seek(Duration.zero, index: previousIndex);
        if (previousIndex < _queueStream.value.length) {
          _historyTracker.track(_queueStream.value[previousIndex]);
        }
        await _normalizeCurrentMediaImage();
      }
    } catch (e) {
      AudioLogger.log(
        '[ERROR][SkipManager] Failed to skip to previous track: $e',
        name: 'SkipManager',
        error: e,
      );
      rethrow;
    }
  }

  int? _getNextIndex(int currentIndex) {
    return _shuffleManager.getNextIndex(
      currentIndex,
      _queueStream.value.length,
    );
  }

  int? _getPreviousIndex(int currentIndex) {
    return _shuffleManager.getPreviousIndex(currentIndex);
  }
}
