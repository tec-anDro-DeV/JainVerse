import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/Logout.dart';
import 'package:jainverse/Presenter/PlaylistMusicPresenter.dart';
import 'package:jainverse/Presenter/ArtistVerificationPresenter.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/UI/AppInfo.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/models/channel_model.dart';
import 'package:jainverse/presenters/channel_presenter.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/utils/ConnectionCheck.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:session_storage/session_storage.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

import '../widgets/common/app_header.dart';
import '../widgets/common/loader.dart';
import 'FavoriteGenres.dart';
import 'ProfileEdit.dart';
import 'contact_us.dart';
import 'VerifyArtistScreen.dart';
import 'CreateChannel.dart';
import 'UserChannel.dart';
import 'PhoneNumberInputScreen.dart';

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin, RouteAware {
  late UserModel model;
  SharedPref sharePrefs = SharedPref();
  bool isOpen = false;
  var progressString = "";
  String isSelected = 'all';
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  bool allowDown = false;
  String version = '';
  String buildNumber = '', appPackageName = '';
  String audioPath = 'images/audio/thumb/';
  String token = '';
  TextEditingController nameController = TextEditingController();
  var focusNode = FocusNode();
  bool connected = true, checkRuning = false;

  late ScrollController _scrollController;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  late AnimationController _headerAnimationController;

  static String name = '', artistStatus = 'P';
  static String imagePresent = '';
  ImageProvider? _profileImageProvider;
  late ModelSettings modelSettings;
  bool hasPre = false;
  bool hasChannel = false;
  Map<String, dynamic>? channelData;

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
      await _fetchProfileFromApi(token);
      sharedPreThemeData = await sharePrefs.getThemeData();
      setState(() {});

      String? sett = await sharePrefs.getSettings();

      final Map<String, dynamic> parsed = json.decode(sett!);
      modelSettings = ModelSettings.fromJson(parsed);
      if ((modelSettings.data.image.isNotEmpty)) {
        final raw = modelSettings.data.image.toString();
        if (raw.startsWith('http')) {
          imagePresent = raw;
        } else {
          imagePresent = AppConstant.ImageUrl + raw;
        }
        try {
          await _prepareProfileImage(imagePresent);
        } catch (e) {
          if (kDebugMode) print('prepareProfileImage failed: $e');
        }
      } else {
        imagePresent = '';
      }

      name = modelSettings.data.name;
      artistStatus = model.data.artist_verify_status;
      if (modelSettings.data.in_app_purchase == 1) {
        hasPre = true;
      }
      if (Platform.isAndroid) {
        hasPre = true;
      }
      return model.data.name;
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
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _headerAnimationController.dispose();
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final ModalRoute? route = ModalRoute.of(context);
      if (route != null) routeObserver.subscribe(this, route);
    } catch (e) {}
  }

  @override
  void didPopNext() {
    (() async {
      try {
        token = await sharePrefs.getToken();
        await _fetchProfileFromApi(token);
        await getSettings();

        Future<void> attemptRefresh([bool cacheBust = false]) async {
          if (imagePresent.isEmpty) return;

          final String urlToUse = cacheBust
              ? '$imagePresent?_=${DateTime.now().millisecondsSinceEpoch}'
              : imagePresent;

          try {
            try {
              await CachedNetworkImage.evictFromCache(imagePresent);
            } catch (e) {
              if (kDebugMode) print('Failed to evict cached network image: $e');
            }

            try {
              PaintingBinding.instance.imageCache.clear();
            } catch (e) {
              if (kDebugMode) print('Failed to clear image cache: $e');
            }

            await _prepareProfileImage(urlToUse);
          } catch (e) {
            if (kDebugMode) print('Profile image refresh attempt failed: $e');
          }
        }

        attemptRefresh(false);

        Future.delayed(
          const Duration(milliseconds: 500),
          () => attemptRefresh(true),
        );

        Future.delayed(const Duration(seconds: 2), () => attemptRefresh(true));
      } catch (e) {
        if (kDebugMode) print('Error refreshing profile on return: $e');
      }

      if (mounted) setState(() {});
    })();
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

      imagePresent = '';
      name = '';
      artistStatus = 'P';

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (BuildContext context) => const PhoneNumberInputScreen(),
        ),
        (Route<dynamic> route) => false,
      );
      Logout().logout(context, token);
    }

    if (modelSettings.data.download == 1) {
      allowDown = true;
    } else {
      allowDown = false;
    }

    setState(() {});
  }

  Future<void> _prepareProfileImage(String url) async {
    try {
      if (url.isEmpty) {
        if (mounted) setState(() => _profileImageProvider = null);
        return;
      }
      final uri = Uri.parse(url);
      final HttpClient client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final HttpClientRequest req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.connectionHeader, 'close');
      req.headers.set(HttpHeaders.acceptHeader, 'image/*');

      final HttpClientResponse resp = await req.close().timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw Exception('Timeout while fetching image bytes'),
      );

      if (resp.statusCode == 200) {
        final Uint8List bytes = await consolidateHttpClientResponseBytes(resp);
        if (bytes.isNotEmpty) {
          try {
            final codec = await ui.instantiateImageCodec(bytes);
            await codec.getNextFrame();
            if (mounted) {
              setState(() => _profileImageProvider = MemoryImage(bytes));
            }
            client.close(force: true);
            return;
          } catch (e) {
            if (kDebugMode) print('Invalid image bytes detected: $e');
            try {
              await CachedNetworkImage.evictFromCache(url);
            } catch (_) {}
            if (mounted) setState(() => _profileImageProvider = null);
            client.close(force: true);
            return;
          }
        }
      } else if (resp.statusCode == 404) {
        try {
          await CachedNetworkImage.evictFromCache(url);
        } catch (e) {
          if (kDebugMode) print('evictFromCache failed: $e');
        }
        try {
          PaintingBinding.instance.imageCache.clear();
        } catch (_) {}

        if (mounted) setState(() => _profileImageProvider = null);
        client.close(force: true);
        return;
      }
      client.close(force: true);
    } catch (e) {
      if (kDebugMode) print('Profile image bytes fetch failed: $e');
    }

    if (mounted) setState(() => _profileImageProvider = null);
  }

  Future<void> checkUserChannel() async {
    try {
      final presenter = ChannelPresenter();
      final result = await presenter.getChannel();

      if (result['status'] == true && result['data'] != null) {
        hasChannel = true;
        channelData = result['data'];
      } else {
        hasChannel = false;
        channelData = null;
      }
      setState(() {});
    } catch (e) {
      hasChannel = false;
      channelData = null;
    }
  }

  Future<void> checkConn() async {
    connected = await ConnectionCheck().checkConnection();
    setState(() {});
  }

  Future<void> _fetchProfileFromApi(String token) async {
    if (token.isEmpty) return;
    try {
      final uri = Uri.parse('${AppConstant.BaseUrl}my_profile');
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonResp = json.decode(resp.body);
        final dynamic data = jsonResp['data'] ?? jsonResp;
        if (data is Map<String, dynamic>) {
          if (data.containsKey('name') && data['name'] != null) {
            name = data['name'].toString();
          }
          if (data.containsKey('artist_verify_status') &&
              data['artist_verify_status'] != null) {
            artistStatus = data['artist_verify_status'].toString();
          }
          if (data.containsKey('image') &&
              data['image'] != null &&
              data['image'].toString().isNotEmpty) {
            final raw = data['image'].toString();
            if (raw.startsWith('http')) {
              imagePresent = raw;
            } else {
              imagePresent = AppConstant.ImageUrl + raw;
            }
            await _prepareProfileImage(imagePresent);
          }
        }
      } else {
        if (kDebugMode) {
          print('my_profile returned ${resp.statusCode}: ${resp.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Failed to fetch profile: $e');
    }

    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _initializeStaticVariables();

    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    session['page'] = "3";

    WidgetsBinding.instance.addObserver(this);
    _audioHandler = const MyApp().called();

    _initFuture = _initializeData();
  }

  void _initializeStaticVariables() {
    imagePresent = '';
  }

  Future<void> _initializeData() async {
    _initializeStaticVariables();
    await loadd();
    await checkConn();
    await getSettings();
    await value();

    await _fetchArtistVerifyStatus();

    await checkUserChannel();
  }

  late Future<void> _initFuture;

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
                            await CacheManager.clearAllCacheIncludingImages();

                            imagePresent = '';
                            name = '';
                            artistStatus = 'P';

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (BuildContext context) =>
                                    const PhoneNumberInputScreen(),
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
                              color: appColors().primaryColorApp,
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

  Future<void> _fetchArtistVerifyStatus() async {
    try {
      if (token.isEmpty) {
        token = await sharePrefs.getToken();
      }

      final resp = await ArtistVerificationPresenter().getVerificationStatus(
        context,
        token,
      );

      if (resp.data != null) {
        artistStatus = resp.data!.verifyStatus;
      } else {
        artistStatus = 'N';
      }
    } catch (e) {
      if (kDebugMode) print('Failed to fetch artist verify status: $e');
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
              Container(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                color: Colors.white,
              ),

              _buildMainScrollableContent(),

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
        final hasMiniPlayer = snapshot.hasData;
        final bottomPadding = hasMiniPlayer
            ? AppPadding.bottom(context, extra: 100.w)
            : AppPadding.bottom(context);
        return FutureBuilder<void>(
          future: _initFuture,
          builder: (context, initSnap) {
            if (initSnap.connectionState != ConnectionState.done) {
              final media = MediaQuery.of(context);
              return SizedBox(
                height: media.size.height,
                width: double.infinity,
                child: Center(
                  child: CircleLoader(
                    size: 220.w,
                    showBackground: false,
                    showLogo: true,
                  ),
                ),
              );
            }

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
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 78.w,
                    ),
                    sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),

                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.contentHorizontalPadding,
                      0,
                      AppSizes.contentHorizontalPadding,
                      bottomPadding,
                    ),
                    sliver: _buildContentSliver(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContentSliver() {
    return SliverToBoxAdapter(child: _buildAccountContent());
  }

  Widget _buildAccountContent() {
    return Column(
      children: [
        _buildModernProfileSection(),

        SizedBox(height: 20.w),

        _buildMenuItemsSection(),

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
          Row(
            children: [
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appColors().primaryColorApp.withOpacity(0.3),

                  image: (_profileImageProvider != null)
                      ? DecorationImage(
                          image: _profileImageProvider!,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (imagePresent.isEmpty && _profileImageProvider == null)
                    ? Icon(
                        Icons.person,
                        size: 40.w,
                        color: appColors().primaryColorApp,
                      )
                    : null,
              ),

              SizedBox(width: 16.w),

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

              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileEdit(),
                      settings: const RouteSettings(arguments: 'afterlogin'),
                    ),
                  );

                  if (result == true) {
                    try {
                      await _initializeData();
                    } catch (e) {
                      await getSettings();
                    }
                  }
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
      if (artistStatus != 'A')
        ModernMenuItem(
          icon: Icons.library_music_outlined,
          title: 'Request as Artist',
          iconColor: appColors().primaryColorApp,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VerifyArtistScreen(),
                settings: const RouteSettings(
                  name: '/AccountPage/RequestArtist',
                ),
              ),
            );
          },
        ),

      ModernMenuItem(
        icon: hasChannel
            ? Icons.video_library_outlined
            : Icons.video_call_outlined,

        title: artistStatus != 'A'
            ? 'Create Channel'
            : (hasChannel ? 'Your Channel' : 'Create Channel'),
        iconColor: appColors().primaryColorApp,
        onTap: () async {
          if (artistStatus != 'A') {
            showDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text('Artist Verification Required'),
                  content: const Text(
                    'You need to request artist verification before creating a channel. Would you like to request now?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                    TextButton(
                      child: const Text('Request Now'),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VerifyArtistScreen(),
                            settings: const RouteSettings(
                              name: '/AccountPage/RequestArtist',
                            ),
                          ),
                        );

                        await _fetchArtistVerifyStatus();
                        await checkUserChannel();
                      },
                    ),
                  ],
                );
              },
            );

            return;
          }

          if (hasChannel && channelData != null) {
            final channel = ChannelModel.fromJson(channelData!);
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserChannel(channel: channel),
                settings: const RouteSettings(name: '/AccountPage/UserChannel'),
              ),
            );
            if (result != null) {
              if (result is ChannelModel) {
                setState(() {
                  channelData = result.toJson();
                });
              } else if (result == true) {
                await checkUserChannel();
              }
            }
          } else {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateChannel(),
                settings: const RouteSettings(
                  name: '/AccountPage/CreateChannel',
                ),
              ),
            );
            if (result != null) {
              await checkUserChannel();
            }
          }
        },
      ),

      ModernMenuItem(
        icon: Icons.music_note_outlined,
        title: 'Change Favorite Genres',
        iconColor: appColors().primaryColorApp,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FavoriteGenres(''),
              settings: const RouteSettings(arguments: 'fromDrawer'),
            ),
          );
          if (mounted) {
            await _initializeData();
          }
        },
      ),
      ModernMenuItem(
        icon: Icons.call_outlined,
        title: 'Contact Us',
        iconColor: appColors().primaryColorApp,
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
        iconColor: appColors().primaryColorApp,
        onTap: () => _showLogoutDialog(context),
      ),
      ModernMenuItem(
        icon: Icons.delete_outline,
        title: 'Delete Account',
        iconColor: appColors().primaryColorApp,
        onTap: () {
          _showDeleteAccountDialog(context);
        },
      ),
      ModernMenuItem(
        icon: Icons.info_outline,
        title: 'App Info',
        iconColor: appColors().primaryColorApp,
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
        children: menuItems.asMap().entries.map((entry) {
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
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: appColors().primaryColorApp.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout,
                    size: 40.w,
                    color: appColors().primaryColorApp,
                  ),
                ),

                SizedBox(height: 24.h),

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

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: appColors().primaryColorApp,
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
                              color: appColors().primaryColorApp,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 16.w),

                    Expanded(
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: appColors().primaryColorApp,
                          borderRadius: BorderRadius.circular(14.w),
                        ),
                        child: TextButton(
                          onPressed: () async {
                            audioHandler?.stop();
                            Logout().logout(context, token);
                            sharePrefs.removeValues();
                            await CacheManager.clearAllCacheIncludingImages();

                            imagePresent = '';
                            name = '';
                            artistStatus = 'P';

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (BuildContext context) =>
                                    const PhoneNumberInputScreen(),
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
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: appColors().primaryColorApp.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_forever_outlined,
                    size: 60.w,
                    color: appColors().primaryColorApp,
                  ),
                ),

                SizedBox(height: 24.h),

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

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: appColors().primaryColorApp,
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
                              color: appColors().primaryColorApp,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 16.w),

                    Expanded(
                      child: Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: appColors().primaryColorApp,
                          borderRadius: BorderRadius.circular(14.w),
                        ),
                        child: TextButton(
                          onPressed: () async {
                            int res = await Logout().deleteApi(
                              context,
                              token,
                              model.data.id,
                            );
                            if (res == 1) {
                              sharePrefs.removeValues();
                              await CacheManager.clearAllCacheIncludingImages();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (BuildContext context) =>
                                      const PhoneNumberInputScreen(),
                                ),
                                (Route<dynamic> route) => false,
                              );
                            } else {
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
