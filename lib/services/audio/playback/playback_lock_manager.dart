import 'dart:async';

/// Prevents duplicate queue operations for the same audio id by memoizing the
/// in-flight Future and reusing it for subsequent callers. Automatically clears
/// stale entries so hung operations do not block future playback attempts.
class PlaybackLockManager {
  PlaybackLockManager({Duration ttl = const Duration(seconds: 8)}) : _ttl = ttl;

  final Duration _ttl;
  final Map<String, _InFlightOperation> _operations = {};

  Future<void> runLocked(String key, Future<void> Function() operation) {
    final existing = _operations[key];
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _operations[key] = _InFlightOperation(completer.future, DateTime.now());

    () async {
      try {
        await operation();
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        _operations.remove(key);
      }
    }();

    return completer.future;
  }

  void cleanupStaleLocks() {
    if (_operations.isEmpty) return;
    final threshold = DateTime.now().subtract(_ttl);
    final staleKeys = _operations.entries
        .where((entry) => entry.value.started.isBefore(threshold))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in staleKeys) {
      _operations.remove(key);
    }
  }

  void forceClear() {
    _operations.clear();
  }
}

class _InFlightOperation {
  _InFlightOperation(this.future, this.started);

  final Future<void> future;
  final DateTime started;
}
