import 'package:audio_service/audio_service.dart';
import 'package:jainverse/Presenter/HistoryPresenter.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';

/// Handles playback history tracking so the handler only orchestrates calls.
class PlaybackHistoryTracker {
  PlaybackHistoryTracker({
    required HistoryPresenter historyPresenter,
    required void Function(Object error, [StackTrace? stackTrace]) reportError,
  }) : _historyPresenter = historyPresenter,
       _reportError = reportError;

  final HistoryPresenter _historyPresenter;
  final void Function(Object error, [StackTrace? stackTrace]) _reportError;

  void track(MediaItem item) {
    try {
      final musicId = _extractMusicId(item);
      if (musicId == null) {
        AudioLogger.log(
          '[PlaybackHistoryTracker] Skipping history tracking - missing music ID for ${item.title}',
          name: 'PlaybackHistoryTracker',
        );
        return;
      }

      _historyPresenter.trackSongPlay(musicId);
      AudioLogger.log(
        '[PlaybackHistoryTracker] Tracking history for ${item.title} (Music ID: $musicId)',
        name: 'PlaybackHistoryTracker',
      );
    } catch (error, stackTrace) {
      AudioLogger.log(
        '[PlaybackHistoryTracker] Failed to track song history: $error',
        name: 'PlaybackHistoryTracker',
        error: error,
        stackTrace: stackTrace,
      );
      _reportError(error, stackTrace);
    }
  }

  String? _extractMusicId(MediaItem item) {
    final extras = item.extras;
    final audioId = extras != null ? extras['audio_id'] : null;
    if (audioId != null) {
      return audioId.toString();
    }

    if (RegExp(r'^\d+$').hasMatch(item.id)) {
      return item.id;
    }
    return null;
  }
}
