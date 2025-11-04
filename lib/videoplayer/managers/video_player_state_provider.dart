import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../models/video_player_state.dart';

/// State notifier for managing video player state
class VideoPlayerStateNotifier extends Notifier<VideoPlayerState> {
  Timer? _positionUpdateTimer;
  Timer? _controlsHideTimer;

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
        playlist: playlist,
        currentIndex: playlistIndex,
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
    final VideoPlayerController toDispose = controller;
    debugPrint(
      '[VideoPlayer] _scheduleDisposeController: scheduled at ${DateTime.now().toIso8601String()} to run in 350ms',
    );
    Future.delayed(const Duration(milliseconds: 350), () async {
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
        if (toDispose.value.isInitialized && toDispose.value.isPlaying) {
          await toDispose.pause();
        }
        await toDispose.dispose();
        debugPrint(
          '[VideoPlayer] _scheduleDisposeController: disposed controller at ${DateTime.now().toIso8601String()}',
        );
      } catch (e) {
        debugPrint('[VideoPlayer] scheduled dispose error: $e');
      }
    });
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

  /// Dispose video player
  Future<void> disposeVideo() async {
    await _cleanupExistingController();

    // Only clear the essential fields instead of resetting to a completely new state
    // This avoids the "modifying provider during build" error
    state = state.copyWith(
      controller: null,
      currentVideoId: null,
      currentVideoTitle: null,
      currentVideoSubtitle: null,
      isPlaying: false,
      isBuffering: false,
      isLoading: false,
      errorMessage: null,
    );
  }
}

/// Provider for video player state
final videoPlayerProvider =
    NotifierProvider<VideoPlayerStateNotifier, VideoPlayerState>(
      VideoPlayerStateNotifier.new,
    );
