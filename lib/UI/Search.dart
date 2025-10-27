import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/CatSubCatMusicPresenter.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/Presenter/HistoryPresenter.dart'; // Add this import
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
// import 'package:jainverse/utils/AdHelper.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:session_storage/session_storage.dart';
import 'package:we_slide/we_slide.dart';
import 'package:dio/dio.dart';

import '../main.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/loader.dart';
import '../widgets/common/search_bar.dart';
import '../widgets/music/recent_search_card.dart';
import '../videoplayer/models/video_item.dart';
import '../videoplayer/widgets/video_card.dart';
import '../videoplayer/screens/common_video_player_screen.dart';
import 'AccountPage.dart';
import 'CreatePlaylist.dart';

AudioPlayerHandler? _audioHandler;
// String yt = ""; // COMMENTED OUT - YouTube parameter

class Search extends StatefulWidget {
  Search(String s, {super.key}) {
    // yt = s; // COMMENTED OUT - YouTube parameter assignment
  }

  @override
  StateClass createState() {
    return StateClass();
  }
}

class StateClass extends State<Search> with SingleTickerProviderStateMixin {
  final double size = 80.0;
  final Color color = Colors.pink;
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  bool _hasVoice = false, tillLoading = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String lastError = '';
  String lastStatus = '', searchTag = '', token = '';
  final String _currentLocaleId = '';
  int resultListened = 0;
  // List<YouTubeVideo> videoResult = []; // COMMENTED OUT - YouTube video results
  var txtSearch = TextEditingController();

  // String yt_key = '', yt_code = ''; // COMMENTED OUT - YouTube API keys
  List<DataMusic> list = [];
  String pathImage = '', audioPath = '';
  late BannerAd _bannerAd;
  final bool _isBannerAdReady = false;
  bool allowDown = false, allowAds = true;

  final WeSlideController _controller = WeSlideController();
  final double _panelMinSize = 0.0;
  late ModelSettings modelSettings;

  final session = SessionStorage();

  // int is_yt = 0; // COMMENTED OUT - YouTube settings flag

  // Add scroll controller and header animation
  late ScrollController _scrollController;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  // Search state management
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _searchTimer; // Add debounce timer

  // Recent searches management
  List<Map<String, dynamic>> recentSearches = [];
  bool _showingRecentSearches = false;

  // Tab management for Music/Video/All
  String _selectedTab = 'All'; // 'All', 'Music', 'Video'
  List<VideoItem> videoList = [];
  bool _isSearchingVideos = false;
  bool _hasVideoError = false;
  String _videoErrorMessage = '';
  final Dio _dio = Dio();

