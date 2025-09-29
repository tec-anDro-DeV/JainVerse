import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/hooks/favorites_hook.dart';

import '../common/image_with_fallback.dart';
import '../common/music_context_menu.dart';
import '../common/music_long_press_handler.dart';

class PopularSongCard extends StatefulWidget {
  final String? songId; // Add song ID for favorites management
  final String imagePath;
  final String songName;
  final String? artistName;
  final String? listenerCount;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final double width;
  final double height;
  final bool isCompact;
  final bool? isFavorite; // Make optional - will use global provider if null

  // Context menu callbacks
  final VoidCallback? onPlay;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;

  const PopularSongCard({
    super.key,
    this.songId, // Optional song ID
    required this.imagePath,
    required this.songName,
    this.artistName,
    this.listenerCount,
    required this.onTap,
    required this.sharedPreThemeData,
    this.width = 320,
    this.height = 130,
    this.isCompact = false,
    this.isFavorite, // Optional - will use global provider if null
    this.onPlay,
    this.onPlayNext,
    this.onAddToQueue,
    this.onDownload,
    this.onAddToPlaylist,
    this.onShare,
    this.onFavorite,
  });

  @override
  State<PopularSongCard> createState() => _PopularSongCardState();
}

class _PopularSongCardState extends State<PopularSongCard>
    with MusicCardLongPressHandler {
  bool _pressed = false;

  MusicContextMenuData _createMenuData(bool isFavorite) {
    return MusicMenuDataFactory.createSongMenuData(
      title: widget.songName,
      artist: widget.artistName ?? '',
      imageUrl: widget.imagePath.isNotEmpty ? widget.imagePath : null,
      onPlay: widget.onPlay,
      onPlayNext: widget.onPlayNext,
      onAddToQueue: widget.onAddToQueue,
      onDownload: widget.onDownload,
      onAddToPlaylist: widget.onAddToPlaylist,
      onShare: widget.onShare,
      onFavorite: widget.onFavorite,
      isFavorite: isFavorite, // Use passed favorite status
    );
  }

  Widget _buildWithContextMenu({
    required Widget child,
    required bool isFavorite,
  }) {
    return buildLongPressWrapper(
      child: child,
      menuData: _createMenuData(isFavorite),
    );
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _pressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _pressed = false;
    });
  }

  void _onTapCancel() {
    setState(() {
      _pressed = false;
    });
  }

  Color _getTextColor(double opacity) {
    final baseColor =
        (widget.sharedPreThemeData.themeImageBack.isEmpty)
            ? Color(int.parse(AppSettings.colorText))
            : appColors().colorText;
    return baseColor.withOpacity(opacity);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Use less width for the card by default so it appears narrower on tablets
    final responsiveWidth =
        widget.isCompact ? screenWidth * 0.86 : screenWidth * 0.70;
    final margin = EdgeInsets.only(left: 10.w, right: 6.w);
    final padding = EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 8.w);

    // If songId is provided, use FavoritesSelector to auto-rebuild on favorites change
    if (widget.songId != null) {
      return FavoritesSelector<bool>(
        selector: (provider) => provider.isFavorite(widget.songId!),
        builder: (context, isFavoriteFromProvider, child) {
          return _buildCard(
            margin,
            padding,
            responsiveWidth,
            isFavoriteFromProvider,
          );
        },
      );
    } else {
      // Fallback to static favorite status
      return _buildCard(
        margin,
        padding,
        responsiveWidth,
        widget.isFavorite ?? false,
      );
    }
  }

  Widget _buildCard(
    EdgeInsets margin,
    EdgeInsets padding,
    double responsiveWidth,
    bool isFavorite,
  ) {
    // Cap the width for tablet/large screens so card doesn't stretch too wide.
    final double maxCardWidth = 420.w; // reduce maximum card width for tablets
    final double constrainedWidth = responsiveWidth.clamp(0, maxCardWidth);

    final Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(25.w),
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedScale(
          scale: _pressed ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            width: constrainedWidth,
            height: widget.height,
            margin: margin,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25.w),
              color: appColors().gray[100],
            ),
            child: Row(
              children: [
                // Left content (text + play button)
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: EdgeInsets.only(right: 12.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.songName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: AppSizes.fontMedium,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                            letterSpacing: -0.2,
                            color: _getTextColor(1.0),
                          ),
                        ),
                        SizedBox(height: 6.w),
                        if (widget.artistName != null &&
                            widget.artistName!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 2.w),
                            child: Text(
                              widget.artistName!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: AppSizes.fontSmall,
                                fontWeight: FontWeight.w400,
                                height: 1,
                                color: _getTextColor(0.7),
                              ),
                            ),
                          ),
                        if (widget.listenerCount != null &&
                            widget.listenerCount!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 2.w),
                            child: Text(
                              widget.listenerCount!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                                height: 1.1,
                                color: _getTextColor(0.6),
                              ),
                            ),
                          ),
                        const Spacer(),
                        Container(
                          width: 46.w,
                          height: 46.w,
                          decoration: BoxDecoration(
                            color: appColors().white,
                            borderRadius: BorderRadius.circular(21.w),
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: appColors().gray[600],
                            size: 30.w,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right image - compute an explicit square size so the image never becomes rectangular
                Builder(
                  builder: (context) {
                    // Calculate available inner height of the card (account for padding)
                    final double verticalPadding = padding.top + padding.bottom;
                    final double availableHeight = (widget.height -
                            verticalPadding)
                        .clamp(0.0, double.infinity);

                    // Derive a target width from a fraction of the card width
                    final double imageMaxWidth = constrainedWidth * 0.36;

                    // On small screens, prefer a larger minimum so the image doesn't look tiny
                    final double screenWidthLocal =
                        MediaQuery.of(context).size.width;
                    final double minImageSize =
                        screenWidthLocal < 360 ? 110.0 : 80.0;

                    // Choose the smaller of the two so image fits inside the card height and width
                    double imageSize =
                        imageMaxWidth < availableHeight
                            ? imageMaxWidth
                            : availableHeight;

                    // Clamp to reasonable bounds (logical pixels) to avoid extremes
                    imageSize = imageSize.clamp(minImageSize, 220.0);

                    return SizedBox(
                      width: imageSize,
                      height: imageSize,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.w),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15.w,
                              offset: Offset(0, 5.w),
                              spreadRadius: -2.w,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24.w),
                          child: ImageWithFallback(
                            imageUrl: widget.imagePath,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            borderRadius: BorderRadius.circular(24.w),
                            fallbackAsset: 'assets/images/song_placeholder.png',
                            backgroundColor: appColors().gray[100],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Container(
      alignment: Alignment.centerLeft,
      child: _buildWithContextMenu(isFavorite: isFavorite, child: card),
    );
  }
}
