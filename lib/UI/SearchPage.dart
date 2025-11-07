import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/CatSubCatMusicPresenter.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/Presenter/HistoryPresenter.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/AdHelper.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:session_storage/session_storage.dart';
import 'package:dio/dio.dart';

import '../main.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/search_bar.dart';
import '../widgets/music/recent_search_card.dart';
import '../widgets/music/search_music_card.dart';
import '../videoplayer/models/video_item.dart';
// removed unused imports to avoid analyzer warnings
import 'AccountPage.dart';

AudioPlayerHandler? _audioHandler;
String yt = "";

class SearchPage extends StatefulWidget {
  final String searchParam;

  const SearchPage(this.searchParam, {super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _numberOfPostsPerRequest = 9;
  final txtSearch = TextEditingController();
  bool allowAds = true;
  ModelSettings? modelSettings;

  BannerAd? _bannerAd;
  int isYt = 0;
  String lastStatus = '', searchTag = '', token = '';
  String pathImage = '', audioPath = '';
  List<DataMusic> list = [];
  final PagingController<int, DataMusic> _pagingController = PagingController(
    firstPageKey: 1,
  );

  // Modern UI properties
  final SharedPref sharePrefs = SharedPref();
  ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  UserModel? model;
  late ScrollController _scrollController;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  final session = SessionStorage();

  List<Map<String, dynamic>> recentSearches = [];
  bool _showingRecentSearches = true; // Start with recent searches

  // Tab management for Music/Video/All (reserved for future use)
  List<VideoItem> videoList = [];
  final Dio _dio = Dio();
  final PagingController<int, VideoItem> _videoPagingController =
      PagingController(firstPageKey: 1);

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });

    // TODO: Implement video pagination
    // _videoPagingController.addPageRequestListener((pageKey) {
    //   _fetchVideoPage(pageKey);
    // });

    session['page'] = "2";
    _audioHandler = const MyApp().called();

    // Initialize data first (run async initialization separately to allow
    // mounted checks after awaits)
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _initializeData();
    await _loadRecentSearches();

    if (!mounted) return;

