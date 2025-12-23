import 'package:audio_service/audio_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/MusicEntryPoint.dart' as entry_point;
import 'package:jainverse/videoplayer/screens/channel_detail_screen.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/hooks/favorites_hook.dart';
import 'package:jainverse/controllers/music/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart'; // Import for AudioPlayerHandler
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/services/station_service.dart';
import 'package:jainverse/services/tab_navigation_service.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/utils/sharing_utils.dart'; // Import sharing utility
import 'package:jainverse/widgets/musicplayer/three_dot_options_menu.dart';

/// Modern track info widget displaying song title, channel, and menu options
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
  // Cache channel information to prevent recalculations
  List<String>? _cachedChannelNames;
  String? _lastMediaItemId;

  @override
  void initState() {
    super.initState();
    // Listen to audio handler stream to rebuild when MediaItem changes
    if (widget.audioHandler != null) {
      widget.audioHandler!.mediaItem.listen((_) {
        if (mounted) {
          // Clear cache when MediaItem changes
          _clearChannelCache();
          setState(() {
            // Rebuild when MediaItem changes
          });
        }
      });
    }
  }

  void _clearChannelCache() {
    _cachedChannelNames = null;
    _lastMediaItemId = null;
  }

  List<String> _getCachedChannelNames() {
    final currentMediaItemId = widget.mediaItem?.id;

    // Return cached data if available and MediaItem hasn't changed
    if (_cachedChannelNames != null && _lastMediaItemId == currentMediaItemId) {
      return _cachedChannelNames!;
    }

    // Recalculate and cache
    final raw = _getRawChannelNames() ?? '';
    _cachedChannelNames = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _lastMediaItemId = currentMediaItemId;

    return _cachedChannelNames!;
  }

  @override
  Widget build(BuildContext context) {
    return FavoritesConsumer(
      builder: (context, favoritesHook, child) {
        // Constrain and center on larger screens (iPad/tablet)
        final screenWidth = MediaQuery.of(context).size.width;
        const tabletThreshold = 600.0;
        // Allow track info to use more width on tablets: 98% of available screen width
        final maxContentWidth = screenWidth >= tabletThreshold
            ? screenWidth * 0.98
            : double.infinity;
        final horizontalPadding = screenWidth >= tabletThreshold
            ? ((screenWidth - maxContentWidth) / 2)
                  .clamp(4.0.w, 96.0.w)
                  .toDouble()
            : 0.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth >= tabletThreshold
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
                        // Clickable channel names
                        Builder(
                          builder: (ctx) {
                            final names = _getCachedChannelNames();

                            if (names.isEmpty) {
                              return Text(
                                'Unknown Channel',
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
                                    final displayName = names[idx];
                                    return TextSpan(
                                      text: displayName,
                                      style: TextStyle(
                                        fontSize: AppSizes.fontMedium,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          _onChannelTap(displayName);
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
                      artist: _formatChannelNames(_getRawChannelNames()),
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
          songData = SongModel.legacy(
            int.parse(audioId),
            widget.mediaItem!.extras?['image'] ?? '',
            widget.mediaItem!.extras?['actual_audio_url'] ??
                widget.mediaItem!.id,
            '3:00', // Default duration
            widget.mediaItem!.title,
            widget.mediaItem!.album ?? '',
            0,
            widget.mediaItem!.extras?['channel_id']?.toString() ?? '',
            _getRawChannelNames() ?? 'Unknown Channel',
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
      final track = SongModel.legacy(
        int.parse(audioId),
        widget.mediaItem!.artUri?.toString() ?? '',
        widget.mediaItem?.extras?['actual_audio_url']?.toString() ?? '',
        widget.mediaItem!.duration?.inSeconds.toString() ?? '0',
        widget.mediaItem!.title,
        '', // audio_slug
        0, // audio_genre_id
        widget.mediaItem?.extras?['channel_id']?.toString() ?? '', // channel_id
        _getRawChannelNames() ?? '',
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
            SnackBar(
              content: Text('Unable to create station: Missing track ID'),
              backgroundColor: appColors().primaryColorApp,
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
        currentSong = SongModel.legacy(
          int.parse(audioId),
          widget.mediaItem?.extras?['image'] ?? '',
          widget.mediaItem?.extras?['actual_audio_url'] ?? '',
          widget.mediaItem?.duration?.inMinutes.toString() ?? '3:00',
          widget.mediaItem?.title ?? 'Unknown Title',
          widget.mediaItem?.album ?? '',
          0,
          widget.mediaItem?.extras?['channel_id']?.toString() ?? '',
          _getRawChannelNames() ?? 'Unknown Channel',
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
            SnackBar(
              content: Text('Failed to create station. Please try again.'),
              backgroundColor: appColors().primaryColorApp,
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
            backgroundColor: appColors().primaryColorApp,
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

  // Add helper to format multiple channel names if needed
  // Format channel names: one name, or join with commas and 'and' before last
  String _formatChannelNames(String? rawChannels) {
    if (rawChannels == null || rawChannels.trim().isEmpty) {
      return 'Unknown Channel';
    }
    final parts = rawChannels
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts[0];
    if (parts.length == 2) return '${parts[0]} and ${parts[1]}';
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }

  /// Retrieve raw channel string, preferring channel-specific extras values.
  String? _getRawChannelNames() {
    final extras = widget.mediaItem?.extras;
    if (extras == null) return null;

    const channelKeys = [
      'channel_name',
      'channelName',
      'channelname',
      'artists_name',
      'artistName',
      'artist_name',
    ];

    for (final key in channelKeys) {
      final candidate = extras[key];
      if (candidate == null) continue;
      final trimmed = candidate.toString().trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  int? _parseIdValue(dynamic rawValue) {
    if (rawValue == null) return null;
    if (rawValue is int) return rawValue;
    if (rawValue is double) return rawValue.toInt();
    if (rawValue is String) {
      final trimmed = rawValue.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    if (rawValue is List && rawValue.isNotEmpty) {
      return _parseIdValue(rawValue.first);
    }
    return null;
  }

  int? _extractChannelId() {
    final extras = widget.mediaItem?.extras;
    if (extras == null) return null;

    const idKeys = ['channel_id', 'channelId', 'artist_id', 'artistId'];

    for (final key in idKeys) {
      final parsed = _parseIdValue(extras[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Navigate to the channel detail screen for the current song
  void _onChannelTap(String channelName) async {
    final channelId = _extractChannelId();
    print(
      '🎵 DEBUG: _onChannelTap called for channel "$channelName" with id $channelId',
    );

    if (channelId == null) {
      print('🎵 ERROR: Channel ID is missing, cannot open channel screen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to find channel information for "$channelName"',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    MusicPlayerStateManager().hideFullPlayer();

    if (mounted) {
      Navigator.of(context).maybePop();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = MaterialPageRoute(
        builder: (_) =>
            ChannelVideosScreen(channelId: channelId, channelName: channelName),
        settings: const RouteSettings(name: '/track_info_to_channel_videos'),
      );

      final pushed = TabNavigationService().pushOnCurrentTab(route);
      if (pushed == null) {
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
