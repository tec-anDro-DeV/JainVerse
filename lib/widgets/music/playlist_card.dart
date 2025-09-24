import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import '../common/image_with_fallback.dart';
import '../common/music_context_menu.dart';
import '../common/music_long_press_handler.dart';

class PlaylistCard extends StatefulWidget {
  final String imagePath;
  final String name;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final double width;
  final double height;
  final String? songCount;

  // Context menu callbacks
  final VoidCallback? onShare;
  final VoidCallback? onRemove;

  const PlaylistCard({
    super.key,
    required this.imagePath,
    required this.name,
    required this.onTap,
    required this.sharedPreThemeData,
    this.width = 155.0,
    this.height = 165.0,
    this.songCount,
    this.onShare,
    this.onRemove,
  });

  @override
  State<PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<PlaylistCard>
    with MusicCardLongPressHandler {
  MusicContextMenuData _createMenuData() {
    return MusicMenuDataFactory.createPlaylistMenuData(
      title: widget.name,
      songCount: widget.songCount ?? 'Playlist',
      imageUrl: widget.imagePath.isNotEmpty ? widget.imagePath : null,
      onShare: widget.onShare,
      onRemove: widget.onRemove,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double side = widget.width.w; // Use width for both sides
    final double borderRadius = side * 0.10; // 10% of side, adjustable

    return buildLongPressWrapper(
      menuData: _createMenuData(),
      child: SizedBox(
        width: side,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: EdgeInsets.all(5.w),
                child: InkResponse(
                  onTap: widget.onTap,
                  child: ImageWithFallback(
                    imageUrl: widget.imagePath,
                    width: side,
                    height: side,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    borderRadius: BorderRadius.circular(borderRadius),
                    fallbackAsset: 'assets/images/song_placeholder.png',
                    backgroundColor: Colors.grey,
                  ),
                ),
              ),
            ),
            SizedBox(height: 4.w),
            Container(
              height: 28.w,
              width: side,
              padding: EdgeInsets.symmetric(horizontal: 3.w),
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: AppSizes.fontNormal,
                  fontWeight: FontWeight.w500,
                  color:
                      (widget.sharedPreThemeData.themeImageBack.isEmpty)
                          ? Color(int.parse(AppSettings.colorText))
                          : appColors().colorText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
