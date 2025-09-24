import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
// import 'package:jainverse/utils/AdHelper.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/sizes.dart';

String title = '';
String detail = '';

class PrivacyPolicy extends StatefulWidget {
  PrivacyPolicy(String tit, String det, {super.key}) {
    title = tit;
    detail = det;
  }

  @override
  State<StatefulWidget> createState() {
    return MyState();
  }
}

class MyState extends State<PrivacyPolicy> {
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  bool allowDown = false, allowAds = true;

  String isSelected = 'all';

  Future<dynamic> value() async {
    model = await sharePrefs.getUserData();
    sharedPreThemeData = await sharePrefs.getThemeData();
    setState(() {});
    return model;
  }

  Future<void> getSettings() async {
    String? sett = await sharePrefs.getSettings();
    final Map<String, dynamic> parsed = json.decode(sett!);
    ModelSettings modelSettings = ModelSettings.fromJson(parsed);
    if (modelSettings.data.download == 1) {
      allowDown = true;
    } else {
      allowDown = false;
    }
    if (modelSettings.data.ads == 1) {
      allowAds = true;
    } else {
      allowAds = false;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    getSettings();

    // _initGoogleMobileAds();

    value();
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: appColors().backgroundLogin,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar replacement (ContactUs style)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      size: 24.w,
                      color: appColors().black,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: appColors().black,
                      fontSize: AppSizes.fontLarge,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
            // Optional: Add logo header for consistency
            SizedBox(height: safeAreaHeight * 0.05),
            // Content area with rounded top card design (ContactUs style)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32.r),
                    topRight: Radius.circular(32.r),
                  ),
                  // boxShadow: [
                  //   BoxShadow(
                  //     offset: const Offset(0, -3),
                  //     color: Colors.black.withOpacity(0.03),
                  //     blurRadius: 8,
                  //   ),
                  // ],
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 20.w,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card for HTML content (ContactUs card style)
                        Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color: appColors().white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: appColors().gray[100],
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            padding: EdgeInsets.all(12.w),
                            child: HtmlWidget(
                              detail,
                              textStyle: TextStyle(
                                color: appColors().black,
                                fontSize: AppSizes.fontNormal,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
