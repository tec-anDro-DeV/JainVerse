import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/performance_debouncer.dart';

/// Stream throttling extension for performance optimization
extension StreamThrottle<T> on Stream<T> {
  Stream<T> throttle(Duration duration) {
    return Stream<T>.eventTransformed(
      this,
      (EventSink<T> sink) => ThrottleSink<T>(sink, duration),
    );
  }
}

class ThrottleSink<T> implements EventSink<T> {
  final EventSink<T> _sink;
  final Duration _duration;
  Timer? _timer;
  T? _lastValue;

  ThrottleSink(this._sink, this._duration);

  @override
  void add(T value) {
    _lastValue = value;
    _timer ??= Timer(_duration, () {
      if (_lastValue != null) {
        _sink.add(_lastValue as T);
      }
      _timer = null;
    });
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _sink.addError(error, stackTrace);
  }

  @override
  void close() {
    _timer?.cancel();
    _sink.close();
  }
}

/// Controller for managing playback controls and queue operations
class PlaybackController extends ChangeNotifier {
  // Singleton pattern
  static final PlaybackController _instance = PlaybackController._internal();
  factory PlaybackController() => _instance;
  PlaybackController._internal();

  AudioPlayerHandler? _audioHandler;
  bool _isDisposed = false; // Add disposal state guard

  // Playback state
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;
  bool _shuffleEnabled = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  // Queue management
  List<MediaItem> _queue = [];
  int? _currentIndex;

  // Stream subscriptions
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _mediaItemSubscription;
  StreamSubscription? _queueSubscription;
  StreamSubscription? _positionSubscription;

  // Getters
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  double get speed => _speed;
  bool get shuffleEnabled => _shuffleEnabled;
  AudioServiceRepeatMode get repeatMode => _repeatMode;
  List<MediaItem> get queue => _queue;
  int? get currentIndex => _currentIndex;
  MediaItem? get currentMediaItem =>
      (_currentIndex != null && _currentIndex! < _queue.length)
          ? _queue[_currentIndex!]
          : null;

  /// Debounced notify listeners to prevent excessive UI updates
  void _debouncedNotifyListeners() {
    if (_isDisposed) return;

    PerformanceDebouncer.debounceUIUpdate(
      'playback_controller_notify',
      () {
        if (!_isDisposed) {
          notifyListeners();
        }
      },
      delay: const Duration(milliseconds: 16), // ~60 FPS
    );
  }

  /// Initialize the playback controller with audio handler
  void initialize(AudioPlayerHandler audioHandler) {
    // If previously disposed, reset the disposal state for reinitialization
    if (_isDisposed) {
      _isDisposed = false;
      developer.log(
        '[DEBUG][PlaybackController][initialize] Reinitializing previously disposed controller',
        name: 'PlaybackController',
      );
    }

    if (_audioHandler == audioHandler && !_isDisposed) {
      developer.log(
        '[DEBUG][PlaybackController][initialize] Already initialized with same handler',
        name: 'PlaybackController',
      );
      return; // Already initialized with the same handler
    }

    _audioHandler = audioHandler;
    _setupStreamListeners();

    developer.log(
      '[DEBUG][PlaybackController][initialize] Initialized',
      name: 'PlaybackController',
    );
  }

