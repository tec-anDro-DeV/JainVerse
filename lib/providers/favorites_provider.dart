import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/UI/MusicEntryPoint.dart' as entry_point;
import 'package:jainverse/main.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Global provider for managing favorites state across the entire app
/// This provider ensures consistent favorite status across all screens and widgets
class FavoritesProvider extends ChangeNotifier {
  // Singleton pattern for global access
  static final FavoritesProvider _instance = FavoritesProvider._internal();
  factory FavoritesProvider() => _instance;
  FavoritesProvider._internal();

  // Core dependencies
  final FavMusicPresenter _favMusicPresenter = FavMusicPresenter();
  final SharedPref _sharePrefs = SharedPref();

  // State variables
  String _token = '';
  List<DataMusic> _favoritesList = [];
  String _favoritesImagePath = '';
  String _favoritesAudioPath = '';
  bool _isLoading = false;
  bool _isInitialized = false;

  // Track favorite IDs for fast lookup
  final Set<String> _favoriteIds = <String>{};

  // Stream controller for real-time updates
  final StreamController<Map<String, bool>> _favoritesStreamController =
      StreamController<Map<String, bool>>.broadcast();

  // Getters
  List<DataMusic> get favoritesList => List.unmodifiable(_favoritesList);
  String get favoritesImagePath => _favoritesImagePath;
  String get favoritesAudioPath => _favoritesAudioPath;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  /// Stream for listening to favorite changes
  Stream<Map<String, bool>> get favoritesStream =>
      _favoritesStreamController.stream;

  /// Initialize the favorites provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _token = await _sharePrefs.getToken();
      if (_token.isNotEmpty) {
        await loadFavorites();
      }
      _isInitialized = true;

