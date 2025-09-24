import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/artist_detail_screen.dart';
import 'package:jainverse/widgets/musicplayer/three_dot_options_menu.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/utils/sharing_utils.dart'; // Import sharing utility
import 'package:jainverse/services/audio_player_service.dart'; // Import for AudioPlayerHandler
import 'package:jainverse/UI/MusicEntryPoint.dart' as entry_point;
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/services/station_service.dart';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:jainverse/services/tab_navigation_service.dart';
import 'package:jainverse/hooks/favorites_hook.dart';

/// Modern track info widget displaying song title, artist, and menu options
class ModernTrackInfo extends StatefulWidget {
  final MediaItem? mediaItem;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onCreateStation;
  final VoidCallback? onRepeat;
  final ColorScheme? colorScheme;
  final AudioPlayerHandler? audioHandler; // Add audioHandler parameter

  const ModernTrackInfo({
    super.key,
    this.mediaItem,
    this.onFavoriteToggle,
    this.onShare,
    this.onDownload,
    this.onAddToPlaylist,
    this.onPlayNext,
    this.onAddToQueue,
    this.onCreateStation,
    this.onRepeat,
    this.colorScheme,
    this.audioHandler, // Add audioHandler parameter
  });

  @override
  State<ModernTrackInfo> createState() => _ModernTrackInfoState();
}

class _ModernTrackInfoState extends State<ModernTrackInfo> {
  // Cache artist information to prevent recalculations
  List<String>? _cachedArtistNames;
  List<String>? _cachedArtistIds;
  String? _lastMediaItemId;

  @override
  void initState() {
    super.initState();
    // Listen to audio handler stream to rebuild when MediaItem changes
    if (widget.audioHandler != null) {
      widget.audioHandler!.mediaItem.listen((_) {
        if (mounted) {
          // Clear cache when MediaItem changes
          _clearArtistCache();
          setState(() {
            // Rebuild when MediaItem changes
          });
        }
      });
    }
  }

  void _clearArtistCache() {
    _cachedArtistNames = null;
    _cachedArtistIds = null;
    _lastMediaItemId = null;
  }

  List<String> _getCachedArtistNames() {
    final currentMediaItemId = widget.mediaItem?.id;

    // Return cached data if available and MediaItem hasn't changed
    if (_cachedArtistNames != null && _lastMediaItemId == currentMediaItemId) {
      return _cachedArtistNames!;
    }

    // Recalculate and cache
    final raw = _getRawArtists() ?? '';
    _cachedArtistNames =
        raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    _lastMediaItemId = currentMediaItemId;

    return _cachedArtistNames!;
  }

  List<String> _getCachedArtistIds() {
    final currentMediaItemId = widget.mediaItem?.id;

    // Return cached data if available and MediaItem hasn't changed
    if (_cachedArtistIds != null && _lastMediaItemId == currentMediaItemId) {
      return _cachedArtistIds!;
    }

    // Recalculate and cache
    _cachedArtistIds = _getArtistIds();
    _lastMediaItemId = currentMediaItemId;

    return _cachedArtistIds!;
  }

