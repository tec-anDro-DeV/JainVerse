import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/Logout.dart';
import 'package:jainverse/Presenter/PlaylistMusicPresenter.dart';
import 'package:jainverse/main.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/utils/AdHelper.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/utils/ConnectionCheck.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'contact_us.dart';
import 'package:jainverse/UI/AppInfo.dart';

import 'AllCategoryByName.dart';
import 'ArtistSignUp.dart';
import 'Blog.dart';
import '../widgets/common/app_header.dart';

import 'FavoriteGenres.dart';
import 'LanguageChoose.dart';
import 'Login.dart';
import 'ProfileEdit.dart';
import 'PurchaseHistory.dart';
import 'SubscriptionPlans.dart';
import 'package:session_storage/session_storage.dart';

// Helper class for modern menu items
class ModernMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color iconColor;

  ModernMenuItem({
    required this.icon,
    required this.title,
    this.onTap,
    required this.iconColor,
  });
}

AudioPlayerHandler? _audioHandler;

int touchindex = 0;

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return MyState();
  }
}

class MyState extends State<AccountPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late UserModel model;
  SharedPref sharePrefs = SharedPref();
  bool isOpen = false;
  var progressString = "";
  String isSelected = 'all';
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  bool allowDown = false, allowAds = true;
  late BannerAd _bannerAd;
  String version = '';
  String buildNumber = '', appPackageName = '';
  String audioPath = 'images/audio/thumb/';
  String token = '';
  TextEditingController nameController = TextEditingController();
  var focusNode = FocusNode();
  bool connected = true, checkRuning = false;

  // Modern scroll controller for header animation
  late ScrollController _scrollController;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  // Animation controller for smooth transitions
  late AnimationController _headerAnimationController;

  static String name = '', email = '', artistStatus = 'P';
  static String imagePresent = '';
  late ModelSettings modelSettings;
  bool hasPre = false;

  get audioHandler => null;
  final session = SessionStorage();

  Future<void> updateAPI(
    String playlistname,
    String PlayListId,
    String token,
  ) async {
    await PlaylistMusicPresenter().updatePlaylist(
      playlistname,
      PlayListId,
      token,
    );
    nameController.text = '';

    setState(() {});
  }

  Future<dynamic> value() async {
    try {
      model = await sharePrefs.getUserData();

      PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
        version = packageInfo.version;
        buildNumber = packageInfo.buildNumber;
        appPackageName = packageInfo.packageName;
      });
      token = await sharePrefs.getToken();
      sharedPreThemeData = await sharePrefs.getThemeData();
      setState(() {});

      String? sett = await sharePrefs.getSettings();

      final Map<String, dynamic> parsed = json.decode(sett!);
      modelSettings = ModelSettings.fromJson(parsed);
      if ((modelSettings.data.image.isNotEmpty)) {
        imagePresent = AppConstant.ImageUrl + modelSettings.data.image;
      } else {
        // Clear the image when the new user doesn't have a profile image
        imagePresent = '';
      }

      name = modelSettings.data.name;
      email = modelSettings.data.email;
      artistStatus = model.data.artist_verify_status;
      if (modelSettings.data.in_app_purchase == 1) {
        hasPre = true;
      }
      if (Platform.isAndroid) {
        hasPre = true;
      }
      return model.data.email;
    } on Exception {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        setState(() {});
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden: // Add support for the new hidden state
        // Handle hidden state if needed
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _headerAnimationController.dispose();
    _bannerAd.dispose();

    super.dispose();
  }

  Future<void> loadd() async {
    setState(() {});
  }

  Future<void> getSettings() async {
    String? sett = await sharePrefs.getSettings();

    final Map<String, dynamic> parsed = json.decode(sett!);
    ModelSettings modelSettings = ModelSettings.fromJson(parsed);
    if (modelSettings.data.status == 0) {
      sharePrefs.removeValues();

      // Clear static variables to prevent data from persisting between accounts
      imagePresent = '';
      name = '';
      email = '';
      artistStatus = 'P';

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (BuildContext context) => const Login()),
        (Route<dynamic> route) => false,
      );
      Logout().logout(context, token);
    }

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

  Future<void> checkConn() async {
    connected = await ConnectionCheck().checkConnection();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    // Initialize static variables for clean state
    _initializeStaticVariables();

    // Initialize scroll controller and animation
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Set session page
    session['page'] = "3";

    WidgetsBinding.instance.addObserver(this);
    _audioHandler = const MyApp().called();

    // Initialize data
    _initializeData();

    // Initialize ads
    _initGoogleMobileAds();
  }

  // Initialize or reset static variables for clean state
  void _initializeStaticVariables() {
    // Reset static variables if they appear to be from a previous user session
    // This ensures clean state between different user logins
    imagePresent = '';
    // Note: Don't clear name and email here as they're loaded in value() method
    // This prevents flashing of empty values
  }

  // Initialize all required data
  Future<void> _initializeData() async {
    _initializeStaticVariables();
    await loadd();
    await checkConn();
    await getSettings();
    await value();
  }

  void displayBottomSheet(BuildContext context) {
    Future<void> future = showModalBottomSheet(
      barrierColor: const Color(0x00000000),
      context: context,
      backgroundColor: appColors().colorBackground,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.all(1),
                  child: Column(
                    children: [
                      Text(
                        Resources.of(context).strings.goPro,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 21,
                          color: appColors().red,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(13),
                        child: const Text(
                          'Buy No-Ads Pack to remove all ads',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 17,
                            color: Color(0xff000000),
                          ),
                        ),
                      ),
                      Container(
                        width: 285,
                        margin: const EdgeInsets.fromLTRB(8, 5, 5, 5),
                        decoration: BoxDecoration(
                          color: appColors().red,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: TextButton(
                          child: const Text(
                            'Buy For 100 Per Year ',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: Color(0xffffffff),
                            ),
                          ),
                          onPressed: () => {},
                        ),
                      ),
                      Container(
                        width: 285,
                        margin: const EdgeInsets.fromLTRB(8, 5, 5, 5),
                        decoration: BoxDecoration(
                          color: appColors().colorBackEditText,
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: TextButton(
                          child: const Text(
                            'Buy For 15 Per Month ',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: Color(0xffffffff),
                            ),
                          ),
                          onPressed: () => {},
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    void closeModal(void value) {
      if (isOpen) {
        isOpen = false;
        setState(() {});
      } else {
        isOpen = true;
        setState(() {});
      }
    }

    future.then((value) => closeModal(value));
  }

  void _initGoogleMobileAds() {
    MobileAds.instance.initialize();

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.largeBanner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {});
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    );

    _bannerAd.load();
  }

  void showCustomDialog(BuildContext context) {
    showGeneralDialog(
      barrierLabel: "Barrier",
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 700),
      context: context,
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            width: 259,
            height: 135,
            margin: const EdgeInsets.only(bottom: 1, left: 22, right: 22),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: appColors().colorBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: appColors().colorBorder),
            ),
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Material(
                    type: MaterialType.transparency,
                    child: Text(
                      Resources.of(context).strings.doYouWantToLogout,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 14.0,
                        color: appColors().colorTextSideDrawer,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            audioHandler?.stop();
                            Logout().logout(context, token);
                            sharePrefs.removeValues();
                            // Clear all cache data including images when logging out
                            await CacheManager.clearAllCacheIncludingImages();

                            // Clear static variables to prevent data from persisting between accounts
                            imagePresent = '';
                            name = '';
                            email = '';
                            artistStatus = 'P';

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder:
                                    (BuildContext context) => const Login(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                            padding: const EdgeInsets.fromLTRB(22, 5, 22, 5),
                            decoration: BoxDecoration(
                              color: appColors().primaryColorApp,
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
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                            padding: const EdgeInsets.fromLTRB(22, 5, 22, 5),
                            decoration: BoxDecoration(
                              color: appColors().PrimaryDarkColorApp,
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: const Offset(0, 0),
          ).animate(anim),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar style for modern look
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Background container - clean white
              Container(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                color: Colors.white,
              ),

              // Main scrollable content
              _buildMainScrollableContent(),

              // Animated header
              _buildAnimatedHeader(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedHeader() {
    return AnimatedSlide(
      offset: _isHeaderVisible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.95)),
            child: AppHeader(
              title: "Profile",
              showBackButton: true,
              showProfileIcon: false,
              onBackPressed: () => Navigator.of(context).pop(),
              backgroundColor: Colors.transparent,
              scrollController: _scrollController,
              scrollAware: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScrollableContent() {
    return StreamBuilder<MediaItem?>(
      stream: _audioHandler!.mediaItem,
      builder: (context, snapshot) {
        // Calculate proper bottom padding accounting for mini player and navigation
        final hasMiniPlayer = snapshot.hasData;
        final bottomPadding =
            hasMiniPlayer
                ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 100.w
                : AppSizes.basePadding + AppSizes.miniPlayerPadding;

        return RefreshIndicator(
          onRefresh: () async {
            await _initializeData();
          },
          color: appColors().primaryColorApp,
          backgroundColor: Colors.white,
          displacement: MediaQuery.of(context).padding.top + 94.w,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Top padding for header
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 78.w,
                ),
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Main content
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.contentHorizontalPadding,
                  0,
                  AppSizes.contentHorizontalPadding,
                  bottomPadding, // Proper padding for main nav and mini player
                ),
                sliver: _buildContentSliver(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentSliver() {
    return SliverToBoxAdapter(
      child: FutureBuilder<dynamic>(
        future: value(),
        builder: (context, projectSnap) {
          if (projectSnap.hasData) {
            return _buildAccountContent();
          } else {
            return _buildLoadingWidget();
          }
        },
      ),
    );
  }

  Widget _buildAccountContent() {
    return Column(
      children: [
        // Modern Profile Section
        _buildModernProfileSection(),

        // Subscription Section (moved outside profile container)
        if (hasPre) ...[
          SizedBox(height: 20.w),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPlans(),
                  settings: const RouteSettings(
                    name: '/AccountPage/SubscriptionPlans',
                  ),
                ),
              );
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: appColors().primaryColorApp,
                borderRadius: BorderRadius.circular(16.w),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 24.w,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Subscription Plans',
                      style: TextStyle(
                        fontSize: AppSizes.fontMedium,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16.w,
                  ),
                ],
              ),
            ),
          ),
        ],

        SizedBox(height: 20.w),

        // Menu Items Section
        _buildMenuItemsSection(),

        //Version Info
        SizedBox(height: 20.w),
        Text(
          Platform.isAndroid
              ? 'Version: $version'
              : Platform.isIOS
              ? 'iOS Version: $version ($buildNumber)'
              : 'Version: $version ($buildNumber)',
          style: TextStyle(
            fontSize: AppSizes.fontSmall,
            color: appColors().colorText,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildModernProfileSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: appColors().gray[100],
        borderRadius: BorderRadius.circular(16.w),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10.w,
            offset: Offset(0, 4.w),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          // Profile Image and Info
          Row(
            children: [
              // Profile Image
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appColors().primaryColorApp.withOpacity(0.3),
                  image:
                      imagePresent.isNotEmpty
                          ? DecorationImage(
                            image: NetworkImage(imagePresent),
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    imagePresent.isEmpty
                        ? Icon(
                          Icons.person,
                          size: 40.w,
                          color: appColors().primaryColorApp,
                        )
                        : null,
              ),

              SizedBox(width: 16.w),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: AppSizes.fontLarge,
                        fontWeight: FontWeight.w600,
                        color: appColors().colorTextHead,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 4.w),

                    Text(
                      email,
                      style: TextStyle(
                        fontSize: AppSizes.fontSmall,
                        color: appColors().colorText,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 8.w),

                    // Artist Status Badge
                    if (artistStatus == 'A')
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 4.w,
                        ),
                        decoration: BoxDecoration(
                          color: appColors().primaryColorApp.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.w),
                        ),
                        child: Text(
                          'Verified Artist',
                          style: TextStyle(
                            fontSize: AppSizes.fontSmall,
                            fontWeight: FontWeight.w500,
                            color: appColors().primaryColorApp,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Edit Button
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileEdit(),
                      settings: const RouteSettings(arguments: 'afterlogin'),
                    ),
                  );
                },
                child: Icon(
                  Icons.edit_outlined,
                  size: 28.w,
                  color: appColors().gray[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemsSection() {
    final menuItems = [
      if (model.data.artist_verify_status != 'A')
        ModernMenuItem(
          icon: Icons.library_music_outlined,
          title: 'Request as Artist',
          iconColor: const Color(0xFFFF6B47),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ArtistSignUp(),
                settings: const RouteSettings(
                  name: '/AccountPage/RequestArtist',
                ),
              ),
            );
          },
        ),
      if (model.data.artist_verify_status == 'A')
        ModernMenuItem(
          icon: Icons.library_music_outlined,
          title: 'Artist Dashboard',
          iconColor: const Color(0xFFFF6B47),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => AllCategoryByName(_audioHandler, "My Songs"),
                settings: const RouteSettings(name: '/AccountPage/MySongs'),
              ),
            );
          },
        ),
      ModernMenuItem(
        icon: Icons.article_outlined,
        title: 'Blogs',
        iconColor: const Color(0xFFFF6B47),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const Blog(),
              settings: const RouteSettings(arguments: 'afterlogin'),
            ),
          );
        },
      ),
      ModernMenuItem(
        icon: Icons.info_outline,
        title: 'App Info',
        iconColor: const Color(0xFFFF6B47),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AppInfo(),
              settings: const RouteSettings(arguments: 'afterlogin'),
            ),
          );
        },
      ),
      ModernMenuItem(
        icon: Icons.history,
        title: 'Purchase History',
        iconColor: const Color(0xFFFF6B47),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PurchaseHistory(),
              settings: const RouteSettings(arguments: 'his'),
            ),
          );
        },
      ),
      ModernMenuItem(
        icon: Icons.language_outlined,
        title: 'Change Language',
        iconColor: const Color(0xFFFF6B47),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LanguageChoose(''),
              settings: const RouteSettings(arguments: 'fromDrawer'),
            ),
          );
        },
      ),
      ModernMenuItem(
        icon: Icons.music_note_outlined,
        title: 'Change Favorite Genres',
        iconColor: const Color(0xFFFF6B47),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FavoriteGenres(''),
              settings: const RouteSettings(arguments: 'fromDrawer'),
            ),
          );
          // Refresh the account page when returning from favorite genres
          if (mounted) {
            await _initializeData();
          }
        },
      ),
      ModernMenuItem(
        icon: Icons.call_outlined,
        title: 'Contact Us',
        iconColor: const Color(0xFFFF6B47),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ContactUs(),
              settings: const RouteSettings(arguments: 'fromDrawer'),
            ),
          );
        },
      ),
      ModernMenuItem(
        icon: Icons.logout,
        title: 'Logout',
        iconColor: const Color(0xFFFF6B47),
        onTap: () => _showLogoutDialog(context),
      ),
      ModernMenuItem(
        icon: Icons.delete_outline,
        title: 'Delete Account',
        iconColor: const Color(0xFFFF6B47),
        onTap: () {
          _showDeleteAccountDialog(context);
        },
      ),
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: appColors().gray[100],
        borderRadius: BorderRadius.circular(16.w),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10.w,
            offset: Offset(0, 4.w),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children:
            menuItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == menuItems.length - 1;

              return Column(
                children: [
                  _buildModernMenuItem(item),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.withOpacity(0.1),
                      indent: 60.w,
                    ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildModernMenuItem(ModernMenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16.w),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.w),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.w),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 22.w),
              ),

              SizedBox(width: 16.w),

              // Title
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: AppSizes.fontMedium,
                    fontWeight: FontWeight.w500,
                    color: appColors().colorTextHead,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16.w,
                color: appColors().gray[300],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320.w,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.w),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container with background
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5722).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    size: 40.w,
                    color: const Color(0xFFFF5722),
                  ),
                ),

                SizedBox(height: 24.h),

                // Title
                Text(
                  'Are You Sure, You Want to\nLogout?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D3748),
                    fontFamily: 'Poppins',
                    height: 1.3,
                  ),
                ),

                SizedBox(height: 32.h),

                // Buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFFF5722),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(14.w),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.w),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: const Color(0xFFFF5722),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 16.w),

                    // Yes button
                    Expanded(
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722),
                          borderRadius: BorderRadius.circular(14.w),
                        ),
                        child: TextButton(
                          onPressed: () async {
                            audioHandler?.stop();
                            Logout().logout(context, token);
                            sharePrefs.removeValues();
                            // Clear all cache data including images when logging out
                            await CacheManager.clearAllCacheIncludingImages();

                            // Clear static variables to prevent data from persisting between accounts
                            imagePresent = '';
                            name = '';
                            email = '';
                            artistStatus = 'P';

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder:
                                    (BuildContext context) => const Login(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.w),
                            ),
                          ),
                          child: Text(
                            'Yes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // For Delete Account Dialog
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320.w,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.w),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container with background
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5722).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_forever_outlined,
                    size: 60.w,
                    color: const Color(0xFFFF5722),
                  ),
                ),

                SizedBox(height: 24.h),

                // Title
                Text(
                  'Are You Sure, You Want to\nDelete your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D3748),
                    fontFamily: 'Poppins',
                    height: 1.3,
                  ),
                ),

                SizedBox(height: 16.h),

                // Warning text
                Text(
                  'This action cannot be undone. All your data will be permanently deleted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppSizes.fontSmall - 2.sp,
                    color: const Color(0xFF718096),
                    fontFamily: 'Poppins',
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 32.h),

                // Buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFFF5722),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(14.w),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.w),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: const Color(0xFFFF5722),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 16.w),

                    // Delete button
                    Expanded(
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722),
                          borderRadius: BorderRadius.circular(14.w),
                        ),
                        child: TextButton(
                          onPressed: () async {
                            // Delete account logic from Delete.dart
                            int res = await Logout().deleteApi(
                              context,
                              token,
                              model.data.id,
                            );
                            if (res == 1) {
                              sharePrefs.removeValues();
                              // Clear all cache data including images when deleting account
                              await CacheManager.clearAllCacheIncludingImages();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder:
                                      (BuildContext context) => const Login(),
                                ),
                                (Route<dynamic> route) => false,
                              );
                            } else {
                              // Show error toast
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to delete account. Please try again.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.w),
                            ),
                          ),
                          child: Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return SizedBox(
      height: 400.w,
      child: Center(
        child: CircularProgressIndicator(color: appColors().primaryColorApp),
      ),
    );
  }

  // Add scroll listener for header animation
  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final currentPosition = _scrollController.position.pixels;
    final scrollDelta = currentPosition - _lastScrollPosition;
    final isAtTop = currentPosition <= 5.0;
    const double scrollThreshold = 10.0;

    if (isAtTop) {
      if (!_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    } else {
      if (scrollDelta > scrollThreshold && _isHeaderVisible) {
        setState(() {
          _isHeaderVisible = false;
        });
      } else if (scrollDelta < -scrollThreshold && !_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    }

    _lastScrollPosition = currentPosition;
  }
}

class Resources {
  Resources();

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
    return Resources();
  }
}
