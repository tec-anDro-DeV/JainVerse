import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// Removed legacy ModelCatSubcatMusic usage; HomeController provides home sections
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/utils/video_player_launcher.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/controllers/home_controller.dart';
import 'package:jainverse/Model/home_models.dart';
import 'package:jainverse/models/song_playback_payload.dart';
import 'package:jainverse/widgets/cards/video_card_small.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/Presenter/SongHistoryPresenter.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:session_storage/session_storage.dart';

import '../main.dart';
import '../widgets/common/app_header.dart';
import '../widgets/music/song_history_card.dart';
import '../widgets/music/home_section_header.dart';
import '../widgets/music/horizontal_song_card.dart';
import 'AccountPage.dart';
import 'AllCategoryByName.dart';
import 'Download.dart';
import 'FavoriteOrHistory.dart';
import 'playlist_screen.dart';
import 'history_screen.dart';
import '../videoplayer/screens/liked_videos_screen.dart';
import '../videoplayer/screens/subscribed_channels_screen.dart';

// LibraryItem class for UI items
class LibraryItem {
  final IconData icon;
  final String title;
  final Color color;

  LibraryItem({required this.icon, required this.title, required this.color});
}

AudioPlayerHandler? _audioHandler;

class MyLibrary extends StatefulWidget {
  const MyLibrary({super.key});

  @override
  State<StatefulWidget> createState() {
    return MyState();
  }
}

class MyState extends State<MyLibrary> with SingleTickerProviderStateMixin {
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  bool allowDown = false;

  String isSelected = 'all';
  String token = '';

  final session = SessionStorage();

  // Add scroll controller and header animation
  late ScrollController _scrollController;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  // Music data variables
  bool _isMusicLoading = true;
  bool _hasMusicError = false;
  String _errorMessage = '';

  // History data variables
  ModelMusicList? _cachedHistoryData;
  bool _isHistoryLoading = true;
  bool _hasHistoryError = false;

  // Use HomeController (same as HomeDiscover) for unified home sections
  late final HomeController _homeController;
  void _onHomeControllerUpdate() => setState(() {});

  final SongHistoryPresenter _songhistoryPresenter = SongHistoryPresenter();
  // Keep a legacy presenter for category-specific requests (used only on user taps)
  // legacy presenter removed — category taps now navigate to Music screen

  // Add favorite service instance for context menu
  final FavoriteService _favoriteService = FavoriteService();

  // Add favorite state management for MyLibrary songs
  final Set<String> _favoriteIds = <String>{};
  bool _favoritesLoaded = false;

  // Centralized music action handler
  late MusicActionHandler _musicActionHandler;

  // Library items data
  final List<LibraryItem> libraryItems = [
    LibraryItem(
      icon: Icons.queue_music_outlined,
      title: 'Song Playlist',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.thumb_up_outlined,
      title: 'My Liked Videos',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.subscriptions_outlined,
      title: 'Subscribed Channels',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.download_outlined,
      title: 'Downloaded Songs',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.favorite_outline_outlined,
      title: 'Favorite Songs',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.album_outlined,
      title: 'Albums',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.category_outlined,
      title: 'Genres',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.music_note_outlined,
      title: 'Songs',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.history,
      title: 'History',
      color: appColors().primaryColorApp,
    ),
  ];

  Future<dynamic> value() async {
    token = await sharePrefs.getToken();
    model = await sharePrefs.getUserData();
    sharedPreThemeData = await sharePrefs.getThemeData();
    setState(() {});
    return model;
  }

  /// Safely decode a JSON string. Returns decoded object or null if invalid.
  /// This protects against cases where the API or cache returns plain text
  /// like "error" which would throw a FormatException on json.decode.
  dynamic _safeJsonDecode(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    try {
      return json.decode(trimmed);
    } catch (e) {
      // Try to salvage by locating the first JSON bracket and decoding from there
      try {
        final start = trimmed.indexOf(RegExp(r'[\[{]'));
        if (start != -1) {
          final sub = trimmed.substring(start);
          return json.decode(sub);
        }
      } catch (_) {
        // ignore
      }
      return null;
    }
  }

  // Add music data loading methods similar to HomeDiscover
  // Legacy cached music data removed; HomeController is the single source now.

