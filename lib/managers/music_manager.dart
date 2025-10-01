import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/UI/MusicEntryPoint.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/models/downloaded_music.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/single_music_service.dart';
import 'package:jainverse/services/station_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/synchronized.dart'; // for queue operation lock

// Simple cache entry for single-music fetches to dedupe in-flight requests
class _SingleMusicCacheEntry {
  final Future<DataMusic?> future;
  final DateTime timestamp;
  _SingleMusicCacheEntry(this.future) : timestamp = DateTime.now();
}

/// MusicManager is a singleton class that manages music playback state, queue operations,
/// and acts as the central coordinator between UI components and the audio service.
/// It provides robust queue management, playback control, and state synchronization for the app.
class MusicManager extends ChangeNotifier {
  // Singleton getter for safe usage
  static MusicManager get instance => _instance ??= MusicManager._internal();
  // Allow re-instantiation by storing nullable instance
  static MusicManager? _instance;
  factory MusicManager() => _instance ??= MusicManager._internal();
  MusicManager._internal() {
    _initialize();
  }

  /// Wait until the audio handler's queue stream reflects [expected] or timeout.
  /// Returns when the handler's queue equals the expected list (by id and count).
  Future<void> _waitForHandlerQueueToMatch(
    List<MediaItem> expected, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_audioHandler == null) return;
    final completer = Completer<void>();
    late StreamSubscription<List<MediaItem>> sub;
    sub = _audioHandler!.queue.listen((handlerQueue) {
      try {
        if (handlerQueue.length == expected.length) {
          // quick id check
          final same = List.generate(expected.length, (i) {
            return expected[i].id == handlerQueue[i].id;
          }).every((e) => e);
          if (same) {
            completer.complete();
          }
        }
      } catch (_) {}
    });

    // If already matching, complete immediately
    final current = await _audioHandler!.queue.first;
    if (current.length == expected.length &&
        List.generate(
          expected.length,
          (i) => expected[i].id == current[i].id,
        ).every((e) => e)) {
      await sub.cancel();
      return;
    }

    // Wait with timeout
    try {
      await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  // Lock to serialize queue operations and prevent race conditions
  final Lock _queueLock = Lock();

  // --- Constants ---
  static const Duration kDebounceDuration = Duration(milliseconds: 100);
  static const Duration kPositionThrottle = Duration(milliseconds: 500);
  static const Duration kQueueUpdateTimeout = Duration(seconds: 8);
  static const Duration kSkipDelay = Duration(milliseconds: 500);
  static const Duration kSkipPostDelay = Duration(milliseconds: 1200);
  static const Duration kSkipFinalDelay = Duration(milliseconds: 1000);
  static const Duration kSkipEmergencyDelay = Duration(milliseconds: 800);
  static const Duration kDefaultSongDuration = Duration(minutes: 3);
  static const Duration kSubscriptionCancelTimeout = Duration(seconds: 1);
  static const Duration kPendingOpsTimeout = Duration(milliseconds: 1000);

  // --- URL Constants ---
  static const String kBaseUrl = '${AppConstant.SiteUrl}public/';
  static const String kPlaceholderImageUrl =
      ''; // Empty string to prevent network errors

  // --- Playback Retry/Backoff Constants ---
  static const int kPlaybackMaxAttempts = 3;
  static const int kPlaybackBaseTimeoutMs = 500;
  static const int kPlaybackTimeoutIncrementMs = 200;
  static const int kPlaybackRetryBaseDelayMs = 50;
  // Coalesce rapid UI taps into a single request window (user tap debounce)
  static const Duration kTapCoalesceDuration = Duration(milliseconds: 400);

  // --- Single music fetch cache ---
  static const Duration _kSingleMusicCacheTtl = Duration(seconds: 30);
  final Map<String, _SingleMusicCacheEntry> _singleMusicCache = {};

  // In-flight operation coalescing and processing indicators
  final Map<String, Future<void>> _inflightOperations = {};
  final Set<String> _processingSongIds = <String>{};

  /// Notifies UI about a currently-processing audio id (optimistic UI)
  final ValueNotifier<String?> processingAudioId = ValueNotifier<String?>(null);

  // Core audio service handler
  AudioPlayerHandler? _audioHandler;

  // Core state
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  double _speed = 1.0;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  // Queue management
  List<MediaItem> _queue = [];
  int? _currentIndex;
  MediaItem? _currentMediaItem;
  List<DataMusic> _originalMusicData = [];

  // Enhanced queue management for Play Next / Add to Queue functionality
  final List<MediaItem> _playNextStack =
      []; // High priority songs inserted via "Play Next"
  final List<MediaItem> _addToQueueStack =
      []; // Low priority songs added via "Add to Queue"

  // Stream subscriptions
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _mediaItemSubscription;
  StreamSubscription? _queueSubscription;
  StreamSubscription? _positionSubscription; // Add position subscription
  bool _isDisposed = false;

  // UI update debouncing
  Timer? _notifyDebounceTimer;

  // Queue replacement tracking to prevent duplicates
  String _lastQueueId = '';
  DateTime _lastQueueReplaceTime = DateTime(0);
  bool _isQueueReplaceInProgress = false;
  Completer<void>? _currentQueueOperation;

  // Async lock for queue operations
  final List<Completer<void>> _queueOperationQueue = [];

  // Instance-level counter to track queue replacements
  int _globalQueueReplacementCounter = 0;
  DateTime _lastGlobalQueueReplacement = DateTime(0);

  // Instance-level SYSTEM-WIDE LOCK to prevent any concurrent queue operations
  bool _globalSystemLock = false;
  String _globalLockOwner = '';
  DateTime _globalLockAcquiredTime = DateTime(0);

  // Shuffle state
  bool _shuffleEnabled = false;
  List<MediaItem> _originalQueue = []; // Store original unshuffled queue

  // Auto Play state
  bool _autoPlayEnabled = true; // Enabled by default when repeat mode is off
  Timer? _autoPlayTimer; // Timer for monitoring last 15 seconds
  bool _isAutoPlayInProgress =
      false; // Prevent multiple concurrent auto-play calls

  // Getters for UI components
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isBuffering =>
      false; // Simplified - always false since we don't track buffering separately
  Duration get position => _position;
  Duration get duration => _currentMediaItem?.duration ?? Duration.zero;
  double get volume => _audioHandler?.volume.value ?? 1.0;
  double get speed => _speed;
  bool get shuffleEnabled => _shuffleEnabled;
  AudioServiceRepeatMode get repeatMode => _repeatMode;
  bool get autoPlayEnabled => _autoPlayEnabled;
  List<MediaItem> get queue => _queue;
  int? get currentIndex => _currentIndex;
  MediaItem? get currentMediaItem => _currentMediaItem;
  List<DataMusic> get originalMusicData => _originalMusicData;

  // Enhanced queue getters for Play Next / Add to Queue functionality
  List<MediaItem> get playNextStack => _playNextStack;
  List<MediaItem> get addToQueueStack => _addToQueueStack;
  List<MediaItem> get fullQueue => [
    ..._queue,
    ..._addToQueueStack,
  ]; // Combined view of main queue + add to queue items

  // Public getters for audio handler access
  AudioPlayerHandler? get audioHandler => _audioHandler;

  /// Create a safe image URL that doesn't cause network errors
  String _createSafeImageUrl(String? imagePath) {
    // If no image path provided, return null (audio service will use default)
    if (imagePath == null || imagePath.isEmpty) {
      return ''; // Return empty string instead of external URL
    }

    // If already a complete URL, validate it's from our server
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      if (imagePath.contains('musicvideo.techcronus.com') ||
          imagePath.startsWith('file://')) {
        return imagePath; // Only allow our server URLs or local files
      }
      return ''; // Reject external URLs that might fail
    }

    // If it's a file:// URL (local file), allow it
    if (imagePath.startsWith('file://')) {
      return imagePath;
    }

    // Construct URL from our server
    return '${kBaseUrl}images/audio/thumb/$imagePath';
  }

  /// Initialize the manager with audio service
  Future<void> _initialize() async {
    try {
      developer.log(
        '[MusicManager] Manager initialized - waiting for audio handler',
        name: 'MusicManager',
      );
      // FIX: Ensure stream listeners are set up if audio handler is already set
      if (_audioHandler != null) {
        _setupStreamListeners();
      }
    } catch (e) {
      developer.log(
        '[MusicManager] Initialization error: $e',
        name: 'MusicManager',
      );
    }
  }

  /// Setup stream listeners for audio service
  void _setupStreamListeners() {
    if (_audioHandler == null || _isDisposed) return;

    // Clean up existing subscriptions before setting up new ones
    _playbackStateSubscription?.cancel();
    _playbackStateSubscription = null;
    _mediaItemSubscription?.cancel();
    _mediaItemSubscription = null;
    _queueSubscription?.cancel();
    _queueSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    // Playback state stream
    _playbackStateSubscription = _audioHandler!.playbackState.listen((
      playbackState,
    ) {
      if (_isDisposed) return;
      _isPlaying = playbackState.playing;
      _isLoading =
          playbackState.processingState == AudioProcessingState.loading;
      _speed = playbackState.speed;
      _repeatMode = playbackState.repeatMode;
      _shuffleEnabled =
          playbackState.shuffleMode == AudioServiceShuffleMode.all;
      _currentIndex = playbackState.queueIndex;
      _safeNotifyListeners();
    });

    // Media item stream
    _mediaItemSubscription = _audioHandler!.mediaItem.listen((mediaItem) {
      if (_isDisposed) return;
      _currentMediaItem = mediaItem;
      _safeNotifyListeners();
    });

    // Queue stream
    _queueSubscription = _audioHandler!.queue.listen((queue) {
      if (_isDisposed) return;
      _queue = List.from(queue);
      _safeNotifyListeners();
    });

    // Ultra-optimized position stream - minimal frequency for maximum performance
    _positionSubscription = AudioService.position
        .throttleTime(kPositionThrottle)
        .distinct((prev, next) => (prev.inSeconds == next.inSeconds))
        .listen((position) {
          if (_isDisposed) return;
          _position = position;
          _safeNotifyListeners();
        });

    // Start auto play monitoring if enabled
    if (_autoPlayEnabled && _repeatMode == AudioServiceRepeatMode.none) {
      _startAutoPlayMonitoring();
    }
  }

  // Replace debounced timer with frame-coalescing to reduce overhead
  bool _notifyScheduled = false;

