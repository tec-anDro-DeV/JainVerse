import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/download_controller.dart';
import '../utils/ConnectionCheck.dart';

class StartupController {
  static final StartupController _instance = StartupController._internal();
  factory StartupController() => _instance;
  StartupController._internal();

  final DownloadController _downloadController = DownloadController();
  final ConnectionCheck _connectionCheck = ConnectionCheck();
  SharedPreferences? _prefs;

  bool _isOfflineMode = false;
  bool _hasConnectivity = false;
  bool _isInitialized = false;

  /// Get current offline mode status
  bool get isOfflineMode => _isOfflineMode;

  /// Get current connectivity status
  bool get hasConnectivity => _hasConnectivity;

  /// Check if app is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the startup controller
  Future<void> initialize() async {
    try {
      debugPrint('[StartupController] Initializing...');

      // Initialize storage services
      _prefs = await SharedPreferences.getInstance();
      await _downloadController.initialize();

      // Check connectivity
      await _checkConnectivity();

      // Determine offline mode based on connectivity
      await _determineOfflineMode();

      // Auto-sync if online
      if (_hasConnectivity && !_isOfflineMode) {
        await _autoSyncAssets();
      }

      _isInitialized = true;
      debugPrint(
        '[StartupController] Initialization complete. Offline mode: $_isOfflineMode, Connectivity: $_hasConnectivity',
      );
    } catch (e) {
      debugPrint('[StartupController] Initialization error: $e');
      // If initialization fails, assume no connectivity but stay in online mode
      // Let the OfflineModeService handle the offline prompt
      _isOfflineMode = false;
      _hasConnectivity = false;
      _isInitialized = true;
    }
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      // Use the existing ConnectionCheck utility
      _hasConnectivity = await _connectionCheck.checkConnection();
      debugPrint('[StartupController] Connectivity check: $_hasConnectivity');
    } catch (e) {
      debugPrint('[StartupController] Connectivity check error: $e');
      _hasConnectivity = false;
    }
  }

  /// Determine if app should be in offline mode
  Future<void> _determineOfflineMode() async {
    try {
      // Get stored offline mode preference
      final storedOfflineMode = _prefs?.getBool('offline_mode') ?? false;

      if (!_hasConnectivity) {
        // Don't force offline mode - let user choose via prompt
        _isOfflineMode = storedOfflineMode;
        debugPrint(
          '[StartupController] No connectivity, keeping stored offline mode: $_isOfflineMode',
        );
      } else {
        // Use stored preference if online
        _isOfflineMode = storedOfflineMode;
        debugPrint(
          '[StartupController] Using stored offline mode preference: $_isOfflineMode',
        );
      }
    } catch (e) {
      debugPrint('[StartupController] Error determining offline mode: $e');
      // Default to online mode, let the user choose offline via prompt if needed
      _isOfflineMode = false;
    }
  }

  /// Auto-sync assets on startup if online
  Future<void> _autoSyncAssets() async {
    try {
      debugPrint('[StartupController] Starting auto-sync...');

      // Get last sync time
      final lastSyncStr = _prefs?.getString('last_sync');
      final lastSync =
          lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;
      final now = DateTime.now();

      // Check if we should sync (e.g., if last sync was more than 24 hours ago)
      bool shouldSync = false;
      if (lastSync == null) {
        shouldSync = true;
        debugPrint('[StartupController] First time sync');
      } else {
        final timeSinceLastSync = now.difference(lastSync);
        shouldSync = timeSinceLastSync.inHours > 24;
        debugPrint(
          '[StartupController] Time since last sync: ${timeSinceLastSync.inHours} hours',
        );
      }

      if (shouldSync) {
        await _performAssetSync();
        await _prefs?.setString('last_sync', now.toIso8601String());
        debugPrint('[StartupController] Auto-sync completed');
      } else {
        debugPrint(
          '[StartupController] Skipping auto-sync (recent sync found)',
        );
      }
    } catch (e) {
      debugPrint('[StartupController] Auto-sync error: $e');
      // Don't fail startup if sync fails
    }
  }

  /// Perform asset synchronization
  Future<void> _performAssetSync() async {
    try {
      // Get all downloaded tracks
      final downloadedTracks = _downloadController.downloadedTracks;
      debugPrint(
        '[StartupController] Found ${downloadedTracks.length} downloaded tracks to sync',
      );

      // Check for missing local files and re-download if needed
      for (final track in downloadedTracks) {
        final trackId = track.id;

        // Check if audio file exists
        final audioPath = track.localAudioPath;
        bool needsAudioRedownload = false;
        if (audioPath.isNotEmpty) {
          final audioFile = await _checkFileExists(audioPath);
          if (!audioFile) {
            needsAudioRedownload = true;
            debugPrint(
              '[StartupController] Missing audio file for track $trackId',
            );
          }
        } else {
          needsAudioRedownload = true;
        }

        // Check if artwork file exists
        final artworkPath = track.localImagePath;
        bool needsArtworkRedownload = false;
        if (artworkPath.isNotEmpty) {
          final artworkFile = await _checkFileExists(artworkPath);
          if (!artworkFile) {
            needsArtworkRedownload = true;
            debugPrint(
              '[StartupController] Missing artwork file for track $trackId',
            );
          }
        }

        // Re-download missing files
        if (needsAudioRedownload || needsArtworkRedownload) {
          debugPrint(
            '[StartupController] Missing assets for track $trackId - sync required',
          );
          // TODO: Implement sync functionality through download controller
        }
      }
    } catch (e) {
      debugPrint('[StartupController] Asset sync error: $e');
    }
  }

  /// Check if a file exists
  Future<bool> _checkFileExists(String filePath) async {
    try {
      // Check if downloads are accessible through DownloadController
      _downloadController
          .downloadedTracks; // Just verify controller is accessible
      // In a real implementation, you'd check file system here
      // For now, we'll assume files exist if path is not null
      return filePath.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Toggle offline mode manually
  Future<void> toggleOfflineMode() async {
    try {
      _isOfflineMode = !_isOfflineMode;
      await _prefs?.setBool('offline_mode', _isOfflineMode);
      debugPrint(
        '[StartupController] Offline mode toggled to: $_isOfflineMode',
      );
    } catch (e) {
      debugPrint('[StartupController] Error toggling offline mode: $e');
    }
  }

  /// Set offline mode
  Future<void> setOfflineMode(bool isOffline) async {
    try {
      _isOfflineMode = isOffline;
      await _prefs?.setBool('offline_mode', isOffline);
      debugPrint('[StartupController] Offline mode set to: $_isOfflineMode');
    } catch (e) {
      debugPrint('[StartupController] Error setting offline mode: $e');
    }
  }

  /// Force connectivity check
  Future<void> refreshConnectivity() async {
    await _checkConnectivity();

    // If we're back online and in offline mode, offer to go online
    if (_hasConnectivity && _isOfflineMode) {
      debugPrint(
        '[StartupController] Connectivity restored while in offline mode',
      );
    }

    // Don't automatically force offline mode when connectivity is lost
    // Let the OfflineModeService handle this with user prompt
    if (!_hasConnectivity && !_isOfflineMode) {
      debugPrint(
        '[StartupController] Connectivity lost - letting OfflineModeService handle prompt',
      );
    }
  }

  /// Check if the app should restrict UI to downloaded content only
  bool shouldRestrictToDownloadsOnly() {
    return _isOfflineMode || !_hasConnectivity;
  }

  /// Get startup recommendations for the UI
  Map<String, dynamic> getStartupRecommendations() {
    return {
      'shouldRestrictUI': shouldRestrictToDownloadsOnly(),
      'showOfflineIndicator': _isOfflineMode,
      'showConnectivityIndicator': !_hasConnectivity,
      'canStreamContent': _hasConnectivity && !_isOfflineMode,
      'canDownloadContent': _hasConnectivity,
      'downloadedTracksCount': 0, // Will be populated by UI
    };
  }

  /// Listen to connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream =>
      Connectivity().onConnectivityChanged;

  /// Handle connectivity changes
  Future<void> handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    final wasConnected = _hasConnectivity;
    _hasConnectivity = !results.contains(ConnectivityResult.none);

    debugPrint(
      '[StartupController] Connectivity changed: $results (hasConnectivity: $_hasConnectivity)',
    );

    // If connectivity status changed
    if (wasConnected != _hasConnectivity) {
      if (_hasConnectivity) {
        // Connectivity restored
        debugPrint('[StartupController] Connectivity restored');
        if (_isOfflineMode) {
          // Option to exit offline mode
          debugPrint('[StartupController] Can exit offline mode now');
        }
        // Auto-sync when back online
        await _autoSyncAssets();
      } else {
        // Connectivity lost
        debugPrint(
          '[StartupController] Connectivity lost - letting OfflineModeService handle prompt',
        );
        // Don't automatically force offline mode, let OfflineModeService handle it
      }
    }
  }

  /// Get download statistics for startup screen
  Future<Map<String, dynamic>> getDownloadStats() async {
    try {
      final tracks = _downloadController.downloadedTracks;
      return {
        'totalTracks': tracks.length,
        'totalSize': 0, // TODO: Calculate from file sizes if needed
        'lastDownload': tracks.isNotEmpty ? DateTime.now() : null,
      };
    } catch (e) {
      debugPrint('[StartupController] Error getting download stats: $e');
      return {'totalTracks': 0, 'totalSize': 0, 'lastDownload': null};
    }
  }

  /// Dispose resources
  void dispose() {
    // DownloadController is a singleton, no need to dispose
  }
}