  // Add initialization tracking
  bool _hasInitialized = false;
  bool _isNavigatingBack = false;

  Future<void> _loadFreshMusicData() async {
    if (token.isEmpty) {
      print('Token is empty, cannot load music data in MyLibrary');
      setState(() {
        _isMusicLoading = false;
        _hasMusicError = true;
        _errorMessage = 'Authentication error. Please login again.';
      });
      return;
    }

    // Check if already loading
    if (CacheManager.isFreshDataLoading) {
      print(
        'Data is already being loaded, skipping duplicate request in MyLibrary',
      );
      return;
    }

    CacheManager.setFreshDataLoading(true);

    if (mounted) {
      setState(() {
        _isMusicLoading = true;
        _hasMusicError = false;
        _errorMessage = '';
      });
    }

    try {
      print('Loading home content via HomeController in MyLibrary');

      // Use HomeController (same as HomeDiscover) instead of CatSubcatMusicPresenter
      await _homeController.loadContent();

      if (mounted) {
        setState(() {
          _isMusicLoading = false;
          _hasMusicError = false;
        });
      }
    } catch (e) {
      print('Error loading fresh music data in MyLibrary: $e');
      if (mounted) {
        setState(() {
          _isMusicLoading = false;
          _hasMusicError = true;
          _errorMessage = 'Failed to load music content. Please try again.';
        });
      }
    } finally {
      CacheManager.setFreshDataLoading(false);
    }
  }

  // History data loading methods
  Future<void> _tryLoadCachedHistoryData() async {
    try {
      final cachedData = await CacheManager.getFromCache('history_data_cache');

      if (cachedData != null) {
        final dataString = cachedData['data'] as String;
        final parsedData = _safeJsonDecode(dataString);
        if (parsedData == null) {
          await CacheManager.clearCache('history_data_cache');
          return;
        }
        final modelData = ModelMusicList.fromJson(parsedData);

        if (mounted) {
          setState(() {
            _cachedHistoryData = modelData;
            _isHistoryLoading = false;
            _hasHistoryError = false;
            print('Loaded history data from cache in MyLibrary');
          });
        }
      }
    } catch (e) {
      print('Error loading cached history data in MyLibrary: $e');
      await CacheManager.clearCache('history_data_cache');
    }
  }

