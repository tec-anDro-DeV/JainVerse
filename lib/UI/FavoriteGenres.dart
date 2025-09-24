import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/Model/ModelMusicGenre.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/AppSettingsPresenter.dart';
import 'package:jainverse/Presenter/MusicGenrePresenter.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/ConnectionCheck.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';

String fromLogin = '';

class FavoriteGenres extends StatefulWidget {
  FavoriteGenres(String s, {super.key}) {
    fromLogin = s;
  }

  @override
  _State createState() {
    // TODO: implement createState
    return _State();
  }
}

class _State extends State<FavoriteGenres> with SingleTickerProviderStateMixin {
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
  List<int> selectedIndexList = [];
  // Track whether initial selected indices have been populated from the future
  bool _selectedInitialized = false;
  int colorChange = 0xff7c94b6, colorUnChange = 0x5Cff0065;
  String fromDrawer = '';
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  String allSelected = '';
  List<String> tags = [];
  late Future<ModelMusicGenre> myFuture;
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

      sharedPreThemeData = await sharePrefs.getThemeData();

      setState(() {});
      return sharedPreThemeData;
    } on Exception {}
  }

  Future<void> getSettings() async {
    String? sett = await sharePrefs.getSettings();

    // Defensive parsing: the stored string may be 'error' or invalid JSON
    if (sett == null || sett.trim().isEmpty) {
      // fallback defaults
      allowDown = false;
      allowAds = true;
      setState(() {});
      return;
    }

    try {
      final dynamic decoded = json.decode(sett);
      if (decoded is Map<String, dynamic>) {
        ModelSettings modelSettings = ModelSettings.fromJson(decoded);
        allowDown = modelSettings.data.download == 1;
        allowAds = modelSettings.data.ads == 1;
      } else {
        // Unexpected shape, use defaults
        allowDown = false;
        allowAds = true;
      }
    } catch (e) {
      // Invalid JSON (for example the literal string 'error') -> use defaults
      allowDown = false;
      allowAds = true;
    }

    setState(() {});
  }

  Future<bool> isBack(BuildContext context) async {
    if (fromLogin.contains("fromLogin")) {
      return (await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  elevation: 5,
                  backgroundColor: appColors().colorBackEditText,
                  title: Text(
                    'Do you want to exit the application?',
                    style: TextStyle(color: appColors().white),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          () => Navigator.pop(context, false), // passing false
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                        padding: const EdgeInsets.fromLTRB(22, 5, 22, 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              appColors().PrimaryDarkColorApp,
                              appColors().PrimaryDarkColorApp,
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
                            color: appColors().white,
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
                              appColors().PrimaryDarkColorApp,
                              appColors().PrimaryDarkColorApp,
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
                            color: appColors().white,
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

  Future<ModelMusicGenre> valueCall() async {
    myFuture = MusicGenrePresenter().getMusicGenre(token);

    futureCall = true;
    setState(() {});

    return myFuture;
  }

  @override
  void initState() {
    isRemoveAny = false;
    super.initState();

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
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
                      'Your Favorite Genres',
                      style: TextStyle(
                        color: appColors().black,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(width: 48.w),
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
                              "Enjoy the Music in Your Favorite Genres",
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
                            child: FutureBuilder<ModelMusicGenre>(
                              future:
                                  futureCall
                                      ? (myFuture.whenComplete(() {}))
                                      : null,
                              builder: (context, projectSnap) {
                                if (kDebugMode) {
                                  print('----- Going right 1');
                                }
                                if (projectSnap.hasError) {
                                  if (kDebugMode) {
                                    print(
                                      '----- Going wrong 1 ${projectSnap.error}',
                                    );
                                  }
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
                                    print(
                                      '----- Going right---- 2 ${data.length}',
                                    );
                                    // Populate initial selection only once to avoid
                                    // mutating state during repeated builds and
                                    // duplicate entries.
                                    if (!_selectedInitialized &&
                                        !isRemoveAny &&
                                        projectSnap
                                            .data!
                                            .selectedGenre
                                            .isNotEmpty) {
                                      // use a set to avoid accidental duplicates
                                      final Set<int> initial = {};
                                      for (final s
                                          in projectSnap.data!.selectedGenre) {
                                        try {
                                          initial.add(int.parse(s));
                                        } catch (_) {
                                          // skip invalid values
                                        }
                                      }
                                      selectedIndexList = initial.toList();
                                      _selectedInitialized = true;
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
                                          header: const ClassicHeader(
                                            refreshingIcon: Icon(
                                              Icons.refresh,
                                              color: Color(0xFFEE5533),
                                            ),
                                            refreshingText: '',
                                          ),
                                          child: StreamBuilder<MediaItem?>(
                                            stream: _audioHandler?.mediaItem,
                                            builder: (context, snapshot) {
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
                                                  bottom: AppSizes.basePadding,
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
                                                          (100 / 85),
                                                      crossAxisSpacing: 12.0,
                                                      mainAxisSpacing: 12.0,
                                                    ),
                                                itemBuilder: (
                                                  BuildContext context,
                                                  int index,
                                                ) {
                                                  String imageUrl =
                                                      AppConstant.ImageUrl +
                                                      projectSnap
                                                          .data!
                                                          .imagePath +
                                                      data[index].image;

                                                  bool isSelected =
                                                      selectedIndexList
                                                          .contains(
                                                            data[index].id,
                                                          );
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
                                                        gradient: LinearGradient(
                                                          colors:
                                                              isSelected
                                                                  ? [
                                                                    const Color(
                                                                      0xFFEE5533,
                                                                    ),
                                                                    const Color(
                                                                      0xFFCC4422,
                                                                    ),
                                                                  ]
                                                                  : [
                                                                    appColors()
                                                                        .gray[300]!,
                                                                    appColors()
                                                                        .gray[400]!,
                                                                  ],
                                                          begin:
                                                              Alignment.topLeft,
                                                          end:
                                                              Alignment
                                                                  .bottomRight,
                                                        ),
                                                        image:
                                                            data[index]
                                                                    .image
                                                                    .isNotEmpty
                                                                ? DecorationImage(
                                                                  colorFilter:
                                                                      isSelected
                                                                          ? null
                                                                          : ColorFilter.mode(
                                                                            Colors.black.withOpacity(
                                                                              0.5,
                                                                            ),
                                                                            BlendMode.darken,
                                                                          ),
                                                                  image:
                                                                      NetworkImage(
                                                                        imageUrl,
                                                                      ),
                                                                  fit:
                                                                      BoxFit
                                                                          .cover,
                                                                )
                                                                : null,
                                                      ),
                                                      child: Stack(
                                                        children: [
                                                          // Content wrapped with InkWell so taps
                                                          // register on the entire card area.
                                                          Positioned.fill(
                                                            child: Material(
                                                              color:
                                                                  Colors
                                                                      .transparent,
                                                              child: InkWell(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16.r,
                                                                    ),
                                                                onTap: () {
                                                                  setState(() {
                                                                    final id =
                                                                        data[index]
                                                                            .id;
                                                                    if (selectedIndexList
                                                                        .contains(
                                                                          id,
                                                                        )) {
                                                                      selectedIndexList
                                                                          .remove(
                                                                            id,
                                                                          );
                                                                    } else {
                                                                      // ensure we don't add duplicates
                                                                      if (!selectedIndexList
                                                                          .contains(
                                                                            id,
                                                                          )) {
                                                                        selectedIndexList
                                                                            .add(
                                                                              id,
                                                                            );
                                                                      }
                                                                    }
                                                                    isRemoveAny =
                                                                        true;
                                                                  });
                                                                },
                                                                child: Container(
                                                                  padding:
                                                                      EdgeInsets.all(
                                                                        12.w,
                                                                      ),
                                                                  child: Align(
                                                                    alignment:
                                                                        Alignment
                                                                            .bottomLeft,
                                                                    child: Text(
                                                                      data[index]
                                                                          .genre_name,
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            16.sp,
                                                                        color:
                                                                            Colors.white,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        fontFamily:
                                                                            'Poppins',
                                                                        shadows: [
                                                                          Shadow(
                                                                            color: Colors.black.withOpacity(
                                                                              0.5,
                                                                            ),
                                                                            blurRadius:
                                                                                4,
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),

                                                          // Selection indicator should be painted above
                                                          // the tappable content so it's always visible
                                                          if (isSelected)
                                                            Positioned(
                                                              top: 8.w,
                                                              right: 8.w,
                                                              child: Container(
                                                                width: 24.w,
                                                                height: 24.w,
                                                                decoration: const BoxDecoration(
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                  shape:
                                                                      BoxShape
                                                                          .circle,
                                                                ),
                                                                child: Icon(
                                                                  Icons.check,
                                                                  size: 16.w,
                                                                  color: const Color(
                                                                    0xFFEE5533,
                                                                  ),
                                                                ),
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
                                          const Color(0xFFEE5533),
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
                            padding:
                                (() {
                                  final hasMiniPlayer =
                                      _audioHandler?.mediaItem.value != null;
                                  final bottomPadding =
                                      hasMiniPlayer
                                          ? AppSizes.basePadding +
                                              AppSizes.miniPlayerPadding +
                                              50.w
                                          : AppSizes.basePadding + 50.w;
                                  return EdgeInsets.only(
                                    bottom: bottomPadding,
                                    left: 24.w,
                                    right: 24.w,
                                    top: 16.w,
                                  );
                                })(),
                            child: SizedBox(
                              height: 56.w,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  // Reset tags for this submission to avoid duplicates
                                  tags = [];
                                  allSelected = '';

                                  for (
                                    int i = 0;
                                    i < selectedIndexList.length;
                                    i++
                                  ) {
                                    final idStr =
                                        selectedIndexList[i].toString();
                                    tags.add(idStr);
                                    if (allSelected.isEmpty) {
                                      allSelected = idStr;
                                    } else {
                                      allSelected =
                                          "${selectedIndexList[i]},$allSelected";
                                    }
                                  }

                                  if (selectedIndexList.isEmpty) {
                                    Fluttertoast.showToast(
                                      msg: 'Select any genre !!',
                                      toastLength: Toast.LENGTH_SHORT,
                                      timeInSecForIosWeb: 1,
                                      backgroundColor: appColors().black,
                                      textColor: appColors().colorBackground,
                                      fontSize: 14.0,
                                    );
                                    return;
                                  }

                                  // Await presenter result and close screen on success
                                  final bool success =
                                      await MusicGenrePresenter().setMusicGenre(
                                        context,
                                        jsonEncode(tags),
                                        token,
                                      );

                                  if (success) {
                                    // Close this screen and return a positive result
                                    if (mounted) Navigator.pop(context, true);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEE5533),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  "Submit",
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
