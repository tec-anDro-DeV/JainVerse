import 'dart:async';

import 'package:flutter/material.dart';

import '../UI/PhoneNumberInputScreen.dart';
import '../UI/MainNavigation.dart';
import '../UI/OfflineDownloadScreen.dart';
import '../UI/onboarding.dart';
import 'offline_mode_service.dart';

/// Global app router manager for handling navigation based on connectivity and offline mode
class AppRouterManager {
  static final AppRouterManager _instance = AppRouterManager._internal();
  factory AppRouterManager() => _instance;
  AppRouterManager._internal();

  final OfflineModeService _offlineModeService = OfflineModeService();
  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<bool>? _offlineModeSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  bool _isInitialized = false;
  String? _currentRoute;

  /// Initialize the router manager
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    debugPrint(
      '[AppRouterManager] initialize() called with navigatorKey: ${navigatorKey.hashCode}',
    );

    if (_isInitialized) {
      debugPrint('[AppRouterManager] Already initialized, skipping');
      return;
    }

    _navigatorKey = navigatorKey;
    debugPrint(
      '[AppRouterManager] Navigator key set: ${_navigatorKey.hashCode}',
    );

    // Listen to offline mode changes
    _offlineModeSubscription = _offlineModeService.offlineModeStream.listen(
      (isOffline) => _handleOfflineModeChange(isOffline),
    );

    // Listen to connectivity changes
    _connectivitySubscription = _offlineModeService.connectivityStream.listen(
      (hasConnectivity) => _handleConnectivityChange(hasConnectivity),
    );

