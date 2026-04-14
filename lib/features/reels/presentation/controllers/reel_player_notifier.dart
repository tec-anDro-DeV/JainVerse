import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:jainverse/features/reels/data/models/reel_item.dart';
import 'package:jainverse/features/reels/presentation/state/reel_player_state.dart';

/// Manages a 2-controller window (current + next) of active [VideoPlayerController]s.
///
/// Keeping only 2 controllers alive prevents exhausting Android's ImageReader
/// buffer slots, which causes the "Unable to acquire a buffer item" spam when 3+
/// video decoders compete for the same hardware buffers.
class ReelPlayerNotifier extends Notifier<ReelPlayerState> {
  /// Live controllers keyed by feed index.
  final Map<int, VideoPlayerController> _pool = {};

  /// Guards against double-dispose crashes.
  final Set<VideoPlayerController> _disposed =
      LinkedHashSet<VideoPlayerController>.identity();

  /// URL cache: index → video URL (populated from the feed list).
  final Map<int, String> _urlCache = {};

  /// Indices currently being initialized (fire-and-forget guard).
  ///
  /// Prevents two concurrent [_initController] calls for the same index from
  /// racing each other and creating duplicate controllers that both allocate
  /// ImageReader surface buffers.
  final Set<int> _initializingIndices = {};

  /// The set of indices currently wanted by the active window.
  ///
  /// Updated in [onPageChanged] before any inits are fired. Each
  /// [_initController] checks this after every await point so that inits
  /// triggered by a stale page change self-cancel quickly instead of
  /// completing and then being immediately disposed.
  Set<int> _activeWindow = {};

  /// The feed index that should play as soon as its controller finishes
  /// initialising. Set by [_requestPlay]; cleared once playback starts or
  /// when [releaseAll] resets the pool.
  int? _pendingPlayIndex;

