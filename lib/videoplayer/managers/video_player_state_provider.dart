import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/video_player_state.dart';

/// State notifier for managing video player state
class VideoPlayerStateNotifier extends Notifier<VideoPlayerState> {
  Timer? _positionUpdateTimer;
  Timer? _controlsHideTimer;

  /// Keeps track of controllers that have already been fully disposed to avoid
  /// double-dispose crashes triggered by overlapping cleanup routines.
  final Set<VideoPlayerController> _disposedControllers =
      LinkedHashSet<VideoPlayerController>.identity();

  /// Prevents scheduling the same controller for disposal multiple times.
  final Set<VideoPlayerController> _scheduledControllerDisposals =
      LinkedHashSet<VideoPlayerController>.identity();

  /// Ensures disposeVideo runs atomically even if called repeatedly in quick succession.
  Completer<void>? _disposeCompleter;

  /// Tracks whether the current controller is active (initialized and not in cleanup)
  bool _isControllerActive = false;

  /// Monotonic counter for initialization requests. Used to ignore stale/overlapped
  /// initializeVideo executions so we don't expose a controller that was disposed
  /// by a newer request.
  int _initRequestCounter = 0;

  @override
  VideoPlayerState build() => const VideoPlayerState();

  /// Initialize video player with a video URL
  Future<void> initializeVideo({
    required String videoUrl,
    required String videoId,
    String? title,
    String? subtitle,
    String? thumbnailUrl,
    List<String>? playlist,
    int? playlistIndex,
    int? channelId,
    String? channelAvatarUrl,
    // Try to auto-start playback after initialization. Set to false when you only want to preload.
    bool autoPlay = true,
    // internal retry counter for transient platform errors
    int retryAttempt = 0,
  }) async {
    const int maxRetries = 1;
    try {
      // Capture any existing controller and immediately remove it from state so
      // the UI hides the previous video right away (shows loading overlay).
      final existingController = state.controller;
      state = state.copyWith(
        controller: null,
        isLoading: true,
        errorMessage: null,
        currentVideoId: videoId,
        currentVideoTitle: title,
        currentVideoSubtitle: subtitle,
        thumbnailUrl: thumbnailUrl,
        channelId: channelId,
        channelAvatarUrl: channelAvatarUrl,
        playlist: playlist,
        currentIndex: playlistIndex,
        isMinimized: false,
        showMiniPlayer: false,
      );

      // Dispose the previously attached controller (if any) without waiting for
      // the rest of the cleanup to avoid leaving its surface visible.
      await _disposeControllerInstance(existingController);

      // Perform remaining cleanup tasks (timers/_isControllerActive)
      await _cleanupExistingController();

      // Small delay to ensure previous controller is fully released
      await Future.delayed(const Duration(milliseconds: 250));

      // Track this initialize request so we can abort if another initializeVideo
      // call starts while this one is running.
      final int myInitId = ++_initRequestCounter;
      debugPrint(
        '[VideoPlayer] initializeVideo START id=$myInitId videoId=$videoId at ${DateTime.now().toIso8601String()}',
      );

      // Quick HTTP HEAD pre-check to avoid platform codec init on unreachable/invalid URLs.
      try {
        final uri = Uri.parse(videoUrl);
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final req = await client
            .openUrl('HEAD', uri)
            .timeout(const Duration(seconds: 4));
        final resp = await req.close().timeout(const Duration(seconds: 4));
        if (resp.statusCode >= 400) {
          throw Exception('Video URL responded with status ${resp.statusCode}');
        }
        client.close(force: true);
      } catch (e) {
        debugPrint('[VideoPlayer] HEAD check failed: $e');
        // Let the native player still attempt to initialize, but this reduces many transient errors.
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await controller.initialize();

      // If a newer initializeVideo started while we were initializing, don't
      // attach this controller to state — dispose it instead.
      if (myInitId != _initRequestCounter) {
        try {
          _scheduleDisposeController(controller);
        } catch (_) {}
        return;
      }

      // Add listeners
      controller.addListener(_videoPlayerListener);
      // Mark controller as active only after listener is attached and initialization completes
      _isControllerActive = true;

      state = state.copyWith(
        controller: controller,
        isLoading: false,
        duration: controller.value.duration,
        volume: controller.value.volume,
        // ensure channel metadata remains present after init
        channelId: channelId ?? state.channelId,
        channelAvatarUrl: channelAvatarUrl ?? state.channelAvatarUrl,
      );

      // Start position update timer
      _startPositionUpdateTimer();

      // Auto-play after successful initialization when requested
      if (autoPlay) {
        try {
          await controller.play();
          state = state.copyWith(isPlaying: true);
          _resetControlsTimer();
        } catch (e) {
          // If play fails, we still keep controller initialized; user can press play manually
          debugPrint('[VideoPlayer] autoplay failed: $e');
        }
      }
      debugPrint(
        '[VideoPlayer] initializeVideo SUCCESS id=$myInitId videoId=$videoId at ${DateTime.now().toIso8601String()}',
      );
    } catch (e, st) {
      // Attempt a single retry for transient codec/surface errors
      debugPrint('[VideoPlayer] initialize error: $e');
      debugPrint(st.toString());

      // If controller was partially created, dispose it safely
      final partial = state.controller;
      if (partial != null) {
        try {
          _isControllerActive = false;
          // Clear controller from state immediately so widgets won't mount with a disposed controller
          state = state.copyWith(controller: null);
          _scheduleDisposeController(partial);
        } catch (_) {
          // ignore
        }
      }

      if (retryAttempt < maxRetries) {
        // small backoff before retrying
        await Future.delayed(const Duration(milliseconds: 200));
        debugPrint(
          '[VideoPlayer] retrying initialize (attempt ${retryAttempt + 1})',
        );
        // Re-call initializeVideo with incremented retryAttempt
        await initializeVideo(
          videoUrl: videoUrl,
          videoId: videoId,
          title: title,
          subtitle: subtitle,
          thumbnailUrl: thumbnailUrl,
          playlist: playlist,
          playlistIndex: playlistIndex,
          autoPlay: autoPlay,
          retryAttempt: retryAttempt + 1,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load video: ${e.toString()}',
      );
    }
  }

  /// Internal cleanup method to ensure proper resource disposal
  Future<void> _cleanupExistingController() async {
    // Mark controller as inactive immediately so listeners/timers stop accessing it
    _isControllerActive = false;

    // Cancel timers first to prevent them from accessing disposed controller
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;

    final controller = state.controller;
    if (controller != null) {
      // Clear the controller reference from state immediately so widgets won't try
      // to add listeners or rebuild using a controller that is being disposed.
      debugPrint(
        '[VideoPlayer] _cleanupExistingController: clearing state.controller at ${DateTime.now().toIso8601String()}',
      );
      state = state.copyWith(controller: null);

      // Schedule a safe dispose after a short delay so the widget tree has time
      // to react to the controller being cleared.
      debugPrint(
        '[VideoPlayer] _cleanupExistingController: scheduling dispose for controller at ${DateTime.now().toIso8601String()}',
      );
      _scheduleDisposeController(controller);
    }
  }

  /// Dispose a specific controller instance safely (does not mutate `state`).
  Future<void> _disposeControllerInstance(
    VideoPlayerController? controller,
  ) async {
    if (controller == null) return;
    try {
      // Schedule a short delayed dispose to avoid races with the widget tree
      // mounting a VideoPlayer that may still be referencing this controller.
      debugPrint(
        '[VideoPlayer] _disposeControllerInstance: scheduling dispose for controller at ${DateTime.now().toIso8601String()}',
      );
      _scheduleDisposeController(controller);
    } catch (e) {
      debugPrint('[VideoPlayer] disposeControllerInstance error: $e');
    }
  }

  /// Schedule a delayed dispose for a controller. The actual dispose only
  /// happens if that controller is not currently attached to `state.controller`.
  void _scheduleDisposeController(VideoPlayerController controller) {
    if (_disposedControllers.contains(controller)) {
      debugPrint(
        '[VideoPlayer] _scheduleDisposeController: skip, controller already disposed',
      );
      return;
    }
    if (_scheduledControllerDisposals.contains(controller)) {
      debugPrint(
        '[VideoPlayer] _scheduleDisposeController: skip, controller already scheduled',
      );
      return;
    }

    _scheduledControllerDisposals.add(controller);
    final VideoPlayerController toDispose = controller;
    debugPrint(
      '[VideoPlayer] _scheduleDisposeController: scheduled at ${DateTime.now().toIso8601String()} to run in 350ms',
    );
    Future.delayed(const Duration(milliseconds: 350), () async {
      _scheduledControllerDisposals.remove(toDispose);
      if (_disposedControllers.contains(toDispose)) {
        debugPrint(
          '[VideoPlayer] _scheduleDisposeController: skip dispose, controller already handled',
        );
        return;
      }
      debugPrint(
        '[VideoPlayer] _scheduleDisposeController: running dispose at ${DateTime.now().toIso8601String()}',
      );
      // If the controller has been re-attached to state, skip disposing it.
      if (state.controller == toDispose) {
        debugPrint(
          '[VideoPlayer] _scheduleDisposeController: skip dispose, controller re-attached at ${DateTime.now().toIso8601String()}',
        );
        return;
      }
      try {
        toDispose.removeListener(_videoPlayerListener);
      } catch (_) {}
      try {
        if (toDispose.value.isInitialized && toDispose.value.isPlaying) {
          await toDispose.pause();
        }
      } catch (_) {}
      try {
        await toDispose.dispose();
        _disposedControllers.add(toDispose);
        debugPrint(
          '[VideoPlayer] _scheduleDisposeController: disposed controller at ${DateTime.now().toIso8601String()}',
        );
      } catch (e) {
        debugPrint('[VideoPlayer] scheduled dispose error: $e');
      }
    });
  }

  /// Public helper for widgets to query whether a controller instance has
  /// already been disposed by this notifier. This allows UI code to avoid
  /// attempting to mount widgets (like `VideoPlayer`) with controllers that
  /// are known to be disposed which would otherwise throw in debug builds.
  bool isControllerDisposed(VideoPlayerController? c) {
    return c != null && _disposedControllers.contains(c);
  }

  /// Public helper to query whether a controller instance is currently
  /// scheduled for disposal. Widgets can use this to avoid mounting a
  /// `VideoPlayer` for a controller that's about to be torn down.
  bool isControllerScheduledForDisposal(VideoPlayerController? c) {
    return c != null && _scheduledControllerDisposals.contains(c);
  }

  /// Video player listener for real-time updates
  void _videoPlayerListener() {
    // If controller has been marked inactive (cleanup in progress), skip handling
    if (!_isControllerActive) return;

    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) return;

    // Guard: don't update if controller is disposed
    try {
      state = state.copyWith(
        isPlaying: controller.value.isPlaying,
        isBuffering: controller.value.isBuffering,
        isCompleted: controller.value.position >= controller.value.duration,
        volume: controller.value.volume,
      );

      // Auto-repeat if enabled and video completed
      if (state.isCompleted && state.repeatMode) {
        seekTo(Duration.zero);
        play();
      }
    } catch (e) {
      // Controller was disposed while listener was running - ignore
    }
  }

  /// Start timer to update position regularly
  void _startPositionUpdateTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) {
      final controller = state.controller;
      // Guard: check controller is active, exists and is initialized before accessing
      if (_isControllerActive &&
          controller != null &&
          controller.value.isInitialized) {
        try {
          state = state.copyWith(position: controller.value.position);
        } catch (e) {
          // Controller was disposed while timer was running - cancel timer
          _positionUpdateTimer?.cancel();
          _positionUpdateTimer = null;
        }
      }
    });
  }

  /// Play video
  Future<void> play() async {
    final controller = state.controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_isControllerActive)
      return;

    try {
      await controller.play();
      state = state.copyWith(isPlaying: true);
      _resetControlsTimer();
    } catch (e) {
      // Controller was disposed during play - ignore
    }
  }

  /// Pause video
  Future<void> pause() async {
    final controller = state.controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_isControllerActive)
      return;

    try {
      await controller.pause();
      state = state.copyWith(isPlaying: false);
      _cancelControlsTimer();
      showControls();
    } catch (e) {
      // Controller was disposed during pause - ignore
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seek to specific position
  Future<void> seekTo(Duration position) async {
    final controller = state.controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_isControllerActive)
      return;

    try {
      await controller.seekTo(position);
      state = state.copyWith(position: position, isCompleted: false);
    } catch (e) {
      // Controller was disposed during seek - ignore
    }
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) return;

    await controller.setVolume(volume.clamp(0.0, 1.0));
    state = state.copyWith(volume: volume.clamp(0.0, 1.0));
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state.isMuted) {
      await controller.setVolume(state.volume);
      state = state.copyWith(isMuted: false);
    } else {
      await controller.setVolume(0.0);
      state = state.copyWith(isMuted: true);
    }
  }

  /// Toggle repeat mode
  void toggleRepeat() {
    state = state.copyWith(repeatMode: !state.repeatMode);
  }

  /// Play next video in playlist
  Future<void> playNext() async {
    if (!state.hasNext || state.playlist == null) return;

    final nextIndex = state.currentIndex! + 1;

    // You'll need to implement this based on your video data structure
    // For now, we'll just update the index
    state = state.copyWith(currentIndex: nextIndex);
  }

  /// Play previous video in playlist
  Future<void> playPrevious() async {
    if (!state.hasPrevious) return;

    final previousIndex = state.currentIndex! - 1;

    // You'll need to implement this based on your video data structure
    // For now, we'll just update the index
    state = state.copyWith(currentIndex: previousIndex);
  }

  /// Toggle fullscreen mode
  void toggleFullScreen() {
    state = state.copyWith(isFullScreen: !state.isFullScreen);
  }

  /// Enter fullscreen
  void enterFullScreen() {
    state = state.copyWith(isFullScreen: true);
  }

  /// Exit fullscreen
  void exitFullScreen() {
    state = state.copyWith(isFullScreen: false);
  }

  /// Show controls
  void showControls() {
    state = state.copyWith(showControls: true);
    if (state.isPlaying) {
      _resetControlsTimer();
    }
  }

  /// Hide controls
  void hideControls() {
    state = state.copyWith(showControls: false);
  }

  /// Toggle controls visibility
  void toggleControls() {
    if (state.showControls) {
      hideControls();
    } else {
      showControls();
    }
  }

  /// Reset controls hide timer
  void _resetControlsTimer() {
    _cancelControlsTimer();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (state.isPlaying) {
        hideControls();
      }
    });
  }

  /// Cancel controls hide timer
  void _cancelControlsTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  /// Minimize video player to mini player
  void minimizeToMiniPlayer() {
    debugPrint('[VideoPlayer] Minimizing to mini player');
    debugPrint(
      '[VideoPlayer] Before - isMinimized: ${state.isMinimized}, showMiniPlayer: ${state.showMiniPlayer}',
    );
    state = state.copyWith(
      isMinimized: true,
      showMiniPlayer: true,
      isFullScreen: false,
    );
    debugPrint(
      '[VideoPlayer] After - isMinimized: ${state.isMinimized}, showMiniPlayer: ${state.showMiniPlayer}',
    );
    // Keep video playing during transition
  }

  /// Expand mini player to full screen
  void expandToFullScreen() {
    debugPrint('[VideoPlayer] Expanding to full screen');
    state = state.copyWith(
      isMinimized: false,
      // Keep showMiniPlayer true temporarily so transition is smooth
      // It will be cleared when full player is shown via clearMiniPlayerFlag()
    );
  }

  /// Clear mini player flag (called when full player is fully shown)
  void clearMiniPlayerFlag() {
    debugPrint('[VideoPlayer] Clearing mini player flag');
    state = state.copyWith(showMiniPlayer: false);
  }

  /// Close mini player and stop video
  Future<void> closeMiniPlayer() async {
    debugPrint('[VideoPlayer] Closing mini player');
    state = state.copyWith(showMiniPlayer: false, isMinimized: false);

    // Stop video after a brief delay to allow animation to complete
    await Future.delayed(const Duration(milliseconds: 300));
    await disposeVideo();
  }

  /// Force stop video playback immediately (used when another media source takes over)
  Future<void> forceStopForExternalMediaSwitch() async {
    final hasActiveVideo =
        state.controller != null || state.currentVideoId != null;
    if (!hasActiveVideo && !state.showMiniPlayer && !state.isMinimized) {
      return;
    }

    debugPrint('[VideoPlayer] Force stopping due to external media switch');
    state = state.copyWith(
      showMiniPlayer: false,
      isMinimized: false,
      isFullScreen: false,
    );

    // Perform an aggressive disposal to ensure no lingering resources remain.
    await disposeVideo();
  }

  /// Dispose video player
  Future<void> disposeVideo() async {
    if (_disposeCompleter != null) {
      debugPrint('[VideoPlayer] disposeVideo: join in-flight dispose');
      return _disposeCompleter!.future;
    }

    final completer = Completer<void>();
    _disposeCompleter = completer;

    try {
      // Mark controller inactive and cancel any timers first.
      _isControllerActive = false;
      _positionUpdateTimer?.cancel();
      _positionUpdateTimer = null;
      _controlsHideTimer?.cancel();
      _controlsHideTimer = null;

      // Capture current controller instance so we can dispose it safely after
      // clearing state to avoid widgets referencing a disposed controller.
      final VideoPlayerController? current = state.controller;

      // Clear provider-held state synchronously so UI no longer sees any video data.
      // Include playlist/currentIndex to ensure all video metadata is cleared.
      state = state.copyWith(
        controller: null,
        currentVideoId: null,
        currentVideoTitle: null,
        currentVideoSubtitle: null,
        thumbnailUrl: null,
        channelId: null,
        channelAvatarUrl: null,
        isPlaying: false,
        isBuffering: false,
        isCompleted: false,
        position: Duration.zero,
        duration: Duration.zero,
        volume: 1.0,
        isMuted: false,
        isLoading: false,
        errorMessage: null,
        showMiniPlayer: false,
        isMinimized: false,
        isFullScreen: false,
        showControls: true,
        repeatMode: false,
        playlist: null,
        currentIndex: null,
      );

      // If there is an existing controller instance, remove its listeners and
      // synchronously attempt to pause and dispose it so native resources are
      // released immediately instead of waiting for scheduled tasks.
      if (current != null) {
        try {
          current.removeListener(_videoPlayerListener);
        } catch (_) {}
        try {
          if (current.value.isInitialized && current.value.isPlaying) {
            await current.pause();
          }
        } catch (_) {}
        try {
          await current.dispose();
          _disposedControllers.add(current);
          debugPrint(
            '[VideoPlayer] disposeVideo: disposed controller immediately',
          );
        } catch (e) {
          debugPrint(
            '[VideoPlayer] disposeVideo: error disposing controller: $e',
          );
        }
      }

      // Reset init counter to avoid ignoring future initialize requests that
      // might otherwise be considered stale.
      _initRequestCounter = 0;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _disposeCompleter = null;
    }
  }
}

/// Provider for video player state
final videoPlayerProvider =
    NotifierProvider<VideoPlayerStateNotifier, VideoPlayerState>(
      VideoPlayerStateNotifier.new,
    );
