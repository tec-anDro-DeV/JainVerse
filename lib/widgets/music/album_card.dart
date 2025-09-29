import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';

import '../common/image_with_fallback.dart';
import '../common/music_context_menu.dart';
import '../common/music_long_press_handler.dart';

class AlbumCard extends StatefulWidget {
  final String imagePath;
  final String albumName;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final double width;
  final double height;
  final String? artistName;

  // Context menu callbacks
  final VoidCallback? onShare;

  const AlbumCard({
    super.key,
    required this.imagePath,
    required this.albumName,
    required this.onTap,
    required this.sharedPreThemeData,
    this.width = 135,
    this.height = 135,
    this.artistName,
    this.onShare,
  });

  @override
  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> with MusicCardLongPressHandler {
  MusicContextMenuData _createMenuData() {
    return MusicMenuDataFactory.createAlbumMenuData(
      title: widget.albumName,
      artist: widget.artistName ?? 'Unknown Artist',
      imageUrl: widget.imagePath.isNotEmpty ? widget.imagePath : null,
      onShare: widget.onShare,
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildLongPressWrapper(
      menuData: _createMenuData(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkResponse(
            onTap: widget.onTap,
            child: Container(
              width: widget.width.w,
              height: widget.height.w,
              margin: EdgeInsets.all(6.w),
              child: ImageWithFallback(
                imageUrl: widget.imagePath,
                width: widget.width.w,
                height: widget.height.w,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                borderRadius: BorderRadius.circular(24.0),
                fallbackAsset: 'assets/images/song_placeholder.png',
                backgroundColor: Colors.grey,
              ),
            ),
          ),
          SizedBox(height: 2.w), // Further reduced spacing
          // Use Flexible to prevent overflow
          Flexible(
            child: Container(
              margin: EdgeInsets.fromLTRB(
                4.w,
                0,
                4.w,
                1.w,
              ), // Further reduced margins
              width: widget.width.w,
              child: Text(
                widget.albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: AppSizes.fontNormal * 0.95, // Slightly smaller font
                  fontWeight: FontWeight.w400,
                  height: 1.1, // Reduced line height
                  letterSpacing: -0.2,
                  color:
                      (widget.sharedPreThemeData.themeImageBack.isEmpty)
                          ? Color(int.parse(AppSettings.colorText))
                          : appColors().colorText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