  @override
  ReelPlayerState build() {
    ref.onDispose(_disposeAll);
    return const ReelPlayerState();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Called by [ReelFeedNotifier.setCurrentIndex] on every page change.
  Future<void> onPageChanged(int activeIndex, List<ReelItem> reels) async {
    // Only cache URLs for the active window — avoids O(n) rebuild as the
    // feed grows with pagination.
    final keepIndices = <int>{
      activeIndex,
      activeIndex + 1,
    }..removeWhere((i) => i < 0 || i >= reels.length);

    // Update the active window BEFORE firing any inits so that in-flight
    // _initController calls for stale indices can self-cancel at their next
    // await point.
    _activeWindow = keepIndices;

    for (final i in keepIndices) {
      _urlCache[i] = reels[i].videoUrl;
    }

    // Dispose controllers outside the window in a batch, emitting state once
    // instead of once-per-controller to avoid redundant widget rebuilds.
    final toRemove =
        _pool.keys.where((i) => !keepIndices.contains(i)).toList();
    if (toRemove.isNotEmpty) {
      for (final i in toRemove) {
        final c = _pool.remove(i);
        if (c != null) await _safeDispose(c);
      }
      state = state.copyWith(
        controllers: Map.from(_pool),
        initializedIndices: Set.of(state.initializedIndices)
            .difference(toRemove.toSet()),
        bufferingIndices: Set.of(state.bufferingIndices)
            .difference(toRemove.toSet()),
      );
    }

    // Initialize missing controllers within the window.
    for (final i in keepIndices) {
      if (!_pool.containsKey(i) && _urlCache.containsKey(i)) {
        _initController(i, _urlCache[i]!); // fire-and-forget
      }
    }

    // Play the active index once its controller is ready.
    _requestPlay(activeIndex);

    // Prime the cache for the next URL (index + 1).
    final nextIndex = activeIndex + 1;
    if (_urlCache.containsKey(nextIndex)) {
      _primeCache(_urlCache[nextIndex]!);
    }
  }

  void toggleMute() {
    final muted = !state.isMuted;
    for (final c in _pool.values) {
      c.setVolume(muted ? 0.0 : 1.0);
    }
    state = state.copyWith(isMuted: muted);
  }

  /// Pauses every controller in the pool without disposing them.
  ///
  /// Call this before pushing a route that will create its own
  /// [VideoPlayerController] (e.g. the upload-preview screen) so that the
  /// total number of concurrent hardware video decoders stays within the
  /// Android ImageReader buffer limit.
  Future<void> pauseAll() async {
    for (final c in _pool.values) {
      if (!_disposed.contains(c) && c.value.isInitialized) {
        await c.pause();
      }
    }
  }

  /// Resumes the controller at [index] if it is still initialized.
  ///
  /// Call this when returning to the reels screen to continue playback without
  /// needing to re-initialize.
  Future<void> resumeAt(int index) async {
    final c = _pool[index];
    if (c != null && !_disposed.contains(c) && c.value.isInitialized) {
      await c.play();
    }
  }

  /// Disposes all controllers and fully resets state, freeing every Android
  /// ImageReader buffer slot held by this pool.
  ///
  /// The [isMuted] preference is preserved so the user's setting survives
  /// tab switches. Call this when leaving the Reels tab; the next
  /// [onPageChanged] call will re-create controllers from scratch, starting
  /// each video at position 0.
  void releaseAll() {
    // Clear window tracking so any in-flight _initController calls
    // self-cancel at their next await point.
    _pendingPlayIndex = null;
    _activeWindow = {};
    _initializingIndices.clear();
    _urlCache.clear();
    // _disposeAll pauses + disposes every controller (fire-and-forget on the
    // async disposal itself) and clears _pool synchronously.
    _disposeAll();
    state = state.copyWith(
      controllers: const {},
      bufferingIndices: const {},
      initializedIndices: const {},
    );
  }

  // ---------------------------------------------------------------------------
  // Controller lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _initController(int index, String url) async {
    // Guard 1: prevent two concurrent inits for the same index from racing
    // each other and creating duplicate controllers that both allocate
    // ImageReader surface buffers.
    if (_initializingIndices.contains(index)) return;
    _initializingIndices.add(index);

    try {
      // Check the cache manager for a locally stored file first.
      VideoPlayerController controller;
      try {
        final fileInfo = await DefaultCacheManager().getFileFromCache(url);
        if (fileInfo != null) {
          controller = VideoPlayerController.file(fileInfo.file);
        } else {
          controller = VideoPlayerController.networkUrl(Uri.parse(url));
        }
      } catch (_) {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      // Guard 2: the window moved while we were awaiting the cache check, or
      // another call already added a controller for this index — bail out.
      if (!_activeWindow.contains(index) || _pool.containsKey(index)) {
        _safeDispose(controller);
        return;
      }

      _pool[index] = controller;
      _emitState(bufferingAdd: index);

      controller.addListener(() => _onControllerUpdate(index, controller));

      try {
        await controller.initialize();
      } catch (e) {
        if (kDebugMode) debugPrint('ReelPlayerNotifier: init error at $index: $e');
        await _disposeAt(index);
        return;
      }

      // Guard 3: the controller was displaced by a dispose call while
      // initialize() was running (e.g. the user scrolled far away).
      if (_pool[index] != controller) {
        _safeDispose(controller);
        return;
      }

      // Guard 4: the active window moved while initialize() was running.
      if (!_activeWindow.contains(index)) {
        await _disposeAt(index);
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(state.isMuted ? 0.0 : 1.0);

      _emitState(bufferingRemove: index, initializedAdd: index);

      // If this index was requested for playback, start it now. This is the
      // deferred path: _requestPlay was called before initialization completed.
      if (_pendingPlayIndex == index && !_disposed.contains(controller)) {
        _pendingPlayIndex = null;
        await controller.play();
      }
    } finally {
      _initializingIndices.remove(index);
    }
  }

  /// Plays the controller at [index] immediately if it is already initialized,
  /// or defers playback until [_initController] completes for that index.
  ///
  /// Replaces the old polling loop, which had a hard 2-second cap that network
  /// videos routinely exceeded, leaving the feed stuck in a non-playing state.
  void _requestPlay(int index) {
    final c = _pool[index];
    if (c != null && !_disposed.contains(c) && c.value.isInitialized) {
      c.play();
      return;
    }
    // Controller not ready yet — _initController will call play() when done.
    _pendingPlayIndex = index;
  }

  void _onControllerUpdate(int index, VideoPlayerController controller) {
    if (!controller.value.isInitialized) return;
    final buffering = controller.value.isBuffering;
    final currentlyBuffering = state.bufferingIndices.contains(index);
    if (buffering == currentlyBuffering) return;
    _emitState(
      bufferingAdd: buffering ? index : null,
      bufferingRemove: buffering ? null : index,
    );
  }

  Future<void> _disposeAt(int index) async {
    final c = _pool.remove(index);
    if (c != null) await _safeDispose(c);
    final newInit = Set.of(state.initializedIndices)..remove(index);
    final newBuf = Set.of(state.bufferingIndices)..remove(index);
    state = state.copyWith(
      controllers: Map.from(_pool),
      initializedIndices: newInit,
      bufferingIndices: newBuf,
    );
  }

  Future<void> _safeDispose(VideoPlayerController c) async {
    if (_disposed.contains(c)) return;
    _disposed.add(c);
    try {
      await c.pause();
      await c.dispose();
    } catch (_) {}
  }

  void _disposeAll() {
    for (final c in List.of(_pool.values)) {
      _safeDispose(c);
    }
    _pool.clear();
  }

  // ---------------------------------------------------------------------------
  // Cache warming
  // ---------------------------------------------------------------------------

  void _primeCache(String url) async {
    try {
      await DefaultCacheManager().getSingleFile(url);
    } catch (_) {
      // Cache warming is best-effort — ignore failures.
    }
  }

  // ---------------------------------------------------------------------------
  // State emission helpers
  // ---------------------------------------------------------------------------

  void _emitState({
    int? bufferingAdd,
    int? bufferingRemove,
    int? initializedAdd,
  }) {
    final buf = Set.of(state.bufferingIndices);
    if (bufferingAdd != null) buf.add(bufferingAdd);
    if (bufferingRemove != null) buf.remove(bufferingRemove);

    final init = Set.of(state.initializedIndices);
    if (initializedAdd != null) init.add(initializedAdd);

    state = state.copyWith(
      controllers: Map.from(_pool),
      bufferingIndices: buf,
      initializedIndices: init,
    );
  }
}
