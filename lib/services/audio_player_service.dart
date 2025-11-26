import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:jainverse/Presenter/HistoryPresenter.dart';
// import 'package:jainverse/ThemeMain/appColors.dart';  // Comment out: unused import after removing toast messages
import 'package:jainverse/utils/BackgroundAudioManager.dart';
// import 'package:flutter/material.dart';  // Comment out: unused import after removing toast messages
// import 'package:fluttertoast/fluttertoast.dart';  // Comment out: unused import after removing toast messages
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:jainverse/services/audio/android/auto_media_browser.dart';
import 'package:jainverse/services/audio/analytics/playback_history_tracker.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:jainverse/services/audio/core/audio_player_error_handler.dart';
import 'package:jainverse/services/audio/core/audio_session_manager.dart';
import 'package:jainverse/services/audio/core/background_sync_manager.dart';
import 'package:jainverse/services/audio/playback/playback_controller_core.dart';
import 'package:jainverse/services/audio/playback/playback_recovery_manager.dart';
import 'package:jainverse/services/audio/playback/skip_manager.dart';
import 'package:jainverse/services/audio/playback/state_broadcaster.dart';
import 'package:jainverse/services/audio/playback/track_completion_handler.dart';
import 'package:jainverse/services/audio/queue/audio_queue_state.dart';
import 'package:jainverse/services/audio/queue/queue_synchronizer.dart';
import 'package:jainverse/services/audio/queue/queue_updater.dart';
import 'package:jainverse/services/audio/queue/shuffle_manager.dart';
import 'package:jainverse/services/audio/core/audio_source_factory.dart';

/// Abstract interface for audio player handler
abstract class AudioPlayerHandler implements AudioHandler {
  Stream<QueueState> get queueState;
  Future<void> moveQueueItem(int currentIndex, int newIndex);
  ValueStream<double> get volume;
  Future<void> setVolume(double volume);
  ValueStream<double> get speed;
  Future<void> playSingle(MediaItem mediaItem);
  Future<void> playInstantContext(List<MediaItem> mediaItems);
}