  /// Safe notification that checks if disposed and coalesces notifications per frame
  void _safeNotifyListeners() {
    if (_isDisposed || !hasListeners) return;
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_isDisposed && hasListeners) {
        notifyListeners();
      }
    });
  }

  /// Set the audio handler (called from main.dart after initialization)
  void setAudioHandler(AudioPlayerHandler handler) {
    if (_isDisposed) return;

    // Cancel all existing subscriptions before setting new handler
    _playbackStateSubscription?.cancel();
    _playbackStateSubscription = null;
    _mediaItemSubscription?.cancel();
    _mediaItemSubscription = null;
    _queueSubscription?.cancel();
    _queueSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    _audioHandler = handler;
    _setupStreamListeners();

    developer.log(
      '[MusicManager] Audio handler set successfully',
      name: 'MusicManager',
    );
  }

  /// Simple queue replacement with enhanced duplicate prevention and async locking
  ///
  /// Replace the current playback queue with a new list of music items.
  /// Handles duplicate prevention, async locking, and ensures correct playback state.
  /// [musicList]: List of DataMusic to play.
  /// [startIndex]: Index to start playback from.
  /// [pathImage], [audioPath]: Used for local file prioritization.
  /// [contextType], [contextId], [callSource]: Contextual info for analytics/debugging.
  Future<void> replaceQueue({
    required List<DataMusic> musicList,
    required int startIndex,
    required String pathImage,
    required String audioPath,
    String contextType = 'playlist',
    String? contextId,
    String? callSource,
  }) async {
    if (_isDisposed) return;
    // Serialize queue operations to prevent race conditions
    return _queueLock.synchronized(() async {
      if (!await ensureAudioHandler()) {
        developer.log(
          '[MusicManager] Cannot replace queue: audio handler unavailable',
          name: 'MusicManager',
        );
        return;
      }

      // Generate unique queue ID based on content
      final queueId =
          '${musicList.map((m) => m.id).join(',')}_${startIndex}_$contextType';
      final now = DateTime.now();
      final source = callSource ?? 'unknown';

      // EARLY EXIT: If a queue replacement is already in progress for the same queue, skip this call
      if (_isQueueReplaceInProgress &&
          _lastQueueId == queueId &&
          now.difference(_lastQueueReplaceTime).inMilliseconds < 1000) {
        // Only 1s lock
        developer.log(
          '[MusicManager] 🚫 Duplicate queue replacement call detected and skipped (queueId: [38;5;208m${queueId.substring(0, 50)}...[0m)',
          name: 'MusicManager',
        );
        return;
      }

      // Update this operation as the current one
      _currentQueueOperation = Completer<void>();

      // GLOBAL DUPLICATE PREVENTION: Check for rapid-fire queue replacements
      final timeSinceLastGlobal =
          now.difference(_lastGlobalQueueReplacement).inMilliseconds;
      _globalQueueReplacementCounter++;

      developer.log(
        '[MusicManager] 📞 QUEUE REPLACEMENT CALLED FROM: $source (global counter: $_globalQueueReplacementCounter, time since last: ${timeSinceLastGlobal}ms)',
        name: 'MusicManager',
      );

      // Enhanced global lock with timeout protection
      if (_globalSystemLock) {
        final lockAge = DateTime.now().difference(_globalLockAcquiredTime);
        if (lockAge.inSeconds > 5) {
          // Lowered lock timeout
          developer.log(
            '[MusicManager] Force releasing stale global lock (age: ${lockAge.inSeconds}s)',
          );
          _globalSystemLock = false;
          _globalLockOwner = '';
        } else {
          developer.log(
            '[MusicManager] 🔒 SYSTEM LOCK ACTIVE - Queue operation blocked, owner: $_globalLockOwner, requester: $source',
            name: 'MusicManager',
          );
          // Release global lock early and complete pending operations
          _globalSystemLock = false;
          _globalLockOwner = '';
          return;
        }
      }

      // Acquire global system lock with ownership tracking
      _globalSystemLock = true;
      _globalLockOwner = source;
      _globalLockAcquiredTime = DateTime.now();

      // Update global tracking
      _lastGlobalQueueReplacement = now;

      // ENHANCED DUPLICATE PREVENTION: Check for recent duplicates first
      if (_lastQueueId == queueId &&
          now.difference(_lastQueueReplaceTime).inMilliseconds < 1000) {
        // Only 1s lock
        developer.log(
          '[MusicManager] ⚠️ DUPLICATE REJECTED - same queue requested within 1 second (source: $source, queueId: ${queueId.substring(0, 50)}...)',
          name: 'MusicManager',
        );
        // Release global lock since we're not proceeding
        _globalSystemLock = false;
        _globalLockOwner = '';
        return;
      }

      // ASYNC LOCK: Wait for any ongoing operation to complete
      if (_isQueueReplaceInProgress) {
        developer.log(
          '[MusicManager] ⏳ WAITING - queue operation in progress, queueing this request (source: $source)',
          name: 'MusicManager',
        );

        // Add to queue and wait
        _queueOperationQueue.add(_currentQueueOperation!);

        // Wait for current operation to complete
        if (_currentQueueOperation != null &&
            !_currentQueueOperation!.isCompleted) {
          // Wait max 2s for previous operation
          await _currentQueueOperation!.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              developer.log(
                '[MusicManager] ⚠️ Previous queue operation timed out, forcing unlock.',
                name: 'MusicManager',
              );
              _isQueueReplaceInProgress = false;
              _globalSystemLock = false;
              _globalLockOwner = '';
              return;
            },
          );
        }

        // Check again if this is still a duplicate after waiting
        if (_lastQueueId == queueId &&
            DateTime.now().difference(_lastQueueReplaceTime).inMilliseconds <
                1000) {
          developer.log(
            '[MusicManager] ⚠️ DUPLICATE REJECTED AFTER WAIT - same queue still recent (source: $source)',
            name: 'MusicManager',
          );
          _queueOperationQueue.remove(_currentQueueOperation!);
          return;
        }
      }

      // Set operation in progress
      _isQueueReplaceInProgress = true;

      try {
        developer.log(
          '[MusicManager] 🚀 STARTING QUEUE REPLACEMENT FROM: $source - ${musicList.length} items, startIndex: $startIndex, context: $contextType',
          name: 'MusicManager',
        );

        // Update tracking IMMEDIATELY to prevent race conditions
        _lastQueueId = queueId;
        _lastQueueReplaceTime = now;

        // Store original data and queue
        _originalMusicData = List.from(musicList);

        // Create MediaItems with local file prioritization
        final mediaItems = await _createMediaItems(
          musicList: musicList,
          pathImage: pathImage,
          audioPath: audioPath,
          contextType: contextType,
          contextId: contextId,
        );
        if (mediaItems.isEmpty) {
          developer.log('[MusicManager] ⚠️ No valid media items created');
          _queue = [];
          _currentIndex = null;
          _currentMediaItem = null;
          _safeNotifyListeners();
          return;
        }

        // Store original queue order for shuffle functionality
        _originalQueue = List.from(mediaItems);

        // Ensure we're starting from a clean state
        final wasPlaying = _audioHandler!.playbackState.value.playing;
        developer.log(
          '[MusicManager] Current playback state - playing: $wasPlaying',
          name: 'MusicManager',
        );

        if (wasPlaying) {
          await _audioHandler!.pause();
          developer.log('[MusicManager] Paused current playback');
          // Small delay to ensure pause is processed
          await Future.delayed(
            const Duration(milliseconds: 50),
          ); // Reduced delay
        }

        // Fast path: If queue and index are already correct, just play
        final currentQueue = _audioHandler!.queue.value;
        final currentIndex = _audioHandler!.playbackState.value.queueIndex;
        if (currentQueue.length == mediaItems.length &&
            currentQueue.asMap().entries.every(
              (e) => e.value.id == mediaItems[e.key].id,
            ) &&
            currentIndex == startIndex) {
          developer.log(
            '[MusicManager] Fast path: queue and index already correct, starting playback immediately.',
            name: 'MusicManager',
          );
          await _audioHandler!.play();
          _queue = List.from(mediaItems);
          _currentIndex = startIndex;
          _currentMediaItem = mediaItems[startIndex];
          _safeNotifyListeners();
          return;
        }

        // Update queue atomically with shorter timeout for better responsiveness
        developer.log('[MusicManager] Updating queue...');
        try {
          await _audioHandler!
              .updateQueue(mediaItems)
              .timeout(const Duration(seconds: 4)); // Reduced timeout
          // FIX: Update local queue immediately after updateQueue
          _queue = List.from(mediaItems);
          // NEW: Refresh state after queue update
          await refreshState();
          // NEW: Wait for the audio handler's own queue stream to reflect the update
          try {
            await _waitForHandlerQueueToMatch(
              mediaItems,
              timeout: const Duration(seconds: 4),
            );
          } catch (e) {
            developer.log(
              '[MusicManager] Warning: handler queue did not fully match mediaItems after update: $e',
            );
          }
        } on TimeoutException {
          developer.log(
            '[MusicManager] ⚠️ Queue update timed out after 4 seconds, attempting quick recovery',
            name: 'MusicManager',
          );
          // Don't immediately throw - try a quick recovery
          throw TimeoutException(
            'Queue update timeout',
            const Duration(seconds: 4),
          );
        }

        // Determine target index and skip if needed
        final validIndex = startIndex.clamp(0, mediaItems.length - 1);
        if (validIndex < 0 || validIndex >= mediaItems.length) {
          developer.log(
            '[MusicManager] Invalid start index after clamp: $validIndex',
            name: 'MusicManager',
          );
          _currentIndex = 0;
          _currentMediaItem = mediaItems.isNotEmpty ? mediaItems[0] : null;
        }
        developer.log(
          '🎯🎯🎯 MUSIC MANAGER QUEUE REPLACEMENT 🎯🎯🎯',
          name: 'MusicManager',
        );
        developer.log(
          '[MusicManager] 🎵 Target index: $validIndex (from startIndex: $startIndex)',
          name: 'MusicManager',
        );
        developer.log(
          '[MusicManager] 🎵 Song that should play: ${mediaItems[validIndex].title}',
          name: 'MusicManager',
        );
        developer.log(
          '[MusicManager] 🎵 First song in queue: ${mediaItems[0].title}',
          name: 'MusicManager',
        );

        if (validIndex > 0) {
          developer.log(
            '[MusicManager] 🎵 Skipping to index $validIndex (${mediaItems[validIndex].title})...',
          );
          try {
            // CRITICAL FIX: Add minimal delay before skip to ensure queue is fully loaded
            await Future.delayed(
              const Duration(milliseconds: 80),
            ); // Reduced delay

            // Add comprehensive debugging before skip operation
            developer.log(
              '[MusicManager] 🎯 PRE-SKIP VERIFICATION:',
              name: 'MusicManager',
            );
            developer.log(
              '[MusicManager] 🎯 Queue length: ${_audioHandler!.queue.value.length}',
              name: 'MusicManager',
            );
            developer.log(
              '[MusicManager] 🎯 Current player index: ${_audioHandler!.playbackState.value.queueIndex}',
              name: 'MusicManager',
            );
            developer.log(
              '[MusicManager] 🎯 Target index: $validIndex',
              name: 'MusicManager',
            );

            await _audioHandler!
                .skipToQueueItem(validIndex)
                .timeout(const Duration(seconds: 2)); // Reduced timeout
            // WAIT SHORT for skip to be fully processed
            await Future.delayed(
              const Duration(milliseconds: 200),
            ); // Reduced delay
            // NEW: Refresh state after skip
            await refreshState();

            // Force refresh media item by waiting for the stream to update
            MediaItem? currentMediaItem;
            try {
              currentMediaItem = await _audioHandler!.mediaItem
                  .where((item) => item != null)
                  .first
                  .timeout(const Duration(seconds: 2));
            } catch (e) {
              // Fallback to current value if stream times out
              currentMediaItem = _audioHandler!.mediaItem.value;
            }

            // FIX: Update local index and media item after skip
            _currentIndex = validIndex;
            _currentMediaItem = currentMediaItem;

            // Verify the current index after skipping
            final currentIndex = _audioHandler!.playbackState.value.queueIndex;
            developer.log(
              '[MusicManager] 🔍 After skip: currentIndex=$currentIndex, expected=$validIndex',
            );

            // Verify we have the correct media item
            if (currentMediaItem != null) {
              developer.log(
                '[MusicManager] 🔍 Current media item after skip: ${currentMediaItem.title}',
              );

              // Double-check that we have the right song
              final expectedSong = mediaItems[validIndex];
              if (currentMediaItem.title != expectedSong.title) {
                developer.log(
                  '[MusicManager] ⚠️ MISMATCH: Expected "${expectedSong.title}" but got "${currentMediaItem.title}"',
                  name: 'MusicManager',
                );

                // Force another skip attempt with minimal wait
                developer.log(
                  '[MusicManager] 🔄 Attempting corrective skip...',
                );
                await _audioHandler!.skipToQueueItem(validIndex);
                await Future.delayed(
                  const Duration(milliseconds: 200),
                ); // Reduced

                // Check again
                final correctedMediaItem = _audioHandler!.mediaItem.value;
                if (correctedMediaItem != null) {
                  developer.log(
                    '[MusicManager] 🔍 After corrective skip: ${correctedMediaItem.title}',
                  );
                }
              }
            }

            developer.log(
              '[MusicManager] ✅ Successfully skipped to index $validIndex',
            );

            // Final verification: ensure we have the correct song loaded
            final finalMediaItem = _audioHandler!.mediaItem.value;
            final finalIndex = _audioHandler!.playbackState.value.queueIndex;
            developer.log(
              '[MusicManager] 🎯 FINAL VERIFICATION: index=$finalIndex, song="${finalMediaItem?.title}", expected="${mediaItems[validIndex].title}"',
              name: 'MusicManager',
            );
          } on TimeoutException {
            developer.log(
              '[MusicManager] ⚠️ Skip operation timed out, proceeding anyway',
              name: 'MusicManager',
            );
          } catch (e) {
            developer.log(
              '[MusicManager] ❌ Skip to index failed: $e, continuing with play...',
              name: 'MusicManager',
            );
            // Continue even if skip fails
          }
        } else {
          // FIX: If starting at index 0, update local index and media item
          _currentIndex = 0;
          _currentMediaItem = mediaItems[0];
          developer.log(
            '[MusicManager] 🎵 Starting with first song (index 0): ${mediaItems[0].title}',
          );
        }

        // Start playback with enhanced error handling and retry logic
        developer.log('[MusicManager] Starting playback...');

        // CRITICAL FIX: Add a minimal delay before starting playback to ensure skip operation is fully processed
        if (validIndex > 0) {
          developer.log(
            '[MusicManager] ⏳ Waiting minimal time for skip operation to complete...',
          );
          await Future.delayed(const Duration(milliseconds: 120)); // Reduced

          // Double-verify we're on the right track before starting playback
          final finalCurrentIndex =
              _audioHandler!.playbackState.value.queueIndex;
          final finalMediaItem = _audioHandler!.mediaItem.value;

          developer.log(
            '[MusicManager] 🔍 FINAL PRE-PLAY CHECK: currentIndex=$finalCurrentIndex, expected=$validIndex',
          );
          developer.log(
            '[MusicManager] 🔍 FINAL PRE-PLAY SONG: "${finalMediaItem?.title}" vs expected "${mediaItems[validIndex].title}"',
          );

          // If we're still not on the right track, try one more time
          if (finalCurrentIndex != validIndex) {
            developer.log(
              '[MusicManager] 🚨 EMERGENCY CORRECTION: Still on wrong track, attempting final skip',
            );
            try {
              await _audioHandler!
                  .skipToQueueItem(validIndex)
                  .timeout(const Duration(seconds: 1)); // Reduced
              await Future.delayed(const Duration(milliseconds: 120));
            } catch (e) {
              developer.log(
                '[MusicManager] ⚠️ Emergency correction failed: $e',
              );
            }
          }
        }

        final playbackSuccess = await _retryPlayback(
          maxAttempts: 2,
        ); // Fewer attempts for speed
        // NEW: Refresh state after play attempt
        await refreshState();
        if (!playbackSuccess) {
          developer.log(
            '[MusicManager] ⚠️ All playback attempts failed, but queue replacement succeeded',
            name: 'MusicManager',
          );
          // Don't fail the entire operation - queue replacement was successful
        }

        developer.log(
          '[MusicManager] ✅ QUEUE REPLACEMENT COMPLETED FROM: $source - ${mediaItems.length} items, playing index $validIndex: ${mediaItems[validIndex].title}',
          name: 'MusicManager',
        );

        // Ensure mini player is shown when queue is successfully replaced
        try {
          // Import and use the music player state manager
          final stateManager = MusicPlayerStateManager();
          stateManager.showMiniPlayerForMusicStart();
          developer.log(
            '[MusicManager] Mini player state updated after successful queue replacement',
            name: 'MusicManager',
          );
        } catch (e) {
          developer.log(
            '[MusicManager] Warning: Could not update mini player state: $e',
            name: 'MusicManager',
          );
        }
      } catch (e) {
        developer.log(
          '[MusicManager] ❌ QUEUE REPLACEMENT FAILED FROM: $source - $e',
          name: 'MusicManager',
          error: e,
        );
        _queue = [];
        _currentIndex = null;
        _currentMediaItem = null;
        _safeNotifyListeners();
        _notifyError('Failed to replace queue: \\${e.toString()}');
      } finally {
        // Reset global counter on successful completion or error
        _globalQueueReplacementCounter = 0;

        // Release global system lock
        _globalSystemLock = false;
        _globalLockOwner = '';

        // Always clear the operation flags and complete the operation
        _isQueueReplaceInProgress = false;

        // Complete current operation
        if (_currentQueueOperation != null &&
            !_currentQueueOperation!.isCompleted) {
          _currentQueueOperation!.complete();
        }

        // Process next operation in queue if any
        if (_queueOperationQueue.isNotEmpty) {
          final nextOperation = _queueOperationQueue.removeAt(0);
          if (!nextOperation.isCompleted) {
            nextOperation.complete();
          }
        }

        // Clear current operation reference
        if (_currentQueueOperation == _currentQueueOperation) {
          _currentQueueOperation = null;
        }
      }
    });
  }

  /// Replace the current queue with a station queue (similar songs starting from current song)
  /// This ensures the current song remains first and playback continues smoothly
  Future<void> replaceQueueWithStation({
    required List<DataMusic> stationSongs,
    required DataMusic currentSong,
    required String pathImage,
    required String audioPath,
  }) async {
    if (_isDisposed) return;

    return _queueLock.synchronized(() async {
      if (!await ensureAudioHandler()) {
        developer.log(
          '[MusicManager] Cannot replace queue with station: audio handler unavailable',
          name: 'MusicManager',
        );
        return;
      }

      try {
        developer.log(
          '[MusicManager] 🎵 Creating station with ${stationSongs.length} songs, starting with: ${currentSong.audio_title}',
          name: 'MusicManager',
        );

        // Ensure current song is first in the station
        final List<DataMusic> orderedStationSongs = [currentSong];

        // Add other songs, excluding the current song to avoid duplicates
        for (final song in stationSongs) {
          if (song.id != currentSong.id) {
            orderedStationSongs.add(song);
          }
        }

        developer.log(
          '[MusicManager] 🎵 Station ordered with ${orderedStationSongs.length} unique songs',
          name: 'MusicManager',
        );

        // Store original data
        _originalMusicData = List.from(orderedStationSongs);

        // Create MediaItems for the station
        final mediaItems = await _createMediaItems(
          musicList: orderedStationSongs,
          pathImage: pathImage,
          audioPath: audioPath,
          contextType: 'station',
          contextId: 'station_${currentSong.id}',
        );

        if (mediaItems.isEmpty) {
          developer.log(
            '[MusicManager] ⚠️ No valid media items created for station',
          );
          return;
        }

        // Store original queue order for shuffle functionality
        _originalQueue = List.from(mediaItems);

        // Get current playback state before replacement
        final wasPlaying = _audioHandler!.playbackState.value.playing;
        final currentPosition = _audioHandler!.playbackState.value.position;
        final currentDuration =
            _audioHandler!.playbackState.value.bufferedPosition;

        // Check if we're near the end of the song (within last 5 seconds)
        final isNearEnd =
            currentDuration > Duration.zero &&
            currentPosition > Duration.zero &&
            (currentDuration - currentPosition) < const Duration(seconds: 5);

        developer.log(
          '[MusicManager] 🎵 Current playback state - playing: $wasPlaying, position: ${currentPosition.inSeconds}s, nearEnd: $isNearEnd',
          name: 'MusicManager',
        );

        // Special handling for station creation to preserve playback position
        developer.log(
          '[MusicManager] 🎵 Creating station with preserved playback using queue manipulation...',
        );

        try {
          // Check if current song is the same as the first song in the station
          // Compare by audio_id in extras rather than full MediaItem ID to avoid context parameter issues
          final currentAudioId =
              _currentMediaItem?.extras?['audio_id']?.toString();
          final stationFirstAudioId =
              mediaItems[0].extras?['audio_id']?.toString();

          // Debug logging to see full extras content
          developer.log(
            '[MusicManager] 🎵 Current MediaItem extras: ${_currentMediaItem?.extras}',
          );
          developer.log(
            '[MusicManager] 🎵 Station first MediaItem extras: ${mediaItems[0].extras}',
          );

          final isSameSong =
              currentAudioId != null &&
              stationFirstAudioId != null &&
              currentAudioId == stationFirstAudioId;

          developer.log(
            '[MusicManager] 🎵 Current audio ID: $currentAudioId, Station first audio ID: $stationFirstAudioId, Same song: $isSameSong',
          );

          if (isSameSong && _queue.isNotEmpty) {
            // If the current song is the same as the station's first song,
            // we can just replace the rest of the queue without touching the current song
            developer.log(
              '[MusicManager] 🎵 Same song detected - updating queue without affecting current playback (preserving position: ${currentPosition.inSeconds}s)',
            );

            // Remove all items after the current index
            final currentIdx = _currentIndex ?? 0;
            final itemsToRemove = _queue.sublist(currentIdx + 1);

            for (final item in itemsToRemove) {
              await _audioHandler!.removeQueueItem(item);
            }

            // Add new station songs (skip the first one since it's already playing)
            final newSongs = mediaItems.sublist(1);
            if (newSongs.isNotEmpty) {
              await _audioHandler!.addQueueItems(newSongs);
            }

            // Update local queue state
            _queue = List.from(mediaItems);
            _currentIndex = 0;
            _currentMediaItem = mediaItems[0];

            developer.log(
              '[MusicManager] ✅ Station queue updated seamlessly - current song continues at ${currentPosition.inSeconds}s',
            );
          } else {
            // Different song - need to use full queue replacement but optimize for position preservation
            developer.log(
              '[MusicManager] 🎵 Different song - using optimized queue replacement',
            );

            // Temporarily pause if playing
            if (wasPlaying) {
              await _audioHandler!.pause();
              developer.log(
                '[MusicManager] 🎵 Paused current playback for station creation',
              );
            }

            // Wait briefly for pause to take effect
            await Future.delayed(const Duration(milliseconds: 50));

            // Update queue using the standard method
            await _audioHandler!
                .updateQueue(mediaItems)
                .timeout(const Duration(seconds: 4));

            // Update local queue immediately after updateQueue
            _queue = List.from(mediaItems);
            _currentIndex = 0; // Always start at index 0 (current song)
            _currentMediaItem = mediaItems[0];

            developer.log(
              '[MusicManager] ✅ Station queue updated successfully',
            );

            // Refresh state after queue update
            await refreshState();

            // Wait for the audio source to be ready
            await Future.delayed(const Duration(milliseconds: 100));

            // Restore the playback position if it was significant
            if (currentPosition > Duration.zero && !isNearEnd) {
              developer.log(
                '[MusicManager] 🎵 Restoring position: ${currentPosition.inSeconds}s',
              );

              try {
                await _audioHandler!.seek(currentPosition);
                developer.log(
                  '[MusicManager] ✅ Position restored to: ${currentPosition.inSeconds}s',
                );
              } catch (e) {
                developer.log(
                  '[MusicManager] ⚠️ Failed to restore position: $e',
                );
              }
            } else if (isNearEnd) {
              await _audioHandler!.seek(Duration.zero);
              developer.log(
                '[MusicManager] 🎵 Started fresh - was near end of song',
              );
            }
          }

          // Resume playback if it was playing before
          if (wasPlaying) {
            developer.log('[MusicManager] 🎵 Resuming station playback...');

            // For same song scenario, just resume immediately
            if (isSameSong && _queue.isNotEmpty) {
              await _audioHandler!.play();
              developer.log(
                '[MusicManager] ✅ Station playback resumed seamlessly - no interruption',
              );
            } else {
              // For different song, start playback with enhanced error handling
              final playbackSuccess = await _retryPlayback(maxAttempts: 3);

              if (playbackSuccess) {
                developer.log(
                  '[MusicManager] ✅ Station playback resumed successfully',
                );
              } else {
                developer.log(
                  '[MusicManager] ⚠️ Station playback failed, but queue replacement succeeded',
                  name: 'MusicManager',
                );
              }
            }
          } else {
            developer.log(
              '[MusicManager] 🎵 Station ready - playback paused',
            );
          }
        } on TimeoutException {
          developer.log(
            '[MusicManager] ⚠️ Station queue update timed out, attempting recovery',
            name: 'MusicManager',
          );
          throw TimeoutException(
            'Station queue update timeout',
            const Duration(seconds: 4),
          );
        }

        // Refresh state after successful station creation
        await refreshState();
        _safeNotifyListeners();

        developer.log(
          '[MusicManager] ✅ STATION CREATED SUCCESSFULLY - ${mediaItems.length} songs, starting with: ${mediaItems[0].title}',
          name: 'MusicManager',
        );
      } catch (e) {
        developer.log(
          '[MusicManager] ❌ STATION CREATION FAILED - $e',
          name: 'MusicManager',
          error: e,
        );

        // Don't clear queue on failure - keep current state
        _safeNotifyListeners();
        _notifyError('Failed to create station: ${e.toString()}');
        rethrow;
      }
    });
  }

  /// Create MediaItems from DataMusic list with local file prioritization
  Future<List<MediaItem>> _createMediaItems({
    required List<DataMusic> musicList,
    required String pathImage,
    required String audioPath,
    required String contextType,
    String? contextId,
  }) async {
    final List<MediaItem> mediaItems = [];

    for (var entry in musicList.asMap().entries) {
      final index = entry.key;
      final music = entry.value;

      // Create audio URL - music.audio already contains the full URL
      final networkAudioUrl =
          music.audio.startsWith('http')
              ? music
                  .audio // Already a complete URL
              : '$kBaseUrl${music.audio.startsWith('/') ? music.audio.substring(1) : music.audio}'; // Construct if relative

      // Check for local audio file using AssetManager-like logic
      String actualAudioUrl = networkAudioUrl;
      try {
        // Only instantiate DownloadController once
        final downloadController = DownloadController();
        final localAudioPath = downloadController.getLocalAudioPath(
          music.id.toString(),
        );

        if (localAudioPath != null && localAudioPath.isNotEmpty) {
          // Local file exists - use proper file URI construction
          final audioFile = File(localAudioPath);
          if (await audioFile.exists()) {
            actualAudioUrl = audioFile.uri.toString();
            developer.log(
              '[MusicManager] Using local audio for \\${music.audio_title}: \\$actualAudioUrl',
              name: 'MusicManager',
            );
          } else {
            developer.log(
              '[MusicManager] Local file missing for \\${music.audio_title}, using network: \\$actualAudioUrl',
              name: 'MusicManager',
            );
            // Remove invalid download record (reuse controller)
            try {
              await downloadController.removeFromDownloads(music.id.toString());
            } catch (e) {
              developer.log(
                '[MusicManager] Failed to cleanup invalid download: \\$e',
                name: 'MusicManager',
              );
            }
          }
        } else {
          developer.log(
            '[MusicManager] Using network audio for \\${music.audio_title}: \\$actualAudioUrl',
            name: 'MusicManager',
          );
        }
      } catch (e) {
        developer.log(
          '[MusicManager] Error checking local audio for \\${music.audio_title}: \\$e',
          name: 'MusicManager',
        );
        // Continue with network URL
      }

      // Create image URL with local file prioritization
      String imageUrl = '';
      try {
        final downloadController = DownloadController();
        // Manual search for downloaded track to allow null
        DownloadedMusic? downloadedTrack;
        for (final track in downloadController.downloadedTracks) {
          if (track.id == music.id.toString() && track.isDownloadComplete) {
            downloadedTrack = track;
            break;
          }
        }
        final localImagePath = downloadedTrack?.localImagePath;

        if (localImagePath != null && localImagePath.isNotEmpty) {
          imageUrl = Uri.file(localImagePath).toString();
          developer.log(
            '[MusicManager] Using local artwork for \\${music.audio_title}: \\$imageUrl',
            name: 'MusicManager',
          );
        } else {
          imageUrl = _createSafeImageUrl(music.image);
        }
      } catch (e) {
        developer.log(
          '[MusicManager] Error checking local artwork for \\${music.audio_title}: \\$e',
          name: 'MusicManager',
        );
        // Continue with safe fallback
        imageUrl = _createSafeImageUrl(music.image);
      }

      // Parse duration - handle both MM:SS format and seconds-only format
      Duration duration = kDefaultSongDuration; // Default fallback
      try {
        final cleanDuration = music.audio_duration.replaceAll('\n', '').trim();
        if (RegExp(r'^\d+\[0m').hasMatch(cleanDuration)) {
          final totalSeconds = int.parse(cleanDuration);
          duration = Duration(seconds: totalSeconds);
          developer.log(
            '[MusicManager] Parsed duration from seconds for \\${music.audio_title}: \\${duration.inMinutes}:\\${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
            name: 'MusicManager',
          );
        } else {
          final parts = cleanDuration.split(':');
          if (parts.length == 2) {
            duration = Duration(
              minutes: int.parse(parts[0]),
              seconds: int.parse(parts[1]),
            );
          } else if (parts.length == 3) {
            duration = Duration(
              hours: int.parse(parts[0]),
              minutes: int.parse(parts[1]),
              seconds: int.parse(parts[2]),
            );
          }
          developer.log(
            '[MusicManager] Parsed duration from time format for \\${music.audio_title}: \\${duration.inMinutes}:\\${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
            name: 'MusicManager',
          );
        }
      } catch (e) {
        developer.log(
          '[MusicManager] Error parsing duration "${music.audio_duration}" for \\${music.audio_title}: \\$e',
          name: 'MusicManager',
        );
        // duration already set to fallback
      }

      final mediaItem = MediaItem(
        id: '$networkAudioUrl?ctx=$contextType&idx=$index',
        title:
            music.audio_title.isNotEmpty ? music.audio_title : 'Unknown Title',
        artist:
            music.artists_name.isNotEmpty
                ? music.artists_name
                : 'Unknown Artist',
        album:
            music.artists_name.isNotEmpty
                ? music.artists_name
                : 'Unknown Album',
        duration: duration,
        artUri:
            imageUrl.isNotEmpty
                ? Uri.parse(imageUrl)
                : null, // Handle empty imageUrl gracefully
        extras: {
          'audio_id': music.id.toString(),
          'actual_audio_url':
              actualAudioUrl, // This will be local path if available
          'network_audio_url': networkAudioUrl, // Keep original for fallback
          'context_type': contextType,
          'context_id': contextId ?? '',
          'queue_index': index,
          'lyrics': music.lyrics,
          'favourite': music.favourite,
          'is_downloaded': actualAudioUrl.startsWith('file://'),
          'artist_id': music.artist_id, // Add artist_id to MediaItem extras
          'artists_name':
              music.artists_name, // Add artists_name to extras for debugging
        },
      );

      mediaItems.add(mediaItem);
    }

    return mediaItems;
  }

  /// Ensures the audio handler is available, and attempts to re-initialize if null
  Future<bool> ensureAudioHandler() async {
    if (_audioHandler != null) return true;
    developer.log(
      '[MusicManager] Audio handler is null, attempting re-initialization',
      name: 'MusicManager',
    );
    // TODO: Add logic to re-initialize or re-attach the audio handler here if possible
    // For now, just log and return false
    return false;
  }

  // Playback control methods
  /// Start/resume playback of the current queue.
  Future<void> play() async {
    if (_isDisposed) return;
    if (!await ensureAudioHandler()) return;
    await _audioHandler?.play();
  }

  /// Pause playback.
  Future<void> pause() async {
    if (_isDisposed) return;
    if (!await ensureAudioHandler()) return;
    await _audioHandler?.pause();
  }

  /// Stop playback and release resources.
  Future<void> stop() async {
    if (_isDisposed) return;
    if (!await ensureAudioHandler()) return;
    await _audioHandler?.stop();
  }

  /// Skip to the next item in the queue.
  Future<void> skipToNext() async {
    if (_isDisposed) return;
    if (!await ensureAudioHandler()) return;

    return _queueLock.synchronized(() async {
      try {
        developer.log(
          '[MusicManager] 🎵 Skip to next requested',
          name: 'MusicManager',
        );

        // Enhanced skip logic: Check Play Next stack first
        if (_playNextStack.isNotEmpty) {
          developer.log(
            '[MusicManager] 🎵 Found Play Next track, consuming from stack',
            name: 'MusicManager',
          );

          // Remove the consumed track from play next stack
          final nextTrack = _playNextStack.removeAt(0);

          // Find this track in the main queue and skip to it
          final targetIndex = _queue.indexWhere(
            (item) => item.extras?['audio_id'] == nextTrack.extras?['audio_id'],
          );

          if (targetIndex >= 0) {
            await _audioHandler!.skipToQueueItem(targetIndex);
            developer.log(
              '[MusicManager] ✅ Skipped to Play Next track: ${nextTrack.title}',
              name: 'MusicManager',
            );
          } else {
            // Fallback to normal skip if track not found
            await _audioHandler!.skipToNext();
          }
        } else {
          // No Play Next tracks, use normal skip behavior
          await _audioHandler!.skipToNext();
          developer.log(
            '[MusicManager] ✅ Normal skip to next track',
            name: 'MusicManager',
          );
        }

        _safeNotifyListeners();
      } catch (e) {
        developer.log(
          '[MusicManager] ❌ Skip to next failed: $e',
          name: 'MusicManager',
          error: e,
        );
      }
    });
  }

  /// Skip to the previous item in the queue.
  Future<void> skipToPrevious() async {
    if (_isDisposed) return;
    if (!await ensureAudioHandler()) return;
    await _audioHandler?.skipToPrevious();
  }

  /// Seek to a specific position in the current track.
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    if (!await ensureAudioHandler()) return;
    await _audioHandler?.seek(position);
  }

  /// Skip to a specific item in the queue by index.
  Future<void> skipToQueueItem(int index) async {
    if (_isDisposed) return;
    if (!await ensureAudioHandler()) return;
    await _audioHandler?.skipToQueueItem(index);
  }

  /// Set repeat mode
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    await _audioHandler?.setRepeatMode(mode);
    _repeatMode = mode;

    // Auto-sync auto play with repeat mode
    // Auto play is enabled when repeat mode is off (none)
    _autoPlayEnabled = (mode == AudioServiceRepeatMode.none);

    developer.log(
      '[MusicManager] Repeat mode set to $mode, auto play: $_autoPlayEnabled',
      name: 'MusicManager',
    );

    _safeNotifyListeners();
  }

  /// Set shuffle mode
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    await _audioHandler?.setShuffleMode(mode);
    _shuffleEnabled = mode == AudioServiceShuffleMode.all;
    _safeNotifyListeners();
  }

  /// Toggle shuffle mode without changing the currently playing song
  /// When enabling shuffle: just enables shuffle mode, future songs will be shuffled
  /// When disabling shuffle: simply disables shuffle mode
  Future<void> toggleShuffle() async {
    try {
      if (_audioHandler == null || _queue.isEmpty) return;

      final newShuffleState = !_shuffleEnabled;

      if (_shuffleEnabled) {
        // Disable shuffle - just toggle the mode
        developer.log(
          '[MusicManager] Disabling shuffle mode',
          name: 'MusicManager',
        );

        await _audioHandler!.setShuffleMode(AudioServiceShuffleMode.none);
      } else {
        // Enable shuffle - just toggle the mode
        developer.log(
          '[MusicManager] Enabling shuffle mode',
          name: 'MusicManager',
        );

        // Store original queue if we don't have it yet for potential future use
        if (_originalQueue.isEmpty) {
          _originalQueue = List.from(_queue);
        }

        await _audioHandler!.setShuffleMode(AudioServiceShuffleMode.all);
      }

      developer.log(
        '[MusicManager] Shuffle toggled to: $newShuffleState',
        name: 'MusicManager',
      );
    } catch (e) {
      developer.log(
        '[ERROR][MusicManager][toggleShuffle] Failed: $e',
        name: 'MusicManager',
        error: e,
      );
    }
  }

  /// Toggle auto play mode (only when repeat mode is off)
  /// Auto play is automatically disabled when repeat mode is on
  Future<void> toggleAutoPlay() async {
    try {
      // Only allow toggle when repeat mode is off
      if (_repeatMode != AudioServiceRepeatMode.none) {
        developer.log(
          '[MusicManager] Auto play toggle blocked - repeat mode is active',
          name: 'MusicManager',
        );
        return;
      }

      _autoPlayEnabled = !_autoPlayEnabled;

      developer.log(
        '[MusicManager] Auto play toggled to: $_autoPlayEnabled',
        name: 'MusicManager',
      );

      // Start or stop monitoring based on new state
      if (_autoPlayEnabled) {
        _startAutoPlayMonitoring();
      } else {
        _stopAutoPlayMonitoring();
      }

      _safeNotifyListeners();
    } catch (e) {
      developer.log(
        '[ERROR][MusicManager][toggleAutoPlay] Failed: $e',
        name: 'MusicManager',
        error: e,
      );
    }
  }

  /// Start monitoring position for auto play feature
  void _startAutoPlayMonitoring() {
    if (_audioHandler == null || _isDisposed) return;

    _stopAutoPlayMonitoring(); // Clear any existing timer

    // Monitor position every 2 seconds when playing
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkForAutoPlay();
    });

    developer.log(
      '[MusicManager] Auto play monitoring started',
      name: 'MusicManager',
    );
  }

  /// Stop auto play monitoring
  void _stopAutoPlayMonitoring() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  /// Check if we should trigger auto play (last song with <15 seconds remaining)
  void _checkForAutoPlay() async {
    if (!_autoPlayEnabled ||
        _isAutoPlayInProgress ||
        _isDisposed ||
        !_isPlaying ||
        _repeatMode != AudioServiceRepeatMode.none) {
      return;
    }

    try {
      final currentIndex = _currentIndex;
      final queueLength = _queue.length;

      // Only trigger on the last song in queue
      if (currentIndex == null || currentIndex != queueLength - 1) {
        return;
      }

      final currentItem = _currentMediaItem;
      if (currentItem == null) return;

      final position = await getCurrentPosition();
      final duration = currentItem.duration ?? kDefaultSongDuration;
      final remaining = duration - position;

      // Trigger auto play when less than 15 seconds remain
      if (remaining.inSeconds <= 15 && remaining.inSeconds > 0) {
        developer.log(
          '[MusicManager] Auto play triggered - ${remaining.inSeconds}s remaining on last track',
          name: 'MusicManager',
        );

        _triggerAutoPlay();
      }
    } catch (e) {
      developer.log(
        '[ERROR][MusicManager] Auto play check failed: $e',
        name: 'MusicManager',
        error: e,
      );
    }
  }

  /// Trigger auto play by creating a station from current song
  void _triggerAutoPlay() async {
    if (_isAutoPlayInProgress || _isDisposed) return;

    _isAutoPlayInProgress = true;

    try {
      final currentItem = _currentMediaItem;
      if (currentItem == null) {
        developer.log(
          '[MusicManager] Auto play failed - no current media item',
          name: 'MusicManager',
        );
        return;
      }

      final audioId = currentItem.extras?['audio_id']?.toString();
      if (audioId == null || audioId.isEmpty) {
        developer.log(
          '[MusicManager] Auto play failed - no audio ID in current item',
          name: 'MusicManager',
        );
        return;
      }

      // Find the current song data
      DataMusic? currentSong;
      try {
        // Try to find in original music data
        currentSong = _originalMusicData.firstWhere(
          (song) => song.id.toString() == audioId,
        );
      } catch (e) {
        // Create minimal song data from MediaItem if not found
        currentSong = DataMusic(
          int.tryParse(audioId) ?? 0, // id
          currentItem.artUri?.toString() ?? '', // image
          currentItem.id, // audio
          currentItem.duration?.inSeconds.toString() ?? '180', // audio_duration
          currentItem.title, // audio_title
          _generateSlug(currentItem.title), // audio_slug
          0, // audio_genre_id
          '', // artist_id
          currentItem.artist ?? 'Unknown Artist', // artists_name
          '', // audio_language
          0, // listening_count
          0, // is_featured
          0, // is_trending
          DateTime.now().toIso8601String(), // created_at
          0, // is_recommended
          '0', // favourite
          '', // download_price
          '', // lyrics
        );
      }

      developer.log(
        '[MusicManager] Auto play: Creating station for ${currentSong.audio_title}',
        name: 'MusicManager',
      );

      // Use StationService to create and append station
      final stationService = StationService();
      final success = await stationService.createStation(currentSong);

      if (success) {
        developer.log(
          '[MusicManager] ✅ Auto play station created successfully',
          name: 'MusicManager',
        );
      } else {
        developer.log(
          '[MusicManager] ⚠️ Auto play station creation failed',
          name: 'MusicManager',
        );
      }
    } catch (e) {
      developer.log(
        '[ERROR][MusicManager] Auto play trigger failed: $e',
        name: 'MusicManager',
        error: e,
      );
    } finally {
      _isAutoPlayInProgress = false;
    }
  }

  // ============================================================================
  // MARK: Play Next / Add to Queue Functionality
  // ============================================================================

  /// Insert a track to play immediately after the current song (Play Next)
  /// If multiple tracks are added via Play Next, they stack - most recent goes right after current
  Future<void> insertPlayNext(
    DataMusic track, {
    String? pathImage,
    String? audioPath,
  }) async {
    if (_isDisposed) return;

    return _queueLock.synchronized(() async {
      if (!await ensureAudioHandler()) {
        developer.log(
          '[MusicManager] Cannot insert play next: audio handler unavailable',
          name: 'MusicManager',
        );
        return;
      }

      try {
        developer.log(
          '[MusicManager] 🎵 Inserting Play Next: ${track.audio_title}',
          name: 'MusicManager',
        );

        // Create MediaItem for the track
        final mediaItems = await _createMediaItems(
          musicList: [track],
          pathImage: pathImage ?? '',
          audioPath: audioPath ?? '',
          contextType: 'play_next',
          contextId: 'play_next_${track.id}',
        );

        if (mediaItems.isEmpty) {
          developer.log(
            '[MusicManager] ⚠️ No valid media item created for Play Next',
          );
          return;
        }

        final mediaItem = mediaItems.first;

        // Insert into play next stack at the beginning (most recent first)
        _playNextStack.insert(0, mediaItem);

        // Get current position in the main queue
        final currentIdx = _currentIndex ?? 0;
        final insertPosition = currentIdx + 1;

        // Insert the track into the actual audio service queue
        await _audioHandler!.addQueueItem(mediaItem);

        // Move the newly added item to the correct position (right after current)
        final updatedQueue = _audioHandler!.queue.value;
        if (updatedQueue.isNotEmpty) {
          final newItemIndex =
              updatedQueue.length - 1; // Last item is the newly added one
          if (newItemIndex > insertPosition) {
            // Move from the end to right after current song
            await _audioHandler!.moveQueueItem(newItemIndex, insertPosition);
          }
        }

        // Update local queue state
        _queue = List.from(_audioHandler!.queue.value);
        _safeNotifyListeners();

        developer.log(
          '[MusicManager] ✅ Play Next inserted: ${track.audio_title} at position $insertPosition',
          name: 'MusicManager',
        );

        // Show user feedback
        _showQueueActionFeedback('Added to Play Next: ${track.audio_title}');
      } catch (e) {
        developer.log(
          '[MusicManager] ❌ Failed to insert Play Next: $e',
          name: 'MusicManager',
          error: e,
        );
        _notifyError('Failed to add to Play Next: ${e.toString()}');
      }
    });
  }

  /// Add a track to the end of the queue (Add to Queue)
  /// These tracks play after all currently queued songs
  Future<void> addToQueue(
    DataMusic track, {
    String? pathImage,
    String? audioPath,
  }) async {
    if (_isDisposed) return;

    return _queueLock.synchronized(() async {
      if (!await ensureAudioHandler()) {
        developer.log(
          '[MusicManager] Cannot add to queue: audio handler unavailable',
          name: 'MusicManager',
        );
        return;
      }

      try {
        developer.log(
          '[MusicManager] 🎵 Adding to Queue: ${track.audio_title}',
          name: 'MusicManager',
        );

        // Create MediaItem for the track
        final mediaItems = await _createMediaItems(
          musicList: [track],
          pathImage: pathImage ?? '',
          audioPath: audioPath ?? '',
          contextType: 'add_to_queue',
          contextId: 'add_to_queue_${track.id}',
        );

        if (mediaItems.isEmpty) {
          developer.log(
            '[MusicManager] ⚠️ No valid media item created for Add to Queue',
          );
          return;
        }

        final mediaItem = mediaItems.first;

        // Add to our local add to queue stack
        _addToQueueStack.add(mediaItem);

        // Add to the end of the actual audio service queue
        await _audioHandler!.addQueueItem(mediaItem);

        // Update local queue state
        _queue = List.from(_audioHandler!.queue.value);
        _safeNotifyListeners();

        developer.log(
          '[MusicManager] ✅ Added to Queue: ${track.audio_title}',
          name: 'MusicManager',
        );

        // Show user feedback
        // _showQueueActionFeedback('Added to Queue: ${track.audio_title}');
      } catch (e) {
        developer.log(
          '[MusicManager] ❌ Failed to add to queue: $e',
          name: 'MusicManager',
          error: e,
        );
        _notifyError('Failed to add to queue: ${e.toString()}');
      }
    });
  }

  /// Get the next track that should play (respects Play Next stack priority)
  MediaItem? getNextTrackToPlay() {
    // First check if there are any Play Next items
    if (_playNextStack.isNotEmpty) {
      return _playNextStack.first;
    }

    // Otherwise, get next from main queue
    final currentIdx = _currentIndex ?? 0;
    if (currentIdx + 1 < _queue.length) {
      return _queue[currentIdx + 1];
    }

    // Check add to queue stack if main queue is exhausted
    if (_addToQueueStack.isNotEmpty) {
      return _addToQueueStack.first;
    }

    return null;
  }

  /// Remove a specific track from play next stack
  void removeFromPlayNext(String trackId) {
    _playNextStack.removeWhere((item) => item.extras?['audio_id'] == trackId);
    _safeNotifyListeners();
  }

  /// Remove a specific track from add to queue stack
  void removeFromAddToQueue(String trackId) {
    _addToQueueStack.removeWhere((item) => item.extras?['audio_id'] == trackId);
    _safeNotifyListeners();
  }

  /// Show user feedback for queue actions (can be extended for UI notifications)
  void _showQueueActionFeedback(String message) {
    developer.log(
      '[MusicManager] Queue Action: $message',
      name: 'MusicManager',
    );
    // This can be extended to show toast notifications or other UI feedback
  }

  // ============================================================================
  // MARK: Enhanced Queue Methods with Complete Song Data (DEADLOCK-FREE)
  // ============================================================================

  /// Enhanced Play Next - fetches complete song data from API
  /// This ensures the song has proper audio URL, duration, and metadata
  /// CRITICAL FIX: Uses non-blocking approach to prevent deadlock
  Future<void> insertPlayNextById(
    String songId,
    String songName,
    String artistName, {
    String? fallbackImagePath,
    String? fallbackAudioPath,
  }) async {
    if (_isDisposed) return;

    try {
      // First check if we can perform the operation quickly
      if (!await ensureAudioHandler()) {
        developer.log(
          '[MusicManager] Cannot insert play next: audio handler unavailable',
          name: 'MusicManager',
        );
        _notifyError('Audio player not ready. Please try again.');
        return;
      }

      developer.log(
        '[MusicManager] 🎵 Enhanced Play Next - fetching data for: $songName (ID: $songId)',
        name: 'MusicManager',
      );

      // Fetch song data WITHOUT queue lock to prevent blocking
      DataMusic? track;

      try {
        // First try to get complete song data from API with timeout
        track = await _fetchSingleMusicWithCache(songId);
      } catch (e) {
        developer.log(
          '[MusicManager] API fetch failed for Play Next: $e',
          name: 'MusicManager',
        );
      }

      if (track == null) {
        // Fallback: try to find in existing data
        if (listCopy.isNotEmpty) {
          try {
            track = listCopy.firstWhere((t) => t.id.toString() == songId);
          } catch (e) {
            // Not found in existing data
          }
        }
      }

      if (track == null) {
        // Last resort: create minimal track data (may have playback issues)
        developer.log(
          '[MusicManager] ⚠️ Creating minimal track data for Play Next: $songName',
          name: 'MusicManager',
        );
        track = DataMusic(
          int.tryParse(songId) ?? 0,
          fallbackImagePath ?? '', // image
          fallbackAudioPath ?? '', // audio (may be empty)
          '3:00', // audio_duration
          songName, // audio_title
          _generateSlug(songName), // audio_slug
          0, // audio_genre_id
          '', // artist_id
          artistName, // artists_name
          '', // audio_language
          0, // listening_count
          0, // is_featured
          0, // is_trending
          '', // created_at
          0, // is_recommended
          '0', // favourite
          '', // download_price
          '', // lyrics
        );
      }

      // CRITICAL FIX: Use direct audio service calls instead of nested synchronized blocks
      try {
        developer.log(
          '[MusicManager] 🎵 Inserting Play Next directly: ${track.audio_title}',
          name: 'MusicManager',
        );

        // Create MediaItem for the track
        final mediaItems = await _createMediaItems(
          musicList: [track],
          pathImage: track.image,
          audioPath: track.audio,
          contextType: 'play_next',
          contextId: 'play_next_${track.id}',
        );

        if (mediaItems.isEmpty) {
          developer.log(
            '[MusicManager] ⚠️ No valid media item created for Play Next',
          );
          return;
        }

        final mediaItem = mediaItems.first;

        // Insert into play next stack at the beginning (most recent first)
        _playNextStack.insert(0, mediaItem);

        // Get current position in the main queue
        final currentIdx = _currentIndex ?? 0;
        final insertPosition = currentIdx + 1;

        // Insert the track into the actual audio service queue
        await _audioHandler!.addQueueItem(mediaItem);

        // Move the newly added item to the correct position (right after current)
        final updatedQueue = _audioHandler!.queue.value;
        if (updatedQueue.isNotEmpty) {
          final newItemIndex =
              updatedQueue.length - 1; // Last item is the newly added one
          if (newItemIndex > insertPosition) {
            // Move from the end to right after current song
            await _audioHandler!.moveQueueItem(newItemIndex, insertPosition);
          }
        }

        // Update local queue state
        _queue = List.from(_audioHandler!.queue.value);
        _safeNotifyListeners();

        developer.log(
          '[MusicManager] ✅ Play Next inserted: ${track.audio_title} at position $insertPosition',
          name: 'MusicManager',
        );

        // Show user feedback
        _showQueueActionFeedback('Added to Play Next: ${track.audio_title}');
      } catch (queueError) {
        developer.log(
          '[MusicManager] ❌ Failed to insert Play Next: $queueError',
          name: 'MusicManager',
          error: queueError,
        );
        _notifyError('Failed to add to Play Next: ${queueError.toString()}');
      }

      developer.log(
        '[MusicManager] ✅ Enhanced Play Next completed for: ${track.audio_title}',
        name: 'MusicManager',
      );
    } catch (e) {
      developer.log(
        '[MusicManager] ❌ Enhanced Play Next failed: $e',
        name: 'MusicManager',
        error: e,
      );

      _notifyError('Failed to add to Play Next: ${e.toString()}');
    }
  }

  /// Enhanced Add to Queue - fetches complete song data from API
  /// This ensures the song has proper audio URL, duration, and metadata
  /// CRITICAL FIX: Uses non-blocking approach to prevent deadlock
  Future<void> addToQueueById(
    String songId,
    String songName,
    String artistName, {
    String? fallbackImagePath,
    String? fallbackAudioPath,
  }) async {
    if (_isDisposed) return;

    try {
      // First check if we can perform the operation quickly
      if (!await ensureAudioHandler()) {
        developer.log(
          '[MusicManager] Cannot add to queue: audio handler unavailable',
          name: 'MusicManager',
        );
        _notifyError('Audio player not ready. Please try again.');
        return;
      }

      developer.log(
        '[MusicManager] 🎵 Enhanced Add to Queue - fetching data for: $songName (ID: $songId)',
        name: 'MusicManager',
      );

      // Fetch song data WITHOUT queue lock to prevent blocking
      DataMusic? track;

      try {
        // First try to get complete song data from API with timeout
        track = await _fetchSingleMusicWithCache(songId);
      } catch (e) {
        developer.log(
          '[MusicManager] API fetch failed for Add to Queue: $e',
          name: 'MusicManager',
        );
      }

      if (track == null) {
        // Fallback: try to find in existing data
        if (listCopy.isNotEmpty) {
          try {
            track = listCopy.firstWhere((t) => t.id.toString() == songId);
          } catch (e) {
            // Not found in existing data
          }
        }
      }

      if (track == null) {
        // Last resort: create minimal track data (may have playback issues)
        developer.log(
          '[MusicManager] ⚠️ Creating minimal track data for Add to Queue: $songName',
          name: 'MusicManager',
        );
        track = DataMusic(
          int.tryParse(songId) ?? 0,
          fallbackImagePath ?? '', // image
          fallbackAudioPath ?? '', // audio (may be empty)
          '3:00', // audio_duration
          songName, // audio_title
          _generateSlug(songName), // audio_slug
          0, // audio_genre_id
          '', // artist_id
          artistName, // artists_name
          '', // audio_language
          0, // listening_count
          0, // is_featured
          0, // is_trending
          '', // created_at
          0, // is_recommended
          '0', // favourite
          '', // download_price
          '', // lyrics
        );
      }

      // CRITICAL FIX: Use direct audio service calls instead of nested synchronized blocks
      try {
        developer.log(
          '[MusicManager] 🎵 Adding to Queue directly: ${track.audio_title}',
          name: 'MusicManager',
        );

        // Create MediaItem for the track
        final mediaItems = await _createMediaItems(
          musicList: [track],
          pathImage: track.image,
          audioPath: track.audio,
          contextType: 'add_to_queue',
          contextId: 'add_to_queue_${track.id}',
        );

        if (mediaItems.isEmpty) {
          developer.log(
            '[MusicManager] ⚠️ No valid media item created for Add to Queue',
          );
          return;
        }

        final mediaItem = mediaItems.first;

        // Add to the add-to-queue stack
        _addToQueueStack.add(mediaItem);

        // Add the track to the end of the actual audio service queue
        await _audioHandler!.addQueueItem(mediaItem);

        // Update local queue state
        _queue = List.from(_audioHandler!.queue.value);
        _safeNotifyListeners();

        developer.log(
          '[MusicManager] ✅ Added to Queue: ${track.audio_title}',
          name: 'MusicManager',
        );

        // Show user feedback
        // _showQueueActionFeedback('Added to Queue: ${track.audio_title}');
      } catch (queueError) {
        developer.log(
          '[MusicManager] ❌ Failed to add to queue: $queueError',
          name: 'MusicManager',
          error: queueError,
        );
        _notifyError('Failed to add to queue: ${queueError.toString()}');
      }

      developer.log(
        '[MusicManager] ✅ Enhanced Add to Queue completed for: ${track.audio_title}',
        name: 'MusicManager',
      );
    } catch (e) {
      developer.log(
        '[MusicManager] ❌ Enhanced Add to Queue failed: $e',
        name: 'MusicManager',
        error: e,
      );

      _notifyError('Failed to add to queue: ${e.toString()}');
    }
  }

  /// Helper method to generate slug from song name
  String _generateSlug(String songName) {
    return songName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .trim();
  }

  /// Cached fetch for single music details to avoid duplicate network requests.
  /// Returns null on timeout or failure.
  Future<DataMusic?> _fetchSingleMusicWithCache(String songId) async {
    // Check cache entry
    final existing = _singleMusicCache[songId];
    if (existing != null) {
      // If entry is fresh, return its future
      if (DateTime.now().difference(existing.timestamp) <
          _kSingleMusicCacheTtl) {
        return existing.future;
      } else {
        // Remove stale entry
        _singleMusicCache.remove(songId);
      }
    }

    // Create new in-flight future and store
    final completer = Completer<DataMusic?>();
    final fetchFuture = completer.future;
    _singleMusicCache[songId] = _SingleMusicCacheEntry(fetchFuture);

    // Start actual fetch (do not await here so future is stored immediately)
    () async {
      try {
        final service = SingleMusicService();
        final result = await service
            .fetchSingleMusic(songId)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (!completer.isCompleted) completer.complete(result);
      } catch (e) {
        if (!completer.isCompleted) completer.complete(null);
      }
    }();

    // Return the in-flight future (caller will await)
    final result = await fetchFuture;

    // Cleanup stale cache entries proactively
    Future.microtask(() {
      final entry = _singleMusicCache[songId];
      if (entry != null &&
          DateTime.now().difference(entry.timestamp) >= _kSingleMusicCacheTtl) {
        _singleMusicCache.remove(songId);
      }
    });

    return result;
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _audioHandler?.setSpeed(speed);
    _speed = speed;
    _safeNotifyListeners();
  }

  /// Get current playback position with enhanced paused state support
  Future<Duration> getCurrentPosition() async {
    try {
      // Always return cached position first for immediate response
      if (_position != Duration.zero) {
        // Try to get fresh position but don't block if it fails
        AudioService.position.first
            .timeout(const Duration(milliseconds: 200))
            .then((freshPosition) {
              _position = freshPosition;
            })
            .catchError((e) {
              // Silently continue with cached position if fresh fetch fails
            });

        return _position;
      }

      // If no cached position, try to get from AudioService
      final position = await AudioService.position.first.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => Duration.zero,
      );

      _position = position; // Update local cache
      return position;
    } catch (e) {
      developer.log(
        '[MusicManager] Error getting position: $e',
        name: 'MusicManager',
      );
      // Return cached position as fallback
      return _position;
    }
  }

  /// Get current media item with fallback
  MediaItem? getCurrentMediaItem() {
    // Return current media item or try to get from handler
    if (_currentMediaItem != null) {
      return _currentMediaItem;
    }
    // Fallback to handler's current media item
    try {
      return _audioHandler?.mediaItem.valueOrNull;
    } catch (e) {
      developer.log(
        '[MusicManager] Error getting current media item: $e',
        name: 'MusicManager',
      );
      return null;
    }
  }

  /// Check if there's any music loaded (for mini player visibility)
  bool get hasAnyMusicLoaded {
    return _currentMediaItem != null ||
        (_audioHandler?.mediaItem.value != null) ||
        _queue.isNotEmpty;
  }

  /// Force state synchronization for UI components
  void syncStateForUI() {
    if (_isDisposed) return;
    developer.log(
      '[MusicManager] Forcing state sync - isPlaying: [38;5;28m[1m[4m$_isPlaying[0m',
      name: 'MusicManager',
    );
    _safeNotifyListeners();
  }

  /// Play a specific song by index within a provided list (coalesced and guarded)
  /// This method sets an optimistic processing state (for UI) and coalesces
  /// duplicate requests for the same song id so multiple taps share one Future.
  Future<void> playSongById({
    required List<DataMusic> musicList,
    required int startIndex,
    required String pathImage,
    required String audioPath,
    String? contextId,
    String? callSource,
  }) async {
    if (_isDisposed) return;

    final audioId = musicList[startIndex].id.toString();

    // If already processing this song, return the existing future if any
    final existing = _inflightOperations[audioId];
    if (existing != null) {
      developer.log(
        '[MusicManager] Coalescing duplicate play request for $audioId',
        name: 'MusicManager',
      );
      return existing;
    }

    // Start processing: set notifier so UI can show optimistic mini-player
    _processingSongIds.add(audioId);
    processingAudioId.value = audioId;

    // Create the operation future and store it so duplicate taps reuse it
    final completer = Completer<void>();
    final opFuture = completer.future;
    _inflightOperations[audioId] = opFuture;

    // Perform the queue replacement asynchronously
    () async {
      try {
        await replaceQueue(
          musicList: musicList,
          startIndex: startIndex,
          pathImage: pathImage,
          audioPath: audioPath,
          contextId: contextId,
          callSource: callSource ?? 'MusicManager.playSongById',
        );
      } catch (e) {
        developer.log(
          '[MusicManager] playSongById failed: $e',
          name: 'MusicManager',
        );
        rethrow;
      } finally {
        _processingSongIds.remove(audioId);
        processingAudioId.value = null;
        _inflightOperations.remove(audioId);
        if (!completer.isCompleted) completer.complete();
      }
    }();

    return opFuture;
  }

  /// Clear any optimistic processing state (e.g., on cancel)
  void clearProcessingAudioId() {
    _processingSongIds.clear();
    processingAudioId.value = null;
  }

  /// Check if manager has any music data for mini player visibility
  bool get hasValidMusicDataLoaded {
    return _currentMediaItem != null ||
        _queue.isNotEmpty ||
        (_audioHandler?.mediaItem.value != null);
  }

  /// Force refresh state from audio handler
  Future<void> refreshState() async {
    if (_audioHandler == null) return;
    try {
      // Get latest state from audio handler
      final playbackState = _audioHandler!.playbackState.value;
      final mediaItem = _audioHandler!.mediaItem.valueOrNull;
      final queue = _audioHandler!.queue.value;
      final position = await getCurrentPosition();
      // Update local state
      _isPlaying = playbackState.playing;
      _isLoading =
          playbackState.processingState == AudioProcessingState.loading;
      _speed = playbackState.speed;
      _repeatMode = playbackState.repeatMode;
      _currentIndex = playbackState.queueIndex;
      _currentMediaItem = mediaItem;
      _queue = List.from(queue);
      _position = position;
      _safeNotifyListeners();
      developer.log(
        '[MusicManager] State refreshed - playing: $_isPlaying, media: \\${_currentMediaItem?.title}',
        name: 'MusicManager',
      );
    } catch (e) {
      developer.log(
        '[MusicManager] Error refreshing state: $e',
        name: 'MusicManager',
      );
    }
  }

  /// Force clear all locks and reset operation state (for emergency cleanup)
  /// CRITICAL: This method should be called when the app detects queue operations are stuck
  void forceClearLocks() {
    developer.log(
      '[MusicManager] 🧹 Force clearing all locks and operations',
      name: 'MusicManager',
    );

    // Reset global system lock
    _globalSystemLock = false;
    _globalLockOwner = '';
    _globalLockAcquiredTime = DateTime(0);

    // Reset instance-level locks
    _isQueueReplaceInProgress = false;
    _lastQueueId = '';
    _lastQueueReplaceTime = DateTime(0);

    // Reset global queue replacement tracking
    _globalQueueReplacementCounter = 0;
    _lastGlobalQueueReplacement = DateTime(0);

    // Complete any pending operations with timeout protection
    _completePendingOperations();

    // Clear play next and add to queue stacks to reset state
    _playNextStack.clear();
    _addToQueueStack.clear();

    developer.log(
      '[MusicManager] ✅ All locks and operations cleared successfully',
      name: 'MusicManager',
    );
  }

  /// Auto-clear stale locks periodically (call this from UI when needed)
  void autoCleanupStaleLocks() {
    final now = DateTime.now();

    // Clear global system lock if it's older than 10 seconds
    if (_globalSystemLock &&
        now.difference(_globalLockAcquiredTime).inSeconds > 10) {
      developer.log(
        '[MusicManager] 🧹 Auto-clearing stale global system lock (age: ${now.difference(_globalLockAcquiredTime).inSeconds}s)',
        name: 'MusicManager',
      );
      _globalSystemLock = false;
      _globalLockOwner = '';
    }

    // Clear queue replacement lock if it's older than 5 seconds
    if (_isQueueReplaceInProgress &&
        now.difference(_lastQueueReplaceTime).inSeconds > 5) {
      developer.log(
        '[MusicManager] 🧹 Auto-clearing stale queue replacement lock (age: ${now.difference(_lastQueueReplaceTime).inSeconds}s)',
        name: 'MusicManager',
      );
      _isQueueReplaceInProgress = false;
    }
  }

  /// Helper for logging and notifying playback errors
  void _logAndNotifyPlaybackError(
    String context,
    Object error,
    PlaybackState state,
  ) {
    developer.log(
      '[MusicManager] Playback $context failed: $error. State: playing=${state.playing}, processingState=${state.processingState}, queueIndex=${state.queueIndex}',
      name: 'MusicManager',
      error: error,
    );
    _notifyError('Playback failed:  𝙴𝚛𝚛𝚘𝚛: ${error.toString()}');
  }

  /// Helper method to retry playback with backoff for improved reliability
  Future<bool> _retryPlayback({int? maxAttempts}) async {
    final int attempts = maxAttempts ?? kPlaybackMaxAttempts;
    for (int attempt = 1; attempt <= attempts; attempt++) {
      try {
        final preState = _audioHandler!.playbackState.value;
        developer.log(
          '[MusicManager] [RETRY] Attempt $attempt/$attempts - Pre-play state: playing=${preState.playing}, processingState=${preState.processingState}, queueIndex=${preState.queueIndex}',
          name: 'MusicManager',
        );
        await _audioHandler!.play().timeout(
          Duration(
            milliseconds:
                kPlaybackBaseTimeoutMs +
                (attempt * kPlaybackTimeoutIncrementMs),
          ),
        );
        final postState = _audioHandler!.playbackState.value;
        developer.log(
          '[MusicManager] [RETRY] Attempt $attempt - Post-play state: playing=${postState.playing}, processingState=${postState.processingState}, queueIndex=${postState.queueIndex}',
          name: 'MusicManager',
        );
        if (!postState.playing) {
          developer.log(
            '[MusicManager] [RETRY] Playback not started after play() on attempt $attempt',
            name: 'MusicManager',
          );
          await refreshState();
          continue;
        }
        developer.log(
          '[MusicManager] ✅ Playback successful on attempt $attempt',
          name: 'MusicManager',
        );
        return true;
      } on TimeoutException {
        final state = _audioHandler!.playbackState.value;
        developer.log(
          '[MusicManager] Playback attempt $attempt timed out. State: playing=${state.playing}, processingState=${state.processingState}, queueIndex=${state.queueIndex}',
          name: 'MusicManager',
        );
        await refreshState();
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        final state = _audioHandler!.playbackState.value;
        if (errorString.contains('connection') &&
            errorString.contains('abort')) {
          developer.log(
            '[MusicManager] Connection abort on attempt $attempt - checking if playback actually started. State: playing=${state.playing}, processingState=${state.processingState}, queueIndex=${state.queueIndex}',
            name: 'MusicManager',
          );
          await Future.delayed(Duration(milliseconds: 100));
          final currentState = _audioHandler!.playbackState.value;
          if (currentState.playing) {
            developer.log(
              '[MusicManager] Connection abort but playback is active - treating as success',
              name: 'MusicManager',
            );
            return true;
          } else {
            developer.log(
              '[MusicManager] Connection abort and playback not active - treating as failure',
              name: 'MusicManager',
            );
            await refreshState();
          }
        } else {
          _logAndNotifyPlaybackError('attempt $attempt', e, state);
          await refreshState();
        }
      }
      if (attempt < attempts) {
        final delay = Duration(
          milliseconds: kPlaybackRetryBaseDelayMs * attempt,
        );
        developer.log(
          '[MusicManager] Waiting ${delay.inMilliseconds}ms before retry attempt ${attempt + 1}',
          name: 'MusicManager',
        );
        await Future.delayed(delay);
      }
    }
    // If all attempts fail, clear playing state for safety
    final finalState = _audioHandler!.playbackState.value;
    developer.log(
      '[MusicManager] All playback attempts failed. Final state: playing=${finalState.playing}, processingState=${finalState.processingState}, queueIndex=${finalState.queueIndex}',
      name: 'MusicManager',
    );
    _isPlaying = false;
    _safeNotifyListeners();
    _notifyError(
      'Unable to start playback after multiple attempts. Please try again or select another song.',
    );
    return false;
  }

  /// Clean up resources - CRITICAL MEMORY LEAK FIX
  @override
  Future<void> dispose() async {
    developer.log(
      '[MusicManager] Starting disposal cleanup',
      name: 'MusicManager',
    );

    // Set disposal flag first to prevent further operations
    _isDisposed = true;

    try {
      // Cancel all stream subscriptions with proper error handling and timeout
      await _disposeSubscriptionSafely(
        _playbackStateSubscription,
        'playbackState',
      );
      _playbackStateSubscription = null;

      await _disposeSubscriptionSafely(_mediaItemSubscription, 'mediaItem');
      _mediaItemSubscription = null;

      await _disposeSubscriptionSafely(_queueSubscription, 'queue');
      _queueSubscription = null;

      await _disposeSubscriptionSafely(_positionSubscription, 'position');
      _positionSubscription = null;

      // Stop auto play monitoring
      _stopAutoPlayMonitoring();

      // Cancel debounce timer with timeout protection
      try {
        _notifyDebounceTimer?.cancel();
      } catch (e) {
        developer.log(
          '[MusicManager] Error canceling debounce timer: $e',
          name: 'MusicManager',
        );
      } finally {
        _notifyDebounceTimer = null;
      }

      // Complete any pending queue operations with timeout protection
      _completePendingOperations();

      // Clear audio handler reference
      _audioHandler = null;

      // Close error stream
      try {
        _errorController.close();
      } catch (e) {
        developer.log(
          '[MusicManager] Error closing errorController: $e',
          name: 'MusicManager',
        );
      }

      developer.log(
        '[MusicManager] Disposal cleanup completed successfully',
        name: 'MusicManager',
      );
    } catch (e) {
      developer.log(
        '[MusicManager] Error during disposal: $e',
        name: 'MusicManager',
        error: e,
      );
    }
    // Always call super.dispose()
    super.dispose();
    // Reset singleton so it can be re-created if needed
    MusicManager._instance = null;
  }

  /// Safely dispose of stream subscriptions with timeout protection
  Future<void> _disposeSubscriptionSafely(
    StreamSubscription? subscription,
    String name,
  ) async {
    if (subscription == null) return;

    try {
      // Use a timeout to prevent hanging during disposal
      final cancelFuture = subscription.cancel();
      await cancelFuture.timeout(
        kSubscriptionCancelTimeout,
        onTimeout: () {
          developer.log(
            '[MusicManager] Timeout while canceling $name subscription',
            name: 'MusicManager',
          );
        },
      );
    } catch (e) {
      developer.log(
        '[MusicManager] Error disposing $name subscription: $e',
        name: 'MusicManager',
        error: e,
      );
    }
  }

  /// Complete pending operations with timeout protection
  void _completePendingOperations() {
    try {
      // Complete current queue operation
      if (_currentQueueOperation != null &&
          !_currentQueueOperation!.isCompleted) {
        _currentQueueOperation!.complete();
      }
      _currentQueueOperation = null;

      // Complete all pending queue operations with timeout
      final startTime = DateTime.now();
      for (final operation in _queueOperationQueue) {
        try {
          if (!operation.isCompleted) {
            operation.complete();
          }
        } catch (e) {
          developer.log(
            '[MusicManager] Error completing queue operation: $e',
            name: 'MusicManager',
          );
        }

        // Prevent infinite loops during disposal
        if (DateTime.now().difference(startTime) > kPendingOpsTimeout) {
          developer.log(
            '[MusicManager] Timeout during queue operation cleanup',
            name: 'MusicManager',
          );
          break;
        }
      }
      _queueOperationQueue.clear();
    } catch (e) {
      developer.log(
        '[MusicManager] Error completing pending operations: $e',
        name: 'MusicManager',
        error: e,
      );
    }
  }

  /// Update favorite status for the current MediaItem and global data
  void updateCurrentSongFavoriteStatus(String newFavoriteStatus) {
    try {
      developer.log(
        'MusicManager: Starting updateCurrentSongFavoriteStatus with status: $newFavoriteStatus',
        name: 'MusicManager',
      );

      final currentMediaItem = _audioHandler?.mediaItem.valueOrNull;
      if (currentMediaItem == null) {
        developer.log(
          'MusicManager: No current MediaItem found',
          name: 'MusicManager',
        );
        return;
      }

      developer.log(
        'MusicManager: Current MediaItem ID: [38;5;208m${currentMediaItem.id}[0m',
        name: 'MusicManager',
      );
      developer.log(
        'MusicManager: Current MediaItem title: ${currentMediaItem.title}',
        name: 'MusicManager',
      );

      // Update the MediaItem extras
      final updatedExtras = Map<String, dynamic>.from(
        currentMediaItem.extras ?? {},
      );
      updatedExtras['favourite'] = newFavoriteStatus;

      developer.log(
        'MusicManager: Updated extras: $updatedExtras',
        name: 'MusicManager',
      );

      // Create updated MediaItem
      final updatedMediaItem = MediaItem(
        id: currentMediaItem.id,
        title: currentMediaItem.title,
        artist: currentMediaItem.artist,
        album: currentMediaItem.album,
        duration: currentMediaItem.duration,
        artUri: currentMediaItem.artUri,
        extras: updatedExtras,
      );

      developer.log(
        'MusicManager: Created updated MediaItem',
        name: 'MusicManager',
      );

      // Update the queue with the new MediaItem
      final currentQueue = List<MediaItem>.from(_queue);
      final currentIndex = currentQueue.indexWhere(
        (item) => item.id == currentMediaItem.id,
      );
      if (currentIndex >= 0) {
        currentQueue[currentIndex] = updatedMediaItem;
        _queue = currentQueue;
        developer.log(
          'MusicManager: Updated local queue at index: $currentIndex',
          name: 'MusicManager',
        );

        // CRITICAL: Update the AudioHandler's MediaItem directly (without replacing entire queue)
        // This ensures the UI gets the updated favorite status immediately
        try {
          _audioHandler?.updateMediaItem(updatedMediaItem);
          developer.log(
            'MusicManager: Successfully updated AudioHandler MediaItem with new favorite status',
            name: 'MusicManager',
          );
        } catch (e) {
          developer.log(
            'MusicManager: ERROR updating AudioHandler MediaItem: $e',
            name: 'MusicManager',
          );
        }
      } else {
        developer.log(
          'MusicManager: WARNING - Could not find MediaItem in queue',
          name: 'MusicManager',
        );
      }

      // Update global listCopy if available
      final audioId = currentMediaItem.extras?['audio_id']?.toString();
      if (audioId != null && listCopy.isNotEmpty) {
        final songIndex = listCopy.indexWhere(
          (song) => song.id.toString() == audioId,
        );
        if (songIndex >= 0) {
          listCopy[songIndex].favourite = newFavoriteStatus;
          developer.log(
            'MusicManager: Updated listCopy at index: $songIndex',
            name: 'MusicManager',
          );
        } else {
          developer.log(
            'MusicManager: WARNING - Could not find song in listCopy',
            name: 'MusicManager',
          );
        }
      } else {
        developer.log(
          'MusicManager: No audioId or empty listCopy',
          name: 'MusicManager',
        );
      }

      _safeNotifyListeners();

      developer.log(
        '[MusicManager] Updated favorite status to: $newFavoriteStatus for song: ${currentMediaItem.title}',
        name: 'MusicManager',
      );
    } catch (e) {
      developer.log(
        '[ERROR][MusicManager][updateCurrentSongFavoriteStatus] Failed: $e',
        name: 'MusicManager',
        error: e,
      );
    }
  }

  // Error notification stream for UI
  final StreamController<String> _errorController =
      StreamController.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  /// Notify listeners of an error
  void _notifyError(String message) {
    developer.log('[MusicManager] Error: $message', name: 'MusicManager');
    // You can extend this to show UI notifications if needed
  }
}
