import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Access navigatorKey to obtain a BuildContext for ProviderScope.containerOf
import '../main.dart' show navigatorKey;
import '../managers/media_coordinator.dart';
import '../videoplayer/managers/video_player_state_provider.dart';

/// Global state manager for music player UI visibility
class MusicPlayerStateManager extends ChangeNotifier {
  static final MusicPlayerStateManager _instance =
      MusicPlayerStateManager._internal();
  factory MusicPlayerStateManager() => _instance;
  MusicPlayerStateManager._internal();

  bool _isFullPlayerVisible = false;
  bool _shouldHideNavigation = false;
  bool _shouldHideMiniPlayer = false;
  bool _isDisposed = false;

  // Track current page context for better state management
  String _currentPageContext = '';

  bool get isFullPlayerVisible => _isFullPlayerVisible;
  bool get shouldHideNavigation => _shouldHideNavigation;
  bool get shouldHideMiniPlayer => _shouldHideMiniPlayer;
  String get currentPageContext => _currentPageContext;

  /// Call this when the full music player UI is opened
  void showFullPlayer() {
    if (_isDisposed) return;

    print(
      '[DEBUG] MusicPlayerStateManager: Showing full player - hiding navigation',
    );
    _isFullPlayerVisible = true;
    _shouldHideNavigation = true;
    _shouldHideMiniPlayer = true;
    _currentPageContext = 'full_player';
    _safeNotifyListeners();
  }

  /// Call this when the full music player UI is closed
  void hideFullPlayer() {
    if (_isDisposed) return;

    print(
      '[DEBUG] MusicPlayerStateManager: Hiding full player - showing navigation',
    );
    _isFullPlayerVisible = false;
    _shouldHideNavigation = false;
    _shouldHideMiniPlayer = false;
    _currentPageContext = '';
    _safeNotifyListeners();
  }

  /// Hide mini player for specific pages (AccountPage, ProfileEdit, etc.)
  void hideMiniPlayerForPage(String pageContext) {
    if (_isDisposed) return;

    print(
      '[DEBUG] MusicPlayerStateManager: Hiding mini player and navigation for page: $pageContext',
    );
    _shouldHideMiniPlayer = true;
    _shouldHideNavigation = true; // Also hide bottom navigation
    _currentPageContext = pageContext;
    _safeNotifyListeners();
  }

  /// Show mini player when leaving specific pages
  void showMiniPlayerForPage(String pageContext) {
    if (_isDisposed) return;

    print(
      '[DEBUG] MusicPlayerStateManager: Showing mini player and navigation, leaving page: $pageContext',
    );
    // Only show if we're not in full player mode and not on another restricted page
    if (!_isFullPlayerVisible &&
        (_currentPageContext == pageContext || _currentPageContext.isEmpty)) {
      _shouldHideMiniPlayer = false;
      _shouldHideNavigation = false; // Also show bottom navigation
      _currentPageContext = '';
    }
    _safeNotifyListeners();
  }

  /// Show mini player only without hiding navigation - for when user starts playing from category/list views
  void showMiniPlayerOnly() {
    if (_isDisposed) return;

    print(
      '[DEBUG] MusicPlayerStateManager: Showing mini player only - keeping navigation visible',
    );
    _isFullPlayerVisible = false;
    _shouldHideNavigation = false; // Keep navigation visible
    _shouldHideMiniPlayer = false; // Show mini player
    _currentPageContext = 'mini_player_only';
    _safeNotifyListeners();
  }

  /// Show mini player when music starts playing from list/category views
  void showMiniPlayerForMusicStart() {
    if (_isDisposed) return;

    print(
      '[DEBUG] MusicPlayerStateManager: Showing mini player for music start - keeping navigation visible',
    );
    _isFullPlayerVisible = false;
    _shouldHideNavigation = false; // Keep navigation visible
    _shouldHideMiniPlayer = false; // Show mini player
    _currentPageContext = 'music_start';
    _safeNotifyListeners();

    // Also notify the app-level media coordinator so music becomes the active
    // media type and the video mini-player (if any) will be hidden.
    try {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        final container = ProviderScope.containerOf(ctx);
        container.read(mediaCoordinatorProvider.notifier).setMusicActive();
        try {
          final videoNotifier = container.read(videoPlayerProvider.notifier);
          unawaited(videoNotifier.forceStopForExternalMediaSwitch());
          print(
            '[DEBUG] MusicPlayerStateManager: Requested video mini player teardown',
          );
        } catch (e) {
          print(
            '[ERROR] MusicPlayerStateManager: Failed to stop video player during music start: $e',
          );
        }
        print(
          '[DEBUG] MusicPlayerStateManager: Notified media coordinator (music active)',
        );
      } else {
        print(
          '[DEBUG] MusicPlayerStateManager: navigatorKey.currentContext is null — cannot notify media coordinator',
        );
      }
    } catch (e) {
      print(
        '[ERROR] MusicPlayerStateManager: Failed to notify media coordinator: $e',
      );
    }
  }

  /// Toggle navigation visibility independently (for custom scenarios)
  void setNavigationVisibility(bool visible) {
    if (_isDisposed) return;

    _shouldHideNavigation = !visible;
    // Also control mini player visibility based on navigation visibility
    if (!visible) {
      _shouldHideMiniPlayer = true;
    } else if (!_isFullPlayerVisible) {
      _shouldHideMiniPlayer = false;
    }
    _safeNotifyListeners();
  }

  /// Force reset all visibility states (emergency reset)
  void forceResetState() {
    if (_isDisposed) return;

    print('[DEBUG] MusicPlayerStateManager: Force resetting all states');
    _isFullPlayerVisible = false;
    _shouldHideNavigation = false;
    _shouldHideMiniPlayer = false;
    _currentPageContext = '';
    _safeNotifyListeners();
  }

  /// Explicitly show navigation and mini player (for restoring UI after full player)
  void showNavigationAndMiniPlayer() {
    if (_isDisposed) return;
    print(
      '[DEBUG] MusicPlayerStateManager: Forcing navigation and mini player visible',
    );
    _isFullPlayerVisible = false;
    _shouldHideNavigation = false;
    _shouldHideMiniPlayer = false;
    _currentPageContext = '';
    _safeNotifyListeners();
  }

  /// Safely notify listeners to avoid widget tree lock exceptions
  void _safeNotifyListeners() {
    if (_isDisposed) return;

    // Log current state for debugging
    print(
      '[DEBUG] MusicPlayerStateManager: State changed - isFullPlayerVisible: $_isFullPlayerVisible, shouldHideNavigation: $_shouldHideNavigation, shouldHideMiniPlayer: $_shouldHideMiniPlayer',
    );

    // Use scheduleMicrotask to defer notification until after current frame
    scheduleMicrotask(() {
      if (!_isDisposed) {
        try {
          notifyListeners();
          print(
            '[DEBUG] MusicPlayerStateManager: Listeners notified successfully',
          );
        } catch (e) {
          print(
            '[ERROR] MusicPlayerStateManager: Error notifying listeners: $e',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
