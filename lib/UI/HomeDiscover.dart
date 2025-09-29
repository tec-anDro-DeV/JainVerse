import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelCatSubcatMusic.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/AppSettingsPresenter.dart';
import 'package:jainverse/Presenter/CatSubCatMusicPresenter.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/Presenter/Logout.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/AllCategoryByName.dart';
import 'package:jainverse/UI/MusicList.dart';
import 'package:jainverse/UI/artist_detail_screen.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/utils/ConnectionCheck.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/widgets/auth/auth_tabbar.dart';
import 'package:jainverse/widgets/common_video_player_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:session_storage/session_storage.dart';
import 'package:upgrader/upgrader.dart';

import '../controllers/download_controller.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/loader.dart';
import '../widgets/music/album_card.dart';
import '../widgets/music/circular_card.dart';
import '../widgets/music/genre_card.dart';
import '../widgets/music/music_section_header.dart';
import '../widgets/music/new_albums_card.dart';
import '../widgets/music/playlist_card.dart';
import '../widgets/music/popular_song_card.dart';
import '../widgets/music/song_card.dart';
import 'AccountPage.dart';
import 'Login.dart';

AudioPlayerHandler? _audioHandler;

class HomeDiscover extends StatefulWidget {
  const HomeDiscover({super.key});

  @override
  _state createState() {
    return _state();
  }
}