  // Add debounced search function
  void _onSearchChanged(String value) {
    // Cancel previous timer
    _searchTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        list = [];
        _hasSearched = false;
        _isSearching = false;
        _hasError = false;
        _showingRecentSearches = true;
      });
      _loadRecentSearches(); // Load recent searches when clearing
      return;
    }

    setState(() {
      _showingRecentSearches = false;
    });

    if (value.length >= 2) {
      // Add debounce delay
      _searchTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          // Check if widget is still mounted
          searchAPI();
        }
      });
    }
  }

  Future<void> searchAPI() async {
    if (!mounted) return; // Safety check

    if (txtSearch.text.trim().isEmpty) {
      setState(() {
        list = [];
        videoList = [];
        _hasSearched = false;
        _isSearching = false;
        _isSearchingVideos = false;
        _hasError = false;
        _hasVideoError = false;
        _showingRecentSearches = true;
      });
      return;
    }

    setState(() {
      _isSearching = _selectedTab == 'All' || _selectedTab == 'Music';
      _isSearchingVideos = _selectedTab == 'All' || _selectedTab == 'Video';
      _hasError = false;
      _hasVideoError = false;
      _errorMessage = '';
      _videoErrorMessage = '';
    });

    searchTag = txtSearch.text.trim();
    print('[DEBUG] Searching for: $searchTag (Tab: $_selectedTab)');

    // Search music if needed
    if (_selectedTab == 'All' || _selectedTab == 'Music') {
      _searchMusic();
    } else {
      setState(() {
        list = [];
      });
    }

    // Search videos if needed
    if (_selectedTab == 'All' || _selectedTab == 'Video') {
      _searchVideos();
    } else {
      setState(() {
        videoList = [];
      });
    }
  }

  Future<void> _searchMusic() async {
    try {
      ModelMusicList mList = await CatSubcatMusicPresenter()
          .getMusicListBySearchName(searchTag, token, context);

      if (!mounted) return;

      pathImage = mList.imagePath;
      audioPath = mList.audioPath;
      list = mList.data;

      print('[DEBUG] Music search results: ${list.length} items found');

      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _hasError = false;
        _showingRecentSearches = false;
      });
    } catch (e) {
      print('[ERROR] Music search failed: $e');
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _hasError = true;
        _errorMessage = 'Music search failed. Please try again.';
        list = [];
      });
    }
  }

  Future<void> _searchVideos() async {
    try {
      final params = {'query': searchTag, 'page': 1, 'per_page': 20};

      final response = await _dio.request(
        AppConstant.BaseUrl + AppConstant.API_SEARCH_VIDEOS,
        data: params,
        options: Options(
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final dataObj = data['data'];
          if (dataObj is Map<String, dynamic>) {
            final List<dynamic> raw = dataObj['videos'] ?? [];
            videoList = raw.map((e) {
              if (e is Map<String, dynamic>) return VideoItem.fromJson(e);
              return VideoItem.fromJson(Map<String, dynamic>.from(e));
            }).toList();

            print(
              '[DEBUG] Video search results: ${videoList.length} items found',
            );

            setState(() {
              _isSearchingVideos = false;
              _hasSearched = true;
              _hasVideoError = false;
              _showingRecentSearches = false;
            });
          }
        }
      }
    } catch (e) {
      print('[ERROR] Video search failed: $e');
      if (!mounted) return;

      setState(() {
        _isSearchingVideos = false;
        _hasSearched = true;
        _hasVideoError = true;
        _videoErrorMessage = 'Video search failed. Please try again.';
        videoList = [];
      });
    }
  }

  Future<void> _loadRecentSearches() async {
    try {
      final searches = await CacheManager.getRecentSearches();
      if (mounted) {
        setState(() {
          recentSearches = searches;
          _showingRecentSearches = txtSearch.text.isEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(DataMusic song) async {
    try {
      final songData = {
        'id': song.id.toString(),
        'audio_title': song.audio_title,
        'artists_name': song.artists_name,
        'image': song.image,
        'audio_duration': song.audio_duration,
        'favourite': song.favourite,
        'audio': song.audio, // Include the complete audio URL
        'audio_slug': song.audio_slug,
        'audio_genre_id': song.audio_genre_id.toString(),
        'artist_id': song.artist_id,
        'audio_language': song.audio_language,
        'listening_count': song.listening_count.toString(),
        'is_featured': song.is_featured.toString(),
        'is_trending': song.is_trending.toString(),
        'is_recommended': song.is_recommended.toString(),
        'created_at': song.created_at,
        'download_price': song.download_price,
        'lyrics': song.lyrics,
      };

      // Pass image and audio paths to cache manager
      await CacheManager.saveRecentSearch(
        songData,
        imagePath: pathImage,
        audioPath: audioPath,
      );
      await _loadRecentSearches();
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> addRemoveAPI(String id, String tag) async {
    await FavMusicPresenter().getMusicAddRemove(id, token, tag);
    setState(() {});
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    setState(() {
      this.level = level;
    });
  }

  void statusListener(String status) {
    if (status.contains('notListening')) {
      _hasVoice = false;
      txtSearch.text = Resources.of(context).strings.searchHint;
      _hasVoice = false;
    }
    setState(() {
      lastStatus = status;
    });
  }

  Future<dynamic> value() async {
    try {
      token = await sharePrefs.getToken();

      // if (!yt.contains("YT")) { // COMMENTED OUT - YouTube check
      // Don't auto-search on init
      // } // COMMENTED OUT - YouTube check end

      model = await sharePrefs.getUserData();
      sharedPreThemeData = await sharePrefs.getThemeData();
      String? sett = await sharePrefs.getSettings();
      if (sett != null && sett.isNotEmpty) {
        final Map<String, dynamic> parsed = json.decode(sett);
        modelSettings = ModelSettings.fromJson(parsed);
        // is_yt = modelSettings.data.is_youtube; // COMMENTED OUT - YouTube settings
      }
      setState(() {});
    } on Exception catch (e) {
      print('Error in value(): $e');
    }
    return model;
  }

  Future<void> getSettings() async {
    String? sett = await sharePrefs.getSettings();
    if (sett == null || sett.isEmpty) return;

    final Map<String, dynamic> parsed = json.decode(sett);
    ModelSettings modelSettings = ModelSettings.fromJson(parsed);
    // yt_code = modelSettings.data.yt_country_code; // COMMENTED OUT - YouTube country code
    // yt_key = modelSettings.data.google_api_key; // COMMENTED OUT - YouTube API key

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

  void _reload() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    // Initialize scroll controller
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    session['page'] = "2";
    _audioHandler = const MyApp().called();

    // Initialize data and load recent searches
    value().then((_) {
      _loadRecentSearches();
    });
    getSettings();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    txtSearch.dispose(); // Add this to prevent memory leaks
    _dio.close(); // Close Dio instance
    if (_isBannerAdReady) {
      _bannerAd.dispose();
    }
    super.dispose();
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

  void showDialog(BuildContext context, String ids, String tag, String favTag) {
    showGeneralDialog(
      barrierLabel: "Barrier",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 700),
      context: context,
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 265,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: appColors().primaryColorApp),
                gradient: LinearGradient(
                  colors: [
                    appColors().colorBackground,
                    appColors().colorBackground,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(1),
                    child: InkResponse(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            alignment: Alignment.centerLeft,
                            width: 68,
                            child: favTag.contains("1")
                                ? Image.asset(
                                    'assets/icons/favfill.png',
                                    color: appColors().colorText,
                                  )
                                : Image.asset('assets/icons/fav2.png'),
                          ),
                          Container(
                            width: 145,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              favTag.contains("1")
                                  ? 'Remove Favorite'
                                  : 'Favorite',
                              style: TextStyle(
                                fontSize: 19,
                                color: appColors().colorText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        addRemoveAPI(ids, tag);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(1),
                    child: InkResponse(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(16),
                            child: Image.asset('assets/icons/addto.png'),
                          ),
                          Container(
                            width: 145,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Add to playlist',
                              style: TextStyle(
                                fontSize: 19,
                                color: appColors().colorText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreatePlaylist(ids),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header with search bar - fixed at top (no animation)
        Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AppHeader(
                    title: "Search",
                    showProfileIcon: true,
                    onProfileTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AccountPage(),
                        ),
                      );
                    },
                    backgroundColor: Colors.transparent,
                    scrollController: _scrollController,
                    scrollAware: false,
                  ),
                  SizedBox(height: 4.w),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingXS + 2.w,
                    ),
                    child: AnimatedSearchBar(
                      controller: txtSearch,
                      hintText: Resources.of(context).strings.searchHint,
                      onChanged: _onSearchChanged,
                      onClear: () {
                        txtSearch.clear();
                        _searchTimer?.cancel();
                        setState(() {
                          list = [];
                          videoList = [];
                          _hasSearched = false;
                          _isSearching = false;
                          _isSearchingVideos = false;
                          _hasError = false;
                          _hasVideoError = false;
                          _showingRecentSearches = true;
                        });
                        _loadRecentSearches();
                      },
                      focusedBorderColor: appColors().primaryColorApp,
                    ),
                  ),
                  SizedBox(height: AppSizes.paddingS),
                  // Tab selector for Music/Video/All
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
                    child: Row(
                      children: [
                        _buildTabButton('All'),
                        SizedBox(width: AppSizes.paddingXS),
                        _buildTabButton('Music'),
                        SizedBox(width: AppSizes.paddingXS),
                        _buildTabButton('Video'),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSizes.paddingS),
                ],
              ),
            ),
          ),
        ),

        // Scrollable content area
        Expanded(child: _buildMainScrollableContent()),
      ],
    );
  }

  Widget _buildTabButton(String tab) {
    final isSelected = _selectedTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tab;
          });
          // Re-search with new tab filter if we have a query
          if (txtSearch.text.trim().isNotEmpty) {
            searchAPI();
          }
        },
        borderRadius: BorderRadius.circular(AppSizes.paddingL),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.w),
          decoration: BoxDecoration(
            color: isSelected
                ? appColors().primaryColorApp
                : appColors().gray[100],
            borderRadius: BorderRadius.circular(AppSizes.paddingL),
          ),
          child: Center(
            child: Text(
              tab,
              style: TextStyle(
                fontSize: AppSizes.fontNormal,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : appColors().gray[600],
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScrollableContent() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_showingRecentSearches) {
          await _loadRecentSearches();
        } else {
          await searchAPI();
        }
      },
      color: appColors().primaryColorApp,
      backgroundColor: Colors.white,
      displacement: 50.w,
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside input fields
          FocusScope.of(context).unfocus();
        },
        child: Container(
          color: Colors.white,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.paddingM,
                  AppSizes.paddingS,
                  AppSizes.paddingM,
                  AppSizes.basePadding +
                      AppSizes.miniPlayerPadding +
                      210.w, // Additional padding for this specific screen
                ),
                sliver: _buildContentSliver(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentSliver() {
    if (_showingRecentSearches) {
      return _buildRecentSearchesSliver();
    }

    // Show loading state
    if (_isSearching || _isSearchingVideos) {
      return SliverToBoxAdapter(child: _buildLoadingWidget());
    }

    if (!_hasSearched) {
      return SliverToBoxAdapter(child: _buildInitialStateWidget());
    }

    // Show results based on selected tab
    if (_selectedTab == 'Music') {
      return _buildMusicResultsSliver();
    } else if (_selectedTab == 'Video') {
      return _buildVideoResultsSliver();
    } else {
      // 'All' tab - show both music and videos
      return _buildCombinedResultsSliver();
    }
  }

  Widget _buildMusicResultsSliver() {
    if (_hasError) {
      return SliverToBoxAdapter(child: _buildErrorWidget());
    }

    if (list.isEmpty) {
      return SliverToBoxAdapter(child: _buildNoResultsWidget());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildMusicCard(index),
        childCount: list.length,
      ),
    );
  }

  Widget _buildVideoResultsSliver() {
    if (_hasVideoError) {
      return SliverToBoxAdapter(child: _buildErrorWidget(isVideo: true));
    }

    if (videoList.isEmpty) {
      return SliverToBoxAdapter(child: _buildNoResultsWidget(isVideo: true));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildVideoCard(index),
        childCount: videoList.length,
      ),
    );
  }

  Widget _buildCombinedResultsSliver() {
    final hasMusic = list.isNotEmpty;
    final hasVideos = videoList.isNotEmpty;

    if (!hasMusic && !hasVideos) {
      if (_hasError || _hasVideoError) {
        return SliverToBoxAdapter(child: _buildErrorWidget());
      }
      return SliverToBoxAdapter(child: _buildNoResultsWidget());
    }

    return SliverMainAxisGroup(
      slivers: [
        // Music section
        if (hasMusic) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSizes.paddingM,
                bottom: AppSizes.paddingS,
              ),
              child: Text(
                'Music',
                style: TextStyle(
                  fontSize: AppSizes.fontLarge + 2.w,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildMusicCard(index),
              childCount: list.length,
            ),
          ),
        ],

        // Videos section
        if (hasVideos) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSizes.paddingL,
                bottom: AppSizes.paddingS,
              ),
              child: Text(
                'Videos',
                style: TextStyle(
                  fontSize: AppSizes.fontLarge + 2.w,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildVideoCard(index),
              childCount: videoList.length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoCard(int index) {
    final video = videoList[index];
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.paddingM),
      child: VideoCard(
        item: video,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommonVideoPlayerScreen(
                videoUrl: video.videoUrl,
                videoTitle: video.title,
                videoItem: video,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentSearchesSliver() {
    if (recentSearches.isEmpty) {
      // Changed from SliverFillRemaining to SliverToBoxAdapter for top alignment
      return SliverToBoxAdapter(child: _buildNoRecentSearchesWidget());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingXS),
            margin: EdgeInsets.only(bottom: AppSizes.paddingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: AppSizes.fontLarge,
                    fontWeight: FontWeight.w600,
                    color: appColors().gray[600],
                    fontFamily: 'Poppins',
                  ),
                ),
                if (recentSearches.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await CacheManager.clearRecentSearches();
                      await _loadRecentSearches();
                    },
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: appColors().primaryColorApp,
                        fontWeight: FontWeight.w500,
                        fontSize: AppSizes.fontNormal,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildRecentSearchItem(recentSearches[index]),
            childCount: recentSearches.length,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearchItem(Map<String, dynamic> item) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppSizes.paddingXS,
        0,
        AppSizes.paddingXS,
        AppSizes.paddingXS,
      ),
      child: RecentSearchCard(
        item: item,
        pathImage:
            item['imagePath'] ??
            pathImage, // Use cached image path if available
        index: 0, // Index not used in this context
        onTap: () async {
          // Create DataMusic object from cached data using CacheManager utility
          final songData = CacheManager.convertToDataMusic(item);

          await addRemoveHisAPI(item['id'].toString());

          // Use music manager for queue replacement instead of navigation
          final musicManager = MusicManager();

          try {
            await musicManager.replaceQueue(
              musicList: [songData],
              startIndex: 0,
              pathImage: item['imagePath'] ?? pathImage,
              audioPath: item['audioPath'] ?? audioPath,
              callSource: 'Search.onRecentSearchTap',
            );

            // Show mini player instead of navigating to full player
            final stateManager = MusicPlayerStateManager();
            stateManager.showMiniPlayerForMusicStart();

            print(
              '[DEBUG] Recent search music playback started via mini player',
            );
          } catch (e) {
            print('[DEBUG] Recent search music playback failed: $e');
          }
        },
        onRemove: () async {
          await _loadRecentSearches();
        },
      ),
    );
  }

  Widget _buildNoRecentSearchesWidget() {
    return Container(
      height: 500.w, // Increased from 400.w
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 100.w,
            color: appColors().gray[300],
          ), // Increased from 80.w
          SizedBox(height: AppSizes.paddingL),
          Text(
            'No Recent Searches',
            style: TextStyle(
              fontSize: AppSizes.fontLarge,
              fontWeight: FontWeight.w600,
              color: appColors().gray[500],
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            'Songs you search and play will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontNormal,
              color: appColors().gray[400],
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicCard(int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0.5.w,
            blurRadius: 4.w,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.w),
          onTap: () async {
            print('🎯🎯🎯 SEARCH MUSIC CARD TAPPED 🎯🎯🎯');
            print(
              '[DEBUG] Search Music Card tapped: ${list[index].audio_title} at index: $index',
            );
            print('[DEBUG] Song ID: ${list[index].id}');
            print('[DEBUG] Audio URL: ${list[index].audio}');
            print('[DEBUG] Audio path: $audioPath');
            print('[DEBUG] List length: ${list.length}');
            print('[DEBUG] INDEX BEING PASSED TO MUSIC WIDGET: $index');

            // Print details of the song that should play
            print('🎵 EXPECTED SONG TO PLAY:');
            print('   - ID: ${list[index].id}');
            print('   - Title: ${list[index].audio_title}');
            print('   - Artist: ${list[index].artists_name}');

            // Print first song in list for comparison
            print('🎵 FIRST SONG IN LIST (should NOT play):');
            print('   - ID: ${list[0].id}');
            print('   - Title: ${list[0].audio_title}');
            print('   - Artist: ${list[0].artists_name}');

            // Save to recent searches before navigation
            await _saveRecentSearch(list[index]);

            // Add history entry before navigation
            addRemoveHisAPI(list[index].id.toString());

            print('[DEBUG] Starting music playback with index: $index...');

            // Use music manager for queue replacement instead of navigation
            final musicManager = MusicManager();

            try {
              await musicManager.replaceQueue(
                musicList: list,
                startIndex: index,
                pathImage: pathImage,
                audioPath: audioPath.isNotEmpty ? audioPath : "images/audio/",
                callSource: 'Search.onMusicCardTap',
              );

              // Show mini player instead of navigating to full player
              final stateManager = MusicPlayerStateManager();
              stateManager.showMiniPlayerForMusicStart();

              print('[DEBUG] Music playback started via mini player');
            } catch (e) {
              print('[DEBUG] Music playback failed: $e');
            }
          },
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.w),
                  child: SizedBox(
                    width: 60.w,
                    height: 60.w,
                    child: Image.network(
                      AppConstant.ImageUrl + pathImage + list[index].image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('[DEBUG] Error loading image: $error');
                        return Image.asset(
                          'assets/images/song_placeholder.png',
                          fit: BoxFit.cover,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: appColors().gray[100],
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5.w,
                              color: appColors().primaryColorApp,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                SizedBox(width: 12.w),
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        list[index].audio_title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppSizes.fontNormal,
                          color: Colors.black87,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.w),
                      Text(
                        list[index].artists_name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppSizes.fontSmall,
                          color: appColors().gray[500],
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: 2.w),
                      Text(
                        list[index].audio_duration.trim(),
                        style: TextStyle(
                          fontSize: 12.w,
                          color: appColors().gray[400],
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),

                // Options button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20.w),
                    onTap: () {
                      print(
                        '[DEBUG] Tapping options for: ${list[index].audio_title}',
                      );
                      showOptionsDialog(
                        context,
                        "${list[index].id}",
                        "add",
                        list[index].favourite,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      child: Icon(
                        Icons.more_vert,
                        color: appColors().gray[500],
                        size: 20.w,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 360.w,
      alignment: Alignment.center,
      child: CircleLoader(size: 180.w, showBackground: false, showLogo: true),
    );
  }

  Widget _buildInitialStateWidget() {
    return Container(
      height: 400.w,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80.w, color: Colors.grey[400]),
          SizedBox(height: AppSizes.paddingL - 4.w),
          Text(
            'Search for your favorite music',
            style: TextStyle(
              fontSize: AppSizes.fontLarge,
              fontWeight: FontWeight.w600,
              color: appColors().gray[500],
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            'Type in the search box to find songs, artists, and albums',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontNormal,
              color: appColors().gray[400],
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget({bool isVideo = false}) {
    final errorMsg = isVideo
        ? (_videoErrorMessage.isNotEmpty
              ? _videoErrorMessage
              : 'Video search failed')
        : (_errorMessage.isNotEmpty ? _errorMessage : 'Search failed');

    return Container(
      height: 300.w,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60.w,
            color: appColors().primaryColorApp.withOpacity(0.4),
          ),
          SizedBox(height: AppSizes.paddingM),
          Text(
            errorMsg,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontMedium,
              color: appColors().gray[500],
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppSizes.paddingL - 4.w),
          InkWell(
            onTap: () {
              searchAPI();
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL - 4.w,
                vertical: 10.w,
              ),
              decoration: BoxDecoration(
                color: appColors().primaryColorApp,
                borderRadius: BorderRadius.circular(AppSizes.paddingL - 4.w),
              ),
              child: Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: AppSizes.fontNormal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsWidget({bool isVideo = false}) {
    return Container(
      height: 400.w,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 200.w,
            width: 200.w,
            child: Image.asset(
              'assets/images/placeholder.png',
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: AppSizes.paddingL),
          Text(
            isVideo ? 'No Videos Found' : 'No Results Found',
            style: TextStyle(
              fontSize: AppSizes.fontExtraLarge,
              fontWeight: FontWeight.bold,
              color: appColors().gray[600],
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              fontSize: AppSizes.fontNormal,
              color: appColors().gray[400],
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  void showDialogBox(
    BuildContext context,
    String ids,
    String tag,
    String favTag,
  ) {
    showGeneralDialog(
      barrierLabel: "Barrier",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 700),
      context: context,
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 265,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: appColors().primaryColorApp),
                gradient: LinearGradient(
                  colors: [
                    appColors().colorBackground,
                    appColors().colorBackground,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(1),
                    child: InkResponse(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            alignment: Alignment.centerLeft,
                            width: 68,
                            child: favTag.contains("1")
                                ? Image.asset(
                                    'assets/icons/favfill.png',
                                    color: appColors().colorText,
                                  )
                                : Image.asset('assets/icons/fav2.png'),
                          ),
                          Container(
                            width: 145,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              favTag.contains("1")
                                  ? 'Remove Favorite'
                                  : 'Favorite',
                              style: TextStyle(
                                fontSize: 19,
                                color: appColors().colorText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        addRemoveAPI(ids, tag);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(1),
                    child: InkResponse(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(16),
                            child: Image.asset('assets/icons/addto.png'),
                          ),
                          Container(
                            width: 145,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Add to playlist',
                              style: TextStyle(
                                fontSize: 19,
                                color: appColors().colorText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreatePlaylist(ids),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Fix the addRemoveHisAPI method
  Future<void> addRemoveHisAPI(String id) async {
    try {
      print('[DEBUG] Adding song to history: $id');
      await HistoryPresenter().addHistory(id, token, 'add');
    } catch (e) {
      print('[ERROR] Failed to add to history: $e');
    }
  }

  void showOptionsDialog(
    BuildContext context,
    String ids,
    String tag,
    String favTag,
  ) {
    showGeneralDialog(
      barrierLabel: "Barrier",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 700),
      context: context,
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 280.w,
              padding: EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10.w,
                    spreadRadius: 2.w,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOptionItem(
                    icon: favTag.contains("1")
                        ? Icons.favorite
                        : Icons.favorite_border,
                    text: favTag.contains("1")
                        ? 'Remove Favorite'
                        : 'Add to Favorite',
                    iconColor: favTag.contains("1")
                        ? appColors().primaryColorApp
                        : Colors.grey[600]!,
                    onTap: () {
                      addRemoveAPI(ids, tag);
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: AppSizes.paddingS),
                  _buildOptionItem(
                    icon: Icons.playlist_add,
                    text: 'Add to Playlist',
                    iconColor: Colors.grey[600]!,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePlaylist(ids),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String text,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.paddingS),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 12.w,
          horizontal: AppSizes.paddingM,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20.w),
            SizedBox(width: AppSizes.paddingM),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: AppSizes.fontSmall,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // COMMENTED OUT - YouTube results widget (removed duplicate method)
  /*
  Widget _buildYouTubeResults() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: videoResult.length,
      itemBuilder: (context, index) {
        String imagepath = videoResult[index].thumbnail.medium.url.toString();
        return Container(
          margin: EdgeInsets.only(bottom: 8.w),
          child: ListTile(
            onTap: () {
              list = [];
              list.add(
                DataMusic(
                  1,
                  imagepath,
                  videoResult[index].url,
                  videoResult[index].duration.toString(),
                  videoResult[index].title.toString(),
                  videoResult[index].description.toString(),
                  1,
                  "1",
                  videoResult[index].channelTitle.toString(),
                  '',
                  1,
                  1,
                  1,
                  "1",
                  1,
                  "1",
                  '',
                ),
              );
              if (videoResult[index].url.contains("watch")) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Music2(list),
                  ),
                ).then((value) {
                  _reload();
                });
              }
            },
            contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.w),
            leading: CircleAvatar(
              radius: 28.w,
              backgroundImage: const AssetImage('assets/images/song_placeholder.png'),
              foregroundImage: NetworkImage(imagepath),
            ),
            title: Text(
              videoResult[index].title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16.w,
                color: Colors.black87,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              videoResult[index].description.toString(),
              maxLines: 1,
              style: TextStyle(
                fontSize: 14.w,
                color: appColors().gray[500],
                fontFamily: 'Poppins',
              ),
            ),
          ),
        );
      },
    );
  }
  */

  // COMMENTED OUT - YouTube search functionality
  /*
  Future<void> getYT(String searc) async {
    if (searc.trim().isEmpty) {
      setState(() {
        videoResult = [];
        _hasSearched = false;
        _isSearching = false;
        _hasError = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasError = false;
      _errorMessage = '';
    });

    String key = yt_key;

    if (key.isNotEmpty) {
      try {
        YoutubeAPI ytApi = YoutubeAPI(key, maxResults: 50, type: "video");
        videoResult = await ytApi.search(
          searc,
          regionCode: yt_code,
          type: "video",
        );
        setState(() {
          _isSearching = false;
          _hasSearched = true;
          _hasError = false;
        });
      } catch (e) {
        setState(() {
          _isSearching = false;
          _hasSearched = true;
          _hasError = true;
          _errorMessage = 'YouTube search failed. Please try again.';
        });
      }
    }
  }
  */
}

class Resources {
  Resources(BuildContext context);

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
    return Resources(context);
  }
}