  @override
  Widget build(BuildContext context) {
    return FavoritesConsumer(
      builder: (context, favoritesHook, child) {
        // Constrain and center on larger screens (iPad/tablet)
        final screenWidth = MediaQuery.of(context).size.width;
        const tabletThreshold = 600.0;
        // Allow track info to use more width on tablets: 98% of available screen width
        final maxContentWidth =
            screenWidth >= tabletThreshold
                ? screenWidth * 0.98
                : double.infinity;
        final horizontalPadding =
            screenWidth >= tabletThreshold
                ? ((screenWidth - maxContentWidth) / 2)
                    .clamp(4.0.w, 96.0.w)
                    .toDouble()
                : 0.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  screenWidth >= tabletThreshold
                      ? maxContentWidth
                      : double.infinity,
            ),
            child: Row(
              children: [
                // Left-aligned track info
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.mediaItem?.title ?? 'Unknown Title',
                          style: TextStyle(
                            fontSize: AppSizes.fontMedium,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.left,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8.w),
                        // Clickable artist names
                        Builder(
                          builder: (ctx) {
                            final names = _getCachedArtistNames();
                            final ids = _getCachedArtistIds();

                            if (names.isEmpty) {
                              return Text(
                                'Unknown Artist',
                                style: TextStyle(
                                  fontSize: AppSizes.fontSmall,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                textAlign: TextAlign.left,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                            return RichText(
                              text: TextSpan(
                                children: List.generate(names.length * 2 - 1, (
                                  i,
                                ) {
                                  if (i.isEven) {
                                    final idx = i ~/ 2;
                                    return TextSpan(
                                      text: names[idx],
                                      style: TextStyle(
                                        fontSize: AppSizes.fontMedium,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                      recognizer:
                                          TapGestureRecognizer()
                                            ..onTap = () {
                                              final artistId =
                                                  idx < ids.length
                                                      ? ids[idx]
                                                      : '';
                                              final artistName = names[idx];

                                              _onArtistTap(
                                                artistId,
                                                artistName,
                                              );
                                            },
                                    );
                                  } else {
                                    final sepIdx = i ~/ 2;
                                    final isLast = sepIdx == names.length - 2;
                                    return TextSpan(
                                      text: isLast ? ' and ' : ', ',
                                      style: TextStyle(
                                        fontSize: AppSizes.fontMedium,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    );
                                  }
                                }),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Three-dot menu icon - use FavoritesSelector to auto-rebuild when favorites change
                FavoritesSelector<bool>(
                  selector: (provider) {
                    final audioId =
                        widget.mediaItem?.extras?['audio_id']?.toString() ??
                        widget.mediaItem?.id ??
                        '';
                    return provider.isFavorite(audioId);
                  },
                  builder: (context, isFavoriteFromProvider, child) {
                    return ThreeDotMenuButton(
                      songId:
                          widget.mediaItem?.extras?['audio_id']?.toString() ??
                          widget.mediaItem?.id ??
                          '',
                      title: widget.mediaItem?.title ?? 'Unknown Title',
                      artist: _formatArtistNames(widget.mediaItem?.artist),
                      songImage: _extractSongImage(),
                      isFavorite: isFavoriteFromProvider,
                      onFavoriteToggle:
                          widget.onFavoriteToggle ?? _handleKeepSong,
                      onShare: widget.onShare ?? _handleShare,
                      onDownload: widget.onDownload ?? _handleDownload,
                      onAddToPlaylist:
                          widget.onAddToPlaylist ?? _handleAddToPlaylist,
                      onPlayNext: widget.onPlayNext ?? _handlePlayNext,
                      onAddToQueue: widget.onAddToQueue ?? _handleQueue,
                      onCreateStation:
                          widget.onCreateStation ?? _handleCreateStation,
                      showDeleteFromLibrary: false,
                      showRemoveFromRecent: false,
                      allowDownload: true,
                      useBottomSheet: false,
                      iconColor: Colors.white.withOpacity(0.8),
                      iconSize: 34.w,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Default handler methods
  void _handleKeepSong() async {
    if (widget.mediaItem?.extras?['audio_id'] != null) {
      try {
        final audioId = widget.mediaItem!.extras!['audio_id'].toString();

        // Try to find the DataMusic object for this song from global listCopy
        DataMusic? songData;
        try {
          songData = entry_point.listCopy.firstWhere(
            (song) => song.id.toString() == audioId,
          );
        } catch (e) {
          print(
            '🔥 TrackInfo: Song not found in listCopy, creating from MediaItem',
          );
          // Create DataMusic object from MediaItem as fallback
          final currentStatus =
              widget.mediaItem!.extras?['favourite']?.toString() ?? '0';
          songData = DataMusic(
            int.parse(audioId),
            widget.mediaItem!.extras?['image'] ?? '',
            widget.mediaItem!.extras?['actual_audio_url'] ??
                widget.mediaItem!.id,
            '3:00', // Default duration
            widget.mediaItem!.title,
            widget.mediaItem!.album ?? '',
            0,
            widget.mediaItem!.extras?['artist_id'] ?? '',
            widget.mediaItem!.artist ?? 'Unknown Artist',
            '',
            0,
            0,
            0,
            '',
            0,
            currentStatus,
            '',
            widget.mediaItem!.extras?['lyrics'] ?? '',
          );
        }

        final favoriteService = FavoriteService();
        await favoriteService.toggleFavoriteOptimistic(songData, () {
          // Force a rebuild to update the UI immediately
          if (mounted) {
            setState(() {
              // This will cause the widget to rebuild and _getCurrentFavoriteStatus()
              // will be called again, getting the updated favorite status
            });
          }
        });

        // CRITICAL: Update the MediaItem extras to reflect the new favorite status
        await _updateCurrentMediaItemFavoriteStatus(songData.favourite);
      } catch (e) {
        // Error handling removed to prevent log flooding
      }
    } else {
      // No audio ID available for favorite toggle
    }
  }

  void _handleShare() {
    if (widget.mediaItem != null) {
      SharingUtils.shareFromMediaItemSafe(widget.mediaItem, context: context);
    }
  }

  void _handleDownload() async {
    print('Download song initiated');

    if (widget.mediaItem == null) {
      print('No media item available for download');
      return;
    }

    try {
      final downloadController = DownloadController();

      // Extract audio ID from MediaItem extras
      final audioId = widget.mediaItem?.extras?['audio_id']?.toString() ?? '';
      if (audioId.isEmpty) {
        print('No audio ID available for download');
        return;
      }

      // Check if already downloaded
      final isDownloaded = downloadController.isTrackDownloaded(audioId);
      if (isDownloaded) {
        print('Track already downloaded');
        return;
      }

      // Check if currently downloading
      if (downloadController.isDownloading(audioId)) {
        print('Track is currently downloading');
        return;
      }

      // Create DataMusic object from MediaItem
      final track = DataMusic(
        int.parse(audioId),
        widget.mediaItem!.artUri?.toString() ?? '',
        widget.mediaItem?.extras?['actual_audio_url']?.toString() ?? '',
        widget.mediaItem!.duration?.inSeconds.toString() ?? '0',
        widget.mediaItem!.title,
        '', // audio_slug
        0, // audio_genre_id
        '', // artist_id
        widget.mediaItem!.artist ?? '',
        '', // audio_language
        0, // listening_count
        0, // is_featured
        0, // is_trending
        '', // created_at
        int.tryParse(
              widget.mediaItem?.extras?['favourite']?.toString() ?? '0',
            ) ??
            0, // favourite
        '', // lyrics
        '', // audio_slug
        '', // updated_at
      );

      print('Starting download for track: [1m${track.audio_title}[0m');

      // Start download
      final success = await downloadController.addToDownloads(audioId);

      if (success) {
        print('Download completed successfully');
      } else {
        print('Download failed');
      }
    } catch (e) {
      print('Download error: $e');
    }
  }

  void _handleAddToPlaylist() {
    print('Add to playlist');
  }

  void _handlePlayNext() {
    print('Play next track');
    // Use the same logic as playback controls - skip to next track
    if (widget.audioHandler != null) {
      widget.audioHandler!.skipToNext();
      print('Skipped to next track via audioHandler');
    } else {
      // Fallback to MusicManager if audioHandler is not available
      final musicManager = MusicManager();
      musicManager.skipToNext();
      print('Skipped to next track using MusicManager');
    }
  }

  void _handleQueue() {
    print('Show queue');
  }

  /// Handle create station functionality
  void _handleCreateStation() async {
    print('Create station initiated');

    if (widget.mediaItem == null) {
      print('No media item available for station creation');
      return;
    }

    try {
      // Extract audio ID from MediaItem extras
      final audioId = widget.mediaItem?.extras?['audio_id']?.toString() ?? '';
      if (audioId.isEmpty) {
        print('No audio ID available for station creation');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to create station: Missing track ID'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Find the current song in the global data
      DataMusic? currentSong;
      try {
        currentSong = entry_point.listCopy.firstWhere(
          (song) => song.id.toString() == audioId,
        );
      } catch (e) {
        print('Current song not found in listCopy, creating from MediaItem');
        // Create DataMusic object from MediaItem as fallback
        currentSong = DataMusic(
          int.parse(audioId),
          widget.mediaItem?.extras?['image'] ?? '',
          widget.mediaItem?.extras?['actual_audio_url'] ?? '',
          widget.mediaItem?.duration?.inMinutes.toString() ?? '3:00',
          widget.mediaItem?.title ?? 'Unknown Title',
          widget.mediaItem?.album ?? '',
          0,
          widget.mediaItem?.extras?['artist_id'] ?? '',
          widget.mediaItem?.artist ?? 'Unknown Artist',
          '',
          0,
          0,
          0,
          '',
          0,
          widget.mediaItem?.extras?['favourite'] ?? '0',
          '',
          widget.mediaItem?.extras?['lyrics'] ?? '',
        );
      }

      // Show loading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Creating station for "${widget.mediaItem!.title}"...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Use StationService to create the station
      final stationService = StationService();
      final success = await stationService.createStation(currentSong);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Station created! Playing similar songs to "${widget.mediaItem!.title}"',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create station. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Station creation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Station creation error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Extract song image filename from MediaItem's artUri
  String? _extractSongImage() {
    if (widget.mediaItem?.artUri != null) {
      final artUriString = widget.mediaItem!.artUri.toString();
      // Extract just the filename from the full image URL
      if (artUriString.contains('/thumb/')) {
        return artUriString.split('/thumb/').last;
      } else if (artUriString.contains('images/audio/thumb/')) {
        return artUriString.split('images/audio/thumb/').last;
      }
    }
    return null;
  }

  // Add helper to format multiple artist names
  // Format artist names: one name, or join with commas and 'and' before last
  String _formatArtistNames(String? rawArtists) {
    if (rawArtists == null || rawArtists.trim().isEmpty) {
      return 'Unknown Artist';
    }
    final parts =
        rawArtists
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    if (parts.length == 1) return parts[0];
    if (parts.length == 2) return '${parts[0]} and ${parts[1]}';
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }

  /// Retrieve raw artist string, preferring 'artists_name' from extras if available
  String? _getRawArtists() {
    // Check MediaItem extras first
    if (widget.mediaItem?.extras != null &&
        widget.mediaItem!.extras!.containsKey('artists_name') &&
        widget.mediaItem!.extras!['artists_name'] != null &&
        widget.mediaItem!.extras!['artists_name']
            .toString()
            .trim()
            .isNotEmpty) {
      return widget.mediaItem!.extras!['artists_name'].toString();
    }

    // Fallback to MediaItem artist
    return widget.mediaItem?.artist;
  }

  /// Get list of artist IDs by looking up the current song in MediaItem extras first, then fallback to global listCopy
  List<String> _getArtistIds() {
    // Primary: Try to get artist_id from MediaItem extras
    final extraRaw = widget.mediaItem?.extras?['artist_id']?.toString() ?? '';

    if (extraRaw.isNotEmpty) {
      try {
        if (extraRaw.startsWith('[') && extraRaw.endsWith(']')) {
          final decoded = jsonDecode(extraRaw) as List<dynamic>;
          return decoded.map((e) => e.toString()).toList();
        }
        return [extraRaw];
      } catch (e) {
        // If parsing fails, try as single value
        return [extraRaw];
      }
    }

    // Fallback: Look up in global listCopy
    final audioId = widget.mediaItem?.extras?['audio_id']?.toString();

    if (audioId == null) {
      return <String>[];
    }

    try {
      final songData = entry_point.listCopy.firstWhere(
        (song) => song.id.toString() == audioId,
      );

      final raw = songData.artist_id;

      if (raw.startsWith('[') && raw.endsWith(']')) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => e.toString()).toList();
      }
      return raw.isNotEmpty ? [raw] : <String>[];
    } catch (e) {
      return <String>[];
    }
  }

  /// Navigate to artist page for specific ID and name
  void _onArtistTap(String artistId, String artistName) async {
    print(
      '🎵 DEBUG: _onArtistTap called with artistId: "$artistId", artistName: "$artistName"',
    );

    if (artistId.isEmpty) {
      print('🎵 ERROR: Artist ID is empty, cannot navigate to artist page');

      // Show a user-friendly message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to find artist information for "$artistName"',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // TODO: In future, could implement search by artist name fallback
      // For now, just log and return
      print('🎵 INFO: Could implement search by artist name as fallback');
      return;
    }

    // Restore bottom nav + mini player flags
    MusicPlayerStateManager().hideFullPlayer();

    // Close the full player route first
    if (mounted) {
      Navigator.of(context).maybePop();
    }

    // Defer push into the current tab's nested navigator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = MaterialPageRoute(
        builder:
            (_) => ArtistDetailScreen(
              audioHandler: widget.audioHandler,
              idTag: artistId,
              typ: 'Artists',
              catName: artistName,
            ),
        settings: const RouteSettings(name: '/track_info_to_artist_songs'),
      );

      final pushed = TabNavigationService().pushOnCurrentTab(route);
      if (pushed == null) {
        // Fallback: if service not initialized, push on root to avoid losing navigation
        Navigator.of(context).push(route);
      }
    });
  }

  /// Update the current MediaItem's favorite status in the audio handler
  /// This ensures the UI stays consistent after favorite toggle
  Future<void> _updateCurrentMediaItemFavoriteStatus(
    String newFavoriteStatus,
  ) async {
    try {
      print(
        '🔥 TrackInfo: Updating MediaItem favorite status to: $newFavoriteStatus',
      );

      // Update the queue item with new extras
      // Note: We rely on the MusicManager's updateCurrentSongFavoriteStatus method
      // which handles this more efficiently than rebuilding the entire queue
      final musicManager = MusicManager();
      musicManager.updateCurrentSongFavoriteStatus(newFavoriteStatus);

      print('🔥 TrackInfo: Successfully updated MediaItem favorite status');
    } catch (e) {
      print(
        '🔥 ERROR TrackInfo: Failed to update MediaItem favorite status: $e',
      );
    }
  }
}