class _state extends State<HomeDiscover>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Returns the main sliver content for the scroll view
  Widget _buildContentSliver() {
    if (_selectedMedia == 'Video') {
      // Show 'Play Sample Video' button centered when Video tab is selected
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_circle_fill, size: 32),
            label: const Text(
              'Play Sample Video',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              backgroundColor:
                  Colors.deepPurple, // Or appColors().primaryColorApp
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => CommonVideoPlayerScreen(
                        videoUrl:
                            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
                        videoTitle: 'Big Buck Bunny',
                      ),
                ),
              );
            },
          ),
        ),
      );
    } else if (_cachedMusicData != null) {
      return SliverToBoxAdapter(
        child: _buildMusicCategories(_cachedMusicData!),
      );
    } else if (_isLoading) {
      return SliverToBoxAdapter(child: _buildLoadingWidget());
    } else if (_hasError || !connected) {
      return SliverToBoxAdapter(child: _buildErrorWidget());
    } else {
      return SliverToBoxAdapter(child: _buildErrorWidget());
    }
  }

  // Media selection for AuthTabBar (Audio/Video)
  String _selectedMedia = 'Audio';
  late UserModel model;
  SharedPref sharePrefs = SharedPref();
  bool isOpen = false;
  var progressString = "";
  String isSelected = 'all';
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  String version = '';
  String buildNumber = '', appPackageName = '';
  String token = '';
  bool connected = true, checkRuning = false;
  bool allowDown = false, allowAds = true;
  List<DataMusic> listVideo = [];
  late ModelSettings modelSettings;

  // Update these variables for better header control
  late ScrollController _scrollController;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  // New animation controller for smoother transitions
  late AnimationController _headerAnimationController;

  final session = SessionStorage();

  // Add a cached data variable to prevent multiple fetches
  ModelCatSubcatMusic? _cachedMusicData;
  bool _isLoading = true;

  // Add error state tracking
  bool _hasError = false;
  String _errorMessage = '';

  // Add presenter instance as class member for better reuse
  final CatSubcatMusicPresenter _presenter = CatSubcatMusicPresenter();

  // Add favorite service instance
  final FavoriteService _favoriteService = FavoriteService();

  // Add favorite state management for HomeDiscover songs
  final Set<String> _favoriteIds = <String>{};
  bool _favoritesLoaded = false;

  // Centralized music action handler
  late MusicActionHandler _musicActionHandler;

  // Add flags to track data loading state
  bool _hasInitialized = false;

  bool _isNavigatingBack = false;

  // iOS overlay entry for download message management
  OverlayEntry? _currentOverlayEntry;

  // Add flag to track background refresh
  bool _isRefreshingInBackground = false;
  DateTime? _lastRefreshTime;

  // Add timer for periodic background refresh
  Timer? _periodicRefreshTimer;

  Future<void> getSettings() async {
    String? sett = await sharePrefs.getSettings();

    // Add null safety check
    if (sett == null || sett.isEmpty) {
      // Handle case where settings are null or empty
      // You can either return early or provide default values
      print('Settings data is null or empty');
      return;
    }

    try {
      final Map<String, dynamic> parsed = json.decode(sett);
      modelSettings = ModelSettings.fromJson(parsed);

      if (modelSettings.data.status == 0) {
        sharePrefs.removeValues();
        // Clear all cache data including images when logging out
        await CacheManager.clearAllCacheIncludingImages();
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

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle JSON parsing errors
      print('Error parsing settings JSON: $e');
      // Optionally set default values or show error to user
    }
  }

  void _reload() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<dynamic> value() async {
    // Get token first before proceeding
    token = await sharePrefs.getToken();
    print('Token retrieved: $token');

    if (token.isEmpty) {
      print('Warning: Empty token retrieved');
    }

    // Continue with other initializations
    try {
      await apiSettings();
      model = await sharePrefs.getUserData();

      await PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
        version = packageInfo.version;
        buildNumber = packageInfo.buildNumber;
        appPackageName = packageInfo.packageName;
      });

      sharedPreThemeData = await sharePrefs.getThemeData();

      if (mounted) {
        setState(() {});
      }
      return model;
    } catch (e) {
      print('Error in value() method: $e');
    }
  }

  Future<void> apiSettings() async {
    String settingDetails = await AppSettingsPresenter().getAppSettings(token);

    sharePrefs.setSettingsData(settingDetails);
    model = await sharePrefs.getUserData();
    String? sett = await sharePrefs.getSettings();

    // Add null safety check here too
    if (sett == null || sett.isEmpty) {
      print('Settings data is null or empty in apiSettings');
      return;
    }

    try {
      final Map<String, dynamic> parsed = json.decode(sett);
      modelSettings = ModelSettings.fromJson(parsed);
    } catch (e) {
      print('Error parsing settings JSON in apiSettings: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Remove explicit play call - let AudioService handle playback state
        // Only trigger background refresh when app is resumed
        _handleAppResume();
        break;
      case AppLifecycleState.paused:
        // Remove explicit pause call - AudioService will handle background playback
        // Stop periodic refresh when app goes to background
        _stopPeriodicRefresh();
        break;
      case AppLifecycleState.inactive:
        // Remove explicit pause call - let AudioService manage playback continuity
        break;
      case AppLifecycleState.detached:
        // Only stop when app is actually being terminated
        _audioHandler?.stop();
        _stopPeriodicRefresh();
        break;
      case AppLifecycleState.hidden:
        _stopPeriodicRefresh();
        break;
    }
  }

  // Handle app resume - refresh data in background while showing cached data
  Future<void> _handleAppResume() async {
    print('App resumed, checking for background refresh');

    // Check if we should force refresh for long periods of inactivity
    if (_shouldForceRefresh()) {
      print('Force refresh due to long inactivity');
      // Clear cache and refresh
      await CacheManager.clearCache(CacheManager.MUSIC_CATEGORIES_CACHE_KEY);
      _refreshDataInBackground();
    } else if (_shouldRefreshData()) {
      print('Triggering background refresh');
      _refreshDataInBackground();
    }

    // Start periodic refresh timer if not already running
    _startPeriodicRefresh();
  }

  // Start periodic background refresh every 10 minutes
  void _startPeriodicRefresh() {
    _periodicRefreshTimer?.cancel(); // Cancel existing timer if any

    _periodicRefreshTimer = Timer.periodic(const Duration(minutes: 10), (
      timer,
    ) {
      if (mounted && _shouldRefreshData()) {
        print('Periodic background refresh triggered');
        _refreshDataInBackground();
      }
    });
  }

  // Stop periodic refresh (called when app goes to background)
  void _stopPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
  }

  // Check if we should refresh data based on time elapsed
  bool _shouldRefreshData() {
    if (_lastRefreshTime == null) return true;

    final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
    // Refresh if more than 5 minutes have passed
    return timeSinceLastRefresh.inMinutes >= 5;
  }

  // Check if we should force refresh (for longer periods)
  bool _shouldForceRefresh() {
    if (_lastRefreshTime == null) return true;

    final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
    // Force refresh if more than 30 minutes have passed
    return timeSinceLastRefresh.inMinutes >= 30;
  }

  // Refresh data in background without affecting UI
  Future<void> _refreshDataInBackground() async {
    if (_isRefreshingInBackground || token.isEmpty) return;

    _isRefreshingInBackground = true;
    _lastRefreshTime = DateTime.now();

    try {
      await checkConn();
      if (connected) {
        print('Starting background refresh...');

        final freshData = await _presenter
            .getCatSubCatMusicList(token, context)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('Background refresh timed out');
              },
            );

        // Save to cache
        await CacheManager.saveToCache(
          CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
          freshData.toJson(),
        );

        // Update UI only if the new data is different or significantly newer
        if (mounted && _shouldUpdateUI(freshData)) {
          setState(() {
            _cachedMusicData = freshData;
            print('Background refresh completed - UI updated');
          });
        } else {
          print(
            'Background refresh completed - UI not updated (no significant changes)',
          );
        }
      }
    } catch (e) {
      print('Background refresh failed: $e');
      // Don't show error to user for background refresh failures
    } finally {
      _isRefreshingInBackground = false;
    }
  }

  // Check if UI should be updated with new data
  bool _shouldUpdateUI(ModelCatSubcatMusic newData) {
    if (_cachedMusicData == null) return true;

    // Compare number of categories
    if (newData.data.length != _cachedMusicData!.data.length) return true;

    for (int i = 0; i < newData.data.length; i++) {
      final newCat = newData.data[i];
      final oldCat = _cachedMusicData!.data.firstWhere(
        (cat) => cat.cat_name == newCat.cat_name,
        orElse: () => DataCat('', '', []),
      );
      // If category not found in old data, update UI
      if (oldCat.cat_name.isEmpty) return true;

      // Compare number of subcategories
      if (newCat.sub_category.length != oldCat.sub_category.length) return true;

      // Compare subcategory IDs or names
      for (int j = 0; j < newCat.sub_category.length; j++) {
        final newSub = newCat.sub_category[j];
        final oldSub = oldCat.sub_category.firstWhere(
          (sub) => sub.id == newSub.id,
          orElse: () => SubData(-1, '', '', '', null),
        );
        // If subcategory not found or name/artist/description changed, update UI
        if (oldSub.id == -1 ||
            oldSub.name != newSub.name ||
            (oldSub.artist != null
                    ? oldSub.artist!.map((a) => a.name).join(', ')
                    : '') !=
                (newSub.artist != null
                    ? newSub.artist!.map((a) => a.name).join(', ')
                    : '') ||
            oldSub.description != newSub.description) {
          return true;
        }
      }
    }
    // No significant changes found
    return false;
  }

  /// Prefetch network images found in the categories to warm Flutter's
  /// in-memory image cache so the first visible render is faster.
  ///
  /// This will deduplicate URLs and prefetch them in small concurrent
  /// batches to avoid overwhelming memory or network.
  Future<void> _prefetchImages(ModelCatSubcatMusic data) async {
    if (!mounted) return;

    try {
      final Set<String> urls = <String>{};

      for (final cat in data.data) {
        final base = AppConstant.ImageUrl + cat.imagePath;
        for (final sub in cat.sub_category) {
          final img = sub.image;
          if (img.isNotEmpty) {
            urls.add(base + img);
          }
        }
      }

      if (urls.isEmpty) return;

      // Limit total prefetch to a reasonable number (avoid huge upfront work)
      const int maxToPrefetch = 120;
      final List<String> toPrefetch = urls.take(maxToPrefetch).toList();

      const int concurrency = 6; // number of parallel prefetches

      for (var i = 0; i < toPrefetch.length; i += concurrency) {
        final batch = toPrefetch.skip(i).take(concurrency).toList();
        await Future.wait(
          batch.map((url) async {
            try {
              // Use NetworkImage and precacheImage to warm the framework cache
              final provider = NetworkImage(url);
              await precacheImage(provider, context);
            } catch (e) {
              // Ignore individual image failures - continue with others
            }
          }),
        );
        // small delay between batches to let UI breathe
        await Future.delayed(const Duration(milliseconds: 60));
      }
    } catch (e) {
      // Top-level safety - do not crash if prefetching fails
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _headerAnimationController.dispose();

    // Cancel periodic refresh timer
    _periodicRefreshTimer?.cancel();

    // Clean up iOS overlay entry
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Set up iOS download UI callback for progress messages
  void _setupIOSDownloadCallback() {
    // Set up iOS UI callback for download progress messages (iOS only)
    if (Platform.isIOS) {
      final downloadController = DownloadController();
      downloadController.setIOSUICallback(_showDownloadMessageFromCallback);
      print('iOS download UI callback set up successfully');
    } else {
      print('Android platform: Using notifications for download feedback');
    }
  }

  /// Show download message using the iOS overlay system (called from DownloadController)
  void _showDownloadMessageFromCallback(String message) {
    if (Platform.isIOS && mounted) {
      _showIOSDownloadMessage(message);
    }
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> checkConn() async {
    connected = await ConnectionCheck().checkConnection();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> checkRunning() async {
    checkRuning = true;
  }

  @override
  void initState() {
    // Initialize scroll controller
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    // Initialize animation controller
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Ensure session page is set to 0 immediately
    session['page'] = "0";

    checkConn();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioHandler = const MyApp().called();

    // Initialize the centralized music action handler
    _musicActionHandler = MusicActionHandlerFactory.create(
      context: context,
      audioHandler: _audioHandler,
      favoriteService: _favoriteService,
      onStateUpdate: () => setState(() {}),
    );

    // Set up iOS download callback
    _setupIOSDownloadCallback();

    // Start loading sequence only if not initialized
    if (!_hasInitialized) {
      _initializeData();
    }

    // Load favorites for state management (non-blocking)
    _loadFavorites();

    checkRunning();
  }

  // Add navigation lifecycle awareness
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check if we're returning from navigation
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && _isNavigatingBack) {
      _isNavigatingBack = false;
      // Only refresh if cache is expired or user explicitly requested refresh
      _checkAndRefreshIfNeeded();
    }

    // If we're coming to this screen for the first time after app resume
    // and we have cached data, refresh in background
    if (route != null && route.isCurrent && _cachedMusicData != null) {
      _refreshDataInBackground();
    }
  }

  // Check if refresh is needed when returning to screen
  Future<void> _checkAndRefreshIfNeeded() async {
    // Only refresh if cache is expired and we're not already loading
    final hasCachedData = await CacheManager.hasCachedData(
      CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
    );

    if (!hasCachedData &&
        !CacheManager.isFreshDataLoading &&
        token.isNotEmpty) {
      print('Cache expired, refreshing data in background');
      await _loadFreshData();
    }
  }

  // New method to initialize data in the correct sequence
  Future<void> _initializeData() async {
    if (_hasInitialized) return;

    try {
      // Always try to load cached data first for immediate display
      await _tryLoadCachedData();

      // Get token and settings in parallel
      await value(); // This sets the token
      await getSettings();

      // Always trigger background refresh if we have token, regardless of cache status
      if (token.isNotEmpty) {
        print('Starting background refresh during initialization');
        _refreshDataInBackground();
        // Start periodic refresh
        _startPeriodicRefresh();
      } else {
        // If no token and no cached data, show error
        if (_cachedMusicData == null && mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Authentication error. Please login again.';
          });
        }
      }

      _hasInitialized = true;
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_cachedMusicData == null) {
            _hasError = true;
            _errorMessage = 'Failed to initialize. Please try again.';
          }
        });
      }
    }
  }

  // New method to try loading cached data first
  Future<void> _tryLoadCachedData() async {
    try {
      final cachedData = await CacheManager.getFromCache(
        CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
      );

      if (cachedData != null) {
        // Parse the JSON data properly
        final dataString = cachedData['data'] as String;
        final parsedData = json.decode(dataString);
        final modelData = ModelCatSubcatMusic.fromJson(parsedData);

        if (mounted) {
          setState(() {
            _cachedMusicData = modelData;
            _isLoading = false;
            _hasError = false;
            print('Loaded data from cache');
          });
        }
      } else {
        // No cached data found, ensure loading state is active
        if (mounted) {
          setState(() {
            _isLoading = true;
            _hasError = false;
            print('No cached data found, showing loader');
          });
        }
      }
    } catch (e) {
      print('Error loading cached data: $e');
      // Clear corrupted cache
      await CacheManager.clearCache(CacheManager.MUSIC_CATEGORIES_CACHE_KEY);
      // Set loading state when cache fails
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }
    }
  }

  // Modified load data method with navigation awareness
  Future<void> _loadFreshData() async {
    if (token.isEmpty) {
      print('Token is empty, cannot load data');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Authentication error. Please login again.';
        });
      }
      return;
    }

    // Check if already loading to prevent duplicate calls
    if (CacheManager.isFreshDataLoading) {
      print('Data is already being loaded, skipping duplicate request');
      return;
    }

    // Set loading state in cache manager
    CacheManager.setFreshDataLoading(true);

    // If we already have cached data, refresh in background
    final bool loadInBackground = _cachedMusicData != null;

    if (!loadInBackground) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
          _errorMessage = '';
        });
      }
    }

    try {
      if (connected) {
        print('Loading fresh music data with token: $token');

        final freshData = await _presenter
            .getCatSubCatMusicList(token, context)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Request timed out after 10 seconds');
              },
            );

        print('Fresh music data loaded successfully');

        // Save to cache
        await CacheManager.saveToCache(
          CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
          freshData.toJson(),
        );

        // Prefetch images to warm the Flutter image cache for first-render
        Future.microtask(() => _prefetchImages(freshData));

        // Prefetch images in background refresh as well
        Future.microtask(() => _prefetchImages(freshData));

        if (mounted) {
          setState(() {
            _cachedMusicData = freshData;
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        print('No internet connection, skipping data load');
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (_cachedMusicData == null) {
              _hasError = true;
              _errorMessage = 'No internet connection';
            }
          });
        }
      }
    } catch (e) {
      print('Error loading fresh music data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;

          // Only show error if we don't have cached data
          if (_cachedMusicData == null) {
            _hasError = true;
            if (e is TimeoutException) {
              _errorMessage =
                  'Request timed out. Please check your connection and try again.';
            } else if (e.toString().contains('connection') ||
                e.toString().contains('network')) {
              _errorMessage =
                  'Network connection error. Please check your internet connection.';
            } else {
              _errorMessage = 'Failed to load content. Please try again.';
            }
          }
        });
      }
    } finally {
      // Clear loading state
      CacheManager.setFreshDataLoading(false);
    }
  }

  // Optimized refresh method
  Future<void> _refreshData() async {
    await checkConn();

    // Force cache refresh for pull-to-refresh
    await CacheManager.forceRefreshCache(
      CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
    );

    // Show immediate feedback that refresh is happening
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    await _loadFreshData();
  }

  // Add this method to define the category order
  List<String> _getCategoryOrder() {
    return [
      "Featured Playlist",
      "Featured Songs",
      "New Albums and EP's",
      "New Songs",
      "Popular Artist",
      "Popular Songs",
      "Popular Albums",
      "Trending Genres",
    ];
  }

  // Helper method to get category priority for sorting
  int _getCategoryPriority(String categoryName) {
    final order = _getCategoryOrder();
    final index = order.indexOf(categoryName);
    return index == -1 ? 999 : index; // Unknown categories go to end
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light, // For iOS
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        // Background container
        Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          color: Colors.white,
        ),

        // Main content
        _buildMainScrollableContent(),

        // Animated header
        _buildAnimatedHeader(),

        // Upgrade card
        Positioned(
          top: MediaQuery.of(context).padding.top + 55.w,
          left: 0,
          right: 0,
          child: UpgradeCard(),
        ),
      ],
    );
  }

  Widget _buildAnimatedHeader() {
    return AnimatedSlide(
      offset: _isHeaderVisible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 250), // Slightly faster animation
      curve: Curves.easeInOut,
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95), // Increased opacity
            ),
            child: AppHeader(
              title: "Discover",
              showProfileIcon: true,
              onProfileTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountPage()),
                );
              },
              backgroundColor: Colors.transparent, // Changed to transparent
              scrollController: _scrollController,
              scrollAware: false, // Disabled scroll awareness in AppHeader
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScrollableContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: appColors().primaryColorApp,
      backgroundColor: Colors.white,
      displacement:
          MediaQuery.of(context).padding.top + AppSizes.refreshDisplacement,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Top padding for header
          SliverPadding(
            padding: EdgeInsets.only(
              top:
                  MediaQuery.of(context).padding.top +
                  AppSizes.topPaddingOffset,
            ),
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // AuthTabBar as a sliver so it scrolls with content
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: 18.w,
              ), // Increased margin for better spacing
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 5.w,
                  horizontal: AppSizes.contentHorizontalPadding,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.w),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8.w,
                        offset: Offset(0, 2.w),
                      ),
                    ],
                  ),
                  child: AuthTabBar(
                    selectedRole: _selectedMedia,
                    onRoleChanged: (media) {
                      setState(() {
                        _selectedMedia = media;
                      });
                    },
                    options: const ['Audio', 'Video'],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          StreamBuilder<MediaItem?>(
            stream: _audioHandler!.mediaItem,
            builder: (context, snapshot) {
              final hasMiniPlayer = snapshot.hasData;
              final bottomPadding =
                  hasMiniPlayer
                      ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 15.w
                      : AppSizes.basePadding;

              return SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.contentHorizontalPadding,
                  AppSizes.contentTopPadding,
                  AppSizes.contentRightPadding,
                  bottomPadding,
                ),
                sliver: _buildContentSliver(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper method to build category headers
  Widget _buildCategoryHeader(DataCat category, BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        12.w,
        0.w, // Removed top margin for tighter spacing
        12.w,
        1.w, // Reduced bottom margin
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 1.w, // Reduced padding for tighter spacing
        ),
        child: MusicSectionHeader(
          title: category.cat_name,
          sharedPreThemeData: sharedPreThemeData,
          onViewAllPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        AllCategoryByName(_audioHandler, category.cat_name),
              ),
            ).then((value) {
              // Only reload if coming back from AllCategoryByName
              if (mounted) {
                _reload();
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 162.w,
      width: MediaQuery.of(context).size.width,
      child: Center(
        child: Container(
          margin: EdgeInsets.only(bottom: 100.w),
          child: CircleLoader(size: 250.w, showLogo: true),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 250.w,
      width: MediaQuery.of(context).size.width,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder image
            Container(
              height: 325.w,
              width: MediaQuery.of(context).size.width * 0.8,
              margin: EdgeInsets.symmetric(horizontal: 25.w),
              child: Image.asset(
                'assets/images/placeholder.png',
                fit: BoxFit.contain,
              ),
            ),

            SizedBox(height: 25.w),

            // Error message
            Container(
              margin: EdgeInsets.symmetric(horizontal: 25.w),
              child: Text(
                _hasError && _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'No Internet Found!\nPlease check your connection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 22.w,
                  color: appColors().colorTextHead,
                ),
              ),
            ),

            SizedBox(height: 37.w),

            // Refresh button
            InkWell(
              onTap: _refreshData,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 37.w, vertical: 15.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      appColors().primaryColorApp,
                      appColors().primaryColorApp,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(31.w),
                  boxShadow: [
                    BoxShadow(
                      color: appColors().primaryColorApp.withOpacity(0.3),
                      blurRadius: 10.w,
                      offset: Offset(0, 5.w),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 25.w),
                    SizedBox(width: 10.w),
                    Text(
                      'Try Again',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 20.w,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicCategories(ModelCatSubcatMusic data) {
    List<DataCat> nonEmptyCategories =
        data.data.where((cat) => cat.sub_category.isNotEmpty).toList();

    if (nonEmptyCategories.isEmpty) {
      return _buildNoDataWidget();
    }

    // Sort categories according to the specified order
    nonEmptyCategories.sort((a, b) {
      int priorityA = _getCategoryPriority(a.cat_name);
      int priorityB = _getCategoryPriority(b.cat_name);
      return priorityA.compareTo(priorityB);
    });

    return ListView.builder(
      scrollDirection: Axis.vertical,
      itemCount: nonEmptyCategories.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Container(
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.only(
            bottom: 12.w,
          ), // Reduced bottom margin for tighter section spacing
          child: Column(
            children: [
              _buildCategoryHeader(nonEmptyCategories[index], context),
              _buildContentRow(nonEmptyCategories[index], context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoDataWidget() {
    return SizedBox(
      height:
          MediaQuery.of(context).size.height - 125.w, // Reduced height slightly
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 312.w,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22.w,
                50.w, // Keep reduced top margin
                0.w,
                19.w,
              ),
              child: Image.asset('assets/images/placeholder.png'),
            ),
          ),
          Text(
            'No Record Found !!',
            style: TextStyle(
              color:
                  (sharedPreThemeData.themeImageBack.isEmpty)
                      ? Color(int.parse(AppSettings.colorText))
                      : appColors().colorText,
              fontFamily: 'Poppins', // Explicitly using existing font family
              fontSize: 25.w,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build Popular Songs in a 2-row grid format
  Widget _buildPopularSongsGrid(DataCat category, BuildContext context) {
    final items = category.sub_category;

    if (items.length == 1) {
      return Align(
        alignment: Alignment.centerLeft, // Ensure left alignment
        child: _buildPopularSongItem(category, 0, context, isSingle: true),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: (items.length / 2).ceil(),
      itemBuilder: (context, columnIndex) {
        // Let the card handle its own width - no override here
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start, // Left align columns
          children: [
            if (columnIndex * 2 < items.length)
              SizedBox(
                height: 180.w,
                child: _buildPopularSongItem(
                  category,
                  columnIndex * 2,
                  context,
                ),
              ),
            SizedBox(height: 3.w), // Minimal spacing between rows
            if (columnIndex * 2 + 1 < items.length)
              SizedBox(
                height: 160.w,
                child: _buildPopularSongItem(
                  category,
                  columnIndex * 2 + 1,
                  context,
                ),
              ),
          ],
        );
      },
    );
  }

  // Helper method to build individual popular song items
  Widget _buildPopularSongItem(
    DataCat category,
    int idx,
    BuildContext context, {
    bool isSingle = false,
  }) {
    final imagePath =
        AppConstant.ImageUrl +
        category.imagePath +
        category.sub_category[idx].image;
    final subCategory = category.sub_category[idx];
    final name = subCategory.name;
    String artistName = '';
    if (subCategory.artist != null && subCategory.artist!.isNotEmpty) {
      final names = subCategory.artist!.map((a) => a.name).toList();
      if (names.length == 1) {
        artistName = names[0];
      } else if (names.length == 2) {
        artistName = '${names[0]} and ${names[1]}';
      } else {
        artistName =
            '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
      }
    }

    onTap() => _handleItemTap(category, idx, context, "Popular Songs");

    return PopularSongCard(
      songId:
          subCategory.id
              .toString(), // Pass songId for global favorites management
      imagePath: imagePath,
      songName: name,
      artistName: artistName,
      onTap: onTap,
      sharedPreThemeData: sharedPreThemeData,
      height: 160.w, // Decreased height for more compact card
      isCompact: isSingle,
      // Remove static isFavorite - let PopularSongCard use global provider
      onPlay:
          () => _musicActionHandler.handlePlaySong(
            subCategory.id.toString(),
            name,
          ),
      onPlayNext:
          () => _musicActionHandler.handlePlayNext(
            subCategory.id.toString(),
            name,
            artistName,
          ),
      onAddToQueue:
          () => _musicActionHandler.handleAddToQueue(
            subCategory.id.toString(),
            name,
            artistName,
          ),
      onDownload:
          () => _musicActionHandler.handleDownload(
            name,
            "song",
            subCategory.id.toString(),
          ),
      onAddToPlaylist:
          () => _musicActionHandler.handleAddToPlaylist(
            subCategory.id.toString(),
            name,
            artistName,
          ),
      onShare:
          () => _musicActionHandler.handleShare(
            name,
            "song",
            itemId: subCategory.id.toString(),
            slug: subCategory.slug,
          ),
      onFavorite:
          () => _musicActionHandler.handleFavoriteToggle(
            subCategory.id.toString(),
            name,
            favoriteIds: _favoriteIds,
          ),
    );
  }

  // Helper method to get responsive item height based on category type and screen size
  double _getItemHeight(String categoryName) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Base height calculation - optimized for tighter spacing
    double baseHeightRatio =
        screenHeight < 600
            ? 0.22
            : 0.20; // Reduced ratios for more compact layout
    double baseHeight = screenHeight * baseHeightRatio;

    // Adjust for screen width - wider screens can use slightly less height ratio
    if (screenWidth > 400) {
      baseHeight *= 1; // Slightly more aggressive reduction for better spacing
    }

    switch (categoryName) {
      case "Featured Playlist":
        return (baseHeight * 0.90).clamp(
          195.w,
          195.w,
        ); // Slightly reduced minimums for tighter layout
      case "Featured Songs":
        return (baseHeight * 0.90).clamp(
          195.w,
          230.w,
        ); // Account for artist names
      case "Popular Albums":
        return (baseHeight * 0.75).clamp(
          170.w,
          200.w,
        ); // Albums are more compact
      case "New Albums and EP's":
        return (baseHeight * 1).clamp(
          220.w,
          320.w,
        ); // Tallest for descriptions, but reduced
      case "New Songs":
        return (baseHeight * 0.90).clamp(
          195.w,
          230.w,
        ); // Same as Featured Songs
      case "Popular Artist":
        return (baseHeight * 0.60).clamp(
          110.w,
          150.w,
        ); // Smallest for circular cards
      case "Trending Genres":
        return (baseHeight * 0.90).clamp(
          195.w,
          230.w,
        ); // Slightly taller than artists
      case "Popular Songs":
        return (baseHeight * 0.75).clamp(
          170.w,
          250.w,
        ); // Horizontal cards are more compact
      default:
        return (baseHeight).clamp(
          185.w,
          260.w,
        ); // Default responsive height, reduced
    }
  }

  // Helper method to build content rows based on category type
  Widget _buildContentRow(DataCat category, BuildContext context) {
    final categoryName = category.cat_name;
    final itemHeight = _getItemHeight(categoryName);

    // Special handling for Popular Songs to show in 2 rows
    if (categoryName == "Popular Songs") {
      final adjustedHeight = category.sub_category.length == 1 ? 180.w : 360.w;

      return Container(
        width: double.infinity,
        height: adjustedHeight,
        alignment: Alignment.centerLeft, // Ensure left alignment
        child: _buildPopularSongsGrid(category, context),
      );
    }

    return Container(
      width: double.infinity,
      height: itemHeight,
      alignment: Alignment.centerLeft, // Changed from center to centerLeft
      margin: EdgeInsets.only(left: 7.w),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: category.sub_category.length,
        itemBuilder: (context, idx) {
          return _buildContentItem(category, idx, context, categoryName);
        },
      ),
    );
  }

  /*
   * ALTERNATIVE FLEXIBLE HEIGHT APPROACH:
   *
   * Instead of using fixed heights, you can use IntrinsicHeight to let cards
   * determine their own height naturally. This provides better responsiveness
   * but requires more layout calculations. To implement this approach:
   *
   * 1. Replace ListView.builder with Row in _buildContentRow
   * 2. Wrap the content in IntrinsicHeight widget
   * 3. Use crossAxisAlignment: CrossAxisAlignment.stretch for consistent heights
   *
   * Example implementation:
   *
   * return IntrinsicHeight(
   *   child: SingleChildScrollView(
   *     scrollDirection: Axis.horizontal,
   *     child: Row(
   *       crossAxisAlignment: CrossAxisAlignment.stretch,
   *       children: category.sub_category.map((item) => buildCard(item)).toList(),
   *     ),
   *   ),
   * );
   */

  // Helper method to build individual content items
  Widget _buildContentItem(
    DataCat category,
    int idx,
    BuildContext context,
    String categoryName,
  ) {
    final imagePath =
        AppConstant.ImageUrl +
        category.imagePath +
        category.sub_category[idx].image;
    final subCategory = category.sub_category[idx];
    final name = subCategory.name;
    String artistName = '';
    if (subCategory.artist != null && subCategory.artist!.isNotEmpty) {
      final names = subCategory.artist!.map((a) => a.name).toList();
      if (names.length == 1) {
        artistName = names[0];
      } else if (names.length == 2) {
        artistName = '${names[0]} and ${names[1]}';
      } else {
        artistName =
            '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
      }
    }
    final description = subCategory.description;

    onTap() => _handleItemTap(category, idx, context, categoryName);

    // Return appropriate card widget based on category type
    switch (categoryName) {
      case "Featured Playlist":
        return PlaylistCard(
          imagePath: imagePath,
          name: name,
          onTap: onTap,
          sharedPreThemeData: sharedPreThemeData,
          songCount: subCategory.description ?? 'Playlist',
          onShare:
              () => _musicActionHandler.handleShare(
                name,
                "playlist",
                itemId: subCategory.id.toString(),
                slug: subCategory.slug,
              ),
          onRemove:
              () => _handleRemoveWithId(
                name,
                "playlist",
                subCategory.id.toString(),
              ),
        );

      case "Popular Artist":
        return CircularCard(
          imagePath: imagePath,
          title: name,
          onTap: onTap,
          sharedPreThemeData: sharedPreThemeData,
        );

      case "Popular Albums":
        return AlbumCard(
          imagePath: imagePath,
          albumName: name,
          artistName: artistName,
          onTap: onTap,
          sharedPreThemeData: sharedPreThemeData,
          onShare:
              () => _musicActionHandler.handleShare(
                name,
                "album",
                itemId: subCategory.id.toString(),
                slug: subCategory.slug,
              ),
        );

      case "New Albums and EP's":
        return NewAlbumsCard(
          imagePath: imagePath,
          albumName: name,
          artistName: artistName,
          description: description,
          onTap: onTap,
          sharedPreThemeData: sharedPreThemeData,
          onShare:
              () => _musicActionHandler.handleShare(
                name,
                "album",
                itemId: subCategory.id.toString(),
                slug: subCategory.slug,
              ),
        );

      case "Popular Songs":
        return PopularSongCard(
          imagePath: imagePath,
          songName: name,
          artistName: artistName,
          onTap: onTap,
          sharedPreThemeData: sharedPreThemeData,
          isFavorite: _isSongFavorited(
            subCategory.id.toString(),
          ), // Add favorite status
          onPlay:
              () => _musicActionHandler.handlePlaySong(
                subCategory.id.toString(),
                name,
              ),
          onPlayNext:
              () => _musicActionHandler.handlePlayNext(
                subCategory.id.toString(),
                name,
                artistName,
              ),
          onAddToQueue:
              () => _musicActionHandler.handleAddToQueue(
                subCategory.id.toString(),
                name,
                artistName,
              ),
          onDownload:
              () => _musicActionHandler.handleDownload(
                name,
                "song",
                subCategory.id.toString(),
              ),
          onAddToPlaylist:
              () => _musicActionHandler.handleAddToPlaylist(
                subCategory.id.toString(),
                name,
                artistName,
              ),
          onShare:
              () => _musicActionHandler.handleShare(
                name,
                "song",
                itemId: subCategory.id.toString(),
                slug: subCategory.slug,
              ),
          onFavorite:
              () => _musicActionHandler.handleFavoriteToggle(
                subCategory.id.toString(),
                name,
                favoriteIds: _favoriteIds,
              ),
        );

      case "Trending Genres":
        return GenreCard(
          imagePath: imagePath,
          genreName: name,
          onTap: onTap,
          sharedPreThemeData: sharedPreThemeData,
          description: description,
        );

      case "Featured Songs":
      case "New Songs":
      default:
        return SongCard(
          songId:
              subCategory.id
                  .toString(), // Pass songId for global favorites management
          imagePath: imagePath,
          songName: name,
          artistName: artistName,
          onTap: onTap,
          sharedPreThemeData: sharedPreThemeData,
          // Remove static isFavorite - let SongCard use global provider
          onPlay:
              () => _musicActionHandler.handlePlaySong(
                subCategory.id.toString(),
                name,
              ),
          onPlayNext:
              () => _musicActionHandler.handlePlayNext(
                subCategory.id.toString(),
                name,
                artistName,
              ),
          onAddToQueue:
              () => _musicActionHandler.handleAddToQueue(
                subCategory.id.toString(),
                name,
                artistName,
              ),
          onDownload:
              () => _musicActionHandler.handleDownload(
                name,
                "song",
                subCategory.id.toString(),
              ),
          onAddToPlaylist:
              () => _musicActionHandler.handleAddToPlaylist(
                subCategory.id.toString(),
                name,
                artistName,
              ),
          onShare:
              () => _musicActionHandler.handleShare(
                name,
                "song",
                itemId: subCategory.id.toString(),
                slug: subCategory.slug,
              ),
          onFavorite:
              () => _musicActionHandler.handleFavoriteToggle(
                subCategory.id.toString(),
                name,
                favoriteIds: _favoriteIds,
              ),
        );
    }
  }

  // Helper method to handle item taps with navigation tracking
  void _handleItemTap(
    DataCat category,
    int idx,
    BuildContext context,
    String categoryName,
  ) {
    final subCategory = category.sub_category[idx];
    final id = subCategory.id.toString();
    final name = subCategory.name;

    // Set navigation flag
    _isNavigatingBack = true;

    print(
      '🎵🎵🎵 HOMEDISCOVER TAP: $categoryName, ID: $id, Name: $name 🎵🎵🎵',
    );

    // For song categories, use direct mini player playback
    if (categoryName.contains("Featured Songs") ||
        categoryName.contains("New Songs") ||
        categoryName.contains("Popular Songs")) {
      // Add haptic feedback for song taps
      HapticFeedback.mediumImpact();

      // For individual songs - play directly in mini player
      _loadAndPlayContent(id, "Songs", name);
    } else if (categoryName == "Popular Artist") {
      // Navigate to ArtistDetailScreen for artist cards
      final artistId = id;
      final artistName = name;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ArtistDetailScreen(
                audioHandler: _audioHandler,
                idTag: artistId,
                typ: 'Artists',
                catName: artistName,
              ),
          settings: const RouteSettings(name: '/track_info_to_artist_songs'),
        ),
      ).then((value) {
        _refreshContent();
      });
    } else {
      // For all other categories (playlists, albums, genres),
      // navigate to MusicList screen for API call and detailed view
      String apiType = _getApiType(categoryName);

      print(
        '[DEBUG] Navigating to MusicList for $categoryName ($apiType): $name, ID: $id',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MusicList(_audioHandler, id, apiType, name),
        ),
      ).then((value) {
        print('[DEBUG] Returned from MusicList, value: $value');
        _refreshContent(); // Refresh content when returning
      });
    }
  }

  // Convert display category name to API type
  String _getApiType(String displayName) {
    switch (displayName) {
      case "Featured Playlist":
        return "Featured Playlists";
      case "Featured Songs":
        return "Featured Songs";
      case "New Albums and EP's":
        return "New Albums";
      case "New Songs":
        return "New Songs";
      case "Popular Artist":
        return "Artists";
      case "Popular Songs":
        return "Trending Songs";
      case "Popular Albums":
        return "Trending Albums";
      case "Trending Genres":
        return "Trending Genres";
      default:
        return displayName;
    }
  }

  // Helper method to refresh content after navigation
  void _refreshContent() {
    if (mounted) {
      setState(() {
        _isNavigatingBack = false;
      });
      _loadCategories();
    }
  }

  // Scroll listener for header animation
  void _scrollListener() {
    if (!_scrollController.hasClients || !mounted) return;

    final currentPosition = _scrollController.position.pixels;
    final scrollDelta = currentPosition - _lastScrollPosition;

    // Check if we're at the top of the scroll view with a small tolerance
    final isAtTop = currentPosition <= 5.0;

    // More sensitive threshold for detecting scroll direction
    const double scrollThreshold = 10.0;

    // Always show header when at top
    if (isAtTop) {
      if (!_isHeaderVisible && mounted) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    } else {
      // Handle header visibility based on scroll direction when not at top
      if (scrollDelta > scrollThreshold && _isHeaderVisible && mounted) {
        // Scrolling down significantly - hide header
        setState(() {
          _isHeaderVisible = false;
        });
      } else if (scrollDelta < -scrollThreshold &&
          !_isHeaderVisible &&
          mounted) {
        // Scrolling up significantly - show header
        setState(() {
          _isHeaderVisible = true;
        });
      }
    }

    _lastScrollPosition = currentPosition;
  }

  // Load fresh categories data
  Future<void> _loadCategories() async {
    if (_isLoading || !mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _loadFreshData();
    } catch (e) {
      print('Error loading categories: $e');
      setState(() {
        _hasError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load content and play directly with the mini player
  /// This method handles all types of content (songs, albums, playlists, etc.)
  Future<void> _loadAndPlayContent(
    String id,
    String contentType,
    String name,
  ) async {
    try {
      print(
        '[DEBUG] Loading content for ID: $id, Type: $contentType, Name: $name',
      );

      // Get the songs for this content
      final response = await _presenter.getMusicListByCategory(
        id,
        contentType,
        token,
      );

      if (response.data.isNotEmpty) {
        print(
          '[DEBUG] Successfully loaded ${response.data.length} songs for $contentType: $name',
        );

        // Use music manager for queue replacement
        final musicManager = MusicManager();

        await musicManager.replaceQueue(
          musicList: response.data,
          startIndex: 0, // Start from the first song
          pathImage: response.imagePath,
          audioPath: response.audioPath,
          callSource: 'HomeDiscover.playContent',
          contextType: contentType,
          contextId: id,
        );

        // Show mini player
        final stateManager = MusicPlayerStateManager();
        stateManager.showMiniPlayerForMusicStart();

        print('[DEBUG] Music playback started via mini player');
      } else {
        print('[ERROR] No content found for this $contentType');
      }
    } catch (e) {
      print('[ERROR] Failed to load and play content: $e');
    }
  }

  /// Handle remove action for music items
  void _handleRemoveWithId(
    String itemName,
    String itemType,
    String itemId,
  ) async {
    try {
      // Show confirmation dialog with improved styling
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Remove $itemType',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: Colors.black87,
              ),
            ),
            content: Text(
              'Are you sure you want to remove "$itemName" from your library?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: 'Poppins',
                color: appColors().gray[500],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                    color: appColors().gray[500],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: appColors().primaryColorApp,
                ),
                child: Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: appColors().primaryColorApp,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        // Show processing message
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Removing $itemName...'),
        //     duration: Duration(seconds: 2),
        //   ),
        // );

        // Here you would implement the actual API call to remove the item
        // For now, we'll simulate it
        await Future.delayed(Duration(milliseconds: 500));

        print('✅ $itemType "$itemName" removed from library');

        // Show success message
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('$itemName removed successfully'),
        //     backgroundColor: Colors.green,
        //     duration: Duration(seconds: 2),
        //   ),
        // );

        // TODO: Refresh the UI to reflect the removal
        // You might want to call setState() or refresh the data
      }
    } catch (e) {
      print('❌ Error removing $itemType: $e');
    }
  }

  /// Show iOS download message using overlay (similar to MusicPlayerView)
  /// This method is specifically for iOS platform only
  void _showIOSDownloadMessage(String message, {double fontSize = 15}) {
    // Only show UI messages on iOS platform
    if (!Platform.isIOS || !mounted) return;

    final overlay = Overlay.of(context);

    // Remove previous overlay entry if exists
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;

    final overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 45.w,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 1,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(overlayEntry);
    _currentOverlayEntry = overlayEntry;

    // Auto-dismiss after 3 seconds for download messages
    final dismissDuration = const Duration(seconds: 3);
    Future.delayed(dismissDuration, () {
      if (_currentOverlayEntry == overlayEntry) {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
        _currentOverlayEntry = null;
      }
    });
  }

  /// Load user's favorite songs from the API to track state
  Future<void> _loadFavorites() async {
    if (_favoritesLoaded) return;

    try {
      final token = await sharePrefs.getToken();
      if (token.isEmpty) return;

      print('💖 Loading favorites for HomeDiscover state management...');

      // Use the existing FavMusicPresenter to get favorites list
      final favPresenter = FavMusicPresenter();
      final favList = await favPresenter.getFavMusicList(token);

      // Extract favorite IDs from the response
      _favoriteIds.clear();
      for (final song in favList.data) {
        _favoriteIds.add(song.id.toString());
      }

      _favoritesLoaded = true;
      print('💖 Loaded ${_favoriteIds.length} favorites for HomeDiscover');

      if (mounted) {
        setState(() {}); // Update UI with favorite states
      }
    } catch (e) {
      print('💖 Error loading favorites: $e');
      // Continue without favorites - not critical
    }
  }

  /// Check if a song is currently favorited
  bool _isSongFavorited(String songId) {
    return _favoriteIds.contains(songId);
  }
}
