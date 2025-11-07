import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/ModelMusicLanguage.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/AppSettingsPresenter.dart';
import 'package:jainverse/Presenter/MusicLanguagePresenter.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/ConnectionCheck.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'MainNavigation.dart';

String fromLogin = '';

class LanguageChoose extends StatefulWidget {
  LanguageChoose(String s, {super.key}) {
    fromLogin = s;
  }

  @override
  _State createState() {
    return _State();
  }
}

class LanguageDetails {
  const LanguageDetails({required this.title, required this.i});

  final String title;
  final String i;
}

class _State extends State<LanguageChoose> with SingleTickerProviderStateMixin {
  void change(int index) {
    setState(() {});
  }

  // Animation controller for subtle UI animations
  late AnimationController _animationController;
  Animation<double> _fadeInAnimation = AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = AlwaysStoppedAnimation(Offset.zero);

  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  String token = '';
  int selectedLanguageId = 0; // Changed from List to single int
  int colorChange = 0xff7c94b6, colorUnChange = 0x5Cff0065;
  String fromDrawer = '';
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  String allSelected = '';
  List<String> tags = [];
  late Future<ModelMusicLanguage> myFuture;
  late Widget futureWidget;
  static bool isRemoveAny = false;
  bool futureCall = false;
  bool allowDown = false, allowAds = true;

  Future<void> apiSettings() async {
    String settingDetails = await AppSettingsPresenter().getAppSettings(token);
    sharePrefs.setSettingsData(settingDetails);
    getSettings();
    valueCall();
  }

  Future<dynamic> value() async {
    try {
      token = await sharePrefs.getToken();
      if (fromLogin.contains("fromLogin")) {
        apiSettings();
      } else {
        apiSettings();
      }

      model = await sharePrefs.getUserData();
      // Only set selected language from model if coming from login
      if (fromLogin.contains("fromLogin") && model.selectedLanguage > 0) {
        selectedLanguageId = model.selectedLanguage;
      }

      sharedPreThemeData = await sharePrefs.getThemeData();

      setState(() {});
      return sharedPreThemeData;
    } on Exception {}
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

  Future<bool> isBack(BuildContext context) async {
    if (fromLogin.contains("fromLogin")) {
      return (await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              elevation: 5,
              backgroundColor: appColors().colorBackEditText,
              title: Text(
                'Do you want to exit the application?',
                style: TextStyle(
                  color: appColors().black, // Explicitly set to black
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, false), // passing false
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                    padding: const EdgeInsets.fromLTRB(22, 5, 22, 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appColors().primaryColorApp,
                          appColors().primaryColorApp,
                          appColors().primaryColorApp,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      Resources.of(context).strings.no,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.0,
                        color: Colors.white, // Always white for contrast
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (Platform.isAndroid) {
                      SystemNavigator.pop();
                    } else {
                      exit(0);
                    }
                  }, // passing true
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                    padding: const EdgeInsets.fromLTRB(22, 5, 22, 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appColors().primaryColorApp,
                          appColors().primaryColorApp,
                          appColors().primaryColorApp,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      Resources.of(context).strings.yes,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.0,
                        color: Colors.white, // Always white for contrast
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )) ??
          false;
    } else {
      return true;
    }
  }

  Future<ModelMusicLanguage> valueCall() async {
    myFuture = MusicLanguagePresenter().getMusicLanguage(token, context);

    futureCall = true;
    setState(() {});

    return myFuture;
  }

  @override
  void initState() {
    isRemoveAny = false;
    super.initState;

    // Initialize audio handler
    _audioHandler = const MyApp().called();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          ),
        );

    // Start animation after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });

    value();
    ConnectionCheck().checkConnection();
    checkConn();
  }

  Future<void> checkConn() async {
    await ConnectionCheck().checkConnection();
    setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );

