import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/UI/MusicEntryPoint.dart' as entry_point;
import 'package:jainverse/hooks/favorites_hook.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Service to handle favorite music operations with reactive UI updates
/// Now works with the global FavoritesProvider for consistent state management
class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  final FavMusicPresenter _favMusicPresenter = FavMusicPresenter();
  final SharedPref _sharePrefs = SharedPref();

  /// Toggle favorite status for a song using global provider
  /// Returns the new favorite status as a string ("0" or "1")
  Future<String> toggleFavorite(
    String songId,
    String currentFavoriteStatus, {
    BuildContext? context,
  }) async {
    try {
      print(
        '🔥 FavoriteService: Toggling favorite for songId: $songId, current: $currentFavoriteStatus',
      );

      // Use global provider if context is available
      if (context != null) {
        try {
          final favoritesHook = FavoritesHook.of(context);
          final success = await favoritesHook.toggleFavorite(songId);

          if (success) {
            final newStatus = favoritesHook.isFavorite(songId) ? "1" : "0";
            print(
              '🔥 FavoriteService: Successfully updated via global provider to status: $newStatus',
            );
            return newStatus;
          }
        } catch (e) {
          print(
            '🔥 FavoriteService: Global provider failed, falling back to direct API: $e',
          );
        }
      }

      // Fallback to direct API call
      final token = await _sharePrefs.getToken();

      // Determine the action based on current status
      final tag = currentFavoriteStatus == "1" ? "remove" : "add";
      print('🔥 FavoriteService: Action: $tag');

      // Call the API - prefer context-aware if context provided
      if (context != null) {
        await _favMusicPresenter.getMusicAddRemoveWithContext(
          context,
          songId,
          token,
          tag,
        );
      } else {
        await _favMusicPresenter.getMusicAddRemove(songId, token, tag);
      }

      // Determine new status
      final newStatus = currentFavoriteStatus == "1" ? "0" : "1";

      // Update global listCopy if available
      _updateGlobalListCopy(songId, newStatus);

      // Update MusicManager's current song
      _updateMusicManagerCurrentSong(songId, newStatus);

      print('🔥 FavoriteService: Successfully updated to status: $newStatus');
      return newStatus;
    } catch (e) {
      print('🔥 ERROR FavoriteService: Error toggling favorite: $e');
      rethrow;
    }
  }

  /// Get favorite status for a specific song from the current song object
  String getFavoriteStatus(DataMusic song) {
    return song.favourite;
  }

  /// Check if a song is marked as favorite
  bool isFavorite(DataMusic song) {
    return song.favourite == "1";
  }

  /// Check if a song is favorite using global provider if available
  bool isFavoriteGlobal(String songId, {BuildContext? context}) {
    if (context != null) {
      try {
        final favoritesHook = FavoritesHook.of(context);
        return favoritesHook.isFavorite(songId);
      } catch (e) {
        print('🔥 FavoriteService: Could not use global provider: $e');
      }
    }

    // Fallback to checking global listCopy
    try {
      if (entry_point.listCopy.isNotEmpty) {
        final song = entry_point.listCopy.firstWhere(
          (song) => song.id.toString() == songId,
          orElse:
              () => DataMusic(
                0,
                '',
                '',
                '',
                '',
                '',
                0,
                '',
                '',
                '',
                0,
                0,
                0,
                '',
                0,
                '0',
                '',
                '',
              ),
        );
        return song.favourite == "1";
      }
    } catch (e) {
      print('🔥 FavoriteService: Could not check global listCopy: $e');
    }

    return false;
  }

  /// Update the global listCopy data structure
  void _updateGlobalListCopy(String songId, String newStatus) {
    try {
      // Update global listCopy if available
      if (entry_point.listCopy.isNotEmpty) {
        final songIndex = entry_point.listCopy.indexWhere(
          (song) => song.id.toString() == songId,
        );
        if (songIndex >= 0) {
          entry_point.listCopy[songIndex].favourite = newStatus;
        }
      }
    } catch (e) {
      print('Error updating global listCopy: $e');
    }
  }

  /// Update MusicManager's current song favorite status
  void _updateMusicManagerCurrentSong(String songId, String newStatus) {
    try {
      final musicManager = MusicManager();
      musicManager.updateCurrentSongFavoriteStatus(newStatus);
    } catch (e) {
      print('Error updating music manager: $e');
    }
  }

  /// Toggle favorite with immediate UI feedback (optimistic update)
  /// This method updates the UI immediately and then calls the API
  /// Now uses global provider when available
  Future<String> toggleFavoriteOptimistic(
    DataMusic song,
    Function() onUIUpdate, {
    BuildContext? context,
  }) async {
    final originalStatus = song.favourite;
    final songId = song.id.toString();

    // Try to use global provider first
    if (context != null) {
      try {
        final favoritesHook = FavoritesHook.of(context);
        final success = await favoritesHook.toggleFavorite(
          songId,
          songData: song,
        );

        if (success) {
          onUIUpdate();
          final newStatus = favoritesHook.isFavorite(songId) ? "1" : "0";
          return newStatus;
        }
      } catch (e) {
        print(
          '🔥 FavoriteService: Global provider optimistic update failed, falling back: $e',
        );
      }
    }

    // Fallback to local optimistic update
    final newStatus = originalStatus == "1" ? "0" : "1";

    // Optimistic update - update UI immediately
    song.favourite = newStatus;
    _updateGlobalListCopy(songId, newStatus);
    _updateMusicManagerCurrentSong(songId, newStatus);
    onUIUpdate();

    try {
      // Make API call
      final token = await _sharePrefs.getToken();
      final tag = originalStatus == "1" ? "remove" : "add";

      // Try to use provided context when available
      if (context != null) {
        await _favMusicPresenter.getMusicAddRemoveWithContext(
          context,
          songId,
          token,
          tag,
        );
      } else {
        await _favMusicPresenter.getMusicAddRemove(songId, token, tag);
      }

      return newStatus;
    } catch (e) {
      // Revert changes on error
      song.favourite = originalStatus;
      _updateGlobalListCopy(songId, originalStatus);
      _updateMusicManagerCurrentSong(songId, originalStatus);
      onUIUpdate();

      print('Error toggling favorite, reverted: $e');
      rethrow;
    }
  }
}
