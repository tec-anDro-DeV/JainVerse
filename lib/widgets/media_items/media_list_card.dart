import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/hooks/favorites_hook.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/visualizer_music_integration.dart';

import '../common/music_context_menu.dart';
import '../common/music_long_press_handler.dart';

/// List View Card for Songs - Text-first layout
/// Features:
/// - Small square thumbnail aligned to the left
/// - Thumbnail takes up about 1/4th of horizontal space
/// - Title (Song name) left-aligned, bold, usually one line
/// - Subtitle (Artist) positioned under title, lighter
/// - Navigation arrow on the far right
/// - Clean, readable, optimized for quick scanning
/// - Efficient for displaying long lists or search results
class MediaListCard extends StatefulWidget {
  /// Show a small primary color dot to the left of the image (for featured/trending/recommended)
  final bool showDot;
  final String? songId; // Add song ID for favorites management
  final String imagePath;
  final String songTitle;
  final String artistName;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final MusicManager musicManager; // Added for enhanced visualizer
  final double height;
  final bool? isFavorite; // Make optional - will use global provider if null
  final bool isPlaying;
  final bool isCurrent;
  final bool showNavigationArrow;
  final bool
  showVisualizer; // allow callers to disable visualizer for non-song types

  // Context menu callbacks
  final VoidCallback? onPlay;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;

  const MediaListCard({
    super.key,
    this.showDot = false,
    this.songId, // Optional song ID
    required this.imagePath,
    required this.songTitle,
    required this.artistName,
    required this.onTap,
    required this.sharedPreThemeData,
    required this.musicManager,
    this.height = 68,
    this.isFavorite, // Optional - will use global provider if null
    this.isPlaying = false,
    this.isCurrent = false,
    this.showNavigationArrow = true,
    this.showVisualizer = true,
    this.onPlay,
    this.onPlayNext,
    this.onAddToQueue,
    this.onDownload,
    this.onAddToPlaylist,
    this.onShare,
    this.onFavorite,
  });

  @override
  State<MediaListCard> createState() => _MediaListCardState();
}

