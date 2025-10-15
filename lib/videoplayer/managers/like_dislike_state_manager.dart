import 'package:flutter/foundation.dart';

/// Singleton manager to track like/dislike state changes globally
/// This ensures like/dislike status stays synchronized across all screens
/// Values: 0 = neutral, 1 = liked, 2 = disliked
class LikeDislikeStateManager {
  static final LikeDislikeStateManager _instance =
      LikeDislikeStateManager._internal();

  factory LikeDislikeStateManager() => _instance;

  LikeDislikeStateManager._internal();

  // Map of videoId -> likeState (0=neutral, 1=liked, 2=disliked)
  final Map<int, int> _likeStates = {};

  // Listeners that get notified when any like state changes
  final List<VoidCallback> _listeners = [];

  /// Get current like state for a video
  int? getLikeState(int videoId) {
    return _likeStates[videoId];
  }

  /// Update like state for a video
  void updateLikeState(int videoId, int likeState) {
    assert(
      likeState == 0 || likeState == 1 || likeState == 2,
      'likeState must be 0, 1, or 2',
    );

    final previousState = _likeStates[videoId];
    _likeStates[videoId] = likeState;

    // Only notify if state actually changed
    if (previousState != likeState) {
      if (kDebugMode) {
        print(
          'LikeDislikeStateManager: Video $videoId like state changed to $likeState',
        );
      }
      _notifyListeners();
    }
  }

  /// Remove like state for a video (useful for cleanup)
  void removeLikeState(int videoId) {
    _likeStates.remove(videoId);
  }

  /// Clear all like states (useful for logout)
  void clearAll() {
    _likeStates.clear();
    _notifyListeners();
  }

  /// Add a listener that will be called when any like state changes
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Remove a listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of changes
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        if (kDebugMode) {
          print('LikeDislikeStateManager: Error notifying listener: $e');
        }
      }
    }
  }

  /// Batch update multiple videos at once (useful when loading video lists)
  void batchUpdate(Map<int, int> updates) {
    bool hasChanges = false;

    for (final entry in updates.entries) {
      final previousState = _likeStates[entry.key];
      if (previousState != entry.value) {
        _likeStates[entry.key] = entry.value;
        hasChanges = true;
      }
    }

    if (hasChanges) {
      if (kDebugMode) {
        print(
          'LikeDislikeStateManager: Batch updated ${updates.length} videos',
        );
      }
      _notifyListeners();
    }
  }

  /// Get all current like states (for debugging)
  Map<int, int> getAllStates() {
    return Map.from(_likeStates);
  }

  /// Check if we have state for a video
  bool hasState(int videoId) {
    return _likeStates.containsKey(videoId);
  }
}
