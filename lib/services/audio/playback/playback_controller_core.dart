import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio/analytics/playback_history_tracker.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:jainverse/services/audio/core/audio_session_manager.dart';
import 'package:jainverse/services/audio/core/background_sync_manager.dart';
import 'package:jainverse/services/audio/playback/playback_recovery_manager.dart';
import 'package:jainverse/services/audio/playback/state_broadcaster.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Handles low-level playback control (play/pause/stop/seek/reload).
class PlaybackControllerCore {
  PlaybackControllerCore({
    required AudioPlayer player,
    required BehaviorSubject<List<MediaItem>> queueStream,
    required PlaybackHistoryTracker historyTracker,
    required AudioSessionManager audioSessionManager,
    required BackgroundSyncManager backgroundSyncManager,
    required StateBroadcaster stateBroadcaster,
    required ValueStream<MediaItem?> mediaItemStream,
    required ConcatenatingAudioSource Function() playlistGetter,
  }) : _player = player,
       _queueStream = queueStream,
       _historyTracker = historyTracker,
       _audioSessionManager = audioSessionManager,
       _backgroundSyncManager = backgroundSyncManager,
       _stateBroadcaster = stateBroadcaster,
       _mediaItemStream = mediaItemStream,
       _playlistGetter = playlistGetter;

  final AudioPlayer _player;
  final BehaviorSubject<List<MediaItem>> _queueStream;
  final PlaybackHistoryTracker _historyTracker;
  final AudioSessionManager _audioSessionManager;
  final BackgroundSyncManager _backgroundSyncManager;
  final StateBroadcaster _stateBroadcaster;
  final ValueStream<MediaItem?> _mediaItemStream;
  final ConcatenatingAudioSource Function() _playlistGetter;

  PlaybackRecoveryManager? _playbackRecovery;

  bool _isPlayOperationInProgress = false;
  Completer<void>? _currentPlayOperation;

  void attachRecoveryManager(PlaybackRecoveryManager recoveryManager) {
    _playbackRecovery = recoveryManager;
  }

  Future<void> play() async {
    if (_isPlayOperationInProgress) {
      AudioLogger.log(
        '[DEBUG][PlaybackControllerCore] Play operation already in progress, checking if stale...',
        name: 'PlaybackControllerCore',
      );

      if (_currentPlayOperation != null &&
          !_currentPlayOperation!.isCompleted) {
        try {
          await _currentPlayOperation!.future.timeout(
            const Duration(seconds: 2),
          );
        } catch (_) {
          AudioLogger.log(
            '[DEBUG][PlaybackControllerCore] Previous play operation timed out, resetting lock',
            name: 'PlaybackControllerCore',
          );
          _isPlayOperationInProgress = false;
        }
      }

      if (_isPlayOperationInProgress) {
        AudioLogger.log(
          '[DEBUG][PlaybackControllerCore] Play operation still running, aborting new attempt',
          name: 'PlaybackControllerCore',
        );
        return;
      }
    }

    _isPlayOperationInProgress = true;
    _currentPlayOperation = Completer<void>();

    try {
      final recovery = _playbackRecovery;
      recovery?.checkCircuitBreaker();
      if (recovery?.isCircuitBreakerOpen == true) {
        AudioLogger.log(
          '[DEBUG][PlaybackControllerCore] Circuit breaker open - skipping playback attempt',
          name: 'PlaybackControllerCore',
        );
        return;
      }

      AudioLogger.log(
        '[DEBUG][PlaybackControllerCore] Starting playback - current queue index: ${_player.currentIndex}, queue length: ${_queueStream.value.length}',
        name: 'PlaybackControllerCore',
      );

      if (_queueStream.value.isEmpty) {
        AudioLogger.log(
          '[ERROR][PlaybackControllerCore] Cannot play - queue is empty',
          name: 'PlaybackControllerCore',
        );
        return;
      }

      final currentIndex = _player.currentIndex;
      if (currentIndex != null && currentIndex < _queueStream.value.length) {
        _historyTracker.track(_queueStream.value[currentIndex]);
      }

      await _audioSessionManager.ensureActive();
      await _backgroundSyncManager.enableWakeLock();

      final processingState = _player.processingState;
      if (processingState == ProcessingState.idle) {
        AudioLogger.log(
          '[DEBUG][PlaybackControllerCore] Player idle, reloading current item',
          name: 'PlaybackControllerCore',
        );
        await reloadCurrentItem();
      }

      if (processingState == ProcessingState.loading) {
        AudioLogger.log(
          '[DEBUG][PlaybackControllerCore] Player loading, waiting for ready state',
          name: 'PlaybackControllerCore',
        );
        await _player.processingStateStream
            .firstWhere(
              (state) =>
                  state == ProcessingState.ready ||
                  state == ProcessingState.buffering,
              orElse: () => ProcessingState.ready,
            )
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                AudioLogger.log(
                  '[DEBUG][PlaybackControllerCore] Timeout waiting for ready state, proceeding anyway',
                  name: 'PlaybackControllerCore',
                );
                return ProcessingState.ready;
              },
            );
      }

