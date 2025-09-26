import 'dart:async';
import 'dart:developer' as developer;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:jainverse/utils/AppConstant.dart';
// import 'package:flutter/material.dart';  // Comment out: unused import after removing toast messages
// import 'package:fluttertoast/fluttertoast.dart';  // Comment out: unused import after removing toast messages
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:jainverse/utils/BackgroundAudioManager.dart';
// import 'package:jainverse/ThemeMain/appColors.dart';  // Comment out: unused import after removing toast messages
import 'package:jainverse/services/media_item_image_fixer.dart';
import 'package:jainverse/Presenter/HistoryPresenter.dart';

/// Queue state for managing audio queue
class QueueState {
  static const QueueState empty = QueueState(
    [],
    0,
    [],
    AudioServiceRepeatMode.none,
  );

  final List<MediaItem> queue;
  final int? queueIndex;
  final List<int>? shuffleIndices;
  final AudioServiceRepeatMode repeatMode;

  const QueueState(
    this.queue,
    this.queueIndex,
    this.shuffleIndices,
    this.repeatMode,
  );

  bool get hasPrevious =>
      repeatMode != AudioServiceRepeatMode.none || (queueIndex ?? 0) > 0;

  bool get hasNext =>
      repeatMode != AudioServiceRepeatMode.none ||
      (queueIndex ?? 0) + 1 < queue.length;

  List<int> get indices =>
      shuffleIndices ?? List.generate(queue.length, (i) => i);
}

/// Abstract interface for audio player handler
abstract class AudioPlayerHandler implements AudioHandler {
  Stream<QueueState> get queueState;
  Future<void> moveQueueItem(int currentIndex, int newIndex);
  ValueStream<double> get volume;
  Future<void> setVolume(double volume);
  ValueStream<double> get speed;
}

/// Media library for organizing audio content with Android Auto support
class MediaLibrary {
  static const albumsRootId = 'albums';

  Map<String, List<MediaItem>> items = <String, List<MediaItem>>{
    AudioService.browsableRootId: const [
      MediaItem(
        id: albumsRootId,
        title: "Music Library",
        playable: false,
        extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
      ),
      MediaItem(
        id: AudioService.recentRootId,
        title: "Recently Played",
        playable: false,
        extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
      ),
    ],
    albumsRootId: [],
    AudioService.recentRootId: [],
  };

