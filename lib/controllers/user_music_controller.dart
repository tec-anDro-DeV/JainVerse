import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelPlayList.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/Presenter/HistoryPresenter.dart';
import 'package:jainverse/Presenter/PlaylistMusicPresenter.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Controller for managing user music data including favorites, history, and playlists
class UserMusicController extends ChangeNotifier {
  // Singleton pattern
  static final UserMusicController _instance = UserMusicController._internal();
  factory UserMusicController() => _instance;
  UserMusicController._internal();

  final SharedPref _sharePrefs = SharedPref();

  // State variables
  String _token = '';
  String _userId = '';

  // Favorites
  List<DataMusic> _favoritesList = [];
  String _favoritesImagePath = '';
  String _favoritesAudioPath = '';
  bool _favoritesLoading = false;

  // History
  List<DataMusic> _historyList = [];
  String _historyImagePath = '';
  String _historyAudioPath = '';
  bool _historyLoading = false;

  // Playlists
  List<DataCat> _playlistsList = [];
  bool _playlistsLoading = false;
  final Map<String, List<DataMusic>> _playlistSongs = {};
  bool _playlistSongsLoading = false;

  // Getters
  List<DataMusic> get favoritesList => List.unmodifiable(_favoritesList);
  String get favoritesImagePath => _favoritesImagePath;
  String get favoritesAudioPath => _favoritesAudioPath;
  bool get favoritesLoading => _favoritesLoading;

  List<DataMusic> get historyList => List.unmodifiable(_historyList);
  String get historyImagePath => _historyImagePath;
  String get historyAudioPath => _historyAudioPath;
  bool get historyLoading => _historyLoading;

  List<DataCat> get playlistsList => List.unmodifiable(_playlistsList);
  bool get playlistsLoading => _playlistsLoading;
  bool get playlistSongsLoading => _playlistSongsLoading;

  /// Initialize the user music controller
  Future<void> initialize() async {
    await _loadUserData();
    developer.log(
      '[DEBUG][UserMusicController][initialize] Initialized',
      name: 'UserMusicController',
    );
  }