      try {
        await _player.play().timeout(
          const Duration(seconds: 1),
          onTimeout: () {
            AudioLogger.log(
              '[WARN][PlaybackControllerCore] Play command timed out after 1 second',
              name: 'PlaybackControllerCore',
            );
          },
        );
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('connection') &&
            errorString.contains('abort')) {
          AudioLogger.log(
            '[WARN][PlaybackControllerCore] Connection aborted during play - normal for network streams',
            name: 'PlaybackControllerCore',
          );
        } else {
          rethrow;
        }
      }

      _stateBroadcaster.performBroadcast(_player.playbackEvent);

      try {
        await _backgroundSyncManager.handlePlaybackStarted(
          _mediaItemStream.valueOrNull,
          _player.position,
        );
      } catch (e) {
        AudioLogger.log(
          '[WARN][PlaybackControllerCore] Failed to notify background sync on play: $e',
          name: 'PlaybackControllerCore',
        );
      }
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('connection') && errorString.contains('abort')) {
        AudioLogger.log(
          '[WARN][PlaybackControllerCore] Connection abort during playback is normal for network streams',
          name: 'PlaybackControllerCore',
        );
      } else {
        AudioLogger.log(
          '[ERROR][PlaybackControllerCore] Playback failed: $e',
          name: 'PlaybackControllerCore',
          error: e,
        );
        await _playbackRecovery?.handlePlaybackError(e);
      }
    } finally {
      _isPlayOperationInProgress = false;
      if (_currentPlayOperation != null &&
          !_currentPlayOperation!.isCompleted) {
        _currentPlayOperation!.complete();
      }
    }
  }

  Future<void> pause() async {
    try {
      AudioLogger.log(
        '[DEBUG][PlaybackControllerCore] Pause requested',
        name: 'PlaybackControllerCore',
      );

      if (_player.processingState == ProcessingState.idle) {
        AudioLogger.log(
          '[WARNING][PlaybackControllerCore] Cannot pause - player is idle',
          name: 'PlaybackControllerCore',
        );
        return;
      }

      if (!_player.playing) {
        AudioLogger.log(
          '[DEBUG][PlaybackControllerCore] Already paused, no action needed',
          name: 'PlaybackControllerCore',
        );
        return;
      }

      await _player.pause().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          AudioLogger.log(
            '[WARN][PlaybackControllerCore] Pause command timed out after 2 seconds',
            name: 'PlaybackControllerCore',
          );
        },
      );

      _stateBroadcaster.performBroadcast(_player.playbackEvent);

      try {
        await _backgroundSyncManager.handlePlaybackPaused(
          _mediaItemStream.valueOrNull,
          _player.position,
        );
      } catch (e) {
        AudioLogger.log(
          '[WARN][PlaybackControllerCore] Failed to notify background sync on pause: $e',
          name: 'PlaybackControllerCore',
        );
      }
    } catch (e) {
      AudioLogger.log(
        '[ERROR][PlaybackControllerCore] Pause failed: $e',
        name: 'PlaybackControllerCore',
        error: e,
      );
    }
  }

  Future<void> stop() async {
    try {
      AudioLogger.log(
        '[DEBUG][PlaybackControllerCore] Stop requested',
        name: 'PlaybackControllerCore',
      );

      await _player.stop();
      await _backgroundSyncManager.disableWakeLock();

      try {
        await _backgroundSyncManager.handlePlaybackStopped(
          _mediaItemStream.valueOrNull,
          _player.position,
        );
      } catch (e) {
        AudioLogger.log(
          '[WARN][PlaybackControllerCore] Failed to notify background sync on stop: $e',
          name: 'PlaybackControllerCore',
        );
      }

      _stateBroadcaster.performBroadcast(_player.playbackEvent);
    } catch (e) {
      AudioLogger.log(
        '[ERROR][PlaybackControllerCore] Stop failed: $e',
        name: 'PlaybackControllerCore',
        error: e,
      );
    }
  }

  Future<void> seek(Duration position) async {
    try {
      AudioLogger.log(
        '[DEBUG][PlaybackControllerCore] Seek to ${position.inSeconds}s requested',
        name: 'PlaybackControllerCore',
      );

      await _player.seek(position);
      _stateBroadcaster.performBroadcast(_player.playbackEvent);
    } catch (e) {
      AudioLogger.log(
        '[ERROR][PlaybackControllerCore] Seek failed: $e',
        name: 'PlaybackControllerCore',
        error: e,
      );
    }
  }

  Future<void> reloadCurrentItem() async {
    try {
      final currentIndex = _player.currentIndex ?? 0;
      final playlist = _playlistGetter();
      if (playlist.children.isNotEmpty &&
          currentIndex < playlist.children.length) {
        await _player
            .setAudioSource(
              playlist,
              initialIndex: currentIndex,
              preload: false,
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                AudioLogger.log(
                  '[DEBUG][PlaybackControllerCore] Reload current item timed out after 5 seconds',
                  name: 'PlaybackControllerCore',
                );
                return;
              },
            );
      } else {
        AudioLogger.log(
          '[WARNING][PlaybackControllerCore] reloadCurrentItem: Playlist empty or index out of range',
          name: 'PlaybackControllerCore',
        );
      }
    } catch (e) {
      AudioLogger.log(
        '[ERROR][PlaybackControllerCore] Failed to reload current item: $e',
        name: 'PlaybackControllerCore',
        error: e,
      );
    }
  }
}
