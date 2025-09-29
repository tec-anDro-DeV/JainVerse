import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/SharedPref.dart';

/// Global offline mode state management service
/// Handles connectivity monitoring and offline mode state across the entire app
class OfflineModeService with ChangeNotifier {
  static final OfflineModeService _instance = OfflineModeService._internal();
  factory OfflineModeService() => _instance;
  OfflineModeService._internal();

  final SharedPref _sharedPref = SharedPref();
  final Connectivity _connectivity = Connectivity();

  bool _isOfflineMode = false;
  bool _hasConnectivity = true;
  bool _isUserLoggedIn = false;
  String? _lastKnownRoute;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Current offline mode status
  bool get isOfflineMode => _isOfflineMode;

  /// Current connectivity status
  bool get hasConnectivity => _hasConnectivity;

  /// User login status
  bool get isUserLoggedIn => _isUserLoggedIn;

  /// Last known route before going offline
  String? get lastKnownRoute => _lastKnownRoute;

  /// Stream for listening to offline mode changes
  Stream<bool> get offlineModeStream => _offlineModeController.stream;
  final StreamController<bool> _offlineModeController =
      StreamController<bool>.broadcast();

  /// Stream for listening to connectivity changes
  Stream<bool> get connectivityStream => _connectivityController.stream;
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  /// Stream for listening to offline prompt requests
  Stream<bool> get offlinePromptStream => _offlinePromptController.stream;
  final StreamController<bool> _offlinePromptController =
      StreamController<bool>.broadcast();

  /// Stream for listening to connectivity restoration notifications
  Stream<bool> get connectivityRestoredStream =>
      _connectivityRestoredController.stream;
  final StreamController<bool> _connectivityRestoredController =
      StreamController<bool>.broadcast();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      debugPrint('[OfflineModeService] Initializing...');

      // Check user login status
      _isUserLoggedIn = await _sharedPref.check();

      // Check initial connectivity
      await _checkConnectivity();

      // Load saved offline mode preference
      await _loadOfflineModePreference();

      // Start listening to connectivity changes
      _startConnectivityMonitoring();

