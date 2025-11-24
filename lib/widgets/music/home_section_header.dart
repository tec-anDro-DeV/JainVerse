import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAllPressed;
  final ModelTheme sharedPreThemeData;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.onViewAllPressed,
    required this.sharedPreThemeData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(18.w, 5.w, 18.w, 5.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: AppSizes.fontMedium,
              fontWeight: FontWeight.w600,
              color: (sharedPreThemeData.themeImageBack.isEmpty)
                  ? appColors().colorText
                  : appColors().colorText,
            ),
          ),
          InkResponse(
            onTap: onViewAllPressed,
            child: Text(
              'View All',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: AppSizes.fontSmall,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: appColors().primaryColorApp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