    _isInitialized = true;
    debugPrint('[AppRouterManager] Initialized successfully');
  }

  /// Handle offline mode changes
  void _handleOfflineModeChange(bool isOffline) {
    debugPrint('[AppRouterManager] Offline mode changed: $isOffline');

    if (!_offlineModeService.isUserLoggedIn) {
      debugPrint(
        '[AppRouterManager] User not logged in, ignoring offline mode change',
      );
      return;
    }

    // Prevent navigation loops by checking current route
    if (isOffline && _currentRoute == '/offline') {
      debugPrint(
        '[AppRouterManager] Already on offline route, skipping navigation',
      );
      return;
    }

    if (!isOffline && _currentRoute != '/offline') {
      debugPrint(
        '[AppRouterManager] Already on online route, skipping navigation',
      );
      return;
    }

    // Navigate immediately without delays
    if (isOffline) {
      _navigateToOfflineMode();
    } else if (_offlineModeService.hasConnectivity) {
      _navigateToOnlineMode();
    } else {
      debugPrint(
        '[AppRouterManager] Cannot navigate to online mode - no connectivity',
      );
    }
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(bool hasConnectivity) {
    debugPrint('[AppRouterManager] Connectivity changed: $hasConnectivity');

    if (!_offlineModeService.isUserLoggedIn) {
      debugPrint(
        '[AppRouterManager] User not logged in, ignoring connectivity change',
      );
      return;
    }

    // Don't automatically navigate back to online when connectivity is restored
    // Let the user decide via the FAB button in offline mode
    // The offline mode service will handle showing the appropriate UI elements
    debugPrint(
      '[AppRouterManager] Connectivity changed, letting user choose when to switch modes',
    );
  }

  /// Navigate to offline mode (Download screen)
  void _navigateToOfflineMode() {
    if (_navigatorKey?.currentState == null) {
      debugPrint(
        '[AppRouterManager] ERROR: Navigator state is null in _navigateToOfflineMode',
      );
      return;
    }

    debugPrint('[AppRouterManager] Navigating to offline mode');

    // Save current route if not already offline
    if (_currentRoute != '/offline') {
      _offlineModeService.saveLastKnownRoute(_currentRoute ?? '/home');
    }

    _currentRoute = '/offline';

    // Navigate immediately without delays
    try {
      // Navigate to offline screen
      _navigatorKey!.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const OfflineDownloadScreen(),
          settings: const RouteSettings(name: '/offline'),
        ),
        (route) => false, // Remove all previous routes
      );
      debugPrint('[AppRouterManager] Successfully navigated to offline mode');
    } catch (e) {
      debugPrint('[AppRouterManager] Error navigating to offline mode: $e');
    }
  }

  /// Navigate to online mode
  void _navigateToOnlineMode() {
    debugPrint('[AppRouterManager] _navigateToOnlineMode() called');

    if (_navigatorKey?.currentState == null) {
      debugPrint(
        '[AppRouterManager] ERROR: Navigator state is null in _navigateToOnlineMode',
      );
      return;
    }

    debugPrint('[AppRouterManager] Navigating to online mode');

    // Determine where to navigate
    String targetRoute = '/home';
    int tabIndex = 0;

    // Try to restore last known route
    final lastRoute = _offlineModeService.lastKnownRoute;
    if (lastRoute != null && lastRoute != '/offline') {
      if (lastRoute.startsWith('/tab/')) {
        final parts = lastRoute.split('/');
        if (parts.length >= 3) {
          tabIndex = int.tryParse(parts[2]) ?? 0;
        }
      }
      targetRoute = lastRoute;
    }
    _currentRoute = targetRoute;
    debugPrint(
      '[AppRouterManager] Navigating to route: $targetRoute with tab index: $tabIndex',
    );

    // Navigate immediately without delays
    try {
      // Navigate to main app
      _navigatorKey!.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainNavigationWrapper(initialIndex: tabIndex),
          settings: RouteSettings(name: targetRoute),
        ),
        (route) => false, // Remove all previous routes
      );

      // Clear the saved route
      _offlineModeService.clearLastKnownRoute();
      debugPrint('[AppRouterManager] Navigation to online mode completed');
    } catch (e) {
      debugPrint('[AppRouterManager] Error navigating to online mode: $e');
    }
  }

  /// Navigate based on startup decision
  void navigateFromSplash() {
    debugPrint('[AppRouterManager] navigateFromSplash() called');
    debugPrint('[AppRouterManager] _isInitialized: $_isInitialized');
    debugPrint('[AppRouterManager] _navigatorKey: $_navigatorKey');
    debugPrint(
      '[AppRouterManager] _navigatorKey hashCode: ${_navigatorKey?.hashCode}',
    );

    // Check if navigator key is available
    if (_navigatorKey == null) {
      debugPrint('[AppRouterManager] ERROR: Navigator key is null');
      return;
    }

    // Wait a moment for the MaterialApp to finish building
    Future.delayed(const Duration(milliseconds: 100), () {
      _performNavigationFromSplash();
    });
  }

  void _performNavigationFromSplash() {
    if (_navigatorKey?.currentState == null) {
      debugPrint('[AppRouterManager] Navigator state not ready, retrying...');
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 200), () {
        _performNavigationFromSplash();
      });
      return;
    }

    final decision = _offlineModeService.getStartupNavigationDecision();
    debugPrint('[AppRouterManager] Startup navigation decision: $decision');

    // Always ensure we have the latest state
    final isUserLoggedIn = decision['isUserLoggedIn'] as bool;
    final isOfflineMode = decision['isOfflineMode'] as bool;
    final hasConnectivity = decision['hasConnectivity'] as bool;

    if (!isUserLoggedIn) {
      // Not logged in - go to onboarding/login
      debugPrint('[AppRouterManager] User not logged in - navigating to login');
      _navigateToLogin();
    } else if (isOfflineMode) {
      // User is deliberately in offline mode - honor their choice
      debugPrint(
        '[AppRouterManager] User is in offline mode - navigating to offline screen',
      );
      _navigateToOfflineMode();
    } else if (!hasConnectivity) {
      // User is logged in but no connectivity - show prompt and go to main app
      debugPrint(
        '[AppRouterManager] User logged in but no connectivity - going to main app (prompt will show)',
      );
      _navigateToOnlineMode();
    } else {
      // Logged in and online - go to main app
      debugPrint(
        '[AppRouterManager] User logged in and online - navigating to main app',
      );
      _navigateToOnlineMode();
    }
  }

  /// Navigate to login/onboarding
  void _navigateToLogin() {
    if (_navigatorKey?.currentState == null) {
      debugPrint(
        '[AppRouterManager] ERROR: Navigator state is null in _navigateToLogin',
      );
      return;
    }

    debugPrint('[AppRouterManager] Navigating to login/onboarding');
    _currentRoute = '/onboarding';

    _navigatorKey!.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => OnboardingScreen(
          onGetStarted: () {
            _navigatorKey!.currentState!.pushReplacement(
              MaterialPageRoute(
                builder: (context) => const PhoneNumberInputScreen(),
                settings: const RouteSettings(name: '/login'),
              ),
            );
          },
        ),
        settings: const RouteSettings(name: '/onboarding'),
      ),
      (route) => false,
    );
  }

  /// Update current route
  void updateCurrentRoute(String route) {
    _currentRoute = route;
  }

  /// Check if can navigate away from offline screen
  bool canNavigateFromOfflineScreen() {
    return _offlineModeService.hasConnectivity &&
        !_offlineModeService.isOfflineMode;
  }

  /// Manual navigation to offline mode
  void goToOfflineMode() {
    _offlineModeService.setOfflineMode(true);
  }

  /// Manual navigation to online mode
  void goToOnlineMode() {
    if (_offlineModeService.hasConnectivity) {
      _offlineModeService.setOfflineMode(false);
    } else {
      debugPrint('[AppRouterManager] Cannot go online - no connectivity');
    }
  }

  /// Dispose resources
  void dispose() {
    _offlineModeSubscription?.cancel();
    _connectivitySubscription?.cancel();
  }
}
