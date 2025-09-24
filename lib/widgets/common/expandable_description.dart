import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/gestures.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

import 'package:jainverse/ThemeMain/sizes.dart';

class ExpandableDescription extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const ExpandableDescription({
    Key? key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We want to show 'more' at the end of the second line if text overflows
    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultStyle = style ?? Theme.of(context).textTheme.bodyMedium;
        final moreStyle = defaultStyle?.copyWith(
          color: appColors().primaryColorApp,
          fontWeight: FontWeight.bold,
        );
        final align = TextAlign.center;

        // Use TextPainter to check if text overflows 2 lines
        final textSpan = TextSpan(text: text, style: defaultStyle);
        final tp = TextPainter(
          text: textSpan,
          maxLines: 2,
          textDirection: TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);
        final isOverflowing = tp.didExceedMaxLines;

        if (!isOverflowing) {
          // No overflow, just show the text
          return Text(
            text,
            style: defaultStyle,
            textAlign: align,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        }

        // If overflowing, show 'more' at the end of the second line
        return GestureDetector(
          onTap: () => _showFullDescriptionModal(context),
          child: RichText(
            textAlign: align,
            text: TextSpan(
              style: defaultStyle,
              children: [
                TextSpan(
                  text: _truncateToFit(
                    text,
                    defaultStyle!,
                    moreStyle!,
                    constraints.maxWidth,
                  ),
                ),
                TextSpan(
                  text: ' more',
                  style: moreStyle,
                  recognizer:
                      TapGestureRecognizer()
                        ..onTap = () => _showFullDescriptionModal(context),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  // Helper to truncate text so that ' more' fits at the end of line 2
  String _truncateToFit(
    String text,
    TextStyle textStyle,
    TextStyle moreStyle,
    double maxWidth,
  ) {
    final moreText = ' more';
    final ellipsis = '\u2026';
    // We want to fit: [truncated text][ellipsis][space][more]
    // So, measure the width of ellipsis + more first
    final moreSpan = TextSpan(text: '$ellipsis$moreText', style: moreStyle);
    final morePainter = TextPainter(
      text: moreSpan,
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );
    morePainter.layout(maxWidth: maxWidth);
    final moreWidth = morePainter.width;

    // Now, binary search to find the max substring that fits with ellipsis + more
    int min = 0;
    int max = text.length;
    int result = 0;
    while (min < max) {
      int mid = (min + max) ~/ 2;
      final testSpan = TextSpan(text: text.substring(0, mid), style: textStyle);
      final testPainter = TextPainter(
        text: TextSpan(
          children: [
            testSpan,
            TextSpan(text: ellipsis + moreText, style: moreStyle),
          ],
        ),
        maxLines: 2,
        textDirection: TextDirection.ltr,
      );
      testPainter.layout(maxWidth: maxWidth);
      if (testPainter.didExceedMaxLines) {
        max = mid;
      } else {
        result = mid;
        min = mid + 1;
      }
    }
    String truncated = text.substring(0, result).trimRight();
    return truncated + ellipsis;
  }

  void _showFullDescriptionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            child: Stack(
              children: [
                // OPTION 1: Remove glassmorphism entirely for solid background
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.93,
                    ), // Solid white background
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                ),

                // OPTION 2: Alternative - Keep glassmorphism but with less opacity
                /*
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95), // Higher opacity
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24.r),
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                  ),
                ),
                */

                // Content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        top: 12.h,
                        left: 16.w,
                        right: 16.w,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: 8.h,
                        left: 20.w,
                        right: 8.w,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Description',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: appColors().primaryColorApp,
                              fontFamily: 'Poppins',
                              fontSize: 20.sp,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.start,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: appColors().primaryColorApp,
                              size: 28.sp,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 8.h,
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            text,
                            style:
                                style?.copyWith(
                                  color: appColors().black, // Force solid black
                                ) ??
                                TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: AppSizes.fontMedium,
                                  color: appColors().black, // Solid black
                                  fontWeight: FontWeight.w500,
                                ),
                            textAlign: TextAlign.justify,
                            textHeightBehavior: TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