  /// Load user data
  Future<void> _loadUserData() async {
    try {
      _token = await _sharePrefs.getToken();
      final model = await _sharePrefs.getUserData();
      _userId = model.data.id.toString();
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][_loadUserData] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
    }
  }

  /// Load favorites list
  Future<void> loadFavorites() async {
    if (_token.isEmpty) return;

    _favoritesLoading = true;
    notifyListeners();

    try {
      // Resolve BuildContext from global navigatorKey when available so we can
      // use context-aware presenter methods (token-expiration handling).
      BuildContext? resolvedContext;
      try {
        resolvedContext = navigatorKey.currentContext;
      } catch (_) {
        resolvedContext = null;
      }

      final FavMusicPresenter favPresenter = FavMusicPresenter();
      final ModelMusicList mList =
          resolvedContext != null
              ? await favPresenter.getFavMusicListWithContext(
                resolvedContext,
                _token,
              )
              : await favPresenter.getFavMusicList(_token);

      _favoritesList = mList.data;
      _favoritesImagePath = mList.imagePath;
      _favoritesAudioPath = mList.audioPath;

      developer.log(
        '[DEBUG][UserMusicController][loadFavorites] Loaded ${_favoritesList.length} favorites',
        name: 'UserMusicController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][loadFavorites] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
    } finally {
      _favoritesLoading = false;
      notifyListeners();
    }
  }

  /// Load history list
  Future<void> loadHistory() async {
    if (_token.isEmpty) return;

    _historyLoading = true;
    notifyListeners();

    try {
      final String data = await HistoryPresenter().getHistory(_token);
      final Map<String, dynamic> parsed = json.decode(data.toString());
      final ModelMusicList mList = ModelMusicList.fromJson(parsed);

      _historyList = mList.data;
      _historyImagePath = mList.imagePath;
      _historyAudioPath = mList.audioPath;

      developer.log(
        '[DEBUG][UserMusicController][loadHistory] Loaded ${_historyList.length} history items',
        name: 'UserMusicController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][loadHistory] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  /// Load playlists
  Future<void> loadPlaylists() async {
    if (_token.isEmpty) return;

    _playlistsLoading = true;
    notifyListeners();

    try {
      final ModelPlayList mList = await PlaylistMusicPresenter().getPlayList(
        _token,
      );
      _playlistsList = mList.data;

      developer.log(
        '[DEBUG][UserMusicController][loadPlaylists] Loaded ${_playlistsList.length} playlists',
        name: 'UserMusicController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][loadPlaylists] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
    } finally {
      _playlistsLoading = false;
      notifyListeners();
    }
  }

  /// Load songs for a specific playlist
  Future<List<DataMusic>> loadPlaylistSongs(String playlistId) async {
    if (_token.isEmpty || playlistId.isEmpty) return [];

    _playlistSongsLoading = true;
    notifyListeners();

    try {
      // Check cache first
      if (_playlistSongs.containsKey(playlistId)) {
        _playlistSongsLoading = false;
        notifyListeners();
        return _playlistSongs[playlistId]!;
      }

      // TODO: getPlaylistMusic method doesn't exist in PlaylistMusicPresenter
      // For now, return empty list until method is implemented
      final songs = <DataMusic>[];
      _playlistSongs[playlistId] = songs;

      developer.log(
        '[DEBUG][UserMusicController][loadPlaylistSongs] Loaded ${songs.length} songs for playlist $playlistId',
        name: 'UserMusicController',
      );

      return songs;
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][loadPlaylistSongs] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
      return [];
    } finally {
      _playlistSongsLoading = false;
      notifyListeners();
    }
  }

  /// Add/Remove favorite
  Future<bool> toggleFavorite(String audioId, String currentStatus) async {
    if (_token.isEmpty || audioId.isEmpty) return false;

    try {
      // Resolve context for token-expiration handling
      BuildContext? resolvedContext;
      try {
        resolvedContext = navigatorKey.currentContext;
      } catch (_) {
        resolvedContext = null;
      }

      final FavMusicPresenter favPresenter = FavMusicPresenter();
      if (resolvedContext != null) {
        await favPresenter.getMusicAddRemoveWithContext(
          resolvedContext,
          audioId,
          _token,
          currentStatus,
        );
      } else {
        await favPresenter.getMusicAddRemove(audioId, _token, currentStatus);
      }

      // Update local state
      if (currentStatus == '1') {
        // Remove from favorites
        _favoritesList.removeWhere((item) => item.id.toString() == audioId);
      } else {
        // Add to favorites - we would need to fetch the item details
        // For now, just refresh the entire list
        await loadFavorites();
        return true;
      }

      notifyListeners();

      developer.log(
        '[DEBUG][UserMusicController][toggleFavorite] Toggled favorite for $audioId',
        name: 'UserMusicController',
      );

      return true;
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][toggleFavorite] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
      return false;
    }
  }

  /// Add to history
  Future<bool> addToHistory(String audioId) async {
    if (_token.isEmpty || audioId.isEmpty) return false;

    try {
      await HistoryPresenter().addHistory(audioId, _token, 'add');

      developer.log(
        '[DEBUG][UserMusicController][addToHistory] Added $audioId to history',
        name: 'UserMusicController',
      );

      return true;
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][addToHistory] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
      return false;
    }
  }

  /// Remove from history
  Future<bool> removeFromHistory(String audioId) async {
    if (_token.isEmpty || audioId.isEmpty) return false;

    try {
      await HistoryPresenter().addHistory(audioId, _token, 'remove');

      // Update local state
      _historyList.removeWhere((item) => item.id.toString() == audioId);
      notifyListeners();

      developer.log(
        '[DEBUG][UserMusicController][removeFromHistory] Removed $audioId from history',
        name: 'UserMusicController',
      );

      return true;
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][removeFromHistory] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
      return false;
    }
  }

  /// Create new playlist
  Future<bool> createPlaylist(String playlistName) async {
    if (_token.isEmpty || playlistName.trim().isEmpty) return false;

    try {
      await PlaylistMusicPresenter().createPlaylist(
        _userId,
        playlistName.trim(),
        _token,
      );

      // Refresh playlists
      await loadPlaylists();

      developer.log(
        '[DEBUG][UserMusicController][createPlaylist] Created playlist: $playlistName',
        name: 'UserMusicController',
      );

      return true;
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][createPlaylist] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
      return false;
    }
  }

  /// Update playlist
  Future<bool> updatePlaylist(String playlistId, String newName) async {
    if (_token.isEmpty || playlistId.isEmpty || newName.trim().isEmpty) {
      return false;
    }

    try {
      await PlaylistMusicPresenter().updatePlaylist(
        newName.trim(),
        playlistId,
        _token,
      );

      // Update local state
      final index = _playlistsList.indexWhere(
        (playlist) => playlist.id.toString() == playlistId,
      );
      if (index != -1) {
        _playlistsList[index].playlist_name = newName.trim();
        notifyListeners();
      }

      developer.log(
        '[DEBUG][UserMusicController][updatePlaylist] Updated playlist $playlistId to: $newName',
        name: 'UserMusicController',
      );

      return true;
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][updatePlaylist] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
      return false;
    }
  }

  /// Delete playlist
  Future<bool> deletePlaylist(String playlistId) async {
    if (_token.isEmpty || playlistId.isEmpty) return false;

    try {
      await PlaylistMusicPresenter().removePlaylist(playlistId, _token);

      // Update local state
      _playlistsList.removeWhere(
        (playlist) => playlist.id.toString() == playlistId,
      );
      _playlistSongs.remove(playlistId);
      notifyListeners();

      developer.log(
        '[DEBUG][UserMusicController][deletePlaylist] Deleted playlist: $playlistId',
        name: 'UserMusicController',
      );

      return true;
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][deletePlaylist] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
      return false;
    }
  }

  /// Add music to playlist
  Future<bool> addMusicToPlaylist(String audioId, String playlistId) async {
    if (_token.isEmpty || audioId.isEmpty || playlistId.isEmpty) return false;

    try {
      await PlaylistMusicPresenter().addMusicPlaylist(
        audioId,
        playlistId,
        _token,
      );

      // Clear cache for this playlist
      _playlistSongs.remove(playlistId);

      developer.log(
        '[DEBUG][UserMusicController][addMusicToPlaylist] Added $audioId to playlist $playlistId',
        name: 'UserMusicController',
      );

      return true;
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][addMusicToPlaylist] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
      return false;
    }
  }

  /// Remove music from playlist
  Future<bool> removeMusicFromPlaylist(
    String audioId,
    String playlistId,
  ) async {
    if (_token.isEmpty || audioId.isEmpty || playlistId.isEmpty) return false;

    try {
      await PlaylistMusicPresenter().removeMusicFromPlaylist(
        audioId,
        playlistId,
        _token,
      );

      // Update local cache
      if (_playlistSongs.containsKey(playlistId)) {
        _playlistSongs[playlistId]!.removeWhere(
          (song) => song.id.toString() == audioId,
        );
        notifyListeners();
      }

      developer.log(
        '[DEBUG][UserMusicController][removeMusicFromPlaylist] Removed $audioId from playlist $playlistId',
        name: 'UserMusicController',
      );

      return true;
    } catch (e) {
      developer.log(
        '[ERROR][UserMusicController][removeMusicFromPlaylist] Failed: $e',
        name: 'UserMusicController',
        error: e,
      );
      return false;
    }
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

  /// Search history
  List<DataMusic> searchHistory(String query) {
    if (query.isEmpty) return _historyList;

    return _historyList.where((item) {
      final titleMatch = item.audio_title.toLowerCase().contains(
        query.toLowerCase(),
      );
      final artistMatch = item.artists_name.toLowerCase().contains(
        query.toLowerCase(),
      );
      return titleMatch || artistMatch;
    }).toList();
  }

  /// Search playlists
  List<DataCat> searchPlaylists(String query) {
    if (query.isEmpty) return _playlistsList;

    return _playlistsList.where((playlist) {
      return playlist.playlist_name.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  /// Get playlist by ID
  DataCat? getPlaylistById(String playlistId) {
    try {
      return _playlistsList.firstWhere(
        (playlist) => playlist.id.toString() == playlistId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get cached playlist songs
  List<DataMusic> getCachedPlaylistSongs(String playlistId) {
    return _playlistSongs[playlistId] ?? [];
  }

  /// Check if song is in favorites
  bool isFavorite(String audioId) {
    return _favoritesList.any((item) => item.id.toString() == audioId);
  }

  /// Check if song is in history
  bool isInHistory(String audioId) {
    return _historyList.any((item) => item.id.toString() == audioId);
  }

  /// Refresh all user data
  Future<void> refreshAll() async {
    await Future.wait([loadFavorites(), loadHistory(), loadPlaylists()]);
  }

  /// Clear cache
  void clearCache() {
    _playlistSongs.clear();
    notifyListeners();
  }
}
