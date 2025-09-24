import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/Model/ModelPlayList.dart';
import 'package:jainverse/Presenter/PlaylistMusicPresenter.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Service class for managing playlist operations
/// Handles API calls and caching for playlist functionality
class PlaylistService {
  static final PlaylistService _instance = PlaylistService._internal();
  factory PlaylistService() => _instance;
  PlaylistService._internal();

  final PlaylistMusicPresenter _presenter = PlaylistMusicPresenter();
  final SharedPref _sharedPref = SharedPref();

  // Cache for playlists to avoid repeated API calls
  ModelPlayList? _cachedPlaylists;
  DateTime? _lastFetchTime;

  // Cache validity duration (5 minutes)
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  /// Get user's playlists with caching - Updated for new API
  Future<ModelPlayList> getPlaylists({bool forceRefresh = false}) async {
    // Check if cache is valid and not force refreshing
    if (!forceRefresh &&
        _cachedPlaylists != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidityDuration) {
      return _cachedPlaylists!;
    }

    try {
      final token = await _sharedPref.getToken();
      if (token.isEmpty) {
        throw Exception('User not logged in');
      }

      // Using the new user-playlist endpoint. If a BuildContext is available
      // callers should pass it to enable token-expiration handling. For
      // services called from UI we attempt to read the current context by
      // expecting callers to provide it. Here we keep the existing signature
      // but callers in UI will call the overloaded version below.
      final playlists = await _presenter.getPlayList(token);

      // Update cache
      _cachedPlaylists = playlists;
      _lastFetchTime = DateTime.now();

      if (kDebugMode) {
        print('✅ PlaylistService: Fetched ${playlists.data.length} playlists');
      }

      return playlists;
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaylistService: Error fetching playlists: $e');
      }
      rethrow;
    }
  }

  /// Context-aware variant used by UI code to enable token-expiration handling
  Future<ModelPlayList> getPlaylistsWithContext(
    BuildContext context, {
    bool forceRefresh = false,
  }) async {
    // Check if cache is valid and not force refreshing
    if (!forceRefresh &&
        _cachedPlaylists != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidityDuration) {
      return _cachedPlaylists!;
    }

    try {
      final token = await _sharedPref.getToken();
      if (token.isEmpty) {
        throw Exception('User not logged in');
      }

      // Pass BuildContext to presenter so BasePresenter can show the
      // "Login Expired" dialog and auto-logout when needed.
      final playlists = await _presenter.getPlayList(token, context);

      // Update cache
      _cachedPlaylists = playlists;
      _lastFetchTime = DateTime.now();

      if (kDebugMode) {
        print('✅ PlaylistService: Fetched ${playlists.data.length} playlists');
      }

      return playlists;
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaylistService: Error fetching playlists: $e');
      }
      rethrow;
    }
  }

  /// Create a new playlist
  Future<bool> createPlaylist(String playlistName) async {
    if (playlistName.trim().isEmpty) {
      if (kDebugMode) {
        print('❌ PlaylistService: Empty playlist name provided');
      }
      return false;
    }

    try {
      final token = await _sharedPref.getToken();
      final userData = await _sharedPref.getUserData();

      if (token.isEmpty) {
        if (kDebugMode) {
          print('❌ PlaylistService: User not logged in');
        }
        throw Exception('User not logged in');
      }

      await _presenter.createPlaylist(
        userData.data.id.toString(),
        playlistName.trim(),
        token,
      );

      // Invalidate cache to force refresh on next fetch
      _invalidateCache();

      if (kDebugMode) {
        print('✅ PlaylistService: Created playlist: $playlistName');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaylistService: Error creating playlist: $e');
      }
      return false;
    }
  }

  /// Add a song to an existing playlist
  Future<bool> addSongToPlaylist(
    String songId,
    String playlistId,
    String playlistName,
  ) async {
    if (songId.isEmpty || playlistId.isEmpty) {
      if (kDebugMode) {
        print('❌ PlaylistService: Invalid songId or playlistId provided');
      }
      return false;
    }

    try {
      final token = await _sharedPref.getToken();
      if (token.isEmpty) {
        if (kDebugMode) {
          print('❌ PlaylistService: User not logged in');
        }
        throw Exception('User not logged in');
      }

      final Map<String, dynamic> res = await _presenter.addMusicPlaylist(
        songId,
        playlistId,
        token,
      );

      // Show backend message directly as a toast (no extra customization)
      final bool status = res['status'] == true || res['status'] == 'true';
      final String msg = (res['msg'] ?? '');

      Fluttertoast.showToast(
        msg: msg.isNotEmpty ? msg : (status ? 'Added to playlist' : 'Failed'),
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: 14.sp,
      );

      // Invalidate cache to ensure fresh data on next fetch
      _invalidateCache();

      if (kDebugMode) {
        print('✅ PlaylistService: addSongToPlaylist response: $res');
      }

      return status;
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaylistService: Error adding song to playlist: $e');
      }
      // Note: Error message will come from API (PlaylistMusicPresenter)
      return false;
    }
  }

  /// Delete a playlist by id
  /// Returns a map with keys: status(bool) and msg(String)
  Future<Map<String, dynamic>> deletePlaylist(String playlistId) async {
    if (playlistId.trim().isEmpty) {
      return {'status': false, 'msg': 'Invalid playlist id'};
    }

    try {
      final token = await _sharedPref.getToken();
      if (token.isEmpty) {
        return {'status': false, 'msg': 'User not logged in'};
      }

      final res = await _presenter.removePlaylist(playlistId, token);

      // If backend indicates success, invalidate cache so UI refreshes
      final bool status = res['status'] == true || res['status'] == 'true';
      if (status) {
        _invalidateCache();
      }

      if (kDebugMode) {
        print('✅ PlaylistService: deletePlaylist response: $res');
      }

      return res;
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaylistService: Error deleting playlist: $e');
      }
      return {'status': false, 'msg': 'Something went wrong'};
    }
  }

  /// Update playlist name
  Future<bool> updatePlaylist(String playlistId, String playlistName) async {
    if (playlistId.trim().isEmpty || playlistName.trim().isEmpty) {
      if (kDebugMode) {
        print('❌ PlaylistService: Invalid playlist id or name');
      }
      return false;
    }

    try {
      final token = await _sharedPref.getToken();
      if (token.isEmpty) {
        if (kDebugMode) {
          print('❌ PlaylistService: User not logged in');
        }
        return false;
      }

      await _presenter.updatePlaylist(
        playlistName.trim(),
        playlistId.trim(),
        token,
      );

      // Invalidate cache to ensure UI shows updated name
      _invalidateCache();

      if (kDebugMode) {
        print(
          '✅ PlaylistService: Updated playlist $playlistId -> $playlistName',
        );
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaylistService: Error updating playlist: $e');
      }
      return false;
    }
  }

  /// Create playlist and add song in one operation
  Future<bool> createPlaylistAndAddSong(
    String playlistName,
    String songId,
  ) async {
    try {
      // First create the playlist
      final success = await createPlaylist(playlistName);
      if (!success) return false;

      // Wait a moment for the playlist to be created
      await Future.delayed(const Duration(milliseconds: 500));

      // Fetch fresh playlists to get the new playlist ID
      final playlists = await getPlaylists(forceRefresh: true);

      // Find the newly created playlist
      final newPlaylist = playlists.data.firstWhere(
        (playlist) => playlist.playlist_name == playlistName.trim(),
        orElse: () => throw Exception('Created playlist not found'),
      );

      // Add song to the new playlist
      return await addSongToPlaylist(
        songId,
        newPlaylist.id.toString(),
        playlistName,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaylistService: Error creating playlist and adding song: $e');
      }
      return false;
    }
  }

  /// Invalidate the playlist cache
  void _invalidateCache() {
    _cachedPlaylists = null;
    _lastFetchTime = null;
  }

  /// Clear all cached data (useful for logout)
  void clearCache() {
    _invalidateCache();
    if (kDebugMode) {
      print('🧹 PlaylistService: Cleared cache');
    }
  }

  /// Check if user has any playlists
  Future<bool> hasPlaylists() async {
    try {
      final playlists = await getPlaylists();
      return playlists.data.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get playlist count
  Future<int> getPlaylistCount() async {
    try {
      final playlists = await getPlaylists();
      return playlists.data.length;
    } catch (e) {
      return 0;
    }
  }
}
