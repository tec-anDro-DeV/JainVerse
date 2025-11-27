import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jainverse/Model/ModelMusicList.dart'; // Import DataMusic model
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/UI/MusicEntryPoint.dart'; // Add access to global data
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/hooks/favorites_hook.dart'; // Import favorites hook
import 'package:jainverse/controllers/music/music_manager.dart';
import 'package:jainverse/models/song_playback_payload.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/services/single_music_service.dart';
import 'package:jainverse/utils/AppConstant.dart'; // Import for base URL constants
import 'package:jainverse/utils/music_player_state_manager.dart'; // Import state manager
import 'package:jainverse/utils/share_helper.dart';
import 'package:jainverse/widgets/playlist/add_to_playlist_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';

/// Enhanced Music Action Handler with Play Next and Add to Queue functionality
/// Supports both songs and non-song items (playlists, albums, etc.)
class MusicActionHandler {
  final BuildContext context;
  final AudioPlayerHandler? audioHandler;
  final FavoriteService favoriteService;
  final VoidCallback?
  onStateUpdate; // Callback to trigger UI updates (setState)

  MusicActionHandler({
    required this.context,
    required this.audioHandler,
    required this.favoriteService,
    this.onStateUpdate,
  });

  /// Handle play song action for individual songs
  /// SMART PLAY: Checks if song is already in queue and skips to it, otherwise replaces queue
  Future<void> handlePlaySong(String songId, String songName) async {
    try {
      if (kDebugMode) {
        print('🎵 Playing Song: $songName (ID: $songId)');
      }

      // Add haptic feedback for play action
      HapticFeedback.mediumImpact();

      // CRITICAL FIX: Clear stale locks before attempting operation
      final musicManager = MusicManager();
      musicManager.autoCleanupStaleLocks();

      // OPTIMIZED SMART PLAY: Check if song is already in current queue
      final currentQueue = audioHandler?.queue.value ?? [];
      int existingIndex = -1;

      // Find if the song is already in the current queue
      for (int i = 0; i < currentQueue.length; i++) {
        final queueSong = currentQueue[i];
        final queueAudioId = queueSong.extras?['audio_id']?.toString();
        if (queueAudioId == songId) {
          existingIndex = i;
          break;
        }
      }

      if (existingIndex != -1 && audioHandler != null) {
        // FAST PATH: Song is already in queue, just skip to it
        if (kDebugMode) {
          print('🚀 Fast skip to existing song at index $existingIndex');
        }

        try {
          await audioHandler!.skipToQueueItem(existingIndex);
          await audioHandler!.play();

          // Show mini player state
          final stateManager = MusicPlayerStateManager();
          stateManager.showMiniPlayerForMusicStart();

          if (kDebugMode) {
            print('✅ Successfully skipped to: $songName');
          }
          return;
        } catch (skipError) {
          if (kDebugMode) {
            print(
              '⚠️ Skip failed, falling back to queue replacement: $skipError',
            );
          }
          // Fall through to queue replacement
        }
      }

      // FALLBACK: Song not in queue or skip failed, use smart queue replacement
      if (kDebugMode) {
        print('🔄 Song not in queue, using smart queue replacement');
      }

      // Try to get the song data from global list first
      DataMusic? targetSong;
      if (listCopy.isNotEmpty) {
        try {
          targetSong = listCopy.firstWhere(
            (song) => song.id.toString() == songId,
          );
        } catch (e) {
          // Song not found in current list, will create minimal data
        }
      }

      if (targetSong != null) {
        // Song found in current list - replace queue with current list starting from this song
        final targetIndex = listCopy.indexWhere(
          (song) => song.id.toString() == songId,
        );

        await musicManager.replaceQueue(
          musicList: listCopy,
          startIndex: targetIndex >= 0 ? targetIndex : 0,
          callSource: 'MusicActionHandler.handlePlaySong.smartReplace',
        );
      } else {
        // Song not in current list - fetch full metadata from API before playing
        final singleMusicService = SingleMusicService();
        final fetchedSong = await singleMusicService.fetchSingleMusic(songId);

        if (fetchedSong == null) {
          if (kDebugMode) {
            print('❌ Unable to fetch song metadata for $songName ($songId)');
          }
          _showErrorSnackBar('Unable to load $songName');
          return;
        }

        await musicManager.replaceQueue(
          musicList: [fetchedSong],
          startIndex: 0,
          callSource: 'MusicActionHandler.handlePlaySong.singleSong',
        );
      }

      // Show mini player instead of navigating to full player
      final stateManager = MusicPlayerStateManager();
      stateManager.showMiniPlayerForMusicStart();

      if (kDebugMode) {
        print('✅ Successfully started playing: $songName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error playing song $songName: $e');
      }

      // If it's a timeout, try to force clear locks and show helpful message
      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        try {
          final musicManager = MusicManager();
          musicManager.forceClearLocks();
          _showErrorSnackBar(
            'Operation timed out, locks cleared. Please try again.',
          );
        } catch (retryError) {
          _showErrorSnackBar(
            'Failed to play song: Please restart the app if this persists.',
          );
        }
      } else {
        _showErrorSnackBar('Failed to play $songName');
      }
    }
  }

  /// Handle the new instant playback flow which plays a single item immediately
  /// while the rest of the provided context queues up in the background.
  Future<void> handleInstantPlay({
    required SongPlaybackPayload payload,
    List<SongPlaybackPayload> context = const [],
    int contextIndex = 0,
  }) async {
    try {
      HapticFeedback.mediumImpact();

      final musicManager = MusicManager();
      musicManager.autoCleanupStaleLocks();

      await musicManager.playInstant(
        payload: payload,
        context: context,
        contextIndex: contextIndex,
      );

      final stateManager = MusicPlayerStateManager();
      stateManager.showMiniPlayerForMusicStart();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Instant play failed for ${payload.title}: $e');
      }

      final extrasId = payload.extras['audio_id']?.toString();
      final fallbackId = (extrasId != null && extrasId.isNotEmpty)
          ? extrasId
          : payload.id;

      if (fallbackId.isEmpty) {
        _showErrorSnackBar('Failed to start ${payload.title}');
        return;
      }

      try {
        await handlePlaySong(fallbackId, payload.title);
      } catch (_) {
        _showErrorSnackBar('Failed to start ${payload.title}');
      }
    }
  }

  /// Handle Play Next action - adds song to play immediately after current track
  Future<void> handlePlayNext(
    String songId,
    String songName,
    String artistName, {
    String? imagePath,
    String? audioPath,
    DataMusic? track,
  }) async {
    try {
      if (kDebugMode) {
        print('🎵 Playing Next: $songName (ID: $songId)');
      }

      // Add haptic feedback for play next action
      HapticFeedback.mediumImpact();

      // CRITICAL FIX: Clear stale locks before attempting operation
      final musicManager = MusicManager();
      musicManager.autoCleanupStaleLocks();

      await _withQueueMutationTolerance(
        () async {
          if (track != null) {
            await musicManager.insertPlayNext(track);
          } else {
            await musicManager.insertPlayNextById(
              songId,
              songName,
              artistName,
              fallbackImagePath: imagePath,
              fallbackAudioPath: audioPath,
            );
          }
        },
        songId: songId,
        actionDescription: 'insertPlayNext',
      );

      if (kDebugMode) {
        print('✅ Successfully added to Play Next: $songName');
      }

      // Show success feedback
      // _showSuccessMessage('Added to Play Next: $songName');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding to Play Next $songName: $e');
      }

      // If it's a timeout, try to force clear locks and retry once
      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        try {
          final musicManager = MusicManager();
          musicManager.forceClearLocks();
          _showErrorSnackBar(
            'Operation timed out, locks cleared. Please try again.',
          );
        } catch (retryError) {
          _showErrorSnackBar(
            'Failed to add to Play Next: Please restart the app if this persists.',
          );
        }
      } else {
        _showErrorSnackBar('Failed to add to Play Next');
      }
    }
  }

  /// Handle Add to Queue action - adds song to end of queue
  Future<void> handleAddToQueue(
    String songId,
    String songName,
    String artistName, {
    String? imagePath,
    String? audioPath,
    DataMusic? track,
  }) async {
    try {
      if (kDebugMode) {
        print('🎵 Adding to Queue: $songName (ID: $songId)');
      }

      // Add haptic feedback for add to queue action
      HapticFeedback.mediumImpact();

      // CRITICAL FIX: Clear stale locks before attempting operation
      final musicManager = MusicManager();
      musicManager.autoCleanupStaleLocks();

      await _withQueueMutationTolerance(
        () async {
          if (track != null) {
            await musicManager.addToQueue(track);
          } else {
            await musicManager.addToQueueById(
              songId,
              songName,
              artistName,
              fallbackImagePath: imagePath,
              fallbackAudioPath: audioPath,
            );
          }
        },
        songId: songId,
        actionDescription: 'addToQueue',
      );

      if (kDebugMode) {
        print('✅ Successfully added to Queue: $songName');
      }

      // Show success feedback
      // _showSuccessMessage('Added to Queue: $songName');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding to Queue $songName: $e');
      }

      // If it's a timeout, try to force clear locks and retry once
      if (e.toString().contains('timeout') ||
          e.toString().contains('Timeout')) {
        try {
          final musicManager = MusicManager();
          musicManager.forceClearLocks();
          _showErrorSnackBar(
            'Operation timed out, locks cleared. Please try again.',
          );
        } catch (retryError) {
          _showErrorSnackBar(
            'Failed to add to Queue: Please restart the app if this persists.',
          );
        }
      } else {
        _showErrorSnackBar('Failed to add to Queue');
      }
    }
  }

  /// Handle share action for music items (works for songs and non-song items)
  Future<void> handleShare(
    String itemName,
    String itemType, {
    String? itemId,
    String? slug,
  }) async {
    try {
      if (kDebugMode) {
        print('🔗 Sharing $itemType: $itemName (ID: $itemId)');
      }

      // Add haptic feedback for share action
      HapticFeedback.lightImpact();

      // Generate shareable URL using the new URL pattern
      String shareText = 'Check out this $itemType: $itemName';

      if (itemId != null && slug != null) {
        final shareUrl = _generateShareUrl(itemType, itemId, slug);
        if (shareUrl.isNotEmpty) {
          shareText += '\n\n$shareUrl';

          if (kDebugMode) {
            print('🔗 Generated share URL: $shareUrl');
          }
        }
      }

      final rect = computeSharePosition(context);
      if (rect != null) {
        await Share.share(shareText, sharePositionOrigin: rect);
      } else {
        await Share.share(shareText);
      }

      if (kDebugMode) {
        print('✅ Successfully shared: $itemName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sharing $itemType $itemName: $e');
      }
      _showErrorSnackBar('Failed to share $itemType');
    }
  }

  /// Generate shareable URL based on item type, ID, and slug
  /// Follows the pattern: {base_url}/{type}/{id}/{slug}
  String _generateShareUrl(String itemType, String itemId, String slug) {
    // Use AppConstant for base URL (remove trailing slash)
    final String baseUrl = AppConstant.SiteUrl.replaceAll(RegExp(r'/+$'), '');

    // Normalize the slug to ensure it's URL-friendly
    final normalizedSlug = _normalizeSlug(slug);

    // Map item types to URL path segments
    String urlType;
    switch (itemType.toLowerCase()) {
      case 'song':
      case 'songs':
      case 'audio':
      case 'single':
        urlType = 'audio/single';
        break;
      case 'artist':
      case 'artists':
        urlType = 'artist';
        break;
      case 'album':
      case 'albums':
        // Album pages use the 'album/single' path on the website
        urlType = 'album/single';
        break;
      case 'playlist':
      case 'playlists':
        // Playlists on the site are served under 'adminplaylist/single'
        urlType = 'adminplaylist/single';
        break;
      case 'genre':
      case 'genres':
        urlType = 'genre';
        break;
      default:
        if (kDebugMode) {
          print('⚠️ Unknown item type for URL generation: $itemType');
        }
        return ''; // Return empty string for unknown types
    }

    final shareableUrl = '$baseUrl/$urlType/$itemId/$normalizedSlug';

    if (kDebugMode) {
      print(
        '🔗 Generated URL: $shareableUrl for type: $itemType, id: $itemId, slug: $normalizedSlug',
      );
    }

    return shareableUrl;
  }

  /// Normalize slug to be URL-friendly
  /// Removes special characters, converts to lowercase, and replaces spaces with hyphens
  String _normalizeSlug(String slug) {
    if (slug.isEmpty) return slug;

    return slug
        .toLowerCase()
        .trim()
        // Remove special characters except hyphens and underscores
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        // Replace multiple whitespace/underscores with single hyphen
        .replaceAll(RegExp(r'[\s_]+'), '-')
        // Remove multiple consecutive hyphens
        .replaceAll(RegExp(r'-+'), '-')
        // Remove leading/trailing hyphens
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Handle download action for music items
  Future<void> handleDownload(
    String itemName,
    String itemType,
    String itemId, {
    String? imagePath,
    String? audioPath,
  }) async {
    try {
      if (kDebugMode) {
        print('📥 Downloading $itemType: $itemName (ID: $itemId)');
      }

      // Add haptic feedback for download action
      HapticFeedback.mediumImpact();

      final downloadController = DownloadController();

      // Check if already downloaded
      if (downloadController.isTrackDownloaded(itemId)) {
        if (Platform.isIOS) {
          _showIOSDownloadMessage('$itemName is already downloaded');
        } else {
          _showSuccessMessage('$itemName is already downloaded');
        }
        return;
      }

      // Start download
      await downloadController.addToDownloads(itemId);

      if (Platform.isIOS) {
        _showIOSDownloadMessage('Download started for $itemName');
      } else {
        _showSuccessMessage('Download started for $itemName');
      }

      if (kDebugMode) {
        print('✅ Download started for: $itemName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error downloading $itemType $itemName: $e');
      }

      if (Platform.isIOS) {
        await _showIOSDownloadError('Failed to download $itemName');
      } else {
        _showErrorSnackBar('Failed to download $itemName');
      }
    }
  }

  /// Handle add to playlist action (songs only)
  Future<void> handleAddToPlaylist(
    String songId,
    String songName,
    String artistName, {
    String? imagePath,
  }) async {
    try {
      if (kDebugMode) {
        print('📋 Adding to Playlist: $songName (ID: $songId)');
      }

      // Add haptic feedback for add to playlist action
      HapticFeedback.lightImpact();

      // Show the add to playlist bottom sheet using the root-modal API so it
      // appears above persistent UI like the main navigation and mini player.
      await AddToPlaylistBottomSheet.show(
        context,
        songId: songId,
        songTitle: songName,
        artistName: artistName,
      );

      if (kDebugMode) {
        print('✅ Add to playlist sheet shown for: $songName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error showing add to playlist for $songName: $e');
      }
      _showErrorSnackBar('Failed to add to playlist');
    }
  }

  /// Handle favorite toggle for songs (songs only)
  /// Now uses global favorites provider for consistent state management
  Future<void> handleFavoriteToggle(
    String songId,
    String songName, {
    Set<String>? favoriteIds,
  }) async {
    try {
      if (kDebugMode) {
        print('❤️ Toggling favorite for: $songName (ID: $songId)');
      }

      // Add haptic feedback for favorite action
      HapticFeedback.lightImpact();

      // Try to use global favorites provider first
      try {
        final favoritesHook = context.favorites;
        final success = await favoritesHook.toggleFavorite(songId);

        if (success) {
          final isNowFavorite = favoritesHook.isFavorite(songId);
          if (isNowFavorite) {
            _showSuccessMessage('Added to favorites: $songName');
          } else {
            _showSuccessMessage('Removed from favorites: $songName');
          }

          // Trigger UI update
          onStateUpdate?.call();

          if (kDebugMode) {
            print('✅ Favorite toggled via global provider for: $songName');
          }
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Global provider failed, using fallback for $songName: $e');
        }
      }

      // Fallback to direct service call
      final isFavorite = favoriteIds?.contains(songId) ?? false;
      final currentStatus = isFavorite ? "1" : "0";
      final newStatus = await favoriteService.toggleFavorite(
        songId,
        currentStatus,
        context: context,
      );

      if (newStatus == "1") {
        _showSuccessMessage('Added to favorites: $songName');
      } else {
        _showSuccessMessage('Removed from favorites: $songName');
      }

      // Trigger UI update
      onStateUpdate?.call();

      if (kDebugMode) {
        print('✅ Favorite toggled via fallback for: $songName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling favorite for $songName: $e');
      }
      _showErrorSnackBar('Failed to update favorites');
    }
  }

  /// Load content and play using the mini player approach (DEPRECATED - Use handlePlaySong instead)
  /// This method now uses the same smart approach as handlePlaySong to avoid opening full player
  Future<void> handleLoadAndPlayContent(
    String contentId,
    String contentType,
    String contentName, {
    String? imagePath,
    String? audioPath,
  }) async {
    if (kDebugMode) {
      print(
        '⚠️ handleLoadAndPlayContent is deprecated. Using smart play approach instead.',
      );
    }

    // Redirect to the smart handlePlaySong method
    await handlePlaySong(contentId, contentName);
  }

  /// Show error snack bar message
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: appColors().primaryColorApp,
      ),
    );
  }

  /// Show success message
  void _showSuccessMessage(String message) {
    if (!mounted) return;
  }

  Future<void> _withQueueMutationTolerance(
    Future<void> Function() mutation, {
    required String songId,
    required String actionDescription,
  }) async {
    try {
      await mutation();
    } catch (error) {
      final isConcurrent = _isConcurrentQueueError(error);
      final alreadyQueued = isConcurrent && _isSongAlreadyQueued(songId);

      if (alreadyQueued) {
        if (kDebugMode) {
          print(
            '⚠️ $actionDescription succeeded despite concurrent queue error; suppressing toast. Error: $error',
          );
        }
        return;
      }

      rethrow;
    }
  }

  bool _isConcurrentQueueError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('addstream') ||
        message.contains('add stream') ||
        message.contains('you cannot add items') ||
        message.contains('bad state');
  }

  bool _isSongAlreadyQueued(String songId) {
    if (songId.isEmpty) return false;
    final queue = MusicManager().queue;
    for (final item in queue) {
      final extrasId = item.extras?['audio_id']?.toString();
      if (extrasId == songId || item.id == songId) {
        return true;
      }
    }
    return false;
  }

  /// Show iOS download error using alert dialog
  Future<void> _showIOSDownloadError(String message) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show iOS download message using overlay
  void _showIOSDownloadMessage(String message, {double fontSize = 15}) {
    // Only show UI messages on iOS platform
    if (!Platform.isIOS || !mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.1,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: TextStyle(color: Colors.white, fontSize: fontSize),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove overlay after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  /// Check if context is still mounted (for async operations)
  bool get mounted => context.mounted;

  /// Helper method to generate slug from song name
}

/// Factory class to create MusicActionHandler instances
class MusicActionHandlerFactory {
  /// Create a handler for screens with song interactions
  static MusicActionHandler create({
    required BuildContext context,
    required AudioPlayerHandler? audioHandler,
    required FavoriteService favoriteService,
    VoidCallback? onStateUpdate,
  }) {
    return MusicActionHandler(
      context: context,
      audioHandler: audioHandler,
      favoriteService: favoriteService,
      onStateUpdate: onStateUpdate,
    );
  }
}