  /// Set up stream listeners for playback state changes
  void _setupStreamListeners() {
    if (_audioHandler == null || _isDisposed) return;

    // Cancel existing subscriptions first
    _playbackStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    _queueSubscription?.cancel();
    _positionSubscription?.cancel();

    // Listen to playback state changes with debouncing
    _playbackStateSubscription = _audioHandler!.playbackState.listen((state) {
      if (_isDisposed) return; // Guard against disposed state

      bool stateChanged = false;

      if (_isPlaying != state.playing) {
        _isPlaying = state.playing;
        stateChanged = true;
      }

      if (_isLoading !=
          (state.processingState == AudioProcessingState.loading)) {
        _isLoading = state.processingState == AudioProcessingState.loading;
        stateChanged = true;
      }

      if (_isBuffering !=
          (state.processingState == AudioProcessingState.buffering)) {
        _isBuffering = state.processingState == AudioProcessingState.buffering;
        stateChanged = true;
      }

      if (_currentIndex != state.queueIndex) {
        _currentIndex = state.queueIndex;
        stateChanged = true;
      }

      if (_shuffleEnabled !=
          (state.shuffleMode == AudioServiceShuffleMode.all)) {
        _shuffleEnabled = state.shuffleMode == AudioServiceShuffleMode.all;
        stateChanged = true;
      }

      if (_repeatMode != state.repeatMode) {
        _repeatMode = state.repeatMode;
        stateChanged = true;
      }

      if (_speed != state.speed) {
        _speed = state.speed;
        stateChanged = true;
      }

      if (stateChanged) {
        _debouncedNotifyListeners();

        // FIXED: Only log significant state changes (play/pause) to reduce log spam
        if (_isPlaying != state.playing) {
          developer.log(
            '[DEBUG][PlaybackController] State: playing=$_isPlaying, index=$_currentIndex',
            name: 'PlaybackController',
          );
        }
      }
    });

    // Listen to media item changes
    _mediaItemSubscription = _audioHandler!.mediaItem.listen((mediaItem) {
      if (_isDisposed) return; // Guard against disposed state

      if (mediaItem != null) {
        final newDuration = mediaItem.duration ?? Duration.zero;
        if (_duration != newDuration) {
          // Only notify on actual duration changes
          _duration = newDuration;
          if (!_isDisposed) {
            _debouncedNotifyListeners();
          }
        }
      }
    });

    // Listen to queue changes
    _queueSubscription = _audioHandler!.queue.listen((queue) {
      if (_isDisposed) return; // Guard against disposed state

      if (_queue.length != queue.length) {
        // Only notify on length changes
        _queue = queue;
        if (!_isDisposed) {
          notifyListeners();
        }

        // FIXED: Only log queue changes during initial setup or significant changes
        if (queue.isNotEmpty &&
            (_queue.isEmpty || queue.length != _queue.length)) {
          developer.log(
            '[DEBUG][PlaybackController] Queue: length=${queue.length}',
            name: 'PlaybackController',
          );
        }
      } else {
        _queue = queue; // Update silently if same length
      }
    });

    // CRITICAL PERFORMANCE FIX: Listen to position changes with aggressive throttling
    _positionSubscription = AudioService.position
        .throttle(
          const Duration(
            milliseconds: 1000,
          ), // CRITICAL: Reduced from 500ms to 1000ms for better performance
        ) // Throttle position updates
        .listen((position) {
          if (_isDisposed) return; // Guard against disposed state

          // CRITICAL: Only update if position changed significantly (avoid micro-updates)
          if ((_position - position).abs().inMilliseconds > 800) {
            // CRITICAL: Increased from 100ms to 800ms
            _position = position;
            if (!_isDisposed) {
              _debouncedNotifyListeners(); // Use debounced notification
            }
          }
        });
  }

