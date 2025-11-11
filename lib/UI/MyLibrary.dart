import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelCatSubcatMusic.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/CatSubCatMusicPresenter.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/Presenter/HistoryPresenter.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:session_storage/session_storage.dart';

import '../main.dart';
import '../widgets/common/app_header.dart';
import '../widgets/music/history_card.dart';
import '../widgets/music/music_section_header.dart';
import '../widgets/music/popular_song_card.dart';
import '../widgets/music/song_card.dart';
import 'AccountPage.dart';
import 'AllCategoryByName.dart';
import 'Download.dart';
import 'FavoriteOrHistory.dart';
import 'MusicEntryPoint.dart'; // Contains Music class
import 'playlist_screen.dart';
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
  ModelCatSubcatMusic? _cachedMusicData;
  bool _isMusicLoading = true;
  bool _isBackgroundRefreshing = false;
  bool _hasMusicError = false;
  String _errorMessage = '';

  // History data variables
  ModelMusicList? _cachedHistoryData;
  bool _isHistoryLoading = true;
  bool _hasHistoryError = false;
  String _historyImagePath = '';
  String _historyAudioPath = '';

  // Add presenter instance
  final CatSubcatMusicPresenter _presenter = CatSubcatMusicPresenter();
  final HistoryPresenter _historyPresenter = HistoryPresenter();

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
      title: 'Playlist',
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
      title: 'Downloaded',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.favorite_outline_outlined,
      title: 'Favorites',
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
      icon: Icons.people_outlined,
      title: 'Artist',
      color: appColors().primaryColorApp,
    ),
    LibraryItem(
      icon: Icons.music_note_outlined,
      title: 'Songs',
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
  Future<void> _tryLoadCachedMusicData() async {
    try {
      final cachedData = await CacheManager.getFromCache(
        CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
      );

      if (cachedData != null) {
        // Parse the JSON data safely
        final dataString = cachedData['data'] as String;
        final parsedData = _safeJsonDecode(dataString);
        if (parsedData == null) {
          // Corrupted or non-JSON cache, clear and bail out
          await CacheManager.clearCache(
            CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
          );
          return;
        }
        final modelData = ModelCatSubcatMusic.fromJson(parsedData);

        if (mounted) {
          setState(() {
            _cachedMusicData = modelData;
            _isMusicLoading = false;
            _hasMusicError = false;
            print('Loaded music data from cache in MyLibrary');
          });
        }
      }
    } catch (e) {
      print('Error loading cached music data in MyLibrary: $e');
      // Clear corrupted cache
      await CacheManager.clearCache(CacheManager.MUSIC_CATEGORIES_CACHE_KEY);
    }
  }

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

    final bool loadInBackground = _cachedMusicData != null;

    if (!loadInBackground) {
      if (mounted) {
        setState(() {
          _isMusicLoading = true;
          _hasMusicError = false;
          _errorMessage = '';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isBackgroundRefreshing = true;
        });
      }
    }

    try {
      print('Loading fresh music data in MyLibrary with token: $token');

      final freshData = await _presenter
          .getCatSubCatMusicList(token, context)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timed out after 10 seconds');
            },
          );

      print('Fresh music data loaded successfully in MyLibrary');

      // Save to cache
      await CacheManager.saveToCache(
        CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
        freshData.toJson(),
      );

      if (mounted) {
        setState(() {
          _cachedMusicData = freshData;
          _isMusicLoading = false;
          _isBackgroundRefreshing = false;
          _hasMusicError = false;
        });
      }
    } catch (e) {
      print('Error loading fresh music data in MyLibrary: $e');
      if (mounted) {
        setState(() {
          _isMusicLoading = false;
          _isBackgroundRefreshing = false;

          if (_cachedMusicData == null) {
            _hasMusicError = true;
            _errorMessage = 'Failed to load music content. Please try again.';
          }
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
            _historyImagePath = modelData.imagePath;
            _historyAudioPath = modelData.audioPath;
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

      final String response = await _historyPresenter.getHistory(token);
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
          _historyImagePath = historyData.imagePath;
          _historyAudioPath = historyData.audioPath;
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

  Future<void> getSettings() async {
    String? sett = await sharePrefs.getSettings();
    final Map<String, dynamic> parsed = json.decode(sett!);
    ModelSettings modelSettings = ModelSettings.fromJson(parsed);
    if (modelSettings.data.download == 1) {
      allowDown = true;
    } else {
      allowDown = false;
    }
    setState(() {});
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

    getSettings();

    // Initialize data loading only if not already done
    if (!_hasInitialized) {
      _initializeData();
    }
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
    final hasCachedData = await CacheManager.hasCachedData(
      CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
    );

    if (!hasCachedData &&
        !CacheManager.isFreshDataLoading &&
        token.isNotEmpty) {
      print('Cache expired in MyLibrary, refreshing data in background');
      await _loadFreshMusicData();
    }
  }

  Future<void> _initializeData() async {
    if (_hasInitialized) return;

    try {
      await _tryLoadCachedMusicData();
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
      case 'Playlist':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaylistScreen(),
            settings: const RouteSettings(name: '/MyLibrary/playlist_screen'),
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
      case 'Downloaded':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Download(),
            settings: const RouteSettings(name: '/MyLibrary/Download'),
          ),
        );
        break;
      case 'Favorites':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Favorite('fav'),
            settings: const RouteSettings(name: '/MyLibrary/Favorite'),
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
      case 'Artist':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllCategoryByName(_audioHandler, "Artists"),
            settings: const RouteSettings(name: '/MyLibrary/Artists'),
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
    }
  }

  // Helper method to handle music item taps with navigation tracking
  void _handleMusicItemTap(
    DataCat category,
    int idx,
    BuildContext context,
    String categoryName,
  ) async {
    final subCategory = category.sub_category[idx];
    final id = subCategory.id.toString();
    final name = subCategory.name;

    // Set navigation flag
    _isNavigatingBack = true;

    print('🎵🎵🎵 MYLIBRARY TAP: $categoryName, ID: $id, Name: $name 🎵🎵🎵');

    try {
      print('[DEBUG] Loading songs for category: $categoryName, ID: $id');

      // Get the songs for this category
      final response = await _presenter.getMusicListByCategory(
        id,
        'Songs',
        token,
      );

      if (response.data.isNotEmpty) {
        print('[DEBUG] Successfully loaded ${response.data.length} songs');

        // Use music manager for queue replacement instead of navigation
        final musicManager = MusicManager();

        await musicManager.replaceQueue(
          musicList: response.data,
          startIndex: 0, // Start from the first song
          pathImage: response.imagePath,
          audioPath: response.audioPath,
          callSource: 'MyLibrary.handleMusicItemTap',
          contextType: categoryName,
          contextId: id,
        );

        // Show mini player instead of navigating to full player
        final stateManager = MusicPlayerStateManager();
        stateManager.showMiniPlayerForMusicStart();

        print('[DEBUG] Music playback started via mini player');
      } else {
        print('[ERROR] No songs found for this category');
      }
    } catch (e) {
      // Log and fallback to navigation if music manager fails
      print('[ERROR] Failed to load and play songs: $e');

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              Music(_audioHandler, id, 'Songs', [], "", 0, false, ''),
        ),
      );
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
        // Centralized bottom padding. The library screen previously added
        // an extra 70.w; preserve that additional spacing by passing extra.
        final bottomPadding = AppPadding.bottom(context, extra: 70.w);
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
                padding: EdgeInsets.fromLTRB(
                  10.w,
                  0.w,
                  0,
                  bottomPadding + 70.w, // Additional padding for library screen
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
    return _buildMusicSectionsSliver();
  }

  Widget _buildMusicSectionsSliver() {
    if (_cachedMusicData != null) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            // Show refreshing indicator if background refresh is happening
            if (_isBackgroundRefreshing)
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

            // Build music categories
            _buildMusicCategories(_cachedMusicData!),
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

  Widget _buildMusicCategories(ModelCatSubcatMusic data) {
    // Filter to show only Popular Songs and Featured Songs
    List<DataCat> targetCategories = data.data
        .where(
          (cat) =>
              (cat.cat_name.contains("Popular Songs") ||
                  cat.cat_name.contains("Featured Songs")) &&
              cat.sub_category.isNotEmpty,
        )
        .toList();

    // Sort to ensure Popular Songs comes before Featured Songs
    targetCategories.sort((a, b) {
      if (a.cat_name.contains("Popular Songs") &&
          b.cat_name.contains("Featured Songs")) {
        return -1; // Popular Songs comes first
      } else if (a.cat_name.contains("Featured Songs") &&
          b.cat_name.contains("Popular Songs")) {
        return 1; // Featured Songs comes second
      }
      return 0; // Keep original order for other cases
    });

    if (targetCategories.isEmpty) {
      return Column(children: [_buildHistorySection()]);
    }

    return Column(
      children: [
        // Add history section at the top
        _buildHistorySection(),

        // Add existing music categories
        ListView.builder(
          scrollDirection: Axis.vertical,
          itemCount: targetCategories.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return Container(
              alignment: Alignment.centerLeft,
              child: Column(
                children: [
                  _buildCategoryHeader(targetCategories[index], context),
                  _buildContentRow(targetCategories[index], context),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Helper method to build category headers
  Widget _buildCategoryHeader(DataCat category, BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        10.w,
        5.w,
        10.w,
        0,
      ), // Reduced top and bottom margins
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.w),
        child: MusicSectionHeader(
          title: category.cat_name,
          sharedPreThemeData: sharedPreThemeData,
          onViewAllPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AllCategoryByName(_audioHandler, category.cat_name),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method to build content rows
  Widget _buildContentRow(DataCat category, BuildContext context) {
    final categoryName = category.cat_name;
    final itemHeight = _getItemHeight(categoryName);

    // Special handling for Popular Songs to show in 2 rows
    if (categoryName == "Popular Songs") {
      final adjustedHeight = category.sub_category.length == 1 ? 170.w : 340.w;

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

  // Helper method to get item height based on category type
  double _getItemHeight(String categoryName) {
    switch (categoryName) {
      case "Featured Songs":
        return 220.w; // Further increased height to accommodate artist names
      case "New Songs":
        return 220.w; // Further increased height to accommodate artist names
      case "Popular Songs":
        return 200.w; // Further increased height for better spacing
      default:
        return 270
            .w; // Further increased default height to accommodate artist names
    }
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
                height: 170.w,
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
    final artistName = subCategory.artist != null
        ? subCategory.artist!.map((a) => a.name).join(', ')
        : '';

    onTap() => _handleMusicItemTap(category, idx, context, "Popular Songs");

    return PopularSongCard(
      songId: subCategory.id
          .toString(), // Pass songId for global favorites management
      imagePath: imagePath,
      songName: name,
      artistName: artistName,
      onTap: onTap,
      sharedPreThemeData: sharedPreThemeData,
      height: 160.w, // Reduced height for more compact cards
      isCompact: isSingle,
      // Remove static isFavorite - let PopularSongCard use global provider
      onPlay: () =>
          _musicActionHandler.handlePlaySong(subCategory.id.toString(), name),
      onPlayNext: () => _musicActionHandler.handlePlayNext(
        subCategory.id.toString(),
        name,
        artistName,
      ),
      onAddToQueue: () => _musicActionHandler.handleAddToQueue(
        subCategory.id.toString(),
        name,
        artistName,
      ),
      onDownload: () => _musicActionHandler.handleDownload(
        name,
        "song",
        subCategory.id.toString(),
      ),
      onAddToPlaylist: () => _musicActionHandler.handleAddToPlaylist(
        subCategory.id.toString(),
        name,
        artistName,
      ),
      onShare: () => _musicActionHandler.handleShare(
        name,
        "song",
        itemId: subCategory.id.toString(),
        slug: subCategory.slug,
      ),
      onFavorite: () => _musicActionHandler.handleFavoriteToggle(
        subCategory.id.toString(),
        name,
        favoriteIds: _favoriteIds,
      ),
    );
  }

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
    final artistName = subCategory.artist != null
        ? subCategory.artist!.map((a) => a.name).join(', ')
        : '';

    onTap() => _handleMusicItemTap(category, idx, context, categoryName);

    // Return SongCard for most categories
    return SongCard(
      songId: subCategory.id
          .toString(), // Pass songId for global favorites management
      imagePath: imagePath,
      songName: name,
      artistName: artistName,
      onTap: onTap,
      sharedPreThemeData: sharedPreThemeData,
      // Remove static isFavorite - let SongCard use global provider
      onPlay: () =>
          _musicActionHandler.handlePlaySong(subCategory.id.toString(), name),
      onPlayNext: () => _musicActionHandler.handlePlayNext(
        subCategory.id.toString(),
        name,
        artistName,
      ),
      onAddToQueue: () => _musicActionHandler.handleAddToQueue(
        subCategory.id.toString(),
        name,
        artistName,
      ),
      onDownload: () => _musicActionHandler.handleDownload(
        name,
        "song",
        subCategory.id.toString(),
      ),
      onAddToPlaylist: () => _musicActionHandler.handleAddToPlaylist(
        subCategory.id.toString(),
        name,
        artistName,
      ),
      onShare: () => _musicActionHandler.handleShare(
        name,
        "song",
        itemId: subCategory.id.toString(),
        slug: subCategory.slug,
      ),
      onFavorite: () => _musicActionHandler.handleFavoriteToggle(
        subCategory.id.toString(),
        name,
        favoriteIds: _favoriteIds,
      ),
    );
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // History section header
        Container(
          margin: EdgeInsets.fromLTRB(7.w, 20.w, 7.w, 10.w),
          child: MusicSectionHeader(
            title: "History",
            sharedPreThemeData: sharedPreThemeData,
            onViewAllPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Favorite('his')),
              );
            },
          ),
        ),
        // History items horizontal list
        Container(
          height: 210.w,
          margin: EdgeInsets.only(left: 7.w),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _cachedHistoryData!.data.length > 10
                ? 10
                : _cachedHistoryData!.data.length,
            itemBuilder: (context, index) {
              final historyItem = _cachedHistoryData!.data[index];
              return HistoryCard(
                imagePath:
                    AppConstant.ImageUrl +
                    _historyImagePath +
                    historyItem.image,
                songName: historyItem.audio_title,
                artistName: historyItem.artists_name,
                sharedPreThemeData: sharedPreThemeData,
                onTap: () => _handleHistoryItemTap(historyItem, index),
                songId: historyItem.id
                    .toString(), // Pass songId instead of isFavorite
                onPlay: () => _musicActionHandler.handlePlaySong(
                  historyItem.id.toString(),
                  historyItem.audio_title,
                ),
                onPlayNext: () => _musicActionHandler.handlePlayNext(
                  historyItem.id.toString(),
                  historyItem.audio_title,
                  historyItem.artists_name,
                ),
                onAddToQueue: () => _musicActionHandler.handleAddToQueue(
                  historyItem.id.toString(),
                  historyItem.audio_title,
                  historyItem.artists_name,
                ),
                onDownload: () => _musicActionHandler.handleDownload(
                  historyItem.audio_title,
                  "song",
                  historyItem.id.toString(),
                ),
                onAddToPlaylist: () => _musicActionHandler.handleAddToPlaylist(
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
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper method to handle history item taps
  void _handleHistoryItemTap(DataMusic historyItem, int index) async {
    _isNavigatingBack = true;

    // Use music manager for queue replacement instead of navigation
    final musicManager = MusicManager();

    try {
      await musicManager.replaceQueue(
        musicList: _cachedHistoryData!.data,
        startIndex: index,
        pathImage: "images/audio/thumb/",
        audioPath: _historyAudioPath,
        callSource: 'MyLibrary.handleHistoryItemTap',
      );

      // Show mini player instead of navigating to full player
      final stateManager = MusicPlayerStateManager();
      stateManager.showMiniPlayerForMusicStart();

      print('[DEBUG] History music playback started via mini player');
    } catch (e) {
      print('[DEBUG] History music playback failed: $e');
      // Fallback to navigation if music manager fails
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Music(
            _audioHandler,
            historyItem.id.toString(),
            'Songs',
            _cachedHistoryData!.data,
            _historyAudioPath,
            index,
            false,
            '',
          ),
        ),
      );
    }
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
