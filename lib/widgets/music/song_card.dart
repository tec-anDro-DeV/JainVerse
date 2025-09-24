import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/hooks/favorites_hook.dart';
import '../common/music_context_menu.dart';
import '../common/music_long_press_handler.dart';
import '../common/image_with_fallback.dart';

class SongCard extends StatefulWidget {
  final String? songId; // Add song ID for favorites management
  final String imagePath;
  final String songName;
  final String? artistName;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final double width;
  final double height;
  final bool? isFavorite; // Make optional - will use global provider if null
  final bool enableContextMenu; // Allow disabling internal context menu

  // Context menu callbacks
  final VoidCallback? onPlay;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;

  const SongCard({
    super.key,
    this.songId, // Optional song ID
    required this.imagePath,
    required this.songName,
    this.artistName,
    required this.onTap,
    required this.sharedPreThemeData,
    this.width = 135,
    this.height = 140,
    this.isFavorite, // Optional - will use global provider if null
    this.enableContextMenu = true, // Enabled by default to preserve behavior
    this.onPlay,
    this.onPlayNext,
    this.onAddToQueue,
    this.onDownload,
    this.onAddToPlaylist,
    this.onShare,
    this.onFavorite,
  });

  @override
  State<SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<SongCard> with MusicCardLongPressHandler {
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

  MusicContextMenuData _createMenuData(bool isFavorite) {
    return MusicMenuDataFactory.createSongMenuData(
      title: widget.songName,
      artist: widget.artistName ?? 'Unknown Artist',
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

  @override
  Widget build(BuildContext context) {
    final double side = widget.width.w;
    final double borderRadius = side * 0.18;

    // If songId is provided, use FavoritesSelector to auto-rebuild on favorites change
    if (widget.songId != null) {
      return FavoritesSelector<bool>(
        selector: (provider) => provider.isFavorite(widget.songId!),
        builder: (context, isFavoriteFromProvider, child) {
          return _buildCard(side, borderRadius, isFavoriteFromProvider);
        },
      );
    } else {
      // Fallback to static favorite status
      return _buildCard(side, borderRadius, widget.isFavorite ?? false);
    }
  }

  Widget _buildCard(double side, double borderRadius, bool isFavorite) {
    final cardContent = SizedBox(
      width: side,
      height: widget.height, // Use the provided height
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: widget.onTap,
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onTapCancel: _onTapCancel,
              child: AnimatedScale(
                scale: _pressed ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    width: side,
                    height: side,
                    margin: EdgeInsets.all(6.w),
                    child: ImageWithFallback(
                      imageUrl: widget.imagePath,
                      width: side,
                      height: side,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      borderRadius: BorderRadius.circular(borderRadius),
                      fallbackAsset: 'assets/images/song_placeholder.png',
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 2.w), // Reduced spacing
          Flexible(
            child: Container(
              margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 0), // No bottom margin
              width: side,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    widget.songName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: AppSizes.fontNormal, // Reduced font size
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                      letterSpacing: -0.2,
                      color:
                          (widget.sharedPreThemeData.themeImageBack.isEmpty)
                              ? Color(int.parse(AppSettings.colorText))
                              : appColors().colorText,
                    ),
                  ),
                  if (widget.artistName != null &&
                      widget.artistName!.isNotEmpty) ...[
                    SizedBox(height: 2.w), // Further reduced spacing
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text(
                        widget.artistName!,
                        maxLines: 1, // Reduced to 1 line to prevent overflow
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize:
                              AppSizes.fontSmall * 0.90, // Reduced font size
                          fontWeight: FontWeight.w400,
                          height: 1.0, // Slightly reduced line height
                          color:
                              (widget.sharedPreThemeData.themeImageBack.isEmpty)
                                  ? Color(
                                    int.parse(AppSettings.colorText),
                                  ).withOpacity(0.7)
                                  : appColors().colorText.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.enableContextMenu) {
      return buildLongPressWrapper(
        menuData: _createMenuData(isFavorite),
        child: cardContent,
      );
    } else {
      return cardContent;
    }
  }
}
