import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/sizes.dart';

class CircularCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final VoidCallback onTap;
  final ModelTheme sharedPreThemeData;
  final double size;
  final String? subtitle;

  const CircularCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.onTap,
    required this.sharedPreThemeData,
    this.size = 92,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveSize = size.w;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(responsiveSize / 2),
              image: DecorationImage(
                image:
                    imagePath.isEmpty
                        ? const AssetImage('assets/images/song_placeholder.png')
                        : NetworkImage(imagePath) as ImageProvider,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            width: responsiveSize,
            height: responsiveSize,
          ),
        ),
        SizedBox(height: 4.w), // Further reduced spacing
        // Use Flexible to prevent overflow
        Flexible(
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: 4.w,
            ), // Further reduced margin
            width: responsiveSize,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: AppSizes.fontNormal * 0.9, // Slightly smaller font
                height: 1, // Reduced line height
                color:
                    (sharedPreThemeData.themeImageBack.isEmpty)
                        ? Color(int.parse(AppSettings.colorText))
                        : appColors().colorText,
              ),
            ),
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: 1.w), // Further reduced spacing
          Flexible(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: 2.w,
              ), // Further reduced margin
              width: responsiveSize,
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: AppSizes.fontSmall * 0.9, // Slightly smaller font
                  height: 1.1, // Reduced line height
                  color:
                      (sharedPreThemeData.themeImageBack.isEmpty)
                          ? Color(int.parse(AppSettings.colorText))
                          : appColors().colorText,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
