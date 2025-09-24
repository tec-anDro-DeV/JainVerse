import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/Model/ModelAppInfo.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/AppInfoPresenter.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';

class AppInfo extends StatefulWidget {
  const AppInfo({super.key});

  @override
  State<StatefulWidget> createState() {
    return MyState();
  }
}

// Card design copied from contact_us.dart
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final VoidCallback onTap;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 28.w),
              ),
              SizedBox(width: 18.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18.w,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    // subtitle removed from UI by design
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyState extends State<AppInfo> {
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  String token = '';
  List<Data> list = [];
  bool allowDown = false, allowAds = true, isLoad = true;
  int selectedIndex = -1;

  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  // Card data with titles
  final List<Map<String, dynamic>> cardData = [
    {
      'icon': Icons.info_outline,
      'title': 'About',
      'subtitle': 'Learn more about JainVerse',
    },
    {
      'icon': Icons.article_outlined,
      'title': 'Terms of Use',
      'subtitle': 'Read our terms and conditions',
    },
    {
      'icon': Icons.privacy_tip_outlined,
      'title': 'Privacy Policy',
      'subtitle': 'How we protect your data',
    },
  ];

  // Method to get current header title
  String getCurrentTitle() {
    if (selectedIndex == -1) {
      return "App Info";
    } else {
      return cardData[selectedIndex]['title'] as String;
    }
  }

  Future<dynamic> value() async {
    await getAPI();
    model = await sharePrefs.getUserData();
    sharedPreThemeData = await sharePrefs.getThemeData();
    setState(() {});
    return model;
  }

  Future<void> getAPI() async {
    String data = await AppInfoPresenter().getInfo(token);
    final Map<String, dynamic> parsed = json.decode(data.toString());
    ModelAppInfo mList = ModelAppInfo.fromJson(parsed);
    list = mList.data;
    isLoad = false;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    // Set status bar color to match backgroundLogin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: appColors().backgroundLogin,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );
    });

    // Initialize audio handler
    _audioHandler = const MyApp().called();

    value();
    getSettings();
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

  // Handle back navigation
  void handleBackPress() {
    if (selectedIndex != -1) {
      // Go back to main list
      setState(() {
        selectedIndex = -1;
      });
    } else {
      // Exit the screen
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final safeAreaHeight = screenHeight - padding.top - padding.bottom;

    // Force status bar color every build for this screen
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: appColors().backgroundLogin,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: appColors().white,
      body: Column(
        children: [
          // Header with dynamic title and back functionality
          Container(
            color: appColors().backgroundLogin,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          size: 24.w,
                          color: appColors().black,
                        ),
                        onPressed: handleBackPress,
                      ),
                    ),
                    Center(
                      child: Text(
                        getCurrentTitle(), // Dynamic title based on selection
                        style: TextStyle(
                          color: appColors().black,
                          fontSize: AppSizes.fontLarge,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Auth Header with logo (always shown)
          Container(
            color: appColors().backgroundLogin,
            child: AuthHeader(
              height: safeAreaHeight * 0.12,
              heroTag: 'app_logo',
            ),
          ),

          // Content area
          Expanded(
            child: Transform.translate(
              offset: Offset(
                0,
                -16.w,
              ), // Move content area up to float over header
              child: Container(
                decoration: BoxDecoration(
                  color: appColors().white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24.r),
                    topRight: Radius.circular(24.r),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: StreamBuilder<MediaItem?>(
                    stream: _audioHandler?.mediaItem,
                    builder: (context, snapshot) {
                      // Calculate proper bottom padding accounting for mini player and navigation
                      final hasMiniPlayer = snapshot.hasData;
                      final bottomPadding =
                          hasMiniPlayer
                              ? AppSizes.basePadding +
                                  AppSizes.miniPlayerPadding +
                                  100.w
                              : AppSizes.basePadding + 100.w;

                      if (selectedIndex == -1) {
                        // Show main list of cards
                        return SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom: bottomPadding,
                            top: 16.w,
                          ),
                          child: Column(
                            children: [
                              ...List.generate(3, (index) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                    vertical: 8.w,
                                  ),
                                  child: _InfoCard(
                                    icon: cardData[index]['icon'] as IconData,
                                    iconColor: appColors().primaryColorApp,
                                    iconBg: Colors.white,
                                    title: cardData[index]['title'] as String,
                                    onTap: () {
                                      if (isLoad || list.isEmpty) return;
                                      setState(() {
                                        selectedIndex = index;
                                      });
                                    },
                                  ),
                                );
                              }),
                              if (isLoad || list.isEmpty)
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            ],
                          ),
                        );
                      } else {
                        // Show selected content
                        return SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: 20.w,
                            right: 20.w,
                            top: 20.w,
                            bottom: bottomPadding,
                          ),
                          child: Container(
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
                              padding: EdgeInsets.all(16.w),
                              child: HtmlWidget(
                                list[selectedIndex].detail,
                                textStyle: TextStyle(
                                  color: appColors().black,
                                  fontSize: 16.w,
                                  fontFamily: 'Poppins',
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