  void updateQueue(List<MediaItem> newQueue) {
    // Update both albums and recent with the new queue for better Android Auto integration
    items[albumsRootId] = newQueue;
    // Also populate recent with current queue items (first 10 items)
    if (newQueue.isNotEmpty) {
      items[AudioService.recentRootId] = newQueue.take(10).toList();
    }
  }
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
    _backgroundAudioManager = BackgroundAudioManager();
    _init();
  }

  // Factory constructor for backward compatibility
  factory AudioPlayerHandlerImpl() => instance;

  // ignore: close_sinks
  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject.seeded(<MediaItem>[]);

  final _player = AudioPlayer();
  late final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    children: [],
  );

  @override
  final BehaviorSubject<double> volume = BehaviorSubject.seeded(1.0);

  @override
  final BehaviorSubject<double> speed = BehaviorSubject.seeded(1.0);

  final _mediaItemExpando = Expando<MediaItem>();
  late final BackgroundAudioManager _backgroundAudioManager;

  // Shuffle state management
  bool _isShuffleEnabled = false;
  List<int> _shuffledIndices = [];
  List<int> _originalIndices = [];
  final BehaviorSubject<List<int>?> _customShuffleIndicesStream =
      BehaviorSubject.seeded(null);

  final MediaLibrary _mediaLibrary = MediaLibrary();
  final HistoryPresenter _historyPresenter = HistoryPresenter();

  // Race condition protection for queue operations
  bool _isQueueOperationInProgress = false;
  final List<Future<void> Function()> _queueOperationQueue = [];
  Completer<void>? _currentQueueOperation;

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
      ).whereType<List<IndexedAudioSource>>();

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
            _customShuffleIndicesStream.distinct(),
            (queue, playbackState, shuffleIndices) => QueueState(
              queue,
              playbackState.queueIndex,
              _isShuffleEnabled ? shuffleIndices : null,
              playbackState.repeatMode,
            ),
          )
          .distinct()
          .debounceTime(const Duration(milliseconds: 50))
          .where(
            (state) =>
                state.shuffleIndices == null ||
                state.queue.length == state.shuffleIndices!.length,
          );

  Future<void> _init() async {
    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl][_init] Starting initialization',
      name: 'AudioPlayerHandlerImpl',
    );

    try {
      await _configureAudioSession();
      await _configurePlayerForPerformance();
      _setupStreamListeners();
      await _initializeBuffering();
      await _setupBackgroundAudioHandling();
      await _init2();

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl][_init] Initialization completed successfully',
        name: 'AudioPlayerHandlerImpl',
      );
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl][_init] Initialization failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );

    await session.setActive(true);

    session.becomingNoisyEventStream.listen((event) {
      _handleBecomingNoisy();
    });

    session.interruptionEventStream.listen((event) {
      _handleAudioInterruption(event);
    });
  }

  Future<void> _configurePlayerForPerformance() async {
    try {
      // PERFORMANCE OPTIMIZATION: Configure player for faster loading
      await _player.setSpeed(1.0);
      await _player.setVolume(0.7); // Set initial volume
      volume.add(0.7);

      // Enable automatic gain control for consistent audio levels
      await _player.setAutomaticallyWaitsToMinimizeStalling(false);

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Player configured for optimal performance',
        name: 'AudioPlayerHandlerImpl',
      );
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Performance configuration failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  void _setupStreamListeners() {
    // Speed changes
    speed.debounceTime(const Duration(milliseconds: 250)).listen((speed) {
      playbackState.add(playbackState.value.copyWith(speed: speed));
    });

    // Media item stream with optimized performance
    Rx.combineLatest4<int?, List<MediaItem>, bool, List<int>?, MediaItem?>(
          _player.currentIndexStream.distinct(),
          queue.distinct(),
          _player.shuffleModeEnabledStream.distinct(),
          _player.shuffleIndicesStream.distinct(),
          (index, queue, shuffleModeEnabled, shuffleIndices) {
            try {
              final queueIndex = getQueueIndex(
                index,
                shuffleModeEnabled,
                shuffleIndices,
              );
              return (queueIndex != null && queueIndex < queue.length)
                  ? queue[queueIndex]
                  : null;
            } catch (e) {
              developer.log(
                '[ERROR][AudioPlayerHandlerImpl] Error in media item stream: $e',
                name: 'AudioPlayerHandlerImpl',
                error: e,
              );
              return null;
            }
          },
        )
        .whereType<MediaItem>()
        .distinct()
        .throttleTime(const Duration(milliseconds: 100))
        .listen(
          (item) {
            mediaItem.add(item);
            // Automatically track song history when track changes
            _trackSongHistory(item);
            // Persist last playback metadata so mini-player can be restored
            try {
              _backgroundAudioManager.persistPlaybackState({
                'id': item.id,
                'title': item.title,
                'artist': item.artist ?? '',
                'album': item.album ?? '',
                'position': _player.position.inMilliseconds.toString(),
                'playing': (_player.playing).toString(),
              });
            } catch (e) {
              developer.log(
                '[WARN][AudioPlayerHandlerImpl] Failed to persist track metadata: $e',
                name: 'AudioPlayerHandlerImpl',
              );
            }
          },
          onError: (error) {
            developer.log(
              '[ERROR][AudioPlayerHandlerImpl] Media item stream error: $error',
              name: 'AudioPlayerHandlerImpl',
              error: error,
            );
          },
        );

    // Playback event stream
    _player.playbackEventStream.listen(
      _broadcastState,
      onError: (error) {
        developer.log(
          '[ERROR][AudioPlayerHandlerImpl] Playback event stream error: $error',
          name: 'AudioPlayerHandlerImpl',
          error: error,
        );
      },
    );

    // Real-time position updates for smooth UI
    _player.positionStream
        .where((_) => _player.playing) // Only emit when playing
        .throttleTime(
          const Duration(milliseconds: 200),
        ) // Update 5 times per second
        .listen(
          (position) => _broadcastState(_player.playbackEvent),
          onError: (error) {
            developer.log(
              '[ERROR][AudioPlayerHandlerImpl] Position stream error: $error',
              name: 'AudioPlayerHandlerImpl',
              error: error,
            );
          },
        );

    // Shuffle mode stream
    _player.shuffleModeEnabledStream.listen(
      (enabled) => _broadcastState(_player.playbackEvent),
      onError: (error) {
        developer.log(
          '[ERROR][AudioPlayerHandlerImpl] Shuffle mode stream error: $error',
          name: 'AudioPlayerHandlerImpl',
          error: error,
        );
      },
    );

    // Processing state handling
    _player.processingStateStream.listen((state) {
      try {
        if (state == ProcessingState.completed) {
          _handleTrackCompletion();
        }
      } catch (e) {
        developer.log(
          '[ERROR][AudioPlayerHandlerImpl] Processing state error: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
      }
    });
  }

  Future<void> _handleTrackCompletion() async {
    try {
      final currentQueue = queue.value;
      final currentIndex = _player.currentIndex ?? 0;

      if (currentQueue.length > 1 && currentIndex < currentQueue.length - 1) {
        // Move to next track and track its history
        skipToNext();
      } else {
        final repeatMode = playbackState.value.repeatMode;
        if (repeatMode == AudioServiceRepeatMode.all) {
          _player.seek(Duration.zero, index: 0);
          // Track history when repeating playlist
          if (currentQueue.isNotEmpty) {
            _trackSongHistory(currentQueue[0]);
          }
          play();
        } else if (repeatMode == AudioServiceRepeatMode.one) {
          _player.seek(Duration.zero);
          // Track history when repeating same song
          if (currentIndex < currentQueue.length) {
            _trackSongHistory(currentQueue[currentIndex]);
          }
          play();
        } else {
          // No next track and repeat mode is none: stop playback but keep the
          // current (last) track selected instead of wrapping back to the
          // first track. This ensures the UI stays on the last song in a
          // paused/stopped state as requested.
          try {
            // Stop the player (will update playback state and native notifications)
            await stop();

            // If we have a non-empty queue, seek to the last item at position 0
            if (currentQueue.isNotEmpty) {
              final lastIndex = currentQueue.length - 1;
              await _player.seek(Duration.zero, index: lastIndex);
            }
          } catch (e) {
            developer.log(
              '[ERROR][AudioPlayerHandlerImpl] Failed to stop and keep last track selected: $e',
              name: 'AudioPlayerHandlerImpl',
              error: e,
            );
          }
        }
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Track completion handling failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  /// Automatically track song history when a song is played or changed
  void _trackSongHistory(MediaItem item) {
    try {
      // Extract music ID from MediaItem extras first, fallback to parsing from ID
      String musicId = '';

      if (item.extras != null && item.extras!['audio_id'] != null) {
        // Use audio_id from extras (preferred method)
        musicId = item.extras!['audio_id'].toString();
      } else {
        // Fallback: try to extract from MediaItem ID if it's just a number
        final id = item.id;
        if (RegExp(r'^\d+$').hasMatch(id)) {
          musicId = id;
        } else {
          // If ID contains URL or other data, skip history tracking
          developer.log(
            '[DEBUG][AudioPlayerHandlerImpl] Skipping history tracking - no valid music ID found for: ${item.title}',
            name: 'AudioPlayerHandlerImpl',
          );
          return;
        }
      }

      if (musicId.isNotEmpty) {
        // Track history asynchronously without blocking audio playback
        _historyPresenter.trackSongPlay(musicId);
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Tracking history for song: ${item.title} (Music ID: $musicId)',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to track song history: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  Future<void> _initializeBuffering() async {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Buffering initialized',
        name: 'AudioPlayerHandlerImpl',
      );
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Buffering initialization failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  Future<void> _setupBackgroundAudioHandling() async {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Setting up background audio',
        name: 'AudioPlayerHandlerImpl',
      );

      await _backgroundAudioManager.initialize();

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Background audio setup completed',
        name: 'AudioPlayerHandlerImpl',
      );
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Background audio setup failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  /// CRITICAL FIX: Enhanced audio interruption handling
  void _handleAudioInterruption(AudioInterruptionEvent event) async {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Audio interruption: ${event.type}',
        name: 'AudioPlayerHandlerImpl',
      );

      switch (event.type) {
        case AudioInterruptionType.pause:
          // CRITICAL FIX: Only pause if actually playing
          if (playbackState.value.playing) {
            await pause();
            developer.log(
              '[DEBUG][AudioPlayerHandlerImpl] Paused due to interruption',
              name: 'AudioPlayerHandlerImpl',
            );
          }
          break;

        case AudioInterruptionType.duck:
          // CRITICAL FIX: Implement proper audio ducking
          if (playbackState.value.playing) {
            final currentVolume = volume.value;
            // Duck to 30% volume instead of pausing
            await setVolume(currentVolume * 0.3);
            developer.log(
              '[DEBUG][AudioPlayerHandlerImpl] Audio ducked to 30% volume',
              name: 'AudioPlayerHandlerImpl',
            );

            // Restore volume after 3 seconds if still playing
            Future.delayed(const Duration(seconds: 3), () async {
              if (playbackState.value.playing) {
                await setVolume(currentVolume);
                developer.log(
                  '[DEBUG][AudioPlayerHandlerImpl] Audio volume restored',
                  name: 'AudioPlayerHandlerImpl',
                );
              }
            });
          }
          break;

        case AudioInterruptionType.unknown:
          // CRITICAL FIX: Handle unknown interruptions gracefully
          developer.log(
            '[DEBUG][AudioPlayerHandlerImpl] Unknown interruption type, no action taken',
            name: 'AudioPlayerHandlerImpl',
          );
          break;
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Error handling interruption: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  void _handleBecomingNoisy() {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Audio becoming noisy - pausing playback',
        name: 'AudioPlayerHandlerImpl',
      );

      if (playbackState.value.playing) {
        pause();
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Error handling noisy event: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  Future<void> _init2() async {
    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl][_init2] Called',
      name: 'AudioPlayerHandlerImpl',
    );

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
        .listen(_broadcastState);
    _player.shuffleModeEnabledStream.distinct().listen(
      (enabled) => _broadcastState(_player.playbackEvent),
    );

    // In this case, the service stops when reaching the end
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Delegate to the unified async completion handler. We don't await
        // here because this is a stream callback; the handler will run
        // asynchronously and perform the appropriate stop/seek logic.
        _handleTrackCompletion();
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

    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl] Volume tracking updated to: $clampedVolume',
      name: 'AudioPlayerHandlerImpl',
    );
  }

  @override
  Future<void> androidSetRemoteVolume(int volumeIndex) async {
    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl] System volume index: $volumeIndex',
      name: 'AudioPlayerHandlerImpl',
    );

    final normalizedVolume = volumeIndex / 15.0;
    final clampedVolume = normalizedVolume.clamp(0.0, 1.0);
    volume.add(clampedVolume);

    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl] Volume tracking updated to: $clampedVolume',
      name: 'AudioPlayerHandlerImpl',
    );
  }

  @override
  Future<void> androidAdjustRemoteVolume(
    AndroidVolumeDirection direction,
  ) async {
    developer.log(
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

    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl] Volume tracking updated to: $newVolume',
      name: 'AudioPlayerHandlerImpl',
    );
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    final enabled = mode == AudioServiceShuffleMode.all;

    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl] Setting shuffle mode: $mode (enabled: $enabled)',
      name: 'AudioPlayerHandlerImpl',
    );

    _isShuffleEnabled = enabled;

    // Generate shuffle indices if enabling shuffle
    if (enabled && queue.value.isNotEmpty) {
      _generateShuffleIndices();
    } else {
      // Emit null to indicate no shuffle when disabled
      _customShuffleIndicesStream.add(null);
    }

    // Update the playback state to reflect the new shuffle mode
    playbackState.add(playbackState.value.copyWith(shuffleMode: mode));

    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl] Shuffle mode set to: $enabled (internal tracking)',
      name: 'AudioPlayerHandlerImpl',
    );
  }

  /// Generate shuffled indices for the current queue
  void _generateShuffleIndices() {
    final currentIndex = _player.currentIndex ?? 0;
    _originalIndices = List.generate(queue.value.length, (i) => i);
    _shuffledIndices = List.from(_originalIndices);

    // Remove current song from shuffle list
    _shuffledIndices.removeAt(currentIndex);

    // Shuffle remaining songs
    _shuffledIndices.shuffle();

    // Add current song back at the beginning
    _shuffledIndices.insert(0, currentIndex);

    // Emit shuffled indices to custom stream
    _customShuffleIndicesStream.add(_shuffledIndices);

    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl] Generated shuffle indices: $_shuffledIndices',
      name: 'AudioPlayerHandlerImpl',
    );
  }

  /// Get the next index based on shuffle mode
  int? _getNextIndex(int currentIndex) {
    if (!_isShuffleEnabled) {
      // Normal sequential mode
      return currentIndex + 1 < queue.value.length ? currentIndex + 1 : null;
    }

    // Shuffle mode
    final currentShufflePosition = _shuffledIndices.indexOf(currentIndex);
    if (currentShufflePosition == -1 ||
        currentShufflePosition + 1 >= _shuffledIndices.length) {
      return null; // End of shuffled list
    }

    return _shuffledIndices[currentShufflePosition + 1];
  }

  /// Get the previous index based on shuffle mode
  int? _getPreviousIndex(int currentIndex) {
    if (!_isShuffleEnabled) {
      // Normal sequential mode
      return currentIndex > 0 ? currentIndex - 1 : null;
    }

    // Shuffle mode
    final currentShufflePosition = _shuffledIndices.indexOf(currentIndex);
    if (currentShufflePosition <= 0) {
      return null; // Beginning of shuffled list
    }

    return _shuffledIndices[currentShufflePosition - 1];
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

  // Audio source creation
  AudioSource _itemToSource(MediaItem mediaItem) {
    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl] Creating optimized audio source for: ${mediaItem.title}',
      name: 'AudioPlayerHandlerImpl',
    );

    Uri? uri;
    try {
      // Use actual_audio_url from extras if available, otherwise fall back to mediaItem.id
      final audioUrl =
          mediaItem.extras?['actual_audio_url'] as String? ?? mediaItem.id;

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Using audio URL: $audioUrl for ${mediaItem.title}',
        name: 'AudioPlayerHandlerImpl',
      );

      if (audioUrl.startsWith('http') || audioUrl.startsWith('https')) {
        // Already a complete URL
        uri = Uri.parse(audioUrl);
      } else if (audioUrl.startsWith('file://')) {
        // File URL
        uri = Uri.parse(audioUrl);
      } else {
        // Relative path - construct full URL
        const baseUrl = '${AppConstant.SiteUrl}public/';
        uri = Uri.parse('$baseUrl$audioUrl');
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Constructed full URL: ${uri.toString()}',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Invalid URL: ${mediaItem.extras?['actual_audio_url'] ?? mediaItem.id}, error: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
      uri = Uri.parse('https://example.com/dummy.mp3');
    }

    final audioSource = AudioSource.uri(
      uri,
      headers: {
        'User-Agent': 'JainVerse/1.0',
        'Accept': 'audio/*',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'max-age=3600',
        'Connection': 'close', // Changed to close to avoid socket issues
        'Accept-Ranges': 'bytes',
      },
      tag: {
        'title': mediaItem.title,
        'artist': mediaItem.artist,
        'id': mediaItem.id,
        'preload': true,
      },
    );
    _mediaItemExpando[audioSource] = mediaItem;
    return audioSource;
  }

  List<AudioSource> _itemsToSources(List<MediaItem> mediaItems) =>
      mediaItems.map(_itemToSource).toList();

  // Queue management methods

  /// CRITICAL: Android Auto MediaBrowserService implementation
  /// Enhanced getChildren method with proper Android Auto support
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    developer.log(
      '[INFO][AudioPlayerHandlerImpl] getChildren called for: $parentMediaId',
      name: 'AudioPlayerHandlerImpl',
    );

    switch (parentMediaId) {
      case AudioService.browsableRootId:
        // Return root level browseable categories for Android Auto
        return [
          const MediaItem(
            id: MediaLibrary.albumsRootId,
            title: "Music Library",
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
          const MediaItem(
            id: AudioService.recentRootId,
            title: "Recently Played",
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
        ];
      case AudioService.recentRootId:
        // Return recently played items
        final recentItems = _recentSubject.value;
        developer.log(
          '[INFO][AudioPlayerHandlerImpl] Returning ${recentItems.length} recent items',
          name: 'AudioPlayerHandlerImpl',
        );
        return recentItems;
      case MediaLibrary.albumsRootId:
        // Return current queue/library items
        final libraryItems = _mediaLibrary.items[parentMediaId] ?? [];
        developer.log(
          '[INFO][AudioPlayerHandlerImpl] Returning ${libraryItems.length} library items',
          name: 'AudioPlayerHandlerImpl',
        );
        return libraryItems;
      default:
        // Fallback to library items for unknown parent IDs
        final fallbackItems = _mediaLibrary.items[parentMediaId] ?? [];
        developer.log(
          '[INFO][AudioPlayerHandlerImpl] Fallback: Returning ${fallbackItems.length} items for $parentMediaId',
          name: 'AudioPlayerHandlerImpl',
        );
        return fallbackItems;
    }
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    switch (parentMediaId) {
      case AudioService.recentRootId:
        final stream = _recentSubject.map((_) => <String, dynamic>{});
        return _recentSubject.hasValue
            ? stream.shareValueSeeded(<String, dynamic>{})
            : stream.shareValue();
      default:
        return Stream.value(
          _mediaLibrary.items[parentMediaId],
        ).map((_) => <String, dynamic>{}).shareValue();
    }
  }

  /// CRITICAL: Android Auto search support for voice commands
  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    developer.log(
      '[INFO][AudioPlayerHandlerImpl] Search called with query: $query',
      name: 'AudioPlayerHandlerImpl',
    );

    if (query.isEmpty) return [];

    final searchResults = <MediaItem>[];
    final queryLower = query.toLowerCase();

    // Search through current queue items
    for (final item in queue.value) {
      final titleMatch = item.title.toLowerCase().contains(queryLower);
      final artistMatch =
          item.artist?.toLowerCase().contains(queryLower) ?? false;
      final albumMatch =
          item.album?.toLowerCase().contains(queryLower) ?? false;

      if (titleMatch || artistMatch || albumMatch) {
        searchResults.add(item);
      }
    }

    // Search through recent items
    for (final item in _recentSubject.value) {
      final titleMatch = item.title.toLowerCase().contains(queryLower);
      final artistMatch =
          item.artist?.toLowerCase().contains(queryLower) ?? false;
      final albumMatch =
          item.album?.toLowerCase().contains(queryLower) ?? false;

      if (titleMatch || artistMatch || albumMatch) {
        // Avoid duplicates
        if (!searchResults.any((existing) => existing.id == item.id)) {
          searchResults.add(item);
        }
      }
    }

    developer.log(
      '[INFO][AudioPlayerHandlerImpl] Search returned ${searchResults.length} results',
      name: 'AudioPlayerHandlerImpl',
    );

    return searchResults
        .take(50)
        .toList(); // Limit to 50 results for performance
  }

  // Queue operation synchronization methods
  Future<T> _synchronizeQueueOperation<T>(
    Future<T> Function() operation,
  ) async {
    // If there's already an operation in progress, queue this one
    if (_isQueueOperationInProgress) {
      final completer = Completer<T>();
      _queueOperationQueue.add(() async {
        try {
          final result = await operation();
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      });
      return completer.future;
    }

    // Mark operation as in progress
    _isQueueOperationInProgress = true;
    _currentQueueOperation = Completer<void>();

    try {
      final result = await operation();
      return result;
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Queue operation failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
      rethrow;
    } finally {
      // Mark operation as complete
      _isQueueOperationInProgress = false;
      _currentQueueOperation?.complete();
      _currentQueueOperation = null;

      // Process next queued operation if any
      if (_queueOperationQueue.isNotEmpty) {
        final nextOperation = _queueOperationQueue.removeAt(0);
        // Don't await here to avoid blocking
        nextOperation().catchError((e) {
          developer.log(
            '[ERROR][AudioPlayerHandlerImpl] Queued operation failed: $e',
            name: 'AudioPlayerHandlerImpl',
            error: e,
          );
        });
      }
    }
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    return _synchronizeQueueOperation(() async {
      await _playlist.add(_itemToSource(mediaItem));
    });
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    return _synchronizeQueueOperation(() async {
      await _playlist.addAll(_itemsToSources(mediaItems));
    });
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    return _synchronizeQueueOperation(() async {
      await _playlist.insert(index, _itemToSource(mediaItem));
    });
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    return _synchronizeQueueOperation(() async {
      // Add shorter timeout to prevent hanging queue updates
      await _performQueueUpdate(newQueue).timeout(
        const Duration(seconds: 6), // Reduced from 10 to 6 seconds
        onTimeout: () {
          developer.log(
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

  Future<void> _performQueueUpdate(List<MediaItem> newQueue) async {
    developer.log(
      '[AudioPlayer] Updating queue with ${newQueue.length} items',
      name: 'AudioPlayerHandlerImpl',
    );

    if (newQueue.isNotEmpty) {
      developer.log(
        '[AudioPlayer] First song: ${newQueue[0].title}',
        name: 'AudioPlayerHandlerImpl',
      );
    }

    // Handle empty queue for clearing purposes
    if (newQueue.isEmpty) {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Clearing queue - stopping playback and clearing playlist',
        name: 'AudioPlayerHandlerImpl',
      );

      try {
        // Stop current playback
        if (_player.playing) {
          await _player.stop();
          developer.log(
            '[DEBUG][AudioPlayerHandlerImpl] Stopped playbook for queue clearing',
            name: 'AudioPlayerHandlerImpl',
          );
        }

        // Clear the playlist completely
        await _playlist.clear();
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Playlist cleared successfully',
          name: 'AudioPlayerHandlerImpl',
        );

        // Update media library with empty queue
        _mediaLibrary.updateQueue([]);

        // Update the queue state explicitly
        super.queue.add([]);

        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Queue successfully cleared',
          name: 'AudioPlayerHandlerImpl',
        );
      } catch (e) {
        developer.log(
          '[ERROR][AudioPlayerHandlerImpl] Failed to clear queue: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
      }

      return;
    }

    // Log current queue state before replacement
    final currentQueue = queue.value;
    developer.log(
      '[DEBUG][AudioPlayerHandlerImpl] Current queue has ${currentQueue.length} items',
      name: 'AudioPlayerHandlerImpl',
    );

    // PERFORMANCE OPTIMIZATION: Fast validation without blocking
    final validQueue = <MediaItem>[];
    for (final item in newQueue) {
      try {
        // Use actual_audio_url from extras for validation, not MediaItem ID
        final audioUrl = item.extras?['actual_audio_url'] as String? ?? item.id;

        // Quick validation - check if it's a valid URL format
        if (audioUrl.startsWith('http') ||
            audioUrl.startsWith('file') ||
            audioUrl.contains('.mp3') ||
            audioUrl.contains('.wav') ||
            audioUrl.contains('.m4a') ||
            audioUrl.contains('.aac')) {
          validQueue.add(item);
        } else {
          developer.log(
            '[WARNING][AudioPlayerHandlerImpl] Invalid audio URL for ${item.title}: $audioUrl',
            name: 'AudioPlayerHandlerImpl',
          );
        }
      } catch (e) {
        developer.log(
          '[ERROR][AudioPlayerHandlerImpl] Error validating URL for ${item.title}: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
      }
    }

    if (validQueue.isEmpty) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] No valid items in queue',
        name: 'AudioPlayerHandlerImpl',
      );
      return;
    }

    try {
      // Stop current playback to ensure clean queue replacement
      if (_player.playing) {
        try {
          await _player.stop().timeout(const Duration(seconds: 2));
        } on TimeoutException {
          developer.log(
            '[WARN][AudioPlayerHandlerImpl] Stop operation timed out during queue replacement',
            name: 'AudioPlayerHandlerImpl',
          );
        }
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Stopped current playback for queue replacement',
          name: 'AudioPlayerHandlerImpl',
        );
        // Shorter delay to improve responsiveness
        await Future.delayed(
          const Duration(milliseconds: 25),
        ); // Reduced from 50ms
      }

      // Clear the existing playlist completely
      try {
        await _playlist.clear().timeout(const Duration(seconds: 2));
      } on TimeoutException {
        developer.log(
          '[WARN][AudioPlayerHandlerImpl] Playlist clear timed out',
          name: 'AudioPlayerHandlerImpl',
        );
      }
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Cleared existing playlist',
        name: 'AudioPlayerHandlerImpl',
      );

      // PERFORMANCE OPTIMIZATION: Create sources in smaller batches for faster processing
      final validSources = <AudioSource>[];
      const batchSize = 3; // Reduced from 5 to 3 for faster processing

      for (int i = 0; i < validQueue.length; i += batchSize) {
        final batch = validQueue.skip(i).take(batchSize);
        final batchSources = await Future.wait(
          batch.map((item) async {
            try {
              final audioSource = _itemToSource(item);
              developer.log(
                '[DEBUG][AudioPlayerHandlerImpl] Created audio source for: ${item.title}',
                name: 'AudioPlayerHandlerImpl',
              );
              return audioSource;
            } catch (e) {
              final errorString = e.toString().toLowerCase();
              if (errorString.contains('connection') &&
                  errorString.contains('abort')) {
                developer.log(
                  '[INFO][AudioPlayerHandlerImpl] Connection abort for ${item.title} - normal for network streams',
                  name: 'AudioPlayerHandlerImpl',
                );
              } else {
                developer.log(
                  '[ERROR][AudioPlayerHandlerImpl] Failed to create source for ${item.title}: $e',
                  name: 'AudioPlayerHandlerImpl',
                  error: e,
                );
              }
              return null;
            }
          }),
          eagerError: false,
        );

        validSources.addAll(batchSources.whereType<AudioSource>());

        // Micro-delay between batches to prevent blocking
        await Future.delayed(const Duration(milliseconds: 1));
      }

      if (validSources.isNotEmpty) {
        // Add all new sources to the playlist with timeout
        try {
          await _playlist
              .addAll(validSources)
              .timeout(const Duration(seconds: 4));
        } on TimeoutException {
          developer.log(
            '[WARN][AudioPlayerHandlerImpl] Adding sources to playlist timed out',
            name: 'AudioPlayerHandlerImpl',
          );
        }

        // Set the new audio source with enhanced error handling
        try {
          await _player
              .setAudioSource(_playlist, preload: false)
              .timeout(const Duration(seconds: 3));
        } on TimeoutException {
          developer.log(
            '[WARN][AudioPlayerHandlerImpl] setAudioSource timed out during queue replacement',
            name: 'AudioPlayerHandlerImpl',
          );
        } catch (e) {
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('connection') &&
              errorString.contains('abort')) {
            developer.log(
              '[INFO][AudioPlayerHandlerImpl] Connection abort during setAudioSource - normal for network streams',
              name: 'AudioPlayerHandlerImpl',
            );
            // Don't treat connection aborts as failures
          } else {
            developer.log(
              '[WARN][AudioPlayerHandlerImpl] setAudioSource failed: $e, continuing anyway',
              name: 'AudioPlayerHandlerImpl',
            );
          }
        }

        // Ensure player is in stopped state after queue update
        if (_player.processingState != ProcessingState.idle) {
          try {
            await _player.stop().timeout(const Duration(seconds: 1));
          } on TimeoutException {
            developer.log(
              '[WARN][AudioPlayerHandlerImpl] Final stop operation timed out',
              name: 'AudioPlayerHandlerImpl',
            );
          } catch (e) {
            developer.log(
              '[WARN][AudioPlayerHandlerImpl] Final stop failed: $e',
              name: 'AudioPlayerHandlerImpl',
            );
          }
        }

        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Successfully replaced queue with ${validSources.length} audio sources',
          name: 'AudioPlayerHandlerImpl',
        );

        // Update the media library with new queue
        _mediaLibrary.updateQueue(validQueue);

        // Regenerate shuffle indices if shuffle is enabled
        if (_isShuffleEnabled && validQueue.isNotEmpty) {
          _generateShuffleIndices();
        }

        // Track history for the first song in the new queue if it's not empty
        if (validQueue.isNotEmpty) {
          _trackSongHistory(validQueue[0]);
        }

        // Log first few items in new queue for verification
        for (int i = 0; i < validQueue.length && i < 3; i++) {
          developer.log(
            '[DEBUG][AudioPlayerHandlerImpl] Queue item $i: ${validQueue[i].title}',
            name: 'AudioPlayerHandlerImpl',
          );
        }
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to replace queue: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
      rethrow; // Re-throw to trigger timeout handling
    }
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
        developer.log(
          '[AudioPlayerHandlerImpl] updateMediaItem: Updated current MediaItem and emitted to stream',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    } else {
      developer.log(
        '[WARNING][AudioPlayerHandlerImpl] updateMediaItem: Invalid index or sequence is null',
        name: 'AudioPlayerHandlerImpl',
      );
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    return _synchronizeQueueOperation(() async {
      final index = queue.value.indexOf(mediaItem);
      if (index >= 0 && index < _playlist.length) {
        await _playlist.removeAt(index);
      } else {
        developer.log(
          '[WARNING][AudioPlayerHandlerImpl] Attempted to remove item not in queue or invalid index: \\${mediaItem.title}',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    });
  }

  @override
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {
    return _synchronizeQueueOperation(() async {
      if (currentIndex >= 0 &&
          currentIndex < queue.value.length &&
          newIndex >= 0 &&
          newIndex < queue.value.length &&
          _playlist.length > currentIndex &&
          _playlist.length > newIndex) {
        await _playlist.move(currentIndex, newIndex);
      } else {
        developer.log(
          '[WARNING][AudioPlayerHandlerImpl] Invalid indices for move operation: \\$currentIndex -> \\$newIndex (queue length: \\${queue.value.length}, playlist length: \\${_playlist.length})',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    });
  }

  // Playback control methods
  @override
  Future<void> skipToNext() async {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Attempting to skip to next track',
        name: 'AudioPlayerHandlerImpl',
      );

      final currentRepeatMode = playbackState.value.repeatMode;
      final currentIndex = _player.currentIndex ?? 0;
      final nextIndex = _getNextIndex(currentIndex);

      // If user manually skips while in "repeat one" mode, change to "repeat all"
      if (currentRepeatMode == AudioServiceRepeatMode.one) {
        await setRepeatMode(AudioServiceRepeatMode.all);
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Changed repeat mode from "one" to "all" due to manual skip',
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

      if (nextIndex == null) {
        // End of queue - handle repeat mode
        final repeatMode = playbackState.value.repeatMode;
        if (repeatMode == AudioServiceRepeatMode.all) {
          final firstIndex =
              _isShuffleEnabled && _shuffledIndices.isNotEmpty
                  ? _shuffledIndices.first
                  : 0;
          await _player.seek(Duration.zero, index: firstIndex);

          // Track history for the song when wrapping around
          if (queue.value.isNotEmpty && firstIndex < queue.value.length) {
            _trackSongHistory(queue.value[firstIndex]);
          }
          await _ensureCurrentMediaItemImageIsNormalized();
        } else {
          // Comment out: Toast message removed
          // Fluttertoast.showToast(
          //   msg: 'Don\'t have track to play in next ',
          //   toastLength: Toast.LENGTH_SHORT,
          //   timeInSecForIosWeb: 1,
          //   backgroundColor: appColors().black,
          //   textColor: appColors().colorBackground,
          //   fontSize: 14.0,
          // );
          return;
        }
      } else {
        // Skip to the next song in our custom order
        await _player.seek(Duration.zero, index: nextIndex);

        // Track history for the next song
        if (nextIndex < queue.value.length) {
          _trackSongHistory(queue.value[nextIndex]);
        }
        await _ensureCurrentMediaItemImageIsNormalized();
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to skip to next: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Attempting to skip to previous track',
        name: 'AudioPlayerHandlerImpl',
      );

      // CRITICAL FEATURE: Check current playback position for 4-second rule
      final currentPosition = _player.position;
      final fourSeconds = const Duration(seconds: 4);

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Current position: ${currentPosition.inSeconds}s, 4-second threshold check',
        name: 'AudioPlayerHandlerImpl',
      );

      // If within first 4 seconds, go to previous track; otherwise restart current song
      if (currentPosition <= fourSeconds) {
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Within 4 seconds (${currentPosition.inSeconds}s) - going to previous track',
          name: 'AudioPlayerHandlerImpl',
        );
        await _skipToPreviousTrack();
      } else {
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] After 4 seconds (${currentPosition.inSeconds}s) - restarting current song',
          name: 'AudioPlayerHandlerImpl',
        );
        await _restartCurrentSong();
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to skip to previous: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  /// Restart the current song from the beginning
  Future<void> _restartCurrentSong() async {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Restarting current song from beginning',
        name: 'AudioPlayerHandlerImpl',
      );

      // Seek to the beginning of the current track
      await _player.seek(Duration.zero);

      // Track history for restarting the current song
      final currentIndex = _player.currentIndex ?? 0;
      if (currentIndex < queue.value.length) {
        _trackSongHistory(queue.value[currentIndex]);
      }

      // Immediate state broadcast for responsive UI
      _performBroadcast(_player.playbackEvent);

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Successfully restarted current song',
        name: 'AudioPlayerHandlerImpl',
      );
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to restart current song: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
      rethrow;
    }
  }

  /// Skip to the actual previous track in the queue
  Future<void> _skipToPreviousTrack() async {
    try {
      final currentRepeatMode = playbackState.value.repeatMode;
      final currentIndex = _player.currentIndex ?? 0;
      final previousIndex = _getPreviousIndex(currentIndex);

      // If user manually skips while in "repeat one" mode, change to "repeat all"
      if (currentRepeatMode == AudioServiceRepeatMode.one) {
        await setRepeatMode(AudioServiceRepeatMode.all);
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Changed repeat mode from "one" to "all" due to manual skip',
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

      if (previousIndex == null) {
        // Beginning of queue - handle repeat mode
        final repeatMode = playbackState.value.repeatMode;
        if (repeatMode == AudioServiceRepeatMode.all) {
          final lastIndex =
              _isShuffleEnabled && _shuffledIndices.isNotEmpty
                  ? _shuffledIndices.last
                  : queue.value.length - 1;
          await _player.seek(Duration.zero, index: lastIndex);

          // Track history for the song when wrapping around
          if (queue.value.isNotEmpty && lastIndex < queue.value.length) {
            _trackSongHistory(queue.value[lastIndex]);
          }
          await _ensureCurrentMediaItemImageIsNormalized();
        } else {
          // Comment out: Toast message removed
          // Fluttertoast.showToast(
          //   msg: 'Don\'t have track in previous',
          //   toastLength: Toast.LENGTH_SHORT,
          //   timeInSecForIosWeb: 1,
          //   backgroundColor: appColors().black,
          //   textColor: appColors().colorBackground,
          //   fontSize: 14.0,
          // );
          return;
          // }
        }
      } else {
        // Skip to the previous song in our custom order
        await _player.seek(Duration.zero, index: previousIndex);

        // Track history for the previous song
        if (previousIndex < queue.value.length) {
          _trackSongHistory(queue.value[previousIndex]);
        }
        await _ensureCurrentMediaItemImageIsNormalized();
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to skip to previous track: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
      rethrow;
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      if (index < 0 ||
          _playlist.children.isEmpty ||
          index >= _playlist.children.length) {
        developer.log(
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
        developer.log(
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

      developer.log(
        '🎯🎯🎯 AUDIO PLAYER SERVICE SKIP TO QUEUE ITEM 🎯🎯🎯',
        name: 'AudioPlayerHandlerImpl',
      );
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Attempting to skip to index: $index',
        name: 'AudioPlayerHandlerImpl',
      );
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Queue length: ${_playlist.children.length}',
        name: 'AudioPlayerHandlerImpl',
      );
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Current player index BEFORE skip: ${_player.currentIndex}',
        name: 'AudioPlayerHandlerImpl',
      );
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Shuffle enabled: ${_player.shuffleModeEnabled}',
        name: 'AudioPlayerHandlerImpl',
      );

      // Remember current playing state
      final wasPlaying = _player.playing;
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Was playing: $wasPlaying',
        name: 'AudioPlayerHandlerImpl',
      );

      // Calculate the effective index to seek to
      final effectiveIndex =
          _player.shuffleModeEnabled ? _player.shuffleIndices![index] : index;
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] 🎵 Effective index to seek to: $effectiveIndex (original: $index)',
        name: 'AudioPlayerHandlerImpl',
      );

      // Perform fast seek operation without pausing first
      try {
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] 🎵 Fast seek to index $effectiveIndex',
          name: 'AudioPlayerHandlerImpl',
        );

        // Seek to the new track at position zero - no pause needed
        await _player.seek(Duration.zero, index: effectiveIndex);

        // Much shorter delay for fast response
        await Future.delayed(const Duration(milliseconds: 100));

        final newCurrentIndex = _player.currentIndex;
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] 🎵 Player current index AFTER seek: $newCurrentIndex (expected: $effectiveIndex)',
          name: 'AudioPlayerHandlerImpl',
        );

        // Verify seek was successful
        if (newCurrentIndex != effectiveIndex) {
          developer.log(
            '[WARN][AudioPlayerHandlerImpl] Seek index mismatch, but proceeding anyway',
            name: 'AudioPlayerHandlerImpl',
          );
        }
      } catch (e) {
        developer.log(
          '[ERROR][AudioPlayerHandlerImpl] Fast seek failed: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );
        rethrow;
      }

      // Quick state broadcast for immediate UI update
      _performBroadcast(_player.playbackEvent);

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] ✅ Successfully skipped to queue item $index, was playing: $wasPlaying',
        name: 'AudioPlayerHandlerImpl',
      );
      // Auto-play after skipping to queue item
      await _player.play();
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] ▶️ Playback started after skipToQueueItem',
        name: 'AudioPlayerHandlerImpl',
      );
      // Ensure the new current MediaItem has normalized image URL - do this async
      _ensureCurrentMediaItemImageIsNormalized();

      // Track history for the new current song - do this async
      if (index < queue.value.length) {
        _trackSongHistory(queue.value[index]);
      }

      // Note: We don't auto-resume playback here. The caller should explicitly call play() if needed.
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to skip to queue item: \\$e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
      rethrow; // Re-throw so the caller knows it failed
    }
  }

  // Play operation lock to prevent concurrent play calls
  bool _isPlayOperationInProgress = false;
  Completer<void>? _currentPlayOperation;

  @override
  Future<void> play() async {
    // Prevent concurrent play operations but with better error handling
    if (_isPlayOperationInProgress) {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Play operation already in progress, checking if stale...',
        name: 'AudioPlayerHandlerImpl',
      );

      // Check if the operation has been running too long (stale lock)
      if (_currentPlayOperation != null &&
          !_currentPlayOperation!.isCompleted) {
        try {
          await _currentPlayOperation!.future.timeout(
            const Duration(seconds: 2),
          );
        } catch (e) {
          developer.log(
            '[DEBUG][AudioPlayerHandlerImpl] Previous play operation timed out, continuing with new operation',
            name: 'AudioPlayerHandlerImpl',
          );
          _isPlayOperationInProgress = false; // Reset stale lock
        }
      }

      if (_isPlayOperationInProgress) {
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Play operation still in progress, aborting duplicate attempt',
          name: 'AudioPlayerHandlerImpl',
        );
        return;
      }
    }

    _isPlayOperationInProgress = true;
    _currentPlayOperation = Completer<void>();

    try {
      // Check circuit breaker before attempting playback
      _checkCircuitBreaker();
      if (_circuitBreakerOpen) {
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Circuit breaker open - skipping playback attempt',
          name: 'AudioPlayerHandlerImpl',
        );
        return;
      }

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Starting playback - current queue index: ${_player.currentIndex}, queue length: ${queue.value.length}',
        name: 'AudioPlayerHandlerImpl',
      );

      // CRITICAL FIX: Check if we have a valid queue first
      if (queue.value.isEmpty) {
        developer.log(
          '[ERROR][AudioPlayerHandlerImpl] Cannot play - queue is empty',
          name: 'AudioPlayerHandlerImpl',
        );
        return;
      }

      // Track history for current song when play is called
      final currentIndex = _player.currentIndex;
      if (currentIndex != null && currentIndex < queue.value.length) {
        final currentMediaItem = queue.value[currentIndex];
        _trackSongHistory(currentMediaItem);
      }

      // CRITICAL FIX: Ensure audio session is active before playing
      final session = await AudioSession.instance;
      await session.setActive(true);
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Audio session activated',
        name: 'AudioPlayerHandlerImpl',
      );

      // CRITICAL FIX: Enable wake lock for continuous playback
      await _backgroundAudioManager.enableWakeLock();

      // CRITICAL FIX: Check player state before attempting to play
      final processingState = _player.processingState;
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Player processing state: $processingState',
        name: 'AudioPlayerHandlerImpl',
      );

      // Handle different processing states appropriately
      if (processingState == ProcessingState.idle) {
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Player idle, reloading current item',
          name: 'AudioPlayerHandlerImpl',
        );
        await _reloadCurrentItem();
      }

      if (processingState == ProcessingState.loading) {
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Player loading, waiting for ready state',
          name: 'AudioPlayerHandlerImpl',
        );
        // Wait for the player to become ready with shorter timeout for faster response
        await _player.processingStateStream
            .firstWhere(
              (state) =>
                  state == ProcessingState.ready ||
                  state == ProcessingState.buffering,
              orElse: () => ProcessingState.ready,
            )
            .timeout(
              const Duration(seconds: 2), // Reduced timeout from 3 to 2 seconds
              onTimeout: () {
                developer.log(
                  '[DEBUG][AudioPlayerHandlerImpl] Timeout waiting for ready state, proceeding anyway',
                  name: 'AudioPlayerHandlerImpl',
                );
                return ProcessingState.ready;
              },
            );
      }

      // CRITICAL FIX: Actually start playback with connection abort protection
      try {
        await _player.play().timeout(
          const Duration(
            seconds: 1,
          ), // Reduced timeout from 3 to 1 second for faster response
          onTimeout: () {
            developer.log(
              '[WARN][AudioPlayerHandlerImpl] Play command timed out after 1 second, but playback may still start',
              name: 'AudioPlayerHandlerImpl',
            );
            // Don't throw - allow the operation to complete and playback may start naturally
          },
        );
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('connection') &&
            errorString.contains('abort')) {
          developer.log(
            '[WARN][AudioPlayerHandlerImpl] Connection aborted during play - this is normal for network streams',
            name: 'AudioPlayerHandlerImpl',
          );
          // Don't treat connection abort as a failure - it's normal for network streams
        } else {
          rethrow; // Re-throw other errors
        }
      }

      // Immediate state broadcast for responsive UI
      _performBroadcast(_player.playbackEvent);

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Playback started successfully',
        name: 'AudioPlayerHandlerImpl',
      );
      // Notify native (iOS) that playback started so native queries are accurate
      try {
        await _backgroundAudioManager.notifyNativePlayingState(true);
        await _backgroundAudioManager.notifyNativeServiceRunning(true);
        // Persist now that playback actually started
        try {
          final current = mediaItem.valueOrNull;
          if (current != null) {
            await _backgroundAudioManager.persistPlaybackState({
              'id': current.id,
              'title': current.title,
              'artist': current.artist ?? '',
              'album': current.album ?? '',
              'position': _player.position.inMilliseconds.toString(),
              'playing': 'true',
            });
          }
        } catch (_) {}
      } catch (e) {
        developer.log(
          '[WARN][AudioPlayerHandlerImpl] Failed to notify native playing state: $e',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('connection') && errorString.contains('abort')) {
        developer.log(
          '[WARN][AudioPlayerHandlerImpl] Connection abort during playback is normal for network streams',
          name: 'AudioPlayerHandlerImpl',
        );
      } else {
        developer.log(
          '[ERROR][AudioPlayerHandlerImpl] Playback failed: $e',
          name: 'AudioPlayerHandlerImpl',
          error: e,
        );

        // CRITICAL FIX: Implement error recovery for actual errors
        await _handlePlaybackError(e);
      }
    } finally {
      // Always release the play operation lock
      _isPlayOperationInProgress = false;
      if (_currentPlayOperation != null &&
          !_currentPlayOperation!.isCompleted) {
        _currentPlayOperation!.complete();
      }
    }
  }

  @override
  Future<void> pause() async {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Pause requested',
        name: 'AudioPlayerHandlerImpl',
      );

      // Check if we have a valid player state
      if (_player.processingState == ProcessingState.idle) {
        developer.log(
          '[WARNING][AudioPlayerHandlerImpl] Cannot pause - player is idle',
          name: 'AudioPlayerHandlerImpl',
        );
        return;
      }

      // Only pause if actually playing
      if (!_player.playing) {
        developer.log(
          '[DEBUG][AudioPlayerHandlerImpl] Already paused, no action needed',
          name: 'AudioPlayerHandlerImpl',
        );
        return;
      }

      // Perform the pause operation with timeout
      await _player.pause().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          developer.log(
            '[WARN][AudioPlayerHandlerImpl] Pause command timed out after 2 seconds',
            name: 'AudioPlayerHandlerImpl',
          );
        },
      );

      // Immediate state broadcast for responsive UI
      _performBroadcast(_player.playbackEvent);

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Playback paused successfully',
        name: 'AudioPlayerHandlerImpl',
      );
      // Sync native playing state
      try {
        await _backgroundAudioManager.notifyNativePlayingState(false);
        // Persist paused state
        try {
          final current = mediaItem.valueOrNull;
          if (current != null) {
            await _backgroundAudioManager.persistPlaybackState({
              'id': current.id,
              'title': current.title,
              'artist': current.artist ?? '',
              'album': current.album ?? '',
              'position': _player.position.inMilliseconds.toString(),
              'playing': 'false',
            });
          }
        } catch (_) {}
      } catch (e) {
        developer.log(
          '[WARN][AudioPlayerHandlerImpl] Failed to notify native playing state on pause: $e',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Pause failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
      // Don't rethrow to prevent cascade failures - pause should be tolerant
    }
  }

  @override
  Future<void> stop() async {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Stop requested',
        name: 'AudioPlayerHandlerImpl',
      );

      await _player.stop();
      await _backgroundAudioManager.disableWakeLock();

      // Sync native state: playback stopped and service no longer running
      try {
        await _backgroundAudioManager.notifyNativePlayingState(false);
        await _backgroundAudioManager.notifyNativeServiceRunning(false);
        // Persist stopped state (clear playing)
        try {
          final current = mediaItem.valueOrNull;
          if (current != null) {
            await _backgroundAudioManager.persistPlaybackState({
              'id': current.id,
              'title': current.title,
              'artist': current.artist ?? '',
              'album': current.album ?? '',
              'position': _player.position.inMilliseconds.toString(),
              'playing': 'false',
            });
          }
        } catch (_) {}
      } catch (e) {
        developer.log(
          '[WARN][AudioPlayerHandlerImpl] Failed to notify native service stopped: $e',
          name: 'AudioPlayerHandlerImpl',
        );
      }

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Playback stopped successfully',
        name: 'AudioPlayerHandlerImpl',
      );
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Stop failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Seek to ${position.inSeconds}s requested',
        name: 'AudioPlayerHandlerImpl',
      );

      await _player.seek(position);

      // Immediate state broadcast for responsive UI
      _performBroadcast(_player.playbackEvent);

      developer.log(
        '[DEBUG][AudioPlayerHandlerImpl] Seek completed successfully',
        name: 'AudioPlayerHandlerImpl',
      );
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Seek failed: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  Future<void> _reloadCurrentItem() async {
    try {
      final currentIndex = _player.currentIndex ?? 0;
      if (_playlist.children.isNotEmpty &&
          currentIndex < _playlist.children.length) {
        // Add timeout to prevent hanging
        await _player
            .setAudioSource(
              _playlist,
              initialIndex: currentIndex,
              preload: false,
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                developer.log(
                  '[DEBUG][AudioPlayerHandlerImpl] Reload current item timed out after 5 seconds',
                  name: 'AudioPlayerHandlerImpl',
                );
                return;
              },
            );
      } else {
        developer.log(
          '[WARNING][AudioPlayerHandlerImpl] _reloadCurrentItem: Playlist is empty or index out of range',
          name: 'AudioPlayerHandlerImpl',
        );
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to reload current item: \\$e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
      // Don't rethrow to prevent cascade failures
    }
  }

  /// Enhanced error recovery with circuit breaker pattern
  bool _circuitBreakerOpen = false;
  DateTime _lastFailureTime = DateTime(0);
  int _failureCount = 0;
  static const int _maxFailureCount = 5;
  static const Duration _circuitBreakerTimeout = Duration(minutes: 2);

  Future<void> _handlePlaybackError(dynamic error) async {
    try {
      final errorString = error.toString().toLowerCase();
      _failureCount++;
      _lastFailureTime = DateTime.now();

      developer.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Handling playback error (failure count: $_failureCount): $error',
        name: 'AudioPlayerHandlerImpl',
        error: error,
      );

      // Circuit breaker pattern - if too many failures, temporarily stop recovery attempts
      if (_failureCount >= _maxFailureCount) {
        _circuitBreakerOpen = true;
        developer.log(
          '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Circuit breaker opened - too many failures',
          name: 'AudioPlayerHandlerImpl',
        );
        return;
      }

      if (errorString.contains('mediacodec') ||
          errorString.contains('exoplayer') ||
          errorString.contains('codec')) {
        await _recoverFromCodecError();
      } else if (errorString.contains('network') ||
          errorString.contains('connection') ||
          errorString.contains('timeout')) {
        await _recoverFromNetworkError();
      } else if (errorString.contains('format') ||
          errorString.contains('source')) {
        await _recoverFromSourceError();
      } else {
        await _performGenericRecovery();
      }
    } catch (recoveryError) {
      developer.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Recovery failed: $recoveryError',
        name: 'AudioPlayerHandlerImpl',
        error: recoveryError,
      );
    }
  }

  /// Check and reset circuit breaker if timeout has passed
  void _checkCircuitBreaker() {
    if (_circuitBreakerOpen &&
        DateTime.now().difference(_lastFailureTime) > _circuitBreakerTimeout) {
      _circuitBreakerOpen = false;
      _failureCount = 0;
      developer.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Circuit breaker reset',
        name: 'AudioPlayerHandlerImpl',
      );
    }
  }

  Future<void> _recoverFromCodecError() async {
    developer.log(
      '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Recovering from codec error',
      name: 'AudioPlayerHandlerImpl',
    );

    try {
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 500));
      await _reloadCurrentItem();
      await Future.delayed(const Duration(milliseconds: 300));
      await _player.play();
    } catch (e) {
      developer.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Codec error recovery failed: $e',
        name: 'AudioPlayerHandlerImpl',
      );
    }
  }

  Future<void> _recoverFromNetworkError() async {
    developer.log(
      '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Recovering from network error',
      name: 'AudioPlayerHandlerImpl',
    );

    try {
      // Wait longer for network recovery
      await Future.delayed(const Duration(seconds: 2));

      // Try to reload the current item with fresh network connection
      await _reloadCurrentItem();
      await Future.delayed(const Duration(milliseconds: 500));

      // Attempt playback with shorter timeout
      await _player.play().timeout(const Duration(seconds: 3));
    } catch (e) {
      developer.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Network error recovery failed: $e',
        name: 'AudioPlayerHandlerImpl',
      );
    }
  }

  Future<void> _recoverFromSourceError() async {
    developer.log(
      '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Recovering from source error',
      name: 'AudioPlayerHandlerImpl',
    );

    try {
      final currentIndex = _player.currentIndex;
      if (currentIndex != null && currentIndex < queue.value.length) {
        // Try to skip to next valid source
        if (currentIndex + 1 < queue.value.length) {
          await skipToQueueItem(currentIndex + 1);
        } else {
          // Loop back to beginning if at end
          await skipToQueueItem(0);
        }
      }
    } catch (e) {
      developer.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Source error recovery failed: $e',
        name: 'AudioPlayerHandlerImpl',
      );
    }
  }

  Future<void> _performGenericRecovery() async {
    developer.log(
      '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Performing generic recovery',
      name: 'AudioPlayerHandlerImpl',
    );

    try {
      // Simple stop and restart
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 1000));
      await _player.play();
    } catch (e) {
      developer.log(
        '[ERROR_RECOVERY][AudioPlayerHandlerImpl] Generic recovery failed: $e',
        name: 'AudioPlayerHandlerImpl',
      );
    }
  }

  /// Broadcast state changes to listeners
  void _broadcastState(PlaybackEvent event) {
    try {
      final isPlaying = _player.playing;
      final processingState = _player.processingState;
      final speed = _player.speed;
      final position = _player.position;
      final bufferedPosition = _player.bufferedPosition;
      final currentIndex = _player.currentIndex;

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState:
              const {
                ProcessingState.idle: AudioProcessingState.idle,
                ProcessingState.loading: AudioProcessingState.loading,
                ProcessingState.buffering: AudioProcessingState.buffering,
                ProcessingState.ready: AudioProcessingState.ready,
                ProcessingState.completed: AudioProcessingState.completed,
              }[processingState]!,
          playing: isPlaying,
          updatePosition: position,
          bufferedPosition: bufferedPosition,
          speed: speed,
          queueIndex: currentIndex,
        ),
      );
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Error broadcasting state: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }

  /// Perform immediate state broadcast
  void _performBroadcast(PlaybackEvent event) {
    _broadcastState(event);
  }

  /// Ensure current media item has normalized image URL
  Future<void> _ensureCurrentMediaItemImageIsNormalized() async {
    try {
      final currentItem = mediaItem.value;
      if (currentItem != null) {
        final fixedItem = MediaItemImageFixer.fixMediaItemImageUrl(currentItem);
        if (fixedItem != currentItem) {
          mediaItem.add(fixedItem);
        }
      }
    } catch (e) {
      developer.log(
        '[ERROR][AudioPlayerHandlerImpl] Failed to normalize current media item image: $e',
        name: 'AudioPlayerHandlerImpl',
        error: e,
      );
    }
  }
}
