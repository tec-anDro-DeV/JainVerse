import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

/// Performance Debouncer for reducing excessive updates and rebuilds
class PerformanceDebouncer {
  static final Map<String, Timer> _timers = {};
  static final Map<String, DateTime> _lastExecutions = {};

  // Navigation guards to prevent duplicate navigation
  static final Set<String> _activeNavigations = {};
  static const Duration _navigationCooldown = Duration(milliseconds: 1000);

  /// Debounce queue updates to prevent excessive notifications
  static void debounceQueueUpdate(
    String key,
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 150),
  }) {
    _timers[key]?.cancel();
    _timers[key] = Timer(delay, () {
      _lastExecutions[key] = DateTime.now();
      callback();
    });
  }

  /// Throttle state updates to limit frequency
  static void throttleStateUpdate(
    String key,
    VoidCallback callback, {
    Duration minimumInterval = const Duration(milliseconds: 100),
  }) {
    final lastExecution = _lastExecutions[key];
    final now = DateTime.now();

    if (lastExecution == null ||
        now.difference(lastExecution) >= minimumInterval) {
      _lastExecutions[key] = now;
      callback();
    }
  }

  /// Debounce UI rebuilds to prevent excessive setState calls
  static void debounceUIUpdate(
    String key,
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 50),
  }) {
    _timers[key]?.cancel();
    _timers[key] = Timer(delay, callback);
  }

  /// Cancel all pending operations for cleanup
  static void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _lastExecutions.clear();
  }

  /// Cancel specific debouncer
  static void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _lastExecutions.remove(key);
  }

  /// Check if an operation is pending
  static bool isPending(String key) {
    return _timers[key]?.isActive ?? false;
  }

  /// Navigation Guard - Prevents duplicate navigation calls
  static Future<T?> safePush<T extends Object?>(
    BuildContext context,
    Route<T> route, {
    String? navigationKey,
  }) async {
    final key = navigationKey ?? route.settings.name ?? 'unnamed_route';

    // Check if this navigation is already in progress
    if (_activeNavigations.contains(key)) {
      developer.log(
        '[NavigationGuard] Blocked duplicate navigation to: $key',
        name: 'PerformanceDebouncer',
      );
      return null;
    }

    // Add to active navigations
    _activeNavigations.add(key);

    try {
      // Perform the navigation
      final result = await Navigator.of(context).push(route);

      // Wait for cooldown period before allowing next navigation
      Timer(_navigationCooldown, () {
        _activeNavigations.remove(key);
      });

      developer.log(
        '[NavigationGuard] Completed navigation to: $key',
        name: 'PerformanceDebouncer',
      );

      return result;
    } catch (e) {
      // Remove from active navigations on error
      _activeNavigations.remove(key);
      developer.log(
        '[NavigationGuard] Navigation error for $key: $e',
        name: 'PerformanceDebouncer',
        error: e,
      );
      rethrow;
    }
  }

  /// Check if navigation is safe to proceed
  static bool canNavigate(String navigationKey) {
    return !_activeNavigations.contains(navigationKey);
  }

  /// Clear all navigation locks (use with caution)
  static void clearNavigationLocks() {
    _activeNavigations.clear();
    developer.log(
      '[NavigationGuard] Cleared all navigation locks',
      name: 'PerformanceDebouncer',
    );
  }
}

/// Memory-efficient widget rebuilder with debouncing
class DebouncedNotifier extends ChangeNotifier {
  Timer? _debounceTimer;
  bool _disposed = false;

  void debouncedNotify({Duration delay = const Duration(milliseconds: 50)}) {
    if (_disposed) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}