  Future<void> _loadHistoryData() async {
    if (token.isEmpty) {
      print('Token is empty, cannot load history data in MyLibrary');
      setState(() {
        _isHistoryLoading = false;
        _hasHistoryError = true;
      });
      return;
    }

    final bool loadInBackground = _cachedHistoryData != null;

    if (!loadInBackground) {
      if (mounted) {
        setState(() {
          _isHistoryLoading = true;
          _hasHistoryError = false;
        });
      }
    }

    try {
      print('Loading history data in MyLibrary with token: $token');

      final String response = await _songhistoryPresenter.getHistory(token);
      final parsed = _safeJsonDecode(response);
      if (parsed == null) {
        throw FormatException('History response was not valid JSON');
      }
      final ModelMusicList historyData = ModelMusicList.fromJson(
        parsed as Map<String, dynamic>,
      );

      print('History data loaded successfully in MyLibrary');

      // Save to cache
      await CacheManager.saveToCache(
        'history_data_cache',
        historyData.toJson(),
      );

      if (mounted) {
        setState(() {
          _cachedHistoryData = historyData;
          _isHistoryLoading = false;
          _hasHistoryError = false;
        });
      }
    } catch (e) {
      print('Error loading history data in MyLibrary: $e');
      if (mounted) {
        setState(() {
          _isHistoryLoading = false;
          if (_cachedHistoryData == null) {
            _hasHistoryError = true;
          }
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize scroll controller
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    session['page'] = "1";
    _audioHandler = const MyApp().called();

    // Initialize the centralized music action handler
    _musicActionHandler = MusicActionHandlerFactory.create(
      context: context,
      audioHandler: _audioHandler,
      favoriteService: _favoriteService,
      onStateUpdate: () => setState(() {}),
    );

    // Initialize HomeController (same pattern as HomeDiscover)
    _homeController = HomeController();
    _homeController.addListener(_onHomeControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeController.initialize();
    });

    // Initialize data loading only if not already done
    if (!_hasInitialized) {
      _initializeData();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _homeController.removeListener(_onHomeControllerUpdate);
    _homeController.dispose();
    super.dispose();
  }

  // Add navigation lifecycle awareness
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && _isNavigatingBack) {
      _isNavigatingBack = false;
      _checkAndRefreshIfNeeded();
    }
  }

  Future<void> _checkAndRefreshIfNeeded() async {
    // If HomeController doesn't have content, try refreshing from server.
    if (!_homeController.hasContent &&
        !CacheManager.isFreshDataLoading &&
        token.isNotEmpty) {
      print('Home content missing in MyLibrary, refreshing data in background');
      await _loadFreshMusicData();
    }
  }

  Future<void> _initializeData() async {
    if (_hasInitialized) return;

    try {
      await _tryLoadCachedHistoryData();
      await value();

      final hasCachedData = await CacheManager.hasCachedData(
        CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
      );

      if (!hasCachedData && token.isNotEmpty) {
        await _loadFreshMusicData();
      }

      // Load history data
      if (token.isNotEmpty) {
        await _loadHistoryData();
      }

      // Load favorites for context menu state
      if (token.isNotEmpty) {
        await _loadFavorites();
      }

      _hasInitialized = true;
    } catch (e) {
      print('Error initializing data in MyLibrary: $e');
      if (mounted) {
        setState(() {
          _isMusicLoading = false;
          _isHistoryLoading = false;
        });
      }
    }
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

  void _handleItemTap(String title) {
    setState(() {});

    // Set navigation flag
    _isNavigatingBack = true;

    switch (title) {
      case 'Song Playlist':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaylistScreen(),
            settings: const RouteSettings(name: '/MyLibrary/SongPlaylist'),
          ),
        );
        break;
      case 'My Liked Videos':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LikedVideosScreen(),
            settings: const RouteSettings(name: '/MyLibrary/LikedVideos'),
          ),
        );
        break;
      case 'Subscribed Channels':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SubscribedChannelsScreen(),
            settings: const RouteSettings(
              name: '/MyLibrary/SubscribedChannels',
            ),
          ),
        );
        break;
      case 'Downloaded Songs':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Download(),
            settings: const RouteSettings(name: '/MyLibrary/DownloadedSongs'),
          ),
        );
        break;
      case 'Favorite Songs':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Favorite('fav'),
            settings: const RouteSettings(name: '/MyLibrary/FavoriteSongs'),
          ),
        );
        break;
      case 'Albums':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllCategoryByName(_audioHandler, "Albums"),
            settings: const RouteSettings(name: '/MyLibrary/Albums'),
          ),
        );
        break;
      case 'Genres':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllCategoryByName(_audioHandler, "Genres"),
            settings: const RouteSettings(name: '/MyLibrary/Genres'),
          ),
        );
        break;
      case 'Songs':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllCategoryByName(_audioHandler, "Songs"),
            settings: const RouteSettings(name: '/MyLibrary/Songs'),
          ),
        );
        break;
      case 'History':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HistoryScreen(),
            settings: const RouteSettings(name: '/MyLibrary/History'),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
              // Background container - changed to white
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
              title: "My Library",
              showProfileIcon: true,
              onProfileTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountPage()),
                );
              },
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
        // Centralized bottom padding. The library screen now uses
        // AppPadding.bottom(context, extra: 50.w) for consistent spacing.
        final bottomPadding = AppPadding.bottom(context, extra: 50.w);
        // Detect tablet / iPad sized devices to reduce over-large spacing
        final bool isTabletLocal =
            MediaQuery.of(context).size.shortestSide >= 600;

        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadFreshMusicData(), _loadHistoryData()]);
          },
          color: appColors().primaryColorApp,
          backgroundColor: Colors.white,
          displacement: MediaQuery.of(context).padding.top + 50.w,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Top padding for header
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 50.w,
                ),
                sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Library items section (responsive spacing for tablets)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  12.w,
                  isTabletLocal ? 12.w : 25.w,
                  16.w,
                  0,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: isTabletLocal ? 12.0 : 9.0,
                    mainAxisSpacing: isTabletLocal ? 2.0 : 5.0,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = libraryItems[index];
                    return _buildLibraryCard(item);
                  }, childCount: libraryItems.length),
                ),
              ),

              // Music sections
              SliverPadding(
                padding: EdgeInsets.only(bottom: 0),
                sliver: _buildContentSliver(),
              ),

              // Bottom spacing (scrollable) to match HomeDiscover
              SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentSliver() {
    return _buildMusicSectionsSliver();
  }

  Widget _buildMusicSectionsSliver() {
    // Prefer HomeController home sections (featuredSongs / popularVideos / newVideos)
    if (_homeController.hasContent) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            if (_homeController.isRefreshing)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 10.w),
                child: Center(
                  child: SizedBox(
                    height: 25.w,
                    width: 25.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        appColors().primaryColorApp,
                      ),
                    ),
                  ),
                ),
              ),

            // History first
            _buildHistorySection(),

            // Featured songs section
            _buildFeaturedSongsSection(),

            // Popular videos
            _buildVideoSection(
              title: 'Popular Videos',
              videos: _homeController.popularVideos,
            ),

            // New videos
            _buildVideoSection(
              title: 'New Videos',
              videos: _homeController.newVideos,
            ),
          ],
        ),
      );
    } else if (_isMusicLoading) {
      return SliverToBoxAdapter(
        child: Container(
          height: 250.w,
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              appColors().primaryColorApp,
            ),
          ),
        ),
      );
    } else if (_hasMusicError) {
      return SliverToBoxAdapter(
        child: Container(
          height: 250.w,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'Failed to load music content',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: AppSizes.fontSmall,
                  color: appColors().gray[500],
                ),
              ),
              SizedBox(height: 20.w),
              InkWell(
                onTap: _loadFreshMusicData,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 25.w,
                    vertical: 12.w,
                  ),
                  decoration: BoxDecoration(
                    color: appColors().primaryColorApp,
                    borderRadius: BorderRadius.circular(25.w),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: AppSizes.fontSmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }
  }

  // Legacy category-based UI removed — HomeController provides the
  // Featured/Popular/New sections. Helper methods that constructed
  // UI from ModelCatSubcatMusic have been deleted.

  Widget _buildLibraryCard(LibraryItem item) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleItemTap(item.title),
        child: Container(
          // Reduce padding on larger devices to avoid excessive spacing
          padding: MediaQuery.of(context).size.shortestSide >= 600
              ? const EdgeInsets.symmetric(vertical: 6, horizontal: 8)
              : const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border(
              //normal bottom border
              bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
            ),
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.shortestSide >= 600
                ? 44
                : 48, // slightly smaller on tablet
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: item.color, size: 25.w),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: AppSizes.fontNormal,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF2D2D2D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Icon(Icons.arrow_forward_ios, color: item.color, size: 18.w),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build history section
  Widget _buildHistorySection() {
    if (_isHistoryLoading) {
      return Container(
        height: 210.w,
        alignment: Alignment.center,
        child: SizedBox(
          height: 25.w,
          width: 25.w,
          child: CircularProgressIndicator(
            strokeWidth: 2.w,
            valueColor: AlwaysStoppedAnimation<Color>(
              appColors().primaryColorApp,
            ),
          ),
        ),
      );
    }

    if (_hasHistoryError ||
        _cachedHistoryData == null ||
        _cachedHistoryData!.data.isEmpty) {
      return Container(
        height: 100.w,
        alignment: Alignment.center,
        child: Text(
          'No listening history found',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: AppSizes.fontSmall,
            color: appColors().gray[500],
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: 18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // History section header
          SizedBox(
            child: HomeSectionHeader(
              title: "Song History",
              sharedPreThemeData: sharedPreThemeData,
              onViewAllPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HistoryScreen()),
                );
              },
            ),
          ),
          // History items horizontal list
          SizedBox(
            height: 210.w,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _cachedHistoryData!.data.length > 10
                  ? 10
                  : _cachedHistoryData!.data.length,
              itemBuilder: (context, index) {
                final historyItem = _cachedHistoryData!.data[index];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: SongHistoryCard(
                    imagePath: historyItem.image.startsWith('http')
                        ? historyItem.image
                        : AppConstant.ImageUrl + historyItem.image,
                    songName: historyItem.audio_title,
                    artistName: historyItem.artists_name,
                    sharedPreThemeData: sharedPreThemeData,
                    onTap: () => _handleInstantHistorySongTap(index),
                    songId: historyItem.id.toString(),
                    onPlay: () => _handleInstantHistorySongTap(index),
                    onPlayNext: () => _musicActionHandler.handlePlayNext(
                      historyItem.id.toString(),
                      historyItem.audio_title,
                      historyItem.artists_name,
                      track: historyItem,
                    ),
                    onAddToQueue: () => _musicActionHandler.handleAddToQueue(
                      historyItem.id.toString(),
                      historyItem.audio_title,
                      historyItem.artists_name,
                      track: historyItem,
                    ),
                    onDownload: () => _musicActionHandler.handleDownload(
                      historyItem.audio_title,
                      "song",
                      historyItem.id.toString(),
                    ),
                    onAddToPlaylist: () =>
                        _musicActionHandler.handleAddToPlaylist(
                          historyItem.id.toString(),
                          historyItem.audio_title,
                          historyItem.artists_name,
                        ),
                    onShare: () => _musicActionHandler.handleShare(
                      historyItem.audio_title,
                      "song",
                      itemId: historyItem.id.toString(),
                      slug: historyItem.audio_slug,
                    ),
                    onFavorite: () => _musicActionHandler.handleFavoriteToggle(
                      historyItem.id.toString(),
                      historyItem.audio_title,
                      favoriteIds: _favoriteIds,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build featured songs section using HomeController data
  Widget _buildFeaturedSongsSection() {
    final songs = _homeController.featuredSongs;
    if (songs.isEmpty) return SizedBox.shrink();

    final theme = sharedPreThemeData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Featured Songs',
          sharedPreThemeData: theme,
          onViewAllPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AllCategoryByName(_audioHandler, 'Featured Songs'),
              ),
            );
          },
        ),
        SizedBox(
          height: 210.w,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemBuilder: (context, index) {
              final song = songs[index];
              final imageUrl = song.imageUrl.isNotEmpty
                  ? song.imageUrl
                  : (song.bannerImage ?? '');
              final artistName = song.channelName;

              return HorizontalSongCard(
                songId: song.id.toString(),
                imagePath: imageUrl,
                songName: song.audioTitle,
                artistName: artistName,
                sharedPreThemeData: theme,
                onTap: () => _musicActionHandler.handlePlaySong(
                  song.id.toString(),
                  song.audioTitle,
                ),
                onPlay: () => _musicActionHandler.handlePlaySong(
                  song.id.toString(),
                  song.audioTitle,
                ),
                onPlayNext: () => _musicActionHandler.handlePlayNext(
                  song.id.toString(),
                  song.audioTitle,
                  artistName,
                  imagePath: imageUrl,
                  track: song,
                ),
                onAddToQueue: () => _musicActionHandler.handleAddToQueue(
                  song.id.toString(),
                  song.audioTitle,
                  artistName,
                  imagePath: imageUrl,
                  track: song,
                ),
                onDownload: () => _musicActionHandler.handleDownload(
                  song.audioTitle,
                  'song',
                  song.id.toString(),
                  imagePath: imageUrl,
                ),
                onAddToPlaylist: () => _musicActionHandler.handleAddToPlaylist(
                  song.id.toString(),
                  song.audioTitle,
                  artistName,
                  imagePath: imageUrl,
                ),
                onShare: () => _musicActionHandler.handleShare(
                  song.audioTitle,
                  'song',
                  itemId: song.id.toString(),
                  slug: song.audioSlug,
                ),
                onFavorite: () => _musicActionHandler.handleFavoriteToggle(
                  song.id.toString(),
                  song.audioTitle,
                  favoriteIds: _favoriteIds,
                ),
              );
            },
            separatorBuilder: (context, _) => SizedBox(width: 12.w),
            itemCount: songs.length,
          ),
        ),
      ],
    );
  }

  // Build video section from a list of VideoModel items
  Widget _buildVideoSection({
    required String title,
    required List<VideoModel> videos,
  }) {
    if (videos.isEmpty) return SizedBox.shrink();

    final theme = sharedPreThemeData;
    final contextItems = videos
        .map((video) => VideoItem.fromVideoModel(video))
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(top: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            title: title,
            sharedPreThemeData: theme,
            onViewAllPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SizedBox()),
            ),
          ),
          SizedBox(
            height: 250.w,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemBuilder: (context, index) {
                final video = videos[index];
                final videoItem = contextItems[index];
                return VideoCardSmall(
                  title: video.title,
                  thumbnailUrl: video.thumbnailUrl,
                  duration: video.duration,
                  channelName: video.channelName,
                  channelImageUrl: video.channelImageUrl,
                  totalViews: video.totalViews,
                  publishedAt: video.createdAt,
                  onTap: () => launchVideoPlayer(
                    context,
                    videoUrl: video.videoUrl,
                    videoId: video.id.toString(),
                    videoTitle: video.title,
                    videoSubtitle: video.channelName,
                    thumbnailUrl: video.thumbnailUrl,
                    videoItem: videoItem,
                    contextVideos: contextItems,
                    contextLabel: title,
                  ),
                );
              },
              separatorBuilder: (context, _) => SizedBox(width: 12.w),
              itemCount: videos.length,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to handle history item taps
  Future<void> _handleInstantHistorySongTap(int tappedIndex) async {
    final songs = _cachedHistoryData?.data ?? [];
    if (tappedIndex < 0 || tappedIndex >= songs.length) return;

    final tappedSong = songs[tappedIndex];
    final fallbackSongId = tappedSong.id.toString();
    final instantIdentifier = fallbackSongId.isNotEmpty
        ? fallbackSongId
        : tappedSong.audioUrl.trim();

    if (instantIdentifier.isEmpty) {
      _showSnackbar('Song unavailable.');
      return;
    }

    if (!_hasPlayableAudio(tappedSong)) {
      await _fallbackToSmartPlay(fallbackSongId, tappedSong.audioTitle);
      return;
    }

    final payloads = _buildInstantPayloads(songs);
    if (payloads.isEmpty) {
      await _fallbackToSmartPlay(fallbackSongId, tappedSong.audioTitle);
      return;
    }

    final normalizedIndex = payloads.indexWhere(
      (payload) => payload.id == instantIdentifier,
    );

    if (normalizedIndex == -1) {
      await _fallbackToSmartPlay(fallbackSongId, tappedSong.audioTitle);
      return;
    }

    final forwardQueue = payloads.sublist(normalizedIndex);
    await _musicActionHandler.handleInstantPlay(
      payload: forwardQueue.first,
      context: forwardQueue,
      contextIndex: 0,
    );
  }

  List<SongPlaybackPayload> _buildInstantPayloads(List<SongModel> songs) {
    return songs
        .where(_hasPlayableAudio)
        .map(SongPlaybackPayload.fromSongModel)
        .toList();
  }

  bool _hasPlayableAudio(SongModel song) {
    return song.audioUrl.trim().isNotEmpty;
  }

  Future<void> _fallbackToSmartPlay(String? songId, String songTitle) async {
    if (songId == null || songId.isEmpty) {
      _showSnackbar('Song unavailable.');
      return;
    }
    await _musicActionHandler.handlePlaySong(songId, songTitle);
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Load user's favorite songs from the API to track state
  Future<void> _loadFavorites() async {
    if (_favoritesLoaded) return;

    try {
      final token = await sharePrefs.getToken();
      if (token.isEmpty) return;

      print('💖 Loading favorites for MyLibrary state management...');

      // Use the existing FavMusicPresenter to get favorites list
      final favPresenter = FavMusicPresenter();
      final favList = await favPresenter.getFavMusicList(token);

      // Extract favorite IDs from the response
      _favoriteIds.clear();
      for (final song in favList.data) {
        _favoriteIds.add(song.id.toString());
      }

      _favoritesLoaded = true;
      print('💖 Loaded ${_favoriteIds.length} favorites for MyLibrary');

      if (mounted) {
        setState(() {}); // Update UI with favorite states
      }
    } catch (e) {
      print('💖 Error loading favorites: $e');
      // Continue without favorites - not critical
    }
  }
}
