import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Manages video player memory to prevent leaks and crashes
class VideoMemoryManager {
  static final VideoMemoryManager _instance = VideoMemoryManager._internal();
  factory VideoMemoryManager() => _instance;
  VideoMemoryManager._internal();

  final Map<String, VideoPlayerController> _activeControllers = {};
  final Map<String, DateTime> _controllerTimestamps = {};
  static const int maxControllers = 3;
  static const Duration controllerTimeout = Duration(minutes: 5);

  Timer? _cleanupTimer;

  /// Initialize the memory manager
  void initialize() {
    // Run cleanup every minute
    _cleanupTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _cleanupOldControllers();
    });

    if (kDebugMode) {
      debugPrint('[VideoMemoryManager] Initialized');
    }
  }

  /// Register a controller
  void registerController(String id, VideoPlayerController controller) {
    // Cleanup if we have too many controllers
    if (_activeControllers.length >= maxControllers) {
      _cleanupOldestController();
    }

    _activeControllers[id] = controller;
    _controllerTimestamps[id] = DateTime.now();

    if (kDebugMode) {
      debugPrint(
        '[VideoMemoryManager] Registered controller: $id (Total: ${_activeControllers.length})',
      );
    }
  }

  /// Unregister and dispose a controller
  Future<void> unregisterController(String id) async {
    final controller = _activeControllers.remove(id);
    _controllerTimestamps.remove(id);

    if (controller != null) {
      try {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          await controller.pause();
        }
        await controller.dispose();

        if (kDebugMode) {
          debugPrint(
            '[VideoMemoryManager] Unregistered controller: $id (Remaining: ${_activeControllers.length})',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[VideoMemoryManager] Error disposing controller $id: $e');
        }
      }
    }
  }

  /// Cleanup controllers older than timeout
  void _cleanupOldControllers() {
    final now = DateTime.now();
    final toRemove = <String>[];

    _controllerTimestamps.forEach((id, timestamp) {
      if (now.difference(timestamp) > controllerTimeout) {
        toRemove.add(id);
      }
    });

    for (final id in toRemove) {
      unregisterController(id);
    }

    if (toRemove.isNotEmpty && kDebugMode) {
      debugPrint(
        '[VideoMemoryManager] Cleaned up ${toRemove.length} old controllers',
      );
    }
  }

  /// Cleanup the oldest controller
  void _cleanupOldestController() {
    if (_controllerTimestamps.isEmpty) return;

    String? oldestId;
    DateTime? oldestTime;

    _controllerTimestamps.forEach((id, timestamp) {
      if (oldestTime == null || timestamp.isBefore(oldestTime!)) {
        oldestTime = timestamp;
        oldestId = id;
      }
    });

    if (oldestId != null) {
      unregisterController(oldestId!);
    }
  }

  /// Pause all active controllers
  Future<void> pauseAll() async {
    for (final controller in _activeControllers.values) {
      try {
        if (controller.value.isInitialized && controller.value.isPlaying) {
          await controller.pause();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[VideoMemoryManager] Error pausing controller: $e');
        }
      }
    }
  }

  /// Dispose all controllers
  Future<void> disposeAll() async {
    final ids = _activeControllers.keys.toList();
    for (final id in ids) {
      await unregisterController(id);
    }

    if (kDebugMode) {
      debugPrint('[VideoMemoryManager] Disposed all controllers');
    }
  }

  /// Get current controller count
  int get activeCount => _activeControllers.length;

  /// Dispose the manager
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    disposeAll();
  }
}