  /// Play the current track
  Future<void> play() async {
    if (_audioHandler == null) return;

    try {
      await _audioHandler!.play();
      developer.log(
        '[DEBUG][PlaybackController][play] Play requested',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][play] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Pause the current track
  Future<void> pause() async {
    if (_audioHandler == null) return;

    try {
      await _audioHandler!.pause();
      developer.log(
        '[DEBUG][PlaybackController][pause] Pause requested',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][pause] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Stop playback
  Future<void> stop() async {
    if (_audioHandler == null) return;

    try {
      await _audioHandler!.stop();
      developer.log(
        '[DEBUG][PlaybackController][stop] Stop requested',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][stop] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Skip to next track
  Future<void> skipToNext() async {
    if (_audioHandler == null) return;

    try {
      await _audioHandler!.skipToNext();
      developer.log(
        '[DEBUG][PlaybackController][skipToNext] Skip to next requested',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][skipToNext] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Skip to previous track
  Future<void> skipToPrevious() async {
    if (_audioHandler == null) return;

    try {
      await _audioHandler!.skipToPrevious();
      developer.log(
        '[DEBUG][PlaybackController][skipToPrevious] Skip to previous requested',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][skipToPrevious] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Seek to a specific position
  Future<void> seek(Duration position) async {
    if (_audioHandler == null) return;

    try {
      await _audioHandler!.seek(position);
      developer.log(
        '[DEBUG][PlaybackController][seek] Seek to ${position.inSeconds}s requested',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][seek] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Skip to a specific queue item
  Future<void> skipToQueueItem(int index) async {
    if (_audioHandler == null || index < 0 || index >= _queue.length) return;

    try {
      // Update current index in our local state first
      _currentIndex = index;
      if (!_isDisposed) {
        notifyListeners();
      }

      // Skip to the requested queue item
      await _audioHandler!.skipToQueueItem(index);

      developer.log(
        '[DEBUG][PlaybackController][skipToQueueItem] Skip to index $index requested',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][skipToQueueItem] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (_audioHandler == null) return;

    volume = volume.clamp(0.0, 1.0);

    try {
      await _audioHandler!.setVolume(volume);
      _volume = volume;
      notifyListeners();

      developer.log(
        '[DEBUG][PlaybackController][setVolume] Volume set to $volume',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][setVolume] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    if (_audioHandler == null) return;

    speed = speed.clamp(0.5, 2.0);

    try {
      await _audioHandler!.setSpeed(speed);
      _speed = speed;
      notifyListeners();

      developer.log(
        '[DEBUG][PlaybackController][setSpeed] Speed set to $speed',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][setSpeed] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Toggle shuffle mode
  Future<void> toggleShuffle() async {
    if (_audioHandler == null) return;

    try {
      final newMode =
          _shuffleEnabled
              ? AudioServiceShuffleMode.none
              : AudioServiceShuffleMode.all;

      await _audioHandler!.setShuffleMode(newMode);

      developer.log(
        '[DEBUG][PlaybackController][toggleShuffle] Shuffle toggled to ${!_shuffleEnabled}',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][toggleShuffle] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Cycle through repeat modes
  Future<void> toggleRepeatMode() async {
    if (_audioHandler == null) return;

    try {
      AudioServiceRepeatMode newMode;
      switch (_repeatMode) {
        case AudioServiceRepeatMode.none:
          newMode = AudioServiceRepeatMode.all;
          break;
        case AudioServiceRepeatMode.all:
          newMode = AudioServiceRepeatMode.one;
          break;
        case AudioServiceRepeatMode.one:
          newMode = AudioServiceRepeatMode.none;
          break;
        case AudioServiceRepeatMode.group:
          newMode = AudioServiceRepeatMode.none;
          break;
      }

      await _audioHandler!.setRepeatMode(newMode);

      developer.log(
        '[DEBUG][PlaybackController][toggleRepeatMode] Repeat mode set to $newMode',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][toggleRepeatMode] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Update the entire queue
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    if (_audioHandler == null) return;

    try {
      developer.log(
        '[DEBUG][PlaybackController][updateQueue] Replacing queue with ${newQueue.length} items',
        name: 'PlaybackController',
      );

      // Don't pause here - let the audio handler manage playback state
      // The MusicManager will handle pausing/playing as needed

      // Update the queue
      await _audioHandler!.updateQueue(newQueue);

      // Update our local cache immediately
      _queue = newQueue;
      _currentIndex = null; // Reset index since we have a new queue

      if (!_isDisposed) {
        notifyListeners();
      }

      developer.log(
        '[DEBUG][PlaybackController][updateQueue] Queue updated with ${newQueue.length} items',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][updateQueue] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Add item to queue
  Future<void> addQueueItem(MediaItem mediaItem) async {
    if (_audioHandler == null) return;

    try {
      await _audioHandler!.addQueueItem(mediaItem);

      developer.log(
        '[DEBUG][PlaybackController][addQueueItem] Added ${mediaItem.title} to queue',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][addQueueItem] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Remove item from queue
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    if (_audioHandler == null) return;

    try {
      await _audioHandler!.removeQueueItem(mediaItem);

      developer.log(
        '[DEBUG][PlaybackController][removeQueueItem] Removed ${mediaItem.title} from queue',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][removeQueueItem] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Move queue item
  Future<void> moveQueueItem(int currentIndex, int newIndex) async {
    if (_audioHandler == null) return;

    try {
      await _audioHandler!.moveQueueItem(currentIndex, newIndex);

      developer.log(
        '[DEBUG][PlaybackController][moveQueueItem] Moved item from $currentIndex to $newIndex',
        name: 'PlaybackController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][PlaybackController][moveQueueItem] Failed: $e',
        name: 'PlaybackController',
        error: e,
      );
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Get formatted position string
  String get positionText {
    final minutes = _position.inMinutes;
    final seconds = _position.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted duration string
  String get durationText {
    final minutes = _duration.inMinutes;
    final seconds = _duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get progress percentage (0.0 to 1.0)
  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  /// Check if there's a next track
  bool get hasNext {
    if (_queue.isEmpty || _currentIndex == null) return false;
    return _repeatMode != AudioServiceRepeatMode.none ||
        _currentIndex! < _queue.length - 1;
  }

  /// Check if there's a previous track
  bool get hasPrevious {
    if (_queue.isEmpty || _currentIndex == null) return false;
    return _repeatMode != AudioServiceRepeatMode.none || _currentIndex! > 0;
  }

  /// Clean up resources - singleton-safe disposal
  void disposeResources() {
    if (_isDisposed) return; // Prevent double disposal

    developer.log(
      '[DEBUG][PlaybackController][disposeResources] Disposing controller resources',
      name: 'PlaybackController',
    );

    _isDisposed = true; // Mark as disposed first

    // Cancel all stream subscriptions
    _playbackStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    _queueSubscription?.cancel();
    _positionSubscription?.cancel();

    // Clear subscriptions
    _playbackStateSubscription = null;
    _mediaItemSubscription = null;
    _queueSubscription = null;
    _positionSubscription = null;

    // Clear audio handler reference
    _audioHandler = null;
  }

  /// Standard dispose method - calls super for ChangeNotifier compliance
  @override
  void dispose() {
    disposeResources();
    super.dispose(); // Must call super for ChangeNotifier
  }
}
