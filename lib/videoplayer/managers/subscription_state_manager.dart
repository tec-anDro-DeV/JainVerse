import 'package:flutter/foundation.dart';

/// Singleton manager to track subscription state changes globally
/// This ensures subscription status stays synchronized across all screens
class SubscriptionStateManager {
  static final SubscriptionStateManager _instance =
      SubscriptionStateManager._internal();

  factory SubscriptionStateManager() => _instance;

  SubscriptionStateManager._internal();

  // Map of channelId -> isSubscribed
  final Map<int, bool> _subscriptionStates = {};

  // Listeners that get notified when any subscription changes
  final List<VoidCallback> _listeners = [];

  /// Get current subscription status for a channel
  bool? getSubscriptionState(int channelId) {
    return _subscriptionStates[channelId];
  }

  /// Update subscription state for a channel
  void updateSubscriptionState(int channelId, bool isSubscribed) {
    final previousState = _subscriptionStates[channelId];
    _subscriptionStates[channelId] = isSubscribed;

    // Only notify if state actually changed
    if (previousState != isSubscribed) {
      if (kDebugMode) {
        print(
          'SubscriptionStateManager: Channel $channelId subscription changed to $isSubscribed',
        );
      }
      _notifyListeners();
    }
  }

  /// Remove subscription state for a channel (useful for cleanup)
  void removeSubscriptionState(int channelId) {
    _subscriptionStates.remove(channelId);
  }

  /// Clear all subscription states (useful for logout)
  void clearAll() {
    _subscriptionStates.clear();
    _notifyListeners();
  }

  /// Add a listener that will be called when any subscription changes
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
          print('SubscriptionStateManager: Error notifying listener: $e');
        }
      }
    }
  }

  /// Batch update multiple channels at once (useful when loading video lists)
  void batchUpdate(Map<int, bool> updates) {
    bool hasChanges = false;

    for (final entry in updates.entries) {
      final previousState = _subscriptionStates[entry.key];
      if (previousState != entry.value) {
        _subscriptionStates[entry.key] = entry.value;
        hasChanges = true;
      }
    }

    if (hasChanges) {
      if (kDebugMode) {
        print(
          'SubscriptionStateManager: Batch updated ${updates.length} channels',
        );
      }
      _notifyListeners();
    }
  }

  /// Get all current subscription states (for debugging)
  Map<int, bool> getAllStates() {
    return Map.from(_subscriptionStates);
  }

  /// Check if we have state for a channel
  bool hasState(int channelId) {
    return _subscriptionStates.containsKey(channelId);
  }
}