      debugPrint(
        '[OfflineModeService] Initialized - Offline: $_isOfflineMode, Connected: $_hasConnectivity, LoggedIn: $_isUserLoggedIn',
      );
    } catch (e) {
      debugPrint('[OfflineModeService] Initialization error: $e');
      // Default to safe state - don't auto-switch to offline mode
      _isOfflineMode = false; // Keep online mode as default
      _hasConnectivity = false; // But assume no connectivity
      // Trigger prompt if user is logged in and there's no connectivity
      if (_isUserLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _offlinePromptController.add(true);
        });
      }
    }
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final wasConnected = _hasConnectivity;
      _hasConnectivity = !results.contains(ConnectivityResult.none);

      debugPrint(
        '[OfflineModeService] Connectivity check: $_hasConnectivity (was: $wasConnected)',
      );

      if (wasConnected != _hasConnectivity) {
        _connectivityController.add(_hasConnectivity);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[OfflineModeService] Connectivity check error: $e');
      _hasConnectivity = false;
      _connectivityController.add(false);
      notifyListeners();
    }
  }

  /// Start monitoring connectivity changes
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
      onError: (error) {
        debugPrint('[OfflineModeService] Connectivity stream error: $error');
        _hasConnectivity = false;
        _connectivityController.add(false);
        notifyListeners();
      },
    );
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasConnected = _hasConnectivity;
    _hasConnectivity = !results.contains(ConnectivityResult.none);

    debugPrint(
      '[OfflineModeService] Connectivity changed: $results -> $_hasConnectivity',
    );

    if (wasConnected != _hasConnectivity) {
      if (!_hasConnectivity) {
        // Lost connectivity - just notify, don't auto-switch to offline
        debugPrint(
          '[OfflineModeService] Connectivity lost - showing offline prompt for user choice',
        );
        _connectivityController.add(_hasConnectivity);
        notifyListeners();
        // Only trigger prompt if user is logged in
        if (_isUserLoggedIn) {
          _offlinePromptController.add(true);
        }
      } else {
        // Connectivity restored - notify user but let them choose
        debugPrint(
          '[OfflineModeService] Connectivity restored - user can choose to go back online via FAB',
        );
        _connectivityController.add(_hasConnectivity);
        notifyListeners();
        // Hide offline prompt when back online
        _offlinePromptController.add(false);

        // If user is in offline mode and connectivity is restored,
        // show them a notification that they can go back online
        if (_isOfflineMode && _isUserLoggedIn) {
          debugPrint(
            '[OfflineModeService] User was in offline mode, staying offline until they choose to switch. FAB will be available.',
          );
          // Trigger connectivity restored notification
          _connectivityRestoredController.add(true);
        }
      }
    }
  }

  /// Load offline mode preference from storage
  Future<void> _loadOfflineModePreference() async {
    try {
      // For now, we'll implement basic storage
      // In a real app, you might use SharedPreferences or Hive

      // Don't automatically switch to offline mode based on connectivity
      // Let the user decide via the floating prompt
      _isOfflineMode = false; // Default to online mode

      // If no connectivity and user is logged in, trigger the prompt
      if (!_hasConnectivity && _isUserLoggedIn) {
        debugPrint(
          '[OfflineModeService] No connectivity detected - will show offline prompt',
        );
        // Trigger the prompt after initialization
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _offlinePromptController.add(true);
        });
      }
    } catch (e) {
      debugPrint('[OfflineModeService] Error loading offline preference: $e');
    }
  }

  /// Set offline mode
  Future<void> setOfflineMode(bool isOffline, {bool force = false}) async {
    await _setOfflineMode(isOffline, force: force);
  }

  /// Manually switch to offline mode (user-triggered)
  Future<void> switchToOfflineMode() async {
    debugPrint('[OfflineModeService] User manually switching to offline mode');
    await _setOfflineMode(true, force: true);
    // Hide the prompt since user has chosen
    _offlinePromptController.add(false);
  }

  /// User declined to switch to offline mode
  void declineOfflineMode() {
    debugPrint('[OfflineModeService] User declined offline mode');
    // Hide the prompt
    _offlinePromptController.add(false);
  }

  /// Manually switch back to online mode (user-triggered via FAB)
  Future<void> switchToOnlineMode() async {
    if (_hasConnectivity) {
      debugPrint('[OfflineModeService] User manually switching to online mode');
      await _setOfflineMode(false, force: true);
    } else {
      debugPrint(
        '[OfflineModeService] Cannot switch to online mode - no connectivity',
      );
      // Show a message that connectivity is still not available
      throw Exception('No internet connectivity available');
    }
  }

  /// Internal method to set offline mode
  Future<void> _setOfflineMode(bool isOffline, {bool force = false}) async {
    try {
      final wasOffline = _isOfflineMode;

      // Only force offline if explicitly requested with force flag
      // Don't auto-force based on connectivity
      _isOfflineMode = isOffline;

      if (wasOffline != _isOfflineMode) {
        debugPrint(
          '[OfflineModeService] Offline mode changed to: $_isOfflineMode ${force ? '(forced)' : ''}',
        );
        _offlineModeController.add(_isOfflineMode);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[OfflineModeService] Error setting offline mode: $e');
    }
  }

  /// Update user login status
  Future<void> setUserLoggedIn(bool loggedIn) async {
    if (_isUserLoggedIn != loggedIn) {
      _isUserLoggedIn = loggedIn;
      debugPrint(
        '[OfflineModeService] User login status changed: $_isUserLoggedIn',
      );

      // If user logged out, exit offline mode
      if (!loggedIn) {
        await _setOfflineMode(false);
        _offlinePromptController.add(false); // Hide prompt if shown
      }
      // If user logged in and no connectivity, show offline prompt instead of forcing
      else if (!_hasConnectivity) {
        _offlinePromptController.add(true);
      }

      notifyListeners();
    }
  }

  /// Save current route for restoration later
  void saveLastKnownRoute(String route) {
    _lastKnownRoute = route;
    debugPrint('[OfflineModeService] Saved last known route: $route');
  }

  /// Clear last known route
  void clearLastKnownRoute() {
    _lastKnownRoute = null;
  }

  /// Check if should redirect to offline mode
  bool shouldRedirectToOffline() {
    return _isUserLoggedIn && _isOfflineMode;
  }

  /// Check if should redirect to online mode
  bool shouldRedirectToOnline() {
    return _isUserLoggedIn && !_isOfflineMode && _hasConnectivity;
  }

  /// Get startup navigation decision
  Map<String, dynamic> getStartupNavigationDecision() {
    return {
      'isUserLoggedIn': _isUserLoggedIn,
      'hasConnectivity': _hasConnectivity,
      'isOfflineMode': _isOfflineMode,
      'shouldGoToOffline':
          _isUserLoggedIn && (!_hasConnectivity || _isOfflineMode),
      'shouldGoToOnline':
          _isUserLoggedIn && _hasConnectivity && !_isOfflineMode,
      'shouldGoToLogin': !_isUserLoggedIn,
      'lastKnownRoute': _lastKnownRoute,
    };
  }

  /// Force connectivity check
  Future<void> refreshConnectivity() async {
    await _checkConnectivity();
  }

  /// Simulate connectivity loss for testing (debug only)
  void simulateConnectivityLoss() {
    if (kDebugMode) {
      debugPrint('[OfflineModeService] Simulating connectivity loss');
      _hasConnectivity = false;
      _connectivityController.add(false);
      notifyListeners();
      // Trigger offline prompt
      _offlinePromptController.add(true);
    }
  }

  /// Manually trigger offline prompt for testing (debug only)
  void triggerOfflinePrompt() {
    if (kDebugMode) {
      debugPrint('[OfflineModeService] Manually triggering offline prompt');
      _offlinePromptController.add(true);
    }
  }

  /// Manually hide offline prompt for testing (debug only)
  void hideOfflinePrompt() {
    if (kDebugMode) {
      debugPrint('[OfflineModeService] Manually hiding offline prompt');
      _offlinePromptController.add(false);
    }
  }

  /// Simulate connectivity restoration for testing (debug only)
  void simulateConnectivityRestoration() {
    if (kDebugMode) {
      debugPrint('[OfflineModeService] Simulating connectivity restoration');
      _hasConnectivity = true;
      _connectivityController.add(true);
      notifyListeners();
      // Hide offline prompt
      _offlinePromptController.add(false);
      // If in offline mode, automatically go back online
      if (_isOfflineMode) {
        _setOfflineMode(false, force: true);
      }
    }
  }

  /// Debug method to force offline mode (only for testing)
  void forceOfflineMode(bool isOffline) {
    if (kDebugMode) {
      _isOfflineMode = isOffline;
      _hasConnectivity = !isOffline;
      _offlineModeController.add(_isOfflineMode);
      _connectivityController.add(_hasConnectivity);
      notifyListeners();
      debugPrint('[OfflineModeService] FORCED offline mode: $_isOfflineMode');
    }
  }

  /// Dispose service
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _offlineModeController.close();
    _connectivityController.close();
    _offlinePromptController.close();
    _connectivityRestoredController.close();
    super.dispose();
  }
}
