import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

/// A reusable widget to display privacy policy, terms of service or other legal content.
///
/// This widget provides a consistent way to display policy content with proper styling
/// across the app.
class PrivacyPolicyView extends StatelessWidget {
  /// The title of the policy document (e.g., "Privacy Policy", "Terms of Service")
  final String title;

  /// The HTML content of the policy document
  final String htmlContent;

  /// Optional callback when the user closes the view
  final VoidCallback? onClose;

  /// Whether to show the app bar with back button (defaults to true)
  final bool showAppBar;

  /// Optional override for the background color
  final Color? backgroundColor;

  const PrivacyPolicyView({
    super.key,
    required this.title,
    required this.htmlContent,
    this.onClose,
    this.showAppBar = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color bgColor = backgroundColor ?? Colors.white;
    final Color primaryTextColor = Colors.black87;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = MediaQuery.of(context).padding;
    final safeAreaHeight = screenHeight - padding.top - padding.bottom;

    return Scaffold(
      backgroundColor: appColors().backgroundLogin,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar with consistent styling
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      size: 30.w,
                      color: appColors().black,
                    ),
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: appColors().black,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  // Empty SizedBox for balanced spacing
                  SizedBox(width: 60.w),
                ],
              ),
            ),

            // Simple colored header for visual consistency
            // Container(
            //   height: safeAreaHeight * 0.009,
            //   width: screenWidth,
            //   color: appColors().backgroundLogin,
            // ),

            // Content area with rounded top corners and shadow
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32.r),
                    topRight: Radius.circular(32.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: 0.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content area with HTML rendering
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 30.w),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.only(top: 16.w, bottom: 24.w),
                              child: HtmlWidget(
                                htmlContent,
                                textStyle: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 15.sp,
                                  height: 1.5,
                                  fontFamily: 'Poppins',
                                ),
                                customStylesBuilder: (element) {
                                  if (element.localName == 'h1' ||
                                      element.localName == 'h2' ||
                                      element.localName == 'h3') {
                                    return {
                                      'margin': '16px 0 12px 0',
                                      'color': '#222222',
                                      'font-weight': 'bold',
                                    };
                                  }

                                  if (element.localName == 'p') {
                                    return {
                                      'margin': '12px 0',
                                      'line-height': '1.5',
                                    };
                                  }

                                  if (element.localName == 'a') {
                                    return {
                                      'color': '#EE5533',
                                      'text-decoration': 'none',
                                    };
                                  }

                                  if (element.localName == 'strong' ||
                                      element.localName == 'b') {
                                    return {
                                      'font-weight': 'bold',
                                      'color': '#333333',
                                    };
                                  }

                                  return null;
                                },
                                onTapUrl: (url) async {
                                  // Handle URL taps here
                                  return true;
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simplified modal version that can be shown as a bottom sheet
class PrivacyPolicyBottomSheet extends StatelessWidget {
  final String title;
  final String htmlContent;

  const PrivacyPolicyBottomSheet({
    super.key,
    required this.title,
    required this.htmlContent,
  });

  /// Show this widget as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String htmlContent,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollController) {
              return PrivacyPolicyBottomSheet(
                title: title,
                htmlContent: htmlContent,
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12.w, bottom: 8.w),
            width: 50.w,
            height: 4.w,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // Main content
          Expanded(
            child: PrivacyPolicyView(
              title: title,
              htmlContent: htmlContent,
              showAppBar: false,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
