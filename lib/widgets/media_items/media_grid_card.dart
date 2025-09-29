import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/visualizer_music_integration.dart';
import 'package:provider/provider.dart';

import '../../providers/favorites_provider.dart';
import '../common/music_context_menu.dart';
import '../common/music_long_press_handler.dart';

/// Grid View Card for Songs - Visual-first layout
/// Features:
/// - Square-shaped image with rounded corners
/// - Image fills most of the card space
/// - Title (Song name) center-aligned below image
/// - Subtitle (Artist name) center-aligned below title
/// - Compact and symmetrical design
/// - Optimized for quick browsing where artwork helps identify the song
class MediaGridCard extends StatefulWidget {
  final String imagePath;
  final String songTitle;
  final String artistName;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final MusicManager musicManager; // Added for enhanced visualizer
  final double width;
  final double height;
  final String songId; // Changed from isFavorite to songId
  final bool isPlaying;
  final bool
  isCurrent; // current item indicator (shows static visualizer when paused)
  final bool
  showVisualizer; // allow callers to disable visualizer for non-song types
  final bool isSong; // hint for denser spacing when content is songs

  // Context menu callbacks
  final VoidCallback? onPlay;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;

  const MediaGridCard({
    super.key,
    required this.imagePath,
    required this.songTitle,
    required this.artistName,
    required this.onTap,
    required this.sharedPreThemeData,
    required this.musicManager, // Added required parameter
    required this.songId, // Made required
    this.width = 150,
    this.height = 250,
    this.isPlaying = false,
    this.isCurrent = false,
    this.showVisualizer = true,
    this.isSong = false,
    this.onPlay,
    this.onPlayNext,
    this.onAddToQueue,
    this.onDownload,
    this.onAddToPlaylist,
    this.onShare,
    this.onFavorite,
  });

  @override
  State<MediaGridCard> createState() => _MediaGridCardState();
}

class _MediaGridCardState extends State<MediaGridCard>
    with MusicCardLongPressHandler {
  bool _pressed = false;

  @override
  void didUpdateWidget(MediaGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        final isFavorite = favoritesProvider.isFavorite(widget.songId);

        return buildLongPressWrapper(
          menuData: _createMenuData(isFavorite),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Padding(
                  // Slightly reduced padding to reclaim vertical space
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Main image container - maintains 1:1 aspect ratio
                      _buildImageContainer(),
                      SizedBox(height: 6.w),
                      // Allow text area to shrink when space is tight to avoid overflow
                      Flexible(fit: FlexFit.loose, child: _buildTextArea()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  MusicContextMenuData _createMenuData(bool isFavorite) {
    return MusicMenuDataFactory.createSongMenuData(
      title: widget.songTitle,
      artist: widget.artistName,
      imageUrl: widget.imagePath.isNotEmpty ? widget.imagePath : null,
      isFavorite: isFavorite, // Use parameter from provider
      onPlay: widget.onPlay,
      onPlayNext: widget.onPlayNext,
      onAddToQueue: widget.onAddToQueue,
      onDownload: widget.onDownload,
      onAddToPlaylist: widget.onAddToPlaylist,
      onShare: widget.onShare,
      onFavorite: widget.onFavorite,
    );
  }

  Widget _buildImageContainer() {
    // Calculate the available width for the image container
    // This ensures consistent square sizing regardless of image content
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use both width and height constraints to prevent vertical overflow
        final double maxW = constraints.maxWidth;
        final double maxH = constraints.maxHeight;

        // Reserve vertical space for the text area below the image.
        // For song content, allow a denser layout (smaller reserved area).
        final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
        final double reservedTextHeight =
            widget.isSong
                ? (isTablet ? 32.w : 28.w)
                : (isTablet ? 40.w : 36.w); // title + artist + spacing

        // Choose the smaller of width and available height minus reserved text
        double imageSize = min(
          maxW,
          (maxH - reservedTextHeight).clamp(0.0, double.infinity),
        );

        // If available height is too small, fall back to using width
        if (imageSize <= 0) imageSize = maxW;

        return SizedBox(
          width: imageSize,
          height: imageSize,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                child:
                    widget.showVisualizer
                        ? AutoManagedVisualizerOverlay(
                          show: widget.isCurrent, // Only show when current
                          musicManager:
                              widget
                                  .musicManager, // Use music manager for auto state management
                          child: SizedBox(
                            width: imageSize,
                            height: imageSize,
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
                                      width: imageSize,
                                      height: imageSize,
                                      fit: BoxFit.cover,
                                      useOldImageOnUrlChange: true,
                                      fadeInDuration: const Duration(
                                        milliseconds: 250,
                                      ),
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
                          ),
                        )
                        : SizedBox(
                          width: imageSize,
                          height: imageSize,
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
                                    width: imageSize,
                                    height: imageSize,
                                    fit: BoxFit.cover,
                                    useOldImageOnUrlChange: true,
                                    fadeInDuration: const Duration(
                                      milliseconds: 250,
                                    ),
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
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextArea() {
    // Allow more flexible sizing to avoid tiny pixel overflow on some devices
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 56.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title wrapped in Flexible to ensure it can shrink when needed
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              widget.songTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                // Slightly reduce the font size and line height to prevent overflow
                fontSize:
                    widget.isSong
                        ? (AppSizes.fontNormal - 2)
                        : (AppSizes.fontNormal - 1),
                height: 1.1,
                fontWeight: FontWeight.w600,
                color:
                    (widget.sharedPreThemeData.themeImageBack.isEmpty)
                        ? Color(int.parse(AppSettings.colorText))
                        : appColors().colorTextHead,
              ),
            ),
          ),

          if (widget.artistName.isNotEmpty) ...[
            SizedBox(height: 4.w),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                widget.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: AppSizes.fontSmall,
                  height: 1.05,
                  fontWeight: FontWeight.w400,
                  color:
                      (widget.sharedPreThemeData.themeImageBack.isEmpty)
                          ? Color(int.parse(AppSettings.colorText))
                          : appColors().colorText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