    // Handle search parameter after initialization
    if (widget.searchParam.isNotEmpty) {
      txtSearch.text = widget.searchParam;
      setState(() {
        _showingRecentSearches = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        searchAPI();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _pagingController.dispose();
    _videoPagingController.dispose();
    txtSearch.dispose();
    _bannerAd?.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await value();
    await getSettings();
    _initGoogleMobileAds();
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
      await _loadRecentSearches(); // Refresh the list
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> searchAPI() async {
    final searchText = txtSearch.text.trim();

    if (searchText.isEmpty) {
      setState(() {
        _showingRecentSearches = true;
        list.clear();
      });
      _pagingController.refresh();
      await _loadRecentSearches();
      return;
    }

    setState(() {
      _showingRecentSearches = false;
    });

    list.clear();
    _pagingController.refresh();
  }

  Future<void> value() async {
    try {
      token = await sharePrefs.getToken();
      model = await sharePrefs.getUserData();
      sharedPreThemeData = await sharePrefs.getThemeData();
      String? sett = await sharePrefs.getSettings();
      if (sett != null && sett.isNotEmpty) {
        final Map<String, dynamic> parsed = json.decode(sett);
        modelSettings = ModelSettings.fromJson(parsed);
        isYt = modelSettings?.data.is_youtube ?? 0;
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error in value(): $e');
    }
  }

  void _initGoogleMobileAds() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              // Ad loaded successfully
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    );

    _bannerAd?.load();
  }

  Future<void> getSettings() async {
    try {
      String? sett = await sharePrefs.getSettings();
      if (sett != null && sett.isNotEmpty) {
        final Map<String, dynamic> parsed = json.decode(sett);
        ModelSettings modelSettings = ModelSettings.fromJson(parsed);

        allowAds = modelSettings.data.ads == 1;

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error in getSettings(): $e');
    }
  }

  void _reload() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollListener() {
    if (!_scrollController.hasClients || !mounted) return;

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

  Future<void> _fetchPage(int pageKey) async {
    final searchText = txtSearch.text.trim();
    if (searchText.isEmpty) return;

    try {
      if (token.isEmpty) {
        token = await sharePrefs.getToken();
      }

      print('[DEBUG] Fetching page $pageKey for search: "$searchText"');

      final response = await CatSubcatMusicPresenter()
          .getMusicListBySearchNamePage(
            searchText,
            token,
            pageKey,
            _numberOfPostsPerRequest,
            context,
          );

      if (!mounted) return;

      Map<String, dynamic> parsed = json.decode(response.toString());
      ModelMusicList all = ModelMusicList.fromJson(parsed);

      // Update paths
      pathImage = all.imagePath;
      audioPath = all.audioPath;

      List<DataMusic> postList = all.data;
      print('[DEBUG] Page $pageKey returned ${postList.length} items');

      final isLastPage = postList.length < _numberOfPostsPerRequest;

      if (isLastPage) {
        _pagingController.appendLastPage(postList);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(postList, nextPageKey);
      }

      // Update the main list for navigation
      list.addAll(postList);
    } catch (e) {
      print('[ERROR] Error in _fetchPage: $e');
      if (mounted) {
        _pagingController.error = e;
      }
    }
  }

  Future<void> addRemoveAPI(String id, String tag) async {
    searchTag = txtSearch.text;
    try {
      await FavMusicPresenter().getMusicAddRemove(id, token, tag);
      if (mounted) {
        setState(() {});
        // Update the item in the paging controller if it exists
        final itemList = _pagingController.itemList;
        if (itemList != null) {
          final itemIndex = itemList.indexWhere(
            (item) => item.id.toString() == id,
          );
          if (itemIndex != -1) {
            // Update the favorite status
            itemList[itemIndex].favourite = tag == "add"
                ? (itemList[itemIndex].favourite == "1" ? "0" : "1")
                : tag;
            // Trigger rebuild to reflect changes
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('Error in addRemoveAPI: $e');
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
        // Main content area
        Expanded(
          child: Stack(
            children: [
              // Background container
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
    return Container(
      color: Colors.transparent,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              // Add horizontal padding only to the search bar for visual consistency
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingXS + 2.w,
                ),
                child: AnimatedSearchBar(
                  controller: txtSearch,
                  hintText: "Search for music...",
                  onChanged: (value) {
                    print('[DEBUG] Search changed: "$value"');
                    if (value.isEmpty) {
                      setState(() {
                        list.clear();
                        _pagingController.refresh();
                        _showingRecentSearches = true;
                      });
                      _loadRecentSearches();
                    } else if (value.length >= 2) {
                      // Reduce threshold to 2
                      searchAPI();
                    }
                  },
                  onClear: () {
                    print('[DEBUG] Search cleared');
                    txtSearch.clear();
                    setState(() {
                      list.clear();
                      _pagingController.refresh();
                      _showingRecentSearches = true;
                    });
                    _loadRecentSearches();
                  },
                  focusedBorderColor: appColors().primaryColorApp,
                ),
              ),
              SizedBox(height: AppSizes.paddingS),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainScrollableContent() {
    if (_audioHandler == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<MediaItem?>(
      stream: _audioHandler!.mediaItem,
      builder: (context, snapshot) {
        final hasMiniPlayer = snapshot.hasData;

        return RefreshIndicator(
          onRefresh: () async {
            if (_showingRecentSearches) {
              await _loadRecentSearches();
            } else {
              list.clear();
              _pagingController.refresh();
            }
          },
          color: appColors().primaryColorApp,
          backgroundColor: Colors.white,
          displacement: MediaQuery.of(context).padding.top + 120.w,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Top padding for header
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 120.w,
                ),
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Main content
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.contentHorizontalPadding,
                  AppSizes.contentTopPadding,
                  AppSizes.contentHorizontalPadding,
                  AppPadding.bottom(context),
                ),
                sliver: _buildContentSliver(hasMiniPlayer),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentSliver(bool hasMiniPlayer) {
    if (_showingRecentSearches) {
      return _buildRecentSearchesSliver(hasMiniPlayer);
    }
    return _buildSearchResultsSliver(hasMiniPlayer);
  }

  Widget _buildRecentSearchesSliver(bool hasMiniPlayer) {
    if (recentSearches.isEmpty) {
      return SliverToBoxAdapter(child: _buildNoRecentSearchesWidget());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.paddingS),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontSize: AppSizes.fontLarge,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
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
                        fontSize: AppSizes.fontNormal,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        final item = recentSearches[index - 1];
        return _buildRecentSearchItem(item, index - 1);
      }, childCount: recentSearches.length + 1),
    );
  }

  Widget _buildSearchResultsSliver(bool hasMiniPlayer) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200.w,
        child: PagedListView<int, DataMusic>.separated(
          pagingController: _pagingController,
          separatorBuilder: (context, index) => SizedBox(height: 1.w),
          builderDelegate: PagedChildBuilderDelegate<DataMusic>(
            firstPageErrorIndicatorBuilder: (context) => _buildErrorWidget(),
            noItemsFoundIndicatorBuilder: (context) => _buildNoResultsWidget(),
            firstPageProgressIndicatorBuilder: (context) =>
                _buildLoadingWidget(),
            newPageProgressIndicatorBuilder: (context) => Container(
              padding: EdgeInsets.all(4.w),
              child: Center(
                child: CircularProgressIndicator(
                  color: appColors().primaryColorApp,
                  strokeWidth: 1.5.w,
                ),
              ),
            ),
            itemBuilder: (context, item, index) {
              return _buildMusicItem(item, index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearchItem(Map<String, dynamic> item, int index) {
    return RecentSearchCard(
      item: item,
      pathImage:
          item['imagePath'] ?? pathImage, // Use cached image path if available
      index: index,
      onTap: () async {
        // Create DataMusic object from cached data using CacheManager utility
        final songData = CacheManager.convertToDataMusic(item);

        // Use music manager for queue replacement instead of navigation
        final musicManager = MusicManager();

        try {
          await musicManager.replaceQueue(
            musicList: [songData],
            startIndex: 0,
            pathImage: pathImage,
            audioPath: item['audioPath'] ?? audioPath,
            callSource: 'SearchPage.onRecentSearchTap',
          );

          // Show mini player instead of navigating to full player
          final stateManager = MusicPlayerStateManager();
          stateManager.showMiniPlayerForMusicStart();

          print('[DEBUG] Recent search music playback started via mini player');
        } catch (e) {
          print('[DEBUG] Recent search music playback failed: $e');
        }
      },
      onRemove: () async {
        await _loadRecentSearches();
      },
    );
  }

  Widget _buildNoRecentSearchesWidget() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80.w, color: Colors.grey[400]),
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

  Widget _buildMusicItem(DataMusic item, int index) {
    print('[DEBUG] Creating SearchMusicCard for: ${item.audio_title}');

    return SearchMusicCard(
      item: item,
      pathImage: pathImage,
      onTap: () async {
        print('🎯🎯🎯 SEARCH PAGE MUSIC CARD TAPPED 🎯🎯🎯');
        print(
          '[DEBUG] Tapped song: ${item.audio_title} at paginated index: $index',
        );
        print('[DEBUG] Song ID: ${item.id}');
        print('[DEBUG] Audio URL: ${item.audio}');

        // Get the complete list of search results
        final currentList = _pagingController.itemList ?? list;

        // Find the actual index of this song in the complete search results
        final actualIndex = currentList.indexWhere(
          (song) => song.id == item.id,
        );

        print('[DEBUG] ACTUAL INDEX IN COMPLETE LIST: $actualIndex');
        print('[DEBUG] TOTAL SONGS IN LIST: ${currentList.length}');

        // Print details of the song that should play
        print('🎵 EXPECTED SONG TO PLAY:');
        print('   - ID: ${item.id}');
        print('   - Title: ${item.audio_title}');
        print('   - Artist: ${item.artists_name}');

        // Print first song in list for comparison if available
        if (currentList.isNotEmpty) {
          print('🎵 FIRST SONG IN LIST (should NOT play):');
          print('   - ID: ${currentList[0].id}');
          print('   - Title: ${currentList[0].audio_title}');
          print('   - Artist: ${currentList[0].artists_name}');
        }

        // Verify the song at actualIndex matches what we expect
        if (actualIndex >= 0 && actualIndex < currentList.length) {
          final songAtIndex = currentList[actualIndex];
          print('🎵 SONG AT ACTUAL INDEX $actualIndex:');
          print('   - ID: ${songAtIndex.id}');
          print('   - Title: ${songAtIndex.audio_title}');
          print('   - Artist: ${songAtIndex.artists_name}');
        }

        // Save to recent searches before navigation
        await _saveRecentSearch(item);

        // Add to history
        try {
          await HistoryPresenter().addHistory(item.id.toString(), token, 'add');
        } catch (e) {
          print('[ERROR] Failed to add to history: $e');
        }

        // Use music manager for queue replacement instead of navigation
        final musicManager = MusicManager();

        try {
          await musicManager.replaceQueue(
            musicList: currentList,
            startIndex: actualIndex >= 0 ? actualIndex : 0,
            pathImage: pathImage,
            audioPath: audioPath.isNotEmpty ? audioPath : "images/audio/",
            callSource: 'SearchPage.onRecentSearchTap',
          );

          // Show mini player instead of navigating to full player
          final stateManager = MusicPlayerStateManager();
          stateManager.showMiniPlayerForMusicStart();

          print('[DEBUG] Music playback started via mini player');
        } catch (e) {
          print('[DEBUG] Music playback failed: $e');
        }
      },
      onActionCompleted: () {
        print('[DEBUG] Action completed, reloading...');
        _reload();
        // Refresh current page if we have search results
        if (_pagingController.itemList != null &&
            _pagingController.itemList!.isNotEmpty) {
          // Don't call searchAPI here, just reload the UI
          setState(() {});
        }
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 300.w,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: appColors().primaryColorApp,
            strokeWidth: 3.w,
          ),
          SizedBox(height: AppSizes.paddingL),
          Text(
            'Searching...',
            style: TextStyle(
              fontSize: AppSizes.fontMedium,
              color: appColors().gray[500],
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
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
            'Search failed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontMedium,
              color: appColors().gray[500],
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppSizes.paddingL),
          InkWell(
            onTap: () {
              searchAPI();
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL,
                vertical: 10.w,
              ),
              decoration: BoxDecoration(
                color: appColors().primaryColorApp,
                borderRadius: BorderRadius.circular(AppSizes.paddingL),
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

  Widget _buildNoResultsWidget() {
    return Container(
      height: 400.w,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80.w, color: Colors.grey[400]),
          SizedBox(height: AppSizes.paddingL),
          Text(
            'No Results Found',
            style: TextStyle(
              fontSize: AppSizes.fontLarge,
              fontWeight: FontWeight.bold,
              color: appColors().gray[600],
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            'Try searching with different keywords',
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
}

class Resources {
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
