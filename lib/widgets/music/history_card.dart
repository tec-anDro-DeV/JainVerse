import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:provider/provider.dart';

import '../../providers/favorites_provider.dart';
import '../common/image_with_fallback.dart';
import '../common/music_context_menu.dart';
import '../common/music_long_press_handler.dart';

class HistoryCard extends StatefulWidget {
  final String imagePath;
  final String songName;
  final String artistName;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final double width;
  final double height;
  final String songId; // Changed from isFavorite to songId

  // Context menu callbacks
  final VoidCallback? onPlay;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;

  const HistoryCard({
    super.key,
    required this.imagePath,
    required this.songName,
    required this.artistName,
    required this.onTap,
    required this.sharedPreThemeData,
    required this.songId, // Made required
    this.width = 135,
    this.height = 135,
    this.onPlay,
    this.onPlayNext,
    this.onAddToQueue,
    this.onDownload,
    this.onAddToPlaylist,
    this.onShare,
    this.onFavorite,
  });

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard>
    with MusicCardLongPressHandler {
  bool _pressed = false;

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

  @override
  Widget build(BuildContext context) {
    final double cardWidth = widget.width.w;
    final double cardHeight = widget.height.w;

    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        final isFavorite = favoritesProvider.isFavorite(widget.songId);

        return buildLongPressWrapper(
          menuData: _createMenuData(isFavorite),
          child: SizedBox(
            width: cardWidth,
            height: cardHeight + 50.w, // Add space for text
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24.0),
                    onTap: widget.onTap,
                    onTapDown: _onTapDown,
                    onTapUp: _onTapUp,
                    onTapCancel: _onTapCancel,
                    child: AnimatedScale(
                      scale: _pressed ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: Container(
                        width: cardWidth,
                        height: cardHeight,
                        margin: EdgeInsets.all(5.w),
                        child: ImageWithFallback(
                          imageUrl: widget.imagePath,
                          width: cardWidth,
                          height: cardHeight,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          borderRadius: BorderRadius.circular(24.0),
                          fallbackAsset: 'assets/images/song_placeholder.png',
                          backgroundColor: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.fromLTRB(5.w, 2, 5.w, 0),
                  width: cardWidth,
                  child: Text(
                    widget.songName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: AppSizes.fontNormal,
                      fontWeight: FontWeight.w600,
                      color:
                          (widget.sharedPreThemeData.themeImageBack.isEmpty)
                              ? appColors().colorText
                              : appColors().colorText,
                    ),
                  ),
                ),
                if (widget.artistName.isNotEmpty)
                  Container(
                    margin: EdgeInsets.fromLTRB(5.w, 2, 5.w, 0),
                    width: cardWidth,
                    child: Text(
                      widget.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: AppSizes.fontSmall,
                        color: appColors().gray[500],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  MusicContextMenuData _createMenuData(bool isFavorite) {
    return MusicMenuDataFactory.createSongMenuData(
      title: widget.songName,
      artist:
          widget.artistName.isNotEmpty ? widget.artistName : 'Unknown Artist',
      imageUrl: widget.imagePath.isNotEmpty ? widget.imagePath : null,
      onPlay: widget.onPlay,
      onPlayNext: widget.onPlayNext,
      onAddToQueue: widget.onAddToQueue,
      onDownload: widget.onDownload,
      onAddToPlaylist: widget.onAddToPlaylist,
      onShare: widget.onShare,
      onFavorite: widget.onFavorite,
      isFavorite: isFavorite, // Use parameter from selector
    );
  }
}
