import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';

import '../common/image_with_fallback.dart';

class GenreCard extends StatefulWidget {
  final String imagePath;
  final String genreName;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final double width;
  final double height;

  const GenreCard({
    super.key,
    required this.imagePath,
    required this.genreName,
    required this.onTap,
    required this.sharedPreThemeData,
    this.width = 135,
    this.height = 135,
  });

  @override
  State<GenreCard> createState() => _GenreCardState();
}

class _GenreCardState extends State<GenreCard> {
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
    final double side = widget.width.w;
    final double borderRadius = side * 0.18;

    return SizedBox(
      width: side,
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: side,
                  height: side,
                  margin: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: ImageWithFallback(
                      imageUrl: widget.imagePath,
                      width: side,
                      height: side,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      borderRadius: BorderRadius.circular(borderRadius),
                      fallbackAsset: 'assets/images/song_placeholder.png',
                      backgroundColor: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4.w),
          Expanded(
            child: Container(
              margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 0.w),
              width: side,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.genreName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize:
                          AppSizes.fontNormal * 0.95, // Slightly smaller font
                      fontWeight: FontWeight.w400,
                      height: 1,
                      letterSpacing: -0.2,
                      color: appColors().colorText,
                    ),
                  ),
                  // description removed
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