      developer.log(
        '[DEBUG][FavoritesProvider][initialize] Initialized successfully',
        name: 'FavoritesProvider',
      );
    } catch (e) {
      developer.log(
        '[ERROR][FavoritesProvider][initialize] Failed: $e',
        name: 'FavoritesProvider',
        error: e,
      );
    }
  }

  /// Load favorites from API
  Future<void> loadFavorites() async {
    if (_token.isEmpty) {
      developer.log(
        '[WARNING][FavoritesProvider][loadFavorites] No token available',
        name: 'FavoritesProvider',
      );
      return;
    }

    _setLoading(true);

    try {
      // Prefer context-aware presenter method when possible so token-expiry
      // handling can be shown via UI. Resolve context from global navigatorKey.
      BuildContext? resolvedContext;
      try {
        resolvedContext = navigatorKey.currentContext;
      } catch (_) {
        resolvedContext = null;
      }

      final ModelMusicList mList =
          resolvedContext != null
              ? await _favMusicPresenter.getFavMusicListWithContext(
                resolvedContext,
                _token,
              )
              : await _favMusicPresenter.getFavMusicList(_token);

      _favoritesList = mList.data;
      _favoritesImagePath = mList.imagePath;
      _favoritesAudioPath = mList.audioPath;

      // Update favorites IDs set for fast lookup
      _favoriteIds.clear();
      for (final song in _favoritesList) {
        _favoriteIds.add(song.id.toString());
      }

      developer.log(
        '[DEBUG][FavoritesProvider][loadFavorites] Loaded ${_favoritesList.length} favorites',
        name: 'FavoritesProvider',
      );

      // Notify all listeners about the updated favorites
      _notifyFavoritesChanged();
    } catch (e) {
      developer.log(
        '[ERROR][FavoritesProvider][loadFavorites] Failed: $e',
        name: 'FavoritesProvider',
        error: e,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Check if a song is favorited
  bool isFavorite(String songId) {
    final result = _favoriteIds.contains(songId);
    // developer.log(
    //   '[DEBUG][FavoritesProvider][isFavorite] songId: $songId, result: $result, totalFavorites: ${_favoriteIds.length}',
    //   name: 'FavoritesProvider',
    // );
    return result;
  }

  /// Toggle favorite status for a song with optimistic updates
  Future<bool> toggleFavorite(String songId, {DataMusic? songData}) async {
    developer.log(
      '[DEBUG][FavoritesProvider][toggleFavorite] START - songId: $songId, isInitialized: $_isInitialized, hasToken: ${_token.isNotEmpty}',
      name: 'FavoritesProvider',
    );

    if (_token.isEmpty) {
      developer.log(
        '[WARNING][FavoritesProvider][toggleFavorite] No token available',
        name: 'FavoritesProvider',
      );
      return false;
    }

    final wasOriginallyFavorite = isFavorite(songId);
    final newFavoriteStatus = !wasOriginallyFavorite;

    developer.log(
      '[DEBUG][FavoritesProvider][toggleFavorite] wasOriginallyFavorite: $wasOriginallyFavorite, newStatus: $newFavoriteStatus',
      name: 'FavoritesProvider',
    );

    // Optimistic update - update UI immediately
    _updateFavoriteStatusOptimistic(songId, newFavoriteStatus, songData);

    try {
      developer.log(
        '[DEBUG][FavoritesProvider][toggleFavorite] Toggling favorite for songId: $songId, newStatus: $newFavoriteStatus',
        name: 'FavoritesProvider',
      );

      // Determine the action based on new status
      final tag = newFavoriteStatus ? "add" : "remove";

      // Call the API - prefer context-aware presenter if we can resolve
      BuildContext? resolvedContext;
      try {
        resolvedContext = navigatorKey.currentContext;
      } catch (_) {
        resolvedContext = null;
      }

      if (resolvedContext != null) {
        await _favMusicPresenter.getMusicAddRemoveWithContext(
          resolvedContext,
          songId,
          _token,
          tag,
        );
      } else {
        await _favMusicPresenter.getMusicAddRemove(songId, _token, tag);
      }

      // Update global references
      _updateGlobalReferences(songId, newFavoriteStatus ? "1" : "0");

      developer.log(
        '[DEBUG][FavoritesProvider][toggleFavorite] Successfully toggled favorite for songId: $songId',
        name: 'FavoritesProvider',
      );

      return true;
    } catch (e) {
      developer.log(
        '[ERROR][FavoritesProvider][toggleFavorite] Failed for songId: $songId, error: $e',
        name: 'FavoritesProvider',
        error: e,
      );

      // Revert optimistic update on error
      _updateFavoriteStatusOptimistic(songId, wasOriginallyFavorite, songData);

      return false;
    }
  }

  /// Add multiple songs to favorites (batch operation)
  Future<List<String>> addToFavoritesBatch(List<String> songIds) async {
    final successfulIds = <String>[];

    for (final songId in songIds) {
      try {
        final success = await toggleFavorite(songId);
        if (success && !isFavorite(songId)) {
          // Only add if it wasn't already a favorite
          successfulIds.add(songId);
        }
      } catch (e) {
        developer.log(
          '[ERROR][FavoritesProvider][addToFavoritesBatch] Failed for songId: $songId, error: $e',
          name: 'FavoritesProvider',
          error: e,
        );
      }
    }

    return successfulIds;
  }

  /// Remove multiple songs from favorites (batch operation)
  Future<List<String>> removeFromFavoritesBatch(List<String> songIds) async {
    final successfulIds = <String>[];

    for (final songId in songIds) {
      try {
        final success = await toggleFavorite(songId);
        if (success && isFavorite(songId)) {
          // Only add if it was actually a favorite
          successfulIds.add(songId);
        }
      } catch (e) {
        developer.log(
          '[ERROR][FavoritesProvider][removeFromFavoritesBatch] Failed for songId: $songId, error: $e',
          name: 'FavoritesProvider',
          error: e,
        );
      }
    }

    return successfulIds;
  }

  /// Search favorites
  List<DataMusic> searchFavorites(String query) {
    if (query.isEmpty) return _favoritesList;

    return _favoritesList.where((item) {
      final titleMatch = item.audio_title.toLowerCase().contains(
        query.toLowerCase(),
      );
      final artistMatch = item.artists_name.toLowerCase().contains(
        query.toLowerCase(),
      );
      return titleMatch || artistMatch;
    }).toList();
  }

  /// Refresh favorites from server
  Future<void> refreshFavorites() async {
    await loadFavorites();
  }

  /// Update token and reinitialize if needed
  Future<void> updateToken(String newToken) async {
    if (_token != newToken) {
      _token = newToken;
      if (newToken.isNotEmpty) {
        await loadFavorites();
      } else {
        _clearFavorites();
      }
    }
  }

  /// Clear all favorites (on logout)
  void _clearFavorites() {
    _favoritesList.clear();
    _favoriteIds.clear();
    _favoritesImagePath = '';
    _favoritesAudioPath = '';
    _isInitialized = false;
    notifyListeners();
    _notifyFavoritesChanged();
  }

  /// Update favorite status optimistically (for immediate UI feedback)
  void _updateFavoriteStatusOptimistic(
    String songId,
    bool isFavorite,
    DataMusic? songData,
  ) {
    developer.log(
      '[DEBUG][FavoritesProvider][_updateFavoriteStatusOptimistic] songId: $songId, isFavorite: $isFavorite, beforeCount: ${_favoriteIds.length}',
      name: 'FavoritesProvider',
    );

    if (isFavorite) {
      _favoriteIds.add(songId);
      // Add to favorites list if we have the song data and it's not already there
      if (songData != null &&
          !_favoritesList.any((song) => song.id.toString() == songId)) {
        // Update the song's favorite status
        songData.favourite = "1";
        _favoritesList.insert(0, songData); // Add to beginning for recency
      }
    } else {
      _favoriteIds.remove(songId);
      // Remove from favorites list
      _favoritesList.removeWhere((song) => song.id.toString() == songId);
      // Update song data if provided
      if (songData != null) {
        songData.favourite = "0";
      }
    }

    developer.log(
      '[DEBUG][FavoritesProvider][_updateFavoriteStatusOptimistic] AFTER - songId: $songId, afterCount: ${_favoriteIds.length}, calling notifyListeners',
      name: 'FavoritesProvider',
    );

    notifyListeners();
    _notifyFavoritesChanged();
  }

  /// Update global references (listCopy, MusicManager, etc.)
  void _updateGlobalReferences(String songId, String favoriteStatus) {
    try {
      // Update global listCopy if available
      if (entry_point.listCopy.isNotEmpty) {
        final songIndex = entry_point.listCopy.indexWhere(
          (song) => song.id.toString() == songId,
        );
        if (songIndex >= 0) {
          entry_point.listCopy[songIndex].favourite = favoriteStatus;
        }
      }

      // Update MusicManager's current song
      final musicManager = MusicManager();
      musicManager.updateCurrentSongFavoriteStatus(favoriteStatus);
    } catch (e) {
      developer.log(
        '[ERROR][FavoritesProvider][_updateGlobalReferences] Failed: $e',
        name: 'FavoritesProvider',
        error: e,
      );
    }
  }

  /// Notify listeners about favorites changes via stream
  void _notifyFavoritesChanged() {
    // Create a map of songId -> isFavorite for easy consumption
    final favoritesMap = <String, bool>{};
    for (final song in _favoritesList) {
      favoritesMap[song.id.toString()] = true;
    }

    _favoritesStreamController.add(favoritesMap);
  }

  /// Set loading state and notify listeners
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _favoritesStreamController.close();
    super.dispose();
  }
}