  void _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {});
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    var route = ModalRoute.of(context);
    if (route!.settings.arguments != null) {
      fromDrawer = ModalRoute.of(context)!.settings.arguments.toString();

      setState(() {});
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final safeAreaHeight = screenHeight - padding.top - padding.bottom;

    return Scaffold(
      backgroundColor: appColors().backgroundLogin,
      body: WillPopScope(
        onWillPop: () {
          return isBack(context);
        },
        child: SafeArea(
          child: Column(
            children: [
              // App Bar replacement
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    fromDrawer.contains('fromDrawer')
                        ? IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              size: 24.w,
                              color: appColors().black,
                            ),
                            onPressed: () => Navigator.pop(context),
                          )
                        : SizedBox(width: 48.w),
                    Text(
                      Resources.of(context).strings.musicLanguage,
                      style: TextStyle(
                        color: appColors().black,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    !fromDrawer.contains('fromDrawer')
                        ? TextButton(
                            onPressed: () {
                              // Automatically set language to 1 (English) when skip is pressed
                              MusicLanguagePresenter().setMusicLanguage(
                                context,
                                '1', // Set to English (ID 1)
                                token,
                              );
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) {
                                    return const MainNavigationWrapper(
                                      initialIndex: 0,
                                    );
                                  },
                                ),
                                (Route<dynamic> route) =>
                                    false, // This removes all previous routes
                              );
                            },
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: appColors().colorTextHead,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          )
                        : SizedBox(width: 48.w),
                  ],
                ),
              ),

              // Header with logo
              AuthHeader(height: safeAreaHeight * 0.12, heroTag: 'app_logo'),

              // Content area with rounded top
              Expanded(
                child: FadeTransition(
                  opacity: _fadeInAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
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
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 0,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: 24.w,
                              left: 24.w,
                              right: 24.w,
                            ),
                            child: Text(
                              Resources.of(context).strings.musicYouMayLike,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: AppSizes.fontNormal,
                                fontWeight: FontWeight.bold,
                                color: appColors().gray[500],
                              ),
                            ),
                          ),
                          SizedBox(height: 16.w),
                          Expanded(
                            child: FutureBuilder<ModelMusicLanguage>(
                              future: futureCall
                                  ? (myFuture.whenComplete(() {}))
                                  : null,
                              builder: (context, projectSnap) {
                                if (projectSnap.hasError) {
                                  Fluttertoast.showToast(
                                    msg: Resources.of(context).strings.tryAgain,
                                    toastLength: Toast.LENGTH_SHORT,
                                    timeInSecForIosWeb: 1,
                                    backgroundColor: appColors().black,
                                    textColor: appColors().colorBackground,
                                    fontSize: 14.0,
                                  );
                                  return const Material();
                                } else {
                                  if (projectSnap.hasData) {
                                    List<Data> data = projectSnap.data!.data;
                                    if (!isRemoveAny &&
                                        selectedLanguageId == 0) {
                                      // When coming from drawer, use selectedLanguage from API response
                                      if (fromDrawer.contains('fromDrawer')) {
                                        if (projectSnap
                                            .data!
                                            .selectedLanguage
                                            .isNotEmpty) {
                                          try {
                                            var firstLanguage = projectSnap
                                                .data!
                                                .selectedLanguage[0];
                                            if (firstLanguage != null &&
                                                firstLanguage
                                                    .toString()
                                                    .isNotEmpty) {
                                              selectedLanguageId = int.parse(
                                                firstLanguage.toString(),
                                              );
                                            }
                                          } catch (e) {
                                            print(
                                              "DEBUG: Error parsing selectedLanguage: $e",
                                            );
                                            selectedLanguageId = 0;
                                          }
                                        }
                                      } else {
                                        // When coming from login, auto-select card with ID 1 for better user experience
                                        if (data.isNotEmpty) {
                                          // Try to find and select the card with ID 1
                                          var cardWithId1 = data.firstWhere(
                                            (element) => element.id == 1,
                                            orElse: () => data
                                                .first, // Fallback to first card if ID 1 not found
                                          );
                                          selectedLanguageId = cardWithId1.id;
                                        }
                                      }
                                    }

                                    if (data.isEmpty) {
                                      return Container(
                                        alignment: Alignment.center,
                                        child: Text(
                                          'No Record Found',
                                          style: TextStyle(
                                            color: appColors().colorTextHead,
                                            fontSize: 18.sp,
                                          ),
                                        ),
                                      );
                                    } else {
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16.w,
                                        ),
                                        child: SmartRefresher(
                                          enablePullDown: true,
                                          enablePullUp: false,
                                          controller: _refreshController,
                                          onRefresh: _onRefresh,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          header: ClassicHeader(
                                            refreshingIcon: Icon(
                                              Icons.refresh,
                                              color:
                                                  appColors().primaryColorApp,
                                            ),
                                            refreshingText: '',
                                          ),
                                          child: StreamBuilder<MediaItem?>(
                                            stream: _audioHandler?.mediaItem,
                                            builder: (context, snapshot) {
                                              // Determine number of columns: 4 for tablets/iPad (shortestSide >= 600), else 2
                                              int gridColumnsForDevice(
                                                BuildContext c,
                                              ) {
                                                final mq = MediaQuery.of(c);
                                                final shortest =
                                                    mq.size.shortestSide;
                                                return shortest >= 600 ? 4 : 2;
                                              }

                                              return GridView.builder(
                                                padding: EdgeInsets.only(
                                                  bottom:
                                                      AppPadding.bottom(
                                                        context,
                                                      ) -
                                                      MediaQuery.of(
                                                        context,
                                                      ).padding.bottom,
                                                ),
                                                scrollDirection: Axis.vertical,
                                                itemCount: data.length,
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount:
                                                          gridColumnsForDevice(
                                                            context,
                                                          ),
                                                      childAspectRatio:
                                                          (100 / 60),
                                                      crossAxisSpacing: 12.0,
                                                      mainAxisSpacing: 12.0,
                                                    ),
                                                itemBuilder: (BuildContext context, int index) {
                                                  String imageUrl =
                                                      AppConstant.ImageUrl +
                                                      projectSnap
                                                          .data!
                                                          .imagePath +
                                                      data[index].image;

                                                  return Card(
                                                    elevation: 2,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadiusDirectional.circular(
                                                            16.r,
                                                          ),
                                                    ),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadiusDirectional.circular(
                                                              16.r,
                                                            ),
                                                        image:
                                                            data[index]
                                                                .image
                                                                .isNotEmpty
                                                            ? DecorationImage(
                                                                colorFilter:
                                                                    selectedLanguageId ==
                                                                        data[index]
                                                                            .id
                                                                    ? null // No overlay for selected
                                                                    : ColorFilter.mode(
                                                                        Colors.black.withOpacity(
                                                                          0.7,
                                                                        ), // More black for unselected
                                                                        BlendMode
                                                                            .darken,
                                                                      ),
                                                                image:
                                                                    NetworkImage(
                                                                      imageUrl,
                                                                    ),
                                                                fit: BoxFit
                                                                    .cover,
                                                              )
                                                            : null,
                                                        color:
                                                            data[index]
                                                                .image
                                                                .isEmpty
                                                            ? (selectedLanguageId ==
                                                                      data[index]
                                                                          .id
                                                                  ? Colors
                                                                        .grey[200] // lighter for selected
                                                                  : Colors
                                                                        .grey[700]) // darker for unselected
                                                            : null,
                                                      ),
                                                      child: Stack(
                                                        children: [
                                                          // Overlay for selected card (removed white overlay)
                                                          // (No overlay for selected card, only text and background)
                                                          Center(
                                                            child: Padding(
                                                              padding:
                                                                  EdgeInsets.all(
                                                                    16.w,
                                                                  ),
                                                              child: Text(
                                                                data[index]
                                                                    .language_name,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: TextStyle(
                                                                  fontSize:
                                                                      18.sp,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .white,
                                                                  fontFamily:
                                                                      'Poppins',
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          // Checkmark icon in top-right corner
                                                          if (selectedLanguageId ==
                                                              data[index].id)
                                                            Positioned(
                                                              top: 8.w,
                                                              right: 8.w,
                                                              child: Container(
                                                                width: 24.w,
                                                                height: 24.w,
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .white,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: Colors
                                                                          .black
                                                                          .withOpacity(
                                                                            0.2,
                                                                          ),
                                                                      blurRadius:
                                                                          4,
                                                                      offset:
                                                                          Offset(
                                                                            0,
                                                                            2,
                                                                          ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: Icon(
                                                                  Icons.check,
                                                                  size: 16.w,
                                                                  color: appColors()
                                                                      .primaryColorApp,
                                                                ),
                                                              ),
                                                            ),
                                                          // Invisible touch area covering entire card
                                                          Positioned.fill(
                                                            child: InkWell(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    16.r,
                                                                  ),
                                                              onTap: () {
                                                                if (selectedLanguageId !=
                                                                    data[index]
                                                                        .id) {
                                                                  // Set the new selection
                                                                  selectedLanguageId =
                                                                      data[index]
                                                                          .id;
                                                                } else {
                                                                  // Allow deselection
                                                                  selectedLanguageId =
                                                                      0;
                                                                }
                                                                isRemoveAny =
                                                                    true;
                                                                change(index);
                                                              },
                                                              child:
                                                                  Container(), // Empty container to make the entire area tappable
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(
                                          appColors().primaryColorApp,
                                        ),
                                        strokeWidth: 3.0,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          Padding(
                            padding: (() {
                              // When LanguageChoose is opened from auth flows
                              // (login, signup/verify email, or forgot password)
                              // we should NOT reserve extra space for the main
                              // navigation bar or the mini player. Keep the
                              // ad-space (if present) but remove nav/player padding.
                              final openedFromAuthFlow =
                                  (fromLogin.contains('fromLogin') ||
                                  fromLogin.contains('signup') ||
                                  fromLogin.toLowerCase().contains('forgot'));

                              // If opened from auth flows we don't reserve
                              // additional navigation / mini-player padding.
                              final navPlayerPadding = openedFromAuthFlow
                                  ? 0.w
                                  : (AppPadding.bottom(context, extra: 30.w) -
                                        MediaQuery.of(context).padding.bottom);

                              return EdgeInsets.only(
                                // keep ad space but conditionally add nav/player padding
                                bottom:
                                    (allowAds ? 60.w : 24.w) + navPlayerPadding,
                                left: 24.w,
                                right: 24.w,
                                top: 16.w,
                              );
                            })(),
                            child: SizedBox(
                              height: 56.w,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (selectedLanguageId <= 0) {
                                    Fluttertoast.showToast(
                                      msg: 'Select any language !!',
                                      toastLength: Toast.LENGTH_SHORT,
                                      timeInSecForIosWeb: 1,
                                      backgroundColor: appColors().black,
                                      textColor: appColors().colorBackground,
                                      fontSize: 14.0,
                                    );
                                  } else {
                                    // Send only the single language ID
                                    MusicLanguagePresenter().setMusicLanguage(
                                      context,
                                      selectedLanguageId.toString(),
                                      token,
                                    );
                                    // Directly navigate without showing a toast
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const MainNavigationWrapper(
                                              initialIndex: 0,
                                            ),
                                      ),
                                      (Route<dynamic> route) =>
                                          false, // This removes all previous routes
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appColors().primaryColorApp,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  Resources.of(context).strings.continu,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Resources {
  Resources._();

  StringsLocalization get strings {
    switch ('en') {
      case 'ar':
        return ArabicStrings();
      case 'fn':
        return FranchStrings();
      default:
        return EnglishStrings();
    }
  }

  static Resources of(BuildContext context) {
    return Resources._();
  }
}
