import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';

import '../common/image_with_fallback.dart';
import '../common/music_context_menu.dart';
import '../common/music_long_press_handler.dart';

class NewAlbumsCard extends StatefulWidget {
  final String imagePath;
  final String albumName;
  final String? artistName;
  final String? description;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final double width;
  final double height;

  // Context menu callbacks
  final VoidCallback? onShare;

  const NewAlbumsCard({
    super.key,
    required this.imagePath,
    required this.albumName,
    this.artistName,
    this.description,
    required this.onTap,
    required this.sharedPreThemeData,
    this.width = 200,
    this.height = 180,
    this.onShare,
  });

  @override
  State<NewAlbumsCard> createState() => _NewAlbumsCardState();
}

class _NewAlbumsCardState extends State<NewAlbumsCard>
    with MusicCardLongPressHandler {
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
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14.w),
        child: Container(
          width: widget.width.w,
          height: widget.height.w,
          margin: EdgeInsets.symmetric(
            horizontal: 6.w,
            vertical: 8.w,
          ), // Reduced margins for better balance
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.w),
            color: appColors().gray[100], // Light background for contrast
          ),
          child: Padding(
            padding: EdgeInsets.all(4.w), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image container
                Expanded(
                  flex: 3, // Give more space to image
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.w),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ImageWithFallback(
                            imageUrl: widget.imagePath,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            borderRadius: BorderRadius.circular(12.w),
                            fallbackAsset: 'assets/images/song_placeholder.png',
                            backgroundColor: Colors.white,
                          ),
                          // Subtle gradient overlay for better visual depth
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.w),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.03),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: 8.w,
                ), // Slightly reduced spacing between image and text
                // Enhanced text section with more flexible layout
                Expanded(
                  flex: 1, // Give less space to text
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize:
                          MainAxisSize.min, // Prevent extra vertical space
                      children: [
                        Text(
                          widget.albumName,
                          maxLines: 2, // Reduced to 2 lines to save space
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: AppSizes.fontNormal,
                            fontWeight: FontWeight.w500,
                            color:
                                (widget
                                        .sharedPreThemeData
                                        .themeImageBack
                                        .isEmpty)
                                    ? appColors().colorText
                                    : appColors().colorText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