/// Unified Audio Player Handler - Single Implementation
///
/// This is the ONLY audio handler implementation in the app.
/// All other implementations (OptimizedAudioPlayerService, etc.)
/// should be removed to avoid confusion and redundancy.
class AudioPlayerHandlerImpl extends BaseAudioHandler
    with SeekHandler
    implements AudioPlayerHandler {
  // Singleton pattern to prevent multiple instances
  static AudioPlayerHandlerImpl? _instance;
  static AudioPlayerHandlerImpl get instance {
    _instance ??= AudioPlayerHandlerImpl._internal();
    return _instance!;
  }

  AudioPlayerHandlerImpl._internal() {
    final backgroundAudioManager = BackgroundAudioManager();
    _backgroundSyncManager = BackgroundSyncManager(
      audioManager: backgroundAudioManager,
    );
    _audioSessionManager = AudioSessionManager(
      playbackState: playbackState,
      volume: volume,
      pause: () => pause(),
      setVolume: (value) => setVolume(value),
    );
    _stateBroadcaster = StateBroadcaster(
      player: _player,
      playbackState: playbackState,
    );
    _queueSynchronizer = QueueSynchronizer(
      player: _player,
      playlistGetter: () => _playlist,
      playlistSetter: (newPlaylist) => _playlist = newPlaylist,
    );
    _autoMediaBrowser = AutoMediaBrowser(
      mediaLibrary: _mediaLibrary,
      recentSubject: _recentSubject,
      queueStream: queue,
    );
    _historyTracker = PlaybackHistoryTracker(
      historyPresenter: _historyPresenter,
      reportError: _reportError,
    );
    _shuffleManager = ShuffleManager();
    _skipManager = SkipManager(
      player: _player,
      queueStream: queue,
      historyTracker: _historyTracker,
      shuffleManager: _shuffleManager,
      playbackState: playbackState,
      setRepeatMode: (mode) => setRepeatMode(mode),
    );
    _audioSourceFactory = AudioSourceFactory(_mediaItemExpando);
    _queueUpdater = QueueUpdater(
      player: _player,
      queueSynchronizer: _queueSynchronizer,
      audioSourceFactory: _audioSourceFactory,
      mediaLibrary: _mediaLibrary,
      historyTracker: _historyTracker,
      shuffleManager: _shuffleManager,
      queueStream: queue,
      emitQueue: (items) => super.queue.add(items),
      playlistGetter: () => _playlist,
    );
    _playbackCore = PlaybackControllerCore(
      player: _player,
      queueStream: queue,
      historyTracker: _historyTracker,
      audioSessionManager: _audioSessionManager,
      backgroundSyncManager: _backgroundSyncManager,
      stateBroadcaster: _stateBroadcaster,
      mediaItemStream: mediaItem,
      playlistGetter: () => _playlist,
    );
    _playbackRecovery = PlaybackRecoveryManager(
      player: _player,
      queueStream: queue,
      reloadCurrentItem: () => _playbackCore.reloadCurrentItem(),
      skipToQueueItem: (index) => skipToQueueItem(index),
    );
    _trackCompletionHandler = TrackCompletionHandler(
      player: _player,
      queueStream: queue,
      playbackState: playbackState,
      historyTracker: _historyTracker,
      skipToNext: () => skipToNext(),
      play: () => play(),
      stop: () => stop(),
      reportError: _reportError,
    );
    _playbackCore.attachRecoveryManager(_playbackRecovery);
    _init();
  }

  // Factory constructor for backward compatibility
  factory AudioPlayerHandlerImpl() => instance;

  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject.seeded(<MediaItem>[]);

  final _player = AudioPlayer();
  // Make the playlist replaceable so we can recover from concurrent
  // modification races in just_audio (addStream) by swapping in a fresh
  // ConcatenatingAudioSource when clear() repeatedly fails.
  late ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    children: [],
  );

  @override
  final BehaviorSubject<double> volume = BehaviorSubject.seeded(1.0);

  @override
  final BehaviorSubject<double> speed = BehaviorSubject.seeded(1.0);

  final _mediaItemExpando = Expando<MediaItem>();
  late final BackgroundSyncManager _backgroundSyncManager;
  late final AudioSessionManager _audioSessionManager;
  late final StateBroadcaster _stateBroadcaster;
  late final TrackCompletionHandler _trackCompletionHandler;

  final MediaLibrary _mediaLibrary = MediaLibrary();
  final HistoryPresenter _historyPresenter = HistoryPresenter();
  final AudioPlayerErrorHandler _errorHandler = const AudioPlayerErrorHandler();
  late final QueueSynchronizer _queueSynchronizer;
  late final AutoMediaBrowser _autoMediaBrowser;
  late final PlaybackHistoryTracker _historyTracker;
  late final ShuffleManager _shuffleManager;
  late final SkipManager _skipManager;
  late final AudioSourceFactory _audioSourceFactory;
  late final QueueUpdater _queueUpdater;
  late final PlaybackControllerCore _playbackCore;
  late final PlaybackRecoveryManager _playbackRecovery;

  /// Stream of the current effective sequence from just_audio
  Stream<List<IndexedAudioSource>> get _effectiveSequence =>
      Rx.combineLatest3<
            List<IndexedAudioSource>?,
            List<int>?,
            bool,
            List<IndexedAudioSource>?
          >(
            _player.sequenceStream,
            _player.shuffleIndicesStream,
            _player.shuffleModeEnabledStream,
            (sequence, shuffleIndices, shuffleModeEnabled) {
              if (sequence == null) return [];
              if (!shuffleModeEnabled) return sequence;
              if (shuffleIndices == null) return null;
              if (shuffleIndices.length != sequence.length) return null;
              return shuffleIndices.map((i) => sequence[i]).toList();
            },
          )
          .whereType<List<IndexedAudioSource>>();

  /// Computes the effective queue index taking shuffle mode into account
  int? getQueueIndex(
    int? currentIndex,
    bool shuffleModeEnabled,
    List<int>? shuffleIndices,
  ) {
    final effectiveIndices = _player.effectiveIndices ?? [];
    final shuffleIndicesInv = List.filled(effectiveIndices.length, 0);
    for (var i = 0; i < effectiveIndices.length; i++) {
      shuffleIndicesInv[effectiveIndices[i]] = i;
    }
    return (shuffleModeEnabled &&
            ((currentIndex ?? 0) < shuffleIndicesInv.length))
        ? shuffleIndicesInv[currentIndex ?? 0]
        : currentIndex;
  }

  /// Stream reporting the combined state of the current queue and media item
  @override
  Stream<QueueState> get queueState =>
      Rx.combineLatest3<List<MediaItem>, PlaybackState, List<int>?, QueueState>(
            queue.distinct(),
            playbackState.distinct(),
            _shuffleManager.indicesStream.distinct(),
            (queueItems, playbackState, shuffleIndices) => QueueState(
              queue: queueItems,
              queueIndex: playbackState.queueIndex,
              shuffleIndices: _shuffleManager.isShuffleEnabled
                  ? shuffleIndices
                  : null,
              repeatMode: playbackState.repeatMode,
            ),
          )
          .distinct()
          .debounceTime(const Duration(milliseconds: 50))
          .where(
            (state) =>
                state.shuffleIndices == null ||
                state.queue.length == state.shuffleIndices!.length,
          );

  Future<void> _initializeBuffering() async {
    try {
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] Buffering initialized',
        name: 'AudioPlayerHandlerImpl',
      );
    } catch (e) {
      AudioLogger.log(
        '[ERROR][AudioPlayerHandlerImpl] Buffering initialization failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  Future<void> _setupBackgroundAudioHandling() async {
    try {
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] Setting up background audio',
        name: 'AudioPlayerHandlerImpl',
      );

      await _backgroundSyncManager.initialize();

      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] Background audio setup completed',
        name: 'AudioPlayerHandlerImpl',
      );
    } catch (e) {
      AudioLogger.log(
        '[ERROR][AudioPlayerHandlerImpl] Background audio setup failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  Future<void> _init() async {
    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl][_init] Called',
      name: 'AudioPlayerHandlerImpl',
    );

    await _initializeBuffering();
    await _setupBackgroundAudioHandling();

    // Load and broadcast the initial queue
    if (_mediaLibrary.items[MediaLibrary.albumsRootId]?.isNotEmpty == true) {
      await updateQueue(_mediaLibrary.items[MediaLibrary.albumsRootId]!);
    }

    // For Android 11, record the most recent item so it can be resumed
    mediaItem.whereType<MediaItem>().listen(
      (item) => _recentSubject.add([item]),
    );

    // Broadcast media item changes with optimized performance
    Rx.combineLatest4<int?, List<MediaItem>, bool, List<int>?, MediaItem?>(
          _player.currentIndexStream.distinct(),
          queue.distinct(),
          _player.shuffleModeEnabledStream.distinct(),
          _player.shuffleIndicesStream.distinct(),
          (index, queue, shuffleModeEnabled, shuffleIndices) {
            final queueIndex = getQueueIndex(
              index,
              shuffleModeEnabled,
              shuffleIndices,
            );
            return (queueIndex != null && queueIndex < queue.length)
                ? queue[queueIndex]
                : null;
          },
        )
        .whereType<MediaItem>()
        .distinct()
        .throttleTime(const Duration(milliseconds: 100))
        .listen(mediaItem.add);

    // Propagate events with throttling to reduce frequency
    _player.playbackEventStream
        .throttleTime(const Duration(milliseconds: 100))
        .listen(_stateBroadcaster.broadcast);
    _player.shuffleModeEnabledStream.distinct().listen(
      (enabled) => _stateBroadcaster.broadcast(_player.playbackEvent),
    );

    // In this case, the service stops when reaching the end
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _trackCompletionHandler.handleTrackCompletion();
      }
    });

    // Broadcast the current queue
    _effectiveSequence
        .map(
          (sequence) =>
              sequence.map((source) => _mediaItemExpando[source]!).toList(),
        )
        .pipe(queue);
  }

  // Volume and speed control methods
  @override
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    this.volume.add(clampedVolume);

    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl] Volume tracking updated to: $clampedVolume',
      name: 'AudioPlayerHandlerImpl',
    );
  }

  @override
  Future<void> androidSetRemoteVolume(int volumeIndex) async {
    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl] System volume index: $volumeIndex',
      name: 'AudioPlayerHandlerImpl',
    );

    final normalizedVolume = volumeIndex / 15.0;
    final clampedVolume = normalizedVolume.clamp(0.0, 1.0);
    volume.add(clampedVolume);

    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl] Volume tracking updated to: $clampedVolume',
      name: 'AudioPlayerHandlerImpl',
    );
  }

  @override
  Future<void> androidAdjustRemoteVolume(
    AndroidVolumeDirection direction,
  ) async {
    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl] System volume adjustment: $direction',
      name: 'AudioPlayerHandlerImpl',
    );

    double newVolume = volume.value;
    if (direction == AndroidVolumeDirection.raise) {
      newVolume = (newVolume + 0.1).clamp(0.0, 1.0);
    } else if (direction == AndroidVolumeDirection.lower) {
      newVolume = (newVolume - 0.1).clamp(0.0, 1.0);
    }

    volume.add(newVolume);

    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl] Volume tracking updated to: $newVolume',
      name: 'AudioPlayerHandlerImpl',
    );
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;

    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl] Setting shuffle mode: $shuffleMode (enabled: $enabled)',
      name: 'AudioPlayerHandlerImpl',
    );

    _shuffleManager.setShuffleMode(
      shuffleMode: shuffleMode,
      queueLength: queue.value.length,
      currentIndex: _player.currentIndex ?? 0,
    );

    // Update the playback state to reflect the new shuffle mode
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));

    AudioLogger.log(
      '[DEBUG][AudioPlayerHandlerImpl] Shuffle mode set to: $enabled (internal tracking)',
      name: 'AudioPlayerHandlerImpl',
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    await _player.setLoopMode(LoopMode.values[repeatMode.index]);
  }

  @override
  Future<void> setSpeed(double speed) async {
    this.speed.add(speed);
    await _player.setSpeed(speed);
  }

  // Queue management methods

  /// CRITICAL: Android Auto MediaBrowserService implementation
  /// Enhanced getChildren method with proper Android Auto support
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    return _autoMediaBrowser.getChildren(parentMediaId, options: options);
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    return _autoMediaBrowser.subscribeToChildren(parentMediaId);
  }

  /// CRITICAL: Android Auto search support for voice commands
  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    return _autoMediaBrowser.search(query, extras: extras);
  }

  // Queue operation synchronization logic lives in [QueueSynchronizer].

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    return _queueSynchronizer.synchronize(() async {
      await _playlist.add(_audioSourceFactory.create(mediaItem));
    });
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    if (mediaItems.isEmpty) return;
    return _queueSynchronizer.synchronize(() async {
      await _queueSynchronizer.safeAddAllToPlaylist(
        _audioSourceFactory.createAll(mediaItems),
      );

      final currentQueue = List<MediaItem>.from(queue.valueOrNull ?? []);
      currentQueue.addAll(mediaItems);
      _mediaLibrary.updateQueue(currentQueue);
      super.queue.add(currentQueue);
    });
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    return _queueSynchronizer.synchronize(() async {
      await _playlist.insert(index, _audioSourceFactory.create(mediaItem));
    });
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    return _queueSynchronizer.synchronize(() async {
      // Add shorter timeout to prevent hanging queue updates
      await _queueUpdater
          .replaceQueue(queue)
          .timeout(
            const Duration(seconds: 6), // Reduced from 10 to 6 seconds
            onTimeout: () {
              AudioLogger.log(
                '[ERROR][AudioPlayerHandlerImpl] Queue update timed out after 6 seconds',
                name: 'AudioPlayerHandlerImpl',
              );
              throw TimeoutException(
                'Queue update timeout after 6 seconds',
                const Duration(seconds: 6),
              );
            },
          );
    });
  }

  @override
  Future<void> playSingle(MediaItem mediaItem) async {
    return _queueSynchronizer.synchronize(() async {
      AudioLogger.log(
        '[AudioPlayerHandlerImpl] Instant play requested for ${mediaItem.title}',
        name: 'AudioPlayerHandlerImpl',
      );

      try {
        if (_player.playing) {
          await _player.stop().timeout(const Duration(seconds: 1));
        }
      } catch (e) {
        AudioLogger.log(
          '[WARN][AudioPlayerHandlerImpl] Unable to stop player before instant play: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
      }

      // Replace playlist with single source for immediate playback
      await _queueSynchronizer.safeClearPlaylist();
      await _queueSynchronizer.safeAddAllToPlaylist([
        _audioSourceFactory.create(mediaItem),
      ]);

      try {
        await _player
            .setAudioSource(_playlist, preload: true)
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        AudioLogger.log(
          '[WARN][AudioPlayerHandlerImpl] setAudioSource failed during instant play: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
      }

      // Announce the synthetic single-item queue so UI can update instantly
      _mediaLibrary.updateQueue([mediaItem]);
      super.queue.add([mediaItem]);
      this.mediaItem.add(mediaItem);

      try {
        await _player.seek(Duration.zero, index: 0);
      } catch (e) {
        AudioLogger.log(
          '[WARN][AudioPlayerHandlerImpl] seek failed during instant play: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
      }

      await _player.play();
    });
  }

  @override
  Future<void> playInstantContext(List<MediaItem> mediaItems) async {
    if (mediaItems.isEmpty) return;
    return _queueSynchronizer.synchronize(() async {
      AudioLogger.log(
        '[AudioPlayerHandlerImpl] Instant context play with ${mediaItems.length} items',
        name: 'AudioPlayerHandlerImpl',
      );

      try {
        if (_player.playing) {
          await _player.stop().timeout(const Duration(seconds: 1));
        }
      } catch (e) {
        AudioLogger.log(
          '[WARN][AudioPlayerHandlerImpl] Unable to stop player before instant context play: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
      }

      await _queueSynchronizer.safeClearPlaylist();
      await _queueSynchronizer.safeAddAllToPlaylist(
        _audioSourceFactory.createAll(mediaItems),
      );

      try {
        await _player
            .setAudioSource(
              _playlist,
              preload: true,
              initialIndex: 0,
              initialPosition: Duration.zero,
            )
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        AudioLogger.log(
          '[WARN][AudioPlayerHandlerImpl] setAudioSource failed during instant context play: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
      }

      final queueSnapshot = List<MediaItem>.from(mediaItems);
      _mediaLibrary.updateQueue(queueSnapshot);
      super.queue.add(queueSnapshot);
      mediaItem.add(queueSnapshot.first);

      try {
        await _player.seek(Duration.zero, index: 0);
      } catch (e) {
        AudioLogger.log(
          '[WARN][AudioPlayerHandlerImpl] seek failed during instant context play: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
      }

      await _player.play();
    });
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    final index = queue.value.indexWhere((item) => item.id == mediaItem.id);
    if (_player.sequence != null &&
        index >= 0 &&
        index < _player.sequence!.length) {
      _mediaItemExpando[_player.sequence![index]] = mediaItem;

      // CRITICAL FIX: If this is the currently playing item, emit the updated MediaItem to the stream
      if (index == _player.currentIndex) {
        this.mediaItem.add(mediaItem);
        AudioLogger.log(
          '[AudioPlayerHandlerImpl] updateMediaItem: Updated current MediaItem and emitted to stream',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    } else {
      AudioLogger.log(
        '[WARNING][AudioPlayerHandlerImpl] updateMediaItem: Invalid index or sequence is null',
        name: 'AudioPlayerHandlerImpl',
      );
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    return _queueSynchronizer.synchronize(() async {
      final index = queue.value.indexOf(mediaItem);
      if (index >= 0 && index < _playlist.length) {
        await _playlist.removeAt(index);
      } else {
        AudioLogger.log(
          '[WARNING][AudioPlayerHandlerImpl] Attempted to remove item not in queue or invalid index: \\${mediaItem.title}',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    });
  }

  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {
    return _queueSynchronizer.synchronize(() async {
      if (currentIndex >= 0 &&
          currentIndex < queue.value.length &&
          newIndex >= 0 &&
          newIndex < queue.value.length &&
          _playlist.length > currentIndex &&
          _playlist.length > newIndex) {
        await _playlist.move(currentIndex, newIndex);
      } else {
        AudioLogger.log(
          '[WARNING][AudioPlayerHandlerImpl] Invalid indices for move operation: \\$currentIndex -> \\$newIndex (queue length: \\${queue.value.length}, playlist length: \\${_playlist.length})',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    });
  }

  // Playback control methods
  @override
  Future<void> skipToNext() async {
    await _skipManager.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _skipManager.skipToPrevious();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      if (index < 0 ||
          _playlist.children.isEmpty ||
          index >= _playlist.children.length) {
        AudioLogger.log(
          '[ERROR][AudioPlayerHandlerImpl] Invalid index: \\$index',
          name: 'AudioPlayerHandlerImpl',
        );
        return;
      }

      final currentRepeatMode = playbackState.value.repeatMode;
      final currentIndex = _player.currentIndex ?? 0;

      // If user manually selects a different song while in "repeat one" mode, change to "repeat all"
      if (currentRepeatMode == AudioServiceRepeatMode.one &&
          index != currentIndex) {
        await setRepeatMode(AudioServiceRepeatMode.all);
        AudioLogger.log(
          '[DEBUG][AudioPlayerHandlerImpl] Changed repeat mode from "one" to "all" due to manual queue item selection',
          name: 'AudioPlayerHandlerImpl',
        );

        // Comment out: Toast message removed
        // Fluttertoast.showToast(
        //   msg: 'Repeat mode changed to "Repeat All"',
        //   toastLength: Toast.LENGTH_SHORT,
        //   timeInSecForIosWeb: 1,
        //   backgroundColor: Colors.black87,
        //   textColor: appColors().colorBackground,
        //   fontSize: 14.0,
        // );
      }

      AudioLogger.log(
        '🎯🎯🎯 AUDIO PLAYER SERVICE SKIP TO QUEUE ITEM 🎯🎯🎯',
        name: 'AudioPlayerHandlerImpl',
      );
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Attempting to skip to index: $index',
        name: 'AudioPlayerHandlerImpl',
      );
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Queue length: ${_playlist.children.length}',
        name: 'AudioPlayerHandlerImpl',
      );
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Current player index BEFORE skip: ${_player.currentIndex}',
        name: 'AudioPlayerHandlerImpl',
      );
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Shuffle enabled: ${_player.shuffleModeEnabled}',
        name: 'AudioPlayerHandlerImpl',
      );

      // Remember current playing state
      final wasPlaying = _player.playing;
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Was playing: $wasPlaying',
        name: 'AudioPlayerHandlerImpl',
      );

      // Calculate the effective index to seek to
      final effectiveIndex = _player.shuffleModeEnabled
          ? _player.shuffleIndices![index]
          : index;
      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Effective index to seek to: $effectiveIndex (original: $index)',
        name: 'AudioPlayerHandlerImpl',
      );

      // Perform fast seek operation without pausing first
      try {
        AudioLogger.log(
          '[DEBUG][AudioPlayerHandlerImpl] 🎵 Fast seek to index $effectiveIndex',
          name: 'AudioPlayerHandlerImpl',
        );

        // Seek to the new track at position zero - no pause needed
        await _player.seek(Duration.zero, index: effectiveIndex);

        // Much shorter delay for fast response
        await Future.delayed(const Duration(milliseconds: 100));

        final newCurrentIndex = _player.currentIndex;
        AudioLogger.log(
          '[DEBUG][AudioPlayerHandlerImpl] 🎵 Player current index AFTER seek: $newCurrentIndex (expected: $effectiveIndex)',
          name: 'AudioPlayerHandlerImpl',
        );

        // Verify seek was successful
        if (newCurrentIndex != effectiveIndex) {
          AudioLogger.log(
            '[WARN][AudioPlayerHandlerImpl] Seek index mismatch, but proceeding anyway',
            name: 'AudioPlayerHandlerImpl',
          );
        }
      } catch (e) {
        AudioLogger.log(
          '[ERROR][AudioPlayerHandlerImpl] Fast seek failed: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
        rethrow;
      }

      // Quick state broadcast for immediate UI update
      _stateBroadcaster.performBroadcast(_player.playbackEvent);

      AudioLogger.log(
        '[DEBUG][AudioPlayerHandlerImpl] ✅ Successfully skipped to queue item $index, was playing: $wasPlaying',
        name: 'AudioPlayerHandlerImpl',
      );
      final shouldResumePlayback = wasPlaying || playbackState.value.playing;

      if (shouldResumePlayback) {
        await _player.play();
        AudioLogger.log(
          '[DEBUG][AudioPlayerHandlerImpl] ▶️ Playback resumed after skipToQueueItem',
          name: 'AudioPlayerHandlerImpl',
        );
      } else {
        AudioLogger.log(
          '[DEBUG][AudioPlayerHandlerImpl] ⏸ SkipToQueueItem completed without auto-resume (user paused before skip)',
          name: 'AudioPlayerHandlerImpl',
        );
      }
      // Track history for the new current song - do this async
      if (index < queue.value.length) {
        _historyTracker.track(queue.value[index]);
      }

      // Caller can still explicitly invoke play() if needed when we skip without resuming.
    } catch (e) {
      AudioLogger.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to skip to queue item: \\$e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
      rethrow; // Re-throw so the caller knows it failed
    }
  }

  @override
  Future<void> play() async {
    await _playbackCore.play();
  }

  @override
  Future<void> pause() async {
    await _playbackCore.pause();
  }

  @override
  Future<void> stop() async {
    await _playbackCore.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _playbackCore.seek(position);
  }

  void _reportError(Object error, [StackTrace? stackTrace]) {
    final classification = _errorHandler.classify(error);
    _errorHandler.report(classification, error: error, stackTrace: stackTrace);
  }
}