class _MediaListCardState extends State<MediaListCard>
    with MusicCardLongPressHandler {
  bool _pressed = false;
  // Removed isPlaying-based pulse animation; visualizer handles motion

  @override
  void didUpdateWidget(MediaListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  MusicContextMenuData _createMenuData(bool isFavorite) {
    return MusicMenuDataFactory.createSongMenuData(
      title: widget.songTitle,
      artist: widget.artistName,
      imageUrl: widget.imagePath.isNotEmpty ? widget.imagePath : null,
      isFavorite: isFavorite, // Use passed favorite status
      onPlay: widget.onPlay,
      onPlayNext: widget.onPlayNext,
      onAddToQueue: widget.onAddToQueue,
      onDownload: widget.onDownload,
      onAddToPlaylist: widget.onAddToPlaylist,
      onShare: widget.onShare,
      onFavorite: widget.onFavorite,
    );
  }

  @override
  Widget build(BuildContext context) {
    // If songId is provided, use FavoritesSelector to auto-rebuild on favorites change
    if (widget.songId != null) {
      return FavoritesSelector<bool>(
        selector: (provider) => provider.isFavorite(widget.songId!),
        builder: (context, isFavoriteFromProvider, child) {
          return _buildCard(isFavoriteFromProvider);
        },
      );
    } else {
      // Fallback to static favorite status
      return _buildCard(widget.isFavorite ?? false);
    }
  }

  Widget _buildMenuButton(bool isFavorite) {
    return IconButton(
      padding: EdgeInsets.all(4.w),
      icon: Icon(
        Icons.more_vert,
        color: appColors().gray[500],
        size: AppSizes.iconSize * 0.8,
      ),
      onPressed: () => handleLongPress(menuData: _createMenuData(isFavorite)),
    );
  }

  Widget _buildCard(bool isFavorite) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildLongPressWrapper(
          menuData: _createMenuData(isFavorite),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius * 0.8),
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 1.03 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  height: widget.height.w,
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingXS),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AppSizes.borderRadius * 0.8,
                    ),
                    border: null,
                  ),
                  child: Row(
                    children: [
                      // Dot indicator for featured/trending/recommended
                      Container(
                        width: 8.w,
                        height: 8.w,
                        margin: EdgeInsets.only(right: 8.w),
                        decoration: BoxDecoration(
                          color:
                              widget.showDot
                                  ? appColors().primaryColorApp
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border:
                              widget.showDot
                                  ? null
                                  : Border.all(color: Colors.transparent),
                        ),
                      ),
                      // Thumbnail image - takes about 1/4 of horizontal space
                      _buildThumbnail(),

                      SizedBox(width: AppSizes.paddingM),

                      // Text area - takes most of the remaining space
                      Expanded(child: _buildTextArea()),

                      // Right side indicators and arrow
                      _buildRightSection(isFavorite),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingXS,
          ),
          child: Divider(height: 1, thickness: 0.8, color: Colors.grey[300]),
        ),
      ],
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 60.w,
      height: 60.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius * 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius * 0.6),
        child:
            widget.showVisualizer
                ? AutoManagedVisualizerOverlay(
                  show: widget.isCurrent, // Only show when current
                  musicManager:
                      widget
                          .musicManager, // Use music manager for auto state management
                  child:
                      widget.imagePath.isEmpty
                          ? Image.asset(
                            'assets/images/song_placeholder.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                          : CachedNetworkImage(
                            imageUrl: widget.imagePath,
                            fit: BoxFit.cover,
                            useOldImageOnUrlChange: true,
                            fadeInDuration: const Duration(milliseconds: 220),
                            placeholder:
                                (context, url) => Image.asset(
                                  'assets/images/song_placeholder.png',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                            errorWidget:
                                (context, url, error) => Image.asset(
                                  'assets/images/song_placeholder.png',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                          ),
                )
                : (widget.imagePath.isEmpty
                    ? Container(
                      color: appColors().gray[200],
                      child: Icon(
                        Icons.music_note,
                        size: 24.w,
                        color: appColors().gray[500],
                      ),
                    )
                    : CachedNetworkImage(
                      imageUrl: widget.imagePath,
                      fit: BoxFit.cover,
                      useOldImageOnUrlChange: true,
                      fadeInDuration: const Duration(milliseconds: 220),
                      placeholder:
                          (context, url) => Container(
                            color: appColors().gray[100],
                            child: Center(
                              child: SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: appColors().primaryColorApp,
                                ),
                              ),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            color: appColors().gray[200],
                            child: Icon(
                              Icons.music_note,
                              size: 24.w,
                              color: appColors().gray[500],
                            ),
                          ),
                    )),
      ),
    );
  }

  Widget _buildTextArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.songTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: AppSizes.fontMedium * 0.9,
            fontWeight: FontWeight.w500,
            color:
                widget.isCurrent
                    ? appColors().primaryColorApp
                    : ((widget.sharedPreThemeData.themeImageBack.isEmpty)
                        ? Color(int.parse(AppSettings.colorText))
                        : appColors().colorTextHead),
          ),
        ),

        if (widget.artistName.isNotEmpty) ...[
          SizedBox(height: 2.w),

          Text(
            widget.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: AppSizes.fontNormal * 0.9,
              fontWeight: FontWeight.w300,
              color:
                  (widget.sharedPreThemeData.themeImageBack.isEmpty)
                      ? Color(int.parse(AppSettings.colorText))
                      : appColors().colorText,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRightSection(bool isFavorite) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // For song items, show a context menu button (three dots)
        if (widget.onPlay != null)
          _buildMenuButton(isFavorite)
        // For others, show the navigation arrow if enabled
        else if (widget.showNavigationArrow)
          Icon(
            Icons.chevron_right,
            color: appColors().gray[500],
            size: AppSizes.iconSize * 0.8,
          ),
      ],
    );
  }
}
