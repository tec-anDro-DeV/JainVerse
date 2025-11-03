import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Helper class to prevent crashes from video players, images, and state management
class CrashPreventionHelper {
  /// Safely dispose a video controller
  static Future<void> safeDisposeVideoController(
    VideoPlayerController? controller,
  ) async {
    if (controller == null) return;

    try {
      // Try to pause first
      if (controller.value.isInitialized && controller.value.isPlaying) {
        await controller.pause().timeout(
          Duration(seconds: 2),
          onTimeout: () {
            debugPrint('[CrashPrevention] Pause timeout');
          },
        );
      }
    } catch (e) {
      debugPrint('[CrashPrevention] Error pausing controller: $e');
    }

    try {
      // Dispose the controller
      await controller.dispose().timeout(
        Duration(seconds: 3),
        onTimeout: () {
          debugPrint('[CrashPrevention] Dispose timeout');
        },
      );
    } catch (e) {
      debugPrint('[CrashPrevention] Error disposing controller: $e');
    }
  }

  /// Safely call setState with mounted check
  static void safeSetState(State state, VoidCallback fn) {
    if (!state.mounted) {
      debugPrint('[CrashPrevention] Prevented setState on unmounted widget');
      return;
    }

    try {
      // ignore: invalid_use_of_protected_member
      state.setState(fn);
    } catch (e) {
      debugPrint('[CrashPrevention] Error in setState: $e');
    }
  }

  /// Safely show snackbar
  static void safeShowSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
  }) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('[CrashPrevention] Error showing snackbar: $e');
    }
  }

  /// Clean up image cache to prevent OOM
  static void cleanupImageCache() {
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      final currentSize = imageCache.currentSizeBytes;
      final maxSize = imageCache.maximumSizeBytes;

      // Clear if using more than 80% of max cache
      if (currentSize > maxSize * 0.8) {
        imageCache.clear();
        imageCache.clearLiveImages();
        debugPrint('[CrashPrevention] Image cache cleared');
      }
    } catch (e) {
      debugPrint('[CrashPrevention] Error cleaning image cache: $e');
    }
  }

  /// Cancel and nullify timer safely
  static Timer? safelyCancelTimer(Timer? timer) {
    try {
      timer?.cancel();
    } catch (e) {
      debugPrint('[CrashPrevention] Error canceling timer: $e');
    }
    return null;
  }

  /// Safely remove listener
  static void safeRemoveListener(
    ChangeNotifier? notifier,
    VoidCallback? listener,
  ) {
    if (notifier == null || listener == null) return;

    try {
      notifier.removeListener(listener);
    } catch (e) {
      debugPrint('[CrashPrevention] Error removing listener: $e');
    }
  }

  /// Run async operation with timeout and error handling
  static Future<T?> safeAsync<T>(
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 10),
    T? defaultValue,
  }) async {
    try {
      return await operation().timeout(
        timeout,
        onTimeout: () {
          debugPrint('[CrashPrevention] Operation timed out');
          return defaultValue as T;
        },
      );
    } catch (e) {
      debugPrint('[CrashPrevention] Async operation error: $e');
      return defaultValue;
    }
  }

  /// Check if widget is mounted before async callback
  static Future<void> safeMountedAsync(
    State state,
    Future<void> Function() callback,
  ) async {
    if (!state.mounted) return;

    try {
      await callback();
    } catch (e) {
      debugPrint('[CrashPrevention] Mounted async error: $e');
    }
  }

  /// Initialize safe memory limits
  static void initializeMemoryLimits() {
    try {
      // Set image cache limits
      final imageCache = PaintingBinding.instance.imageCache;
      imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
      imageCache.maximumSize = 1000; // Max 1000 images

      debugPrint('[CrashPrevention] Memory limits initialized');
    } catch (e) {
      debugPrint('[CrashPrevention] Error setting memory limits: $e');
    }
  }
}

/// Extension for safe state management
extension SafeStateExtension on State {
  /// Safe setState wrapper
  void safeSetState(VoidCallback fn) {
    CrashPreventionHelper.safeSetState(this, fn);
  }

  /// Safe mounted async operation
  Future<void> safeMountedAsync(Future<void> Function() callback) {
    return CrashPreventionHelper.safeMountedAsync(this, callback);
  }
}
