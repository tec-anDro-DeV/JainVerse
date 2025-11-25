import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:jainverse/utils/BackgroundAudioManager.dart';

/// Coordinates BackgroundAudioManager interactions and state persistence.
class BackgroundSyncManager {
  BackgroundSyncManager({required BackgroundAudioManager audioManager})
    : _audioManager = audioManager;

  final BackgroundAudioManager _audioManager;

  Future<void> initialize() async {
    try {
      await _audioManager.initialize();
    } catch (e) {
      AudioLogger.log(
        '[ERROR][BackgroundSyncManager] Initialization failed: $e',
        name: 'BackgroundSyncManager',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> enableWakeLock() => _audioManager.enableWakeLock();

  Future<void> disableWakeLock() => _audioManager.disableWakeLock();

  Future<void> handlePlaybackStarted(
    MediaItem? currentItem,
    Duration position,
  ) async {
    await _notifyNativeState(playing: true, serviceRunning: true);
    await _persistState(currentItem, position, isPlaying: true);
  }

  Future<void> handlePlaybackPaused(
    MediaItem? currentItem,
    Duration position,
  ) async {
    await _notifyNativeState(playing: false);
    await _persistState(currentItem, position, isPlaying: false);
  }

  Future<void> handlePlaybackStopped(
    MediaItem? currentItem,
    Duration position,
  ) async {
    await _notifyNativeState(playing: false, serviceRunning: false);
    await _persistState(currentItem, position, isPlaying: false);
  }

  Future<void> persistPlaybackState(
    MediaItem mediaItem,
    Duration position, {
    required bool playing,
  }) async {
    await _persistState(mediaItem, position, isPlaying: playing);
  }

  Future<void> _notifyNativeState({
    required bool playing,
    bool? serviceRunning,
  }) async {
    try {
      await _audioManager.notifyNativePlayingState(playing);
      if (serviceRunning != null) {
        await _audioManager.notifyNativeServiceRunning(serviceRunning);
      }
    } catch (e) {
      AudioLogger.log(
        '[WARN][BackgroundSyncManager] Failed to notify native state: $e',
        name: 'BackgroundSyncManager',
      );
    }
  }

  Future<void> _persistState(
    MediaItem? mediaItem,
    Duration position, {
    required bool isPlaying,
  }) async {
    if (mediaItem == null) return;
    try {
      await _audioManager.persistPlaybackState({
        'id': mediaItem.id,
        'title': mediaItem.title,
        'artist': mediaItem.artist ?? '',
        'album': mediaItem.album ?? '',
        'position': position.inMilliseconds.toString(),
        'playing': isPlaying.toString(),
      });
    } catch (e) {
      AudioLogger.log(
        '[WARN][BackgroundSyncManager] Failed to persist playback state: $e',
        name: 'BackgroundSyncManager',
      );
    }
  }
}
