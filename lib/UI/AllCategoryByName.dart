import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelAllCat.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Presenter/CatSubCatMusicPresenter.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/UI/artist_detail_screen.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/utils/performance_debouncer.dart';

import '../main.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/loader.dart';
import '../widgets/common/search_bar.dart';
import '../widgets/media_items/index.dart';
import 'MusicEntryPoint.dart';
import 'MusicList.dart';

AudioPlayerHandler? _audioHandler;

class AllCategoryByName extends StatefulWidget {
  // Per-instance display type to avoid shared global state
  final String typ;

  const AllCategoryByName(
    AudioPlayerHandler? audioHandler,
    String type, {
    super.key,
  }) : typ = type;

  @override
  _AllCategoryByNameState createState() => _AllCategoryByNameState();
}

class _AllCategoryByNameState extends State<AllCategoryByName> {
  // Local cache of type for this instance
  late String _typ;
  bool _isLastPage = false;
  int _pageNumber = 1;
  bool _error = false;
  bool _loading = true, noData = false;
  final int _numberOfPostsPerRequest = 20;
  List<SubData> _posts = [];
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  String token = "", path = "";
  // Search bar controller
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _isSearching = false;
  VoidCallback? _searchListener;

  // Consistent scroll controller for header animations
  late ScrollController _scrollController;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;
  bool _isPaginating = false; // next-page in progress
  static const double _paginationTriggerOffset = 300.0; // px before bottom
  // Guard against concurrent first-page fetches and duplicate items
  bool _isFetchingFirstPage = false;
  final Set<int> _seenIds = <int>{};

  // Consistent constants for design
  static const double _headerAnimationThreshold = 10.0;
  static const double _topScrollThreshold = 5.0;

  // Add favorite service instance
  final FavoriteService _favoriteService = FavoriteService();

  // Add favorite state management for AllCategoryByName songs
  final Set<String> _favoriteIds = <String>{};
  bool _favoritesLoaded = false;

  // Incremented on every search change; used to detect stale responses
  int _searchRequestId = 0;

  // iOS overlay entry for download message management
  OverlayEntry? _currentOverlayEntry;

  // Centralized music action handler
  late MusicActionHandler _musicActionHandler;

  // Add mapping function to convert display names to API types
  String _getApiType(String displayType) {
    switch (displayType) {
      case "Featured Playlist":
        return "Featured Playlists";
      case "Featured Songs":
        return "Featured Songs";
      case "New Albums and EP's":
        return "New Albums";
      case "New Songs":
        return "New Songs";
      case "Popular Artist":
        return "Trending Artists";
      case "Popular Songs":
        return "Trending Songs";
      case "Popular Albums":
        return "Trending Albums";
      case "Trending Genres":
        return "Trending Genres";
      case "My Songs":
        return "My Songs";
      default:
        return displayType;
    }
  }

  // Helper method to determine if the content type should use 3-column layout (songs)
  bool _isSongType(String apiType) {
    return apiType.contains("Songs") || apiType == "My Songs";
  }

  Future<void> getCate() async {
    token = await sharePrefs.getToken();
    sharedPreThemeData = await sharePrefs.getThemeData();
    _pageNumber = 1;
    _posts = [];
    _isLastPage = false;
    _loading = true;
    _error = false;
    _isFetchingFirstPage = false;
    _seenIds.clear();
    fetchData();
  }

  @override
  void initState() {
    super.initState();
    _typ = widget.typ;
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _audioHandler = const MyApp().called();

    // Initialize the centralized music action handler
    _musicActionHandler = MusicActionHandlerFactory.create(
      context: context,
      audioHandler: _audioHandler,
      favoriteService: _favoriteService,
      onStateUpdate: () {
        if (!mounted) return;
        setState(() {});
      },
    );

    getCate();
    print(_typ);

    // Load favorites for state management (non-blocking)
    _loadFavorites();

    // Listen to search input with debounce
    _searchListener = () {
      final next = _searchController.text.trim();
      if (next == _searchText) return;
      PerformanceDebouncer.debounceUIUpdate('allcat_search_change', () {
        _onSearchChanged(next);
      }, delay: const Duration(milliseconds: 350));
    };
    _searchController.addListener(_searchListener!);

    // After first frame, adjust mini player and navigation based on origin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always show navigation and mini player when entering this screen
      final stateManager = MusicPlayerStateManager();
      stateManager.showNavigationAndMiniPlayer();
    });
  }

  @override
  void didUpdateWidget(covariant AllCategoryByName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.typ != widget.typ) {
      _typ = widget.typ;
      // Reset view and data state on type change
      _pageNumber = 1;
      _posts = [];
      _isLastPage = false;
      _loading = true;
      _error = false;
      noData = false;
      _isGridView = true;
      _isFetchingFirstPage = false;
      _seenIds.clear();
      fetchData();
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Cancel any pending search debounce to avoid callbacks after dispose
    PerformanceDebouncer.cancel('allcat_search_change');
    if (_searchListener != null) {
      _searchController.removeListener(_searchListener!);
    }
    _scrollController.dispose();

    // Clean up iOS overlay entry
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;

    super.dispose();
  }

  Future<void> _pullRefresh() async {
    if (_pageNumber != 1) {
      _pageNumber = 1;
      _posts = [];
      _isLastPage = false;
      _loading = true;
      _error = false;
      noData = false;
      _isPaginating = false;
      _isFetchingFirstPage = false;
      _seenIds.clear();
      fetchData();
    }
  }

  Future<void> fetchData({bool paginate = false}) async {
    token = await sharePrefs.getToken();
    // Capture the request id for search-staleness detection
    final int requestId = _searchRequestId;
    try {
      final apiType = _getApiType(_typ);
      if (kDebugMode) {
        print("Category: $_typ");
        print(
          "Fetching data for category: $_typ with type: $apiType, paginate=$paginate, page=$_pageNumber",
        );
      }

      if (paginate) {
        // Prevent duplicate first-page requests
        if (_isFetchingFirstPage) {
          if (kDebugMode) {
            print('Duplicate first-page fetch suppressed for $_typ');
          }
          return;
        }
        _isFetchingFirstPage = true;
        if (mounted) setState(() {});
      }

      // Use unified getMusic with optional search
      final response = await CatSubcatMusicPresenter().getMusic(
        token: token,
        type: apiType,
        page: _pageNumber,
        limit: _numberOfPostsPerRequest,
        search: _isSearching ? _searchText : null,
        context: context,
      );

      // If a newer search was issued after this request started, drop this response
      if (requestId != _searchRequestId) {
        if (kDebugMode) {
          print(
            'Dropping stale response for $_typ (requestId=$requestId, current=$_searchRequestId)',
          );
        }
        // Ensure in-flight flags are reset so the UI doesn't get stuck
        if (paginate) {
          _isPaginating = false;
        } else {
          _loading = false;
          _isFetchingFirstPage = false;
        }
        return;
      }

      if (kDebugMode) {
        print("Response for $_typ: $response");
      }

      Map<String, dynamic> parsed;
      try {
        parsed = json.decode(response.toString());
      } catch (e) {
        if (kDebugMode) {
          print("JSON parsing error for $_typ: $e");
        }
        if (!mounted) return;
        setState(() {
          if (paginate) {
            _isPaginating = false;
          } else {
            _loading = false;
            _isFetchingFirstPage = false;
          }
          _error = true;
        });
        return;
      }

      if (!parsed.containsKey('status') ||
          !parsed.containsKey('sub_category')) {
        if (kDebugMode) {
          print("Unexpected response structure for $_typ");
        }
        if (!mounted) return;
        setState(() {
          if (paginate) {
            _isPaginating = false;
          } else {
            _loading = false;
            _isFetchingFirstPage = false;
          }
          _error = true;
        });
        return;
      }

      if (parsed['status'] == false) {
        if (kDebugMode) {
          print("API returned false status for $_typ: ${parsed['msg']}");
        }
        if (!mounted) return;
        setState(() {
          if (paginate) {
            _isPaginating = false;
          } else {
            _loading = false;
            _isFetchingFirstPage = false;
          }
          noData = true;
        });
        return;
      }

      ModelAllCat allCat = ModelAllCat.fromJson(parsed);
      path = allCat.imagePath;
      List<SubData> postList = allCat.sub_category;

      if (postList.isNotEmpty) {
        if (kDebugMode) {
          print("Successfully loaded ${postList.length} items for $_typ");
          // Additional logging for Featured Playlists
          if (apiType == "Featured Playlists") {
            for (int i = 0; i < postList.length; i++) {
              final item = postList[i];
              print(
                "Playlist $i: ID=${item.id}, playlist_name='${item.playlist_name}', name='${item.name}', image_url='${item.image_url}', image='${item.image}'",
              );
            }
          }
        }
        if (!mounted) return;
        setState(() {
          // Prefer server-provided pagination meta when available
          if (allCat.totalPages != null && allCat.currentPage != null) {
            _isLastPage = allCat.currentPage! >= allCat.totalPages!;
          } else {
            _isLastPage = postList.length < _numberOfPostsPerRequest;
          }
          if (paginate) {
            _isPaginating = false;
          } else {
            _loading = false;
            _isFetchingFirstPage = false;
          }
          // Advance page based on server meta if present, else increment
          if (allCat.currentPage != null) {
            _pageNumber = allCat.currentPage! + 1;
          } else {
            _pageNumber = _pageNumber + 1;
          }
          // Deduplicate by ID to avoid duplicate cards
          final List<SubData> newItems = [];
          for (final item in postList) {
            if (_seenIds.add(item.id)) {
              newItems.add(item);
            }
          }
          _posts.addAll(newItems);
        });
      } else {
        if (kDebugMode) {
          print("No data found for $_typ");
        }
        noData = true;
        if (paginate) {
          _isPaginating = false;
        } else if (_loading) {
          _loading = false;
          _isFetchingFirstPage = false;
        }
        if (!mounted) return;
        setState(() {});
      }
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print("Timeout error for $_typ: $e");
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _isFetchingFirstPage = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching data for $_typ: $e");
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _isFetchingFirstPage = false;
      });
    }
  }

  void _reload() {
    setState(() {});
  }

  // View mode: grid or list
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    // Consistent status bar styling
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // Dismiss keyboard when tapping outside input fields (e.g., search bar)
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
          // Main scrollable content
          _buildMainScrollableContent(),

          // Animated header overlay
          _buildAnimatedHeader(),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return AnimatedSlide(
      offset: _isHeaderVisible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: EdgeInsets.only(right: 0.0.w),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.90)),
          child: AppHeader(
            title: _typ,
            showBackButton: true,
            showProfileIcon: false,
            backgroundColor: Colors.transparent,
            scrollController: _scrollController,
            scrollAware: true,
            showGridToggle: true,
            onGridToggle: () => setState(() => _isGridView = !_isGridView),
            isGridView: _isGridView,
          ),
        ),
      ),
    );
  }

  Widget _buildMainScrollableContent() {
    return RefreshIndicator(
      onRefresh: _pullRefresh,
      color: appColors().primaryColorApp,
      backgroundColor: Colors.white,
      displacement: MediaQuery.of(context).padding.top + AppSizes.paddingL,
      child: StreamBuilder<MediaItem?>(
        stream: _audioHandler!.mediaItem,
        builder: (context, mediaSnapshot) {
          // Nest a playback state listener so play/pause toggles rebuild the list and overlays
          return StreamBuilder<PlaybackState>(
            stream: _audioHandler!.playbackState,
            builder: (context, playbackSnapshot) {
              final hasMiniPlayer = mediaSnapshot.hasData;
              final bottomPadding = hasMiniPlayer
                  ? AppPadding.bottom(context, extra: 100.w)
                  : AppPadding.bottom(context);

              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // Consistent top padding for header
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 70.w,
                    ),
                    sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),
                  // Search bar
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.contentHorizontalPadding,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: CommonSearchBar(
                        controller: _searchController,
                        hintText: 'Search $_typ',
                        onChanged: (_) {}, // handled by listener with debounce
                        onClear: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                    ),
                  ),

                  // Main content with consistent padding
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.contentHorizontalPadding,
                    ),
                    sliver: _buildContentSliver(),
                  ),

                  // Pagination footer: full-width centered loader or retry
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppSizes.paddingM,
                      ),
                      child: Center(
                        child: _isPaginating
                            ? _buildPaginationLoading()
                            : (_error
                                  ? _buildPaginationError()
                                  : const SizedBox.shrink()),
                      ),
                    ),
                  ),

                  // Bottom padding for consistent spacing with mini player logic
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContentSliver() {
    // Server-backed results: use _posts directly
    final List<SubData> data = _posts;
    // Show appropriate state
    if (data.isEmpty) {
      if (_loading) {
        return SliverToBoxAdapter(child: _buildLoadingWidget());
      }
      if (_error) {
        return SliverToBoxAdapter(child: _buildErrorWidget());
      }
      if (noData && !_isSearching) {
        return SliverToBoxAdapter(child: _buildNoDataWidget());
      }
      // Empty results (likely search)
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.paddingL),
            child: Text(
              _isSearching
                  ? 'No results found for "$_searchText"'
                  : 'No $_typ found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: AppSizes.fontNormal,
                color: appColors().colorText,
              ),
            ),
          ),
        ),
      );
    }
    // Switch slivers directly (no AnimatedSwitcher at sliver level)
    return _isGridView ? _buildGridSliver(data) : _buildListSliver(data);
  }

  // Grid view sliver
  Widget _buildGridSliver(List<SubData> filteredPosts) {
    final apiType = _getApiType(_typ);

    // Determine grid layout based on content type
    int crossAxisCount;
    double childAspectRatio;

    // Detect tablet / iPad sized screens
    final bool isTabletLocal = MediaQuery.of(context).size.shortestSide >= 600;

    // Reserve a fixed vertical space for title, subtitle and action icons inside the card.
    // Songs have an additional artist line so give them extra reserved space.
    final double reservedVerticalForText = _isSongType(apiType)
        ? (isTabletLocal ? 64.0 : 54.0) // songs: more room for title + artist
        : (isTabletLocal ? 40.0 : 36.0); // other types: slightly less

    if (_isSongType(apiType)) {
      // Songs: 3 columns on phone, 4 on tablet
      crossAxisCount = isTabletLocal ? 4 : 3;
    } else {
      // Playlists, Albums, Artists, Genres: 2 columns on phone, 4 on tablet for denser layout
      crossAxisCount = isTabletLocal ? 4 : 2;
    }

    // Compute a safe childAspectRatio dynamically from available width and reserved text height.
    // childAspectRatio = itemWidth / itemHeight
    final screenWidth =
        MediaQuery.of(context).size.width -
        (AppSizes.contentHorizontalPadding * 2);
    final totalGapsWidth = (crossAxisCount - 1) * AppSizes.paddingXS;
    final itemWidth = (screenWidth - totalGapsWidth) / crossAxisCount;

    // Choose an image area height that's at least equal to itemWidth (square image)
    // plus the reserved vertical area for text below it.
    final itemHeight = itemWidth + reservedVerticalForText;
    childAspectRatio = itemWidth / itemHeight;

    // Apply clamps to avoid extreme aspect ratios and reduce overly tall cards on tablets
    // Allow slightly taller cards for song items by lowering the min aspect ratio.
    if (childAspectRatio < 0.65) childAspectRatio = 0.65;
    if (childAspectRatio > 1.0) childAspectRatio = 1.0;

    // Reduce spacing slightly on tablets to make rows more compact
    final double spacing = isTabletLocal
        ? (AppSizes.paddingXS * 0.4)
        : AppSizes.paddingXS;

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      delegate: _buildItemDelegate(filteredPosts),
    );
  }

  // List view sliver
  Widget _buildListSliver(List<SubData> filteredPosts) {
    return SliverList(delegate: _buildItemDelegate(filteredPosts));
  }

  // Shared delegate for pagination and item rendering
  SliverChildBuilderDelegate _buildItemDelegate(List<SubData> filteredPosts) {
    return SliverChildBuilderDelegate((context, index) {
      final SubData post = filteredPosts[index];
      return _buildModernCard(post);
    }, childCount: filteredPosts.length);
  }

  Widget _buildModernCard(SubData post) {
    final apiType = _getApiType(_typ);

    // Extract image URL
    String imageUrl = '';
    if (post.image_url != null && post.image_url!.isNotEmpty) {
      imageUrl = AppConstant.ImageUrl + path + post.image;
    } else if (post.image.isNotEmpty) {
      imageUrl = AppConstant.ImageUrl + path + post.image;
    }

    // Determine display name and artist name based on content type
    String displayName;
    String artistName;

    if (apiType == "Featured Playlists") {
      displayName = post.playlist_name.isNotEmpty
          ? post.playlist_name
          : post.name;
      if (post.artists != null && post.artists!.isNotEmpty) {
        if (post.artists!.length == 1) {
          artistName =
              post.artists!.first.artist_name ?? post.artists!.first.name;
        } else if (post.artists!.length == 2) {
          final a1 = post.artists!.first;
          final a2 = post.artists![1];
          artistName =
              "${a1.artist_name ?? a1.name} & ${a2.artist_name ?? a2.name}";
        } else {
          final a1 = post.artists!.first;
          artistName =
              "${a1.artist_name ?? a1.name} & ${post.artists!.length - 1} others";
        }
      } else {
        artistName = "";
      }
    } else if (apiType.contains("Songs")) {
      displayName = post.name;
      if (post.artists != null && post.artists!.isNotEmpty) {
        if (post.artists!.length == 1) {
          artistName =
              post.artists!.first.artist_name ?? post.artists!.first.name;
        } else if (post.artists!.length == 2) {
          final a1 = post.artists!.first;
          final a2 = post.artists![1];
          artistName =
              "${a1.artist_name ?? a1.name} & ${a2.artist_name ?? a2.name}";
        } else {
          final a1 = post.artists!.first;
          artistName =
              "${a1.artist_name ?? a1.name} & ${post.artists!.length - 1} others";
        }
      } else {
        artistName = "Unknown Artist";
      }
    } else if (apiType.contains("Artists")) {
      displayName = post.name;
      artistName = "";
    } else if (apiType.contains("Albums")) {
      displayName = post.name;
      if (post.artists != null && post.artists!.isNotEmpty) {
        artistName =
            post.artists!.first.artist_name ?? post.artists!.first.name;
      } else {
        artistName = "";
      }
    } else if (apiType.contains("Genres")) {
      displayName = post.name;
      artistName = "";
    } else {
      displayName = post.name;
      artistName = apiType
          .replaceAll("Trending ", "")
          .replaceAll("Featured ", "");
    }

    if (kDebugMode) {
      print(
        "Media Card - Type: $apiType, Image URL: $imageUrl, Title: $displayName, Subtitle: $artistName",
      );
      if (post.artists != null && post.artists!.isNotEmpty) {
        print("Artists: ${post.artists!.map((a) => a.name).join(', ')}");
      }
    }

    // Determine if this item is the currently playing one
    final musicManager = MusicManager();
    final currentItem = musicManager.getCurrentMediaItem();
    final currentAudioId = currentItem?.extras?['audio_id']?.toString();
    final thisAudioId = post.id.toString();
    final isCurrentItem =
        currentAudioId != null && currentAudioId == thisAudioId;
    final isPlayingNow = isCurrentItem && musicManager.isPlaying;

    // Animate image and text on view change
    // Show dot only if is_trending == 1 (for songs only)
    final bool showDot = apiType.contains("Songs") && (post.is_trending == 1);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: _isGridView
          ? MediaGridCard(
              key: ValueKey('grid_${post.id}'),
              imagePath: imageUrl,
              songTitle: displayName,
              artistName: artistName,
              // Pass content-type flag so MediaGridCard can adjust layout for songs
              isSong: apiType.contains("Songs"),
              onTap: () => _handleItemNavigation(post),
              sharedPreThemeData: sharedPreThemeData,
              musicManager: musicManager,
              songId: post.id.toString(), // Pass songId instead of isFavorite
              isCurrent: isCurrentItem,
              isPlaying: isPlayingNow,
              onPlay: apiType.contains("Songs")
                  ? () => _musicActionHandler.handlePlaySong(
                      post.id.toString(),
                      displayName,
                    )
                  : null,
              onPlayNext: apiType.contains("Songs")
                  ? () => _musicActionHandler.handlePlayNext(
                      post.id.toString(),
                      displayName,
                      artistName,
                      imagePath: imageUrl,
                    )
                  : null,
              onAddToQueue: apiType.contains("Songs")
                  ? () => _musicActionHandler.handleAddToQueue(
                      post.id.toString(),
                      displayName,
                      artistName,
                      imagePath: imageUrl,
                    )
                  : null,
              onDownload: apiType.contains("Songs")
                  ? () => _musicActionHandler.handleDownload(
                      displayName,
                      "song",
                      post.id.toString(),
                    )
                  : null,
              onAddToPlaylist: apiType.contains("Songs")
                  ? () => _musicActionHandler.handleAddToPlaylist(
                      post.id.toString(),
                      displayName,
                      artistName,
                    )
                  : null,
              onShare:
                  (apiType.contains("Songs") ||
                      apiType.contains("Albums") ||
                      apiType.contains("Playlists"))
                  ? () => _musicActionHandler.handleShare(
                      displayName,
                      apiType.contains("Songs")
                          ? "song"
                          : apiType.contains("Albums")
                          ? "album"
                          : "playlist",
                      itemId: post.id.toString(),
                      slug: post.slug,
                    )
                  : null,
              onFavorite: apiType.contains("Songs")
                  ? () => _musicActionHandler.handleFavoriteToggle(
                      post.id.toString(),
                      displayName,
                      favoriteIds: _favoriteIds,
                    )
                  : null,
              // Only enable the visualizer for song types
              showVisualizer: apiType.contains("Songs"),
            )
          : MediaListCard(
              key: ValueKey('list_${post.id}'),
              songId: post.id
                  .toString(), // Pass songId for global favorites management
              imagePath: imageUrl,
              songTitle: displayName,
              artistName: artistName,
              onTap: () => _handleItemNavigation(post),
              sharedPreThemeData: sharedPreThemeData,
              musicManager: musicManager,
              // Remove static isFavorite - let MediaListCard use global provider
              isCurrent: isCurrentItem,
              isPlaying: isPlayingNow,
              onPlay: apiType.contains("Songs")
                  ? () => _musicActionHandler.handlePlaySong(
                      post.id.toString(),
                      displayName,
                    )
                  : null,
              onPlayNext: apiType.contains("Songs")
                  ? () => _musicActionHandler.handlePlayNext(
                      post.id.toString(),
                      displayName,
                      artistName,
                      imagePath: imageUrl,
                    )
                  : null,
              onAddToQueue: apiType.contains("Songs")
                  ? () => _musicActionHandler.handleAddToQueue(
                      post.id.toString(),
                      displayName,
                      artistName,
                      imagePath: imageUrl,
                    )
                  : null,
              onDownload: apiType.contains("Songs")
                  ? () => _musicActionHandler.handleDownload(
                      displayName,
                      "song",
                      post.id.toString(),
                    )
                  : null,
              onAddToPlaylist: apiType.contains("Songs")
                  ? () => _musicActionHandler.handleAddToPlaylist(
                      post.id.toString(),
                      displayName,
                      artistName,
                    )
                  : null,
              onShare:
                  (apiType.contains("Songs") ||
                      apiType.contains("Albums") ||
                      apiType.contains("Playlists"))
                  ? () => _musicActionHandler.handleShare(
                      displayName,
                      apiType.contains("Songs")
                          ? "song"
                          : apiType.contains("Albums")
                          ? "album"
                          : "playlist",
                      itemId: post.id.toString(),
                      slug: post.slug,
                    )
                  : null,
              onFavorite: apiType.contains("Songs")
                  ? () => _musicActionHandler.handleFavoriteToggle(
                      post.id.toString(),
                      displayName,
                      favoriteIds: _favoriteIds,
                    )
                  : null,
              showDot: showDot,
              // Only enable the visualizer for song types
              showVisualizer: apiType.contains("Songs"),
            ),
    );
  }

  Widget _buildLoadingWidget() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 360.w,
      width: double.infinity,
      child: Center(child: CircleLoader(size: 280.w, showLogo: true)),
    );
  }

  Widget _buildPaginationLoading() {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingL),
      child: Center(
        child: CircularProgressIndicator(
          color: appColors().primaryColorApp,
          strokeWidth: 2.0,
        ),
      ),
    );
  }

  Widget _buildPaginationError() {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingL),
      child: Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _error = false;
              fetchData(paginate: true);
            });
          },
          icon: Icon(
            Icons.refresh,
            color: appColors().primaryColorApp,
            size: AppSizes.iconSize,
          ),
          label: Text(
            'Load More',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: AppSizes.fontNormal,
              color: appColors().primaryColorApp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: MediaQuery.of(context).size.height - 250.w,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Consistent error illustration
          Container(
            height: 200.w,
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: Image.asset(
              'assets/images/placeholder.png',
              fit: BoxFit.contain,
            ),
          ),

          SizedBox(height: AppSizes.paddingL),

          // Error title
          Text(
            'Something went wrong',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: AppSizes.fontLarge,
              color: appColors().colorTextHead,
            ),
          ),

          SizedBox(height: AppSizes.paddingS),

          // Error description
          Text(
            'Unable to load $_typ. Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
              fontSize: AppSizes.fontNormal,
              color: appColors().colorText,
              height: 1.4,
            ),
          ),

          SizedBox(height: AppSizes.paddingL),

          // Consistent retry button
          _buildRetryButton(),
        ],
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return Container(
      height: MediaQuery.of(context).size.height - 250.w,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Consistent no data illustration
          Container(
            height: 200.w,
            margin: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: Image.asset(
              'assets/images/song_placeholder.png',
              fit: BoxFit.contain,
            ),
          ),

          SizedBox(height: AppSizes.paddingL),

          // No data title
          Text(
            'No $_typ found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: AppSizes.fontLarge,
              fontWeight: FontWeight.w700,
              color: appColors().colorTextHead,
            ),
          ),

          SizedBox(height: AppSizes.paddingS),

          // No data description
          Text(
            'Try refreshing or check back later for new content.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: AppSizes.fontNormal,
              fontWeight: FontWeight.w400,
              color: appColors().colorText,
              height: 1.4,
            ),
          ),

          SizedBox(height: AppSizes.paddingL),

          // Consistent refresh button
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _loading = true;
            _error = false;
            fetchData();
          });
        },
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                appColors().primaryColorApp,
                appColors().primaryColorApp,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            boxShadow: [
              BoxShadow(
                color: appColors().primaryColorApp.withOpacity(0.3),
                blurRadius: 12.0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: AppSizes.iconSize,
              ),
              SizedBox(width: AppSizes.paddingS),
              Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: AppSizes.fontNormal,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pullRefresh,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: appColors().primaryColorApp, width: 1.5),
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                color: appColors().primaryColorApp,
                size: AppSizes.iconSize,
              ),
              SizedBox(width: AppSizes.paddingS),
              Text(
                'Refresh',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: AppSizes.fontNormal,
                  color: appColors().primaryColorApp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final currentPosition = _scrollController.position.pixels;
    final scrollDelta = currentPosition - _lastScrollPosition;
    final isAtTop = currentPosition <= _topScrollThreshold;

    if (isAtTop || scrollDelta < -_headerAnimationThreshold) {
      // Always show header when at top or scrolling up
      if (!_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    } else if (scrollDelta > _headerAnimationThreshold) {
      // Only hide header when scrolling down past threshold and not at top
      if (_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = false;
        });
      }
    }

    _lastScrollPosition = currentPosition;

    // Trigger pagination near the bottom
    final maxExtent = _scrollController.position.maxScrollExtent;
    final nearBottom =
        currentPosition >= (maxExtent - _paginationTriggerOffset);
    if (!_loading && !_isPaginating && !_isLastPage && !_error && nearBottom) {
      fetchData(paginate: true);
    }
  }

  void _onSearchChanged(String next) {
    if (!mounted) return;
    _searchText = next;
    final searching = _searchText.trim().isNotEmpty;
    if (searching != _isSearching) {
      _isSearching = searching;
    }
    // Bump request id so any in-flight requests are considered stale
    _searchRequestId++;
    // Reset pagination and fetch from page 1 for both modes
    _pageNumber = 1;
    _posts = [];
    _isLastPage = false;
    _loading = true;
    _error = false;
    noData = false;
    _isFetchingFirstPage = false;
    _seenIds.clear();
    setState(() {});
    fetchData();
  }

  void _handleItemNavigation(SubData post) async {
    final apiType = _getApiType(_typ);

    if (kDebugMode) {
      print("Navigating: $_typ -> $apiType for item: ${post.name}");
      print(
        "Post details - ID: ${post.id}, playlist_name: ${post.playlist_name}, name: ${post.name}",
      );
    }

    // For types that require using MusicList (has subcategories)
    if (apiType.contains("Albums") ||
        apiType.contains("Genres") ||
        apiType == "Featured Playlists") {
      final playlistName =
          apiType == "Featured Playlists" && post.playlist_name.isNotEmpty
          ? post.playlist_name
          : post.name;

      if (kDebugMode) {
        print(
          "Navigating to category list: ID=${post.id}, Type=$apiType, Name=$playlistName",
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MusicList(_audioHandler, "${post.id}", apiType, playlistName),
        ),
      ).then((value) {
        debugPrint(value);
        _reload();
      });
    } else if (apiType.contains("Artists")) {
      final artistId = post.id;
      final artistName = post.name;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArtistDetailScreen(
            audioHandler: _audioHandler,
            idTag: artistId.toString(),
            typ: 'Artists',
            catName: artistName,
          ),
          settings: const RouteSettings(name: '/track_info_to_artist_songs'),
        ),
      ).then((value) {
        debugPrint(value);
        _reload();
      });
    } else {
      // For direct playback items (songs), use mini player
      if (kDebugMode) {
        print("🎵🎵🎵 ALLCATEGORYBYNAME STARTING SONG IN MINI PLAYER 🎵🎵🎵");
        print("🎵 Type: $apiType, ID: ${post.id}, Name: ${post.name}");
      }

      try {
        print('[DEBUG] Loading content for ID: ${post.id}, Type: $apiType');

        // Get the songs for this category
        final response = await CatSubcatMusicPresenter().getMusicListByCategory(
          "${post.id}",
          apiType,
          token,
        );

        if (response.data.isNotEmpty) {
          print(
            '[DEBUG] Successfully loaded ${response.data.length} songs for $apiType: ${post.name}',
          );

          // Debug: Print first song data to see what we received
          if (response.data.isNotEmpty) {
            final firstSong = response.data[0];
            print(
              '[DEBUG] First song data: id=${firstSong.id}, audio_title="${firstSong.audio_title}", audio_slug="${firstSong.audio_slug}", artists_name="${firstSong.artists_name}"',
            );
          }

          // Use music manager for queue replacement
          final musicManager = MusicManager();

          await musicManager.replaceQueue(
            musicList: response.data,
            startIndex: 0, // Start from the first song
            pathImage: response.imagePath,
            audioPath: response.audioPath,
            callSource: 'AllCategoryByName.playContent',
            contextType: apiType,
            contextId: "${post.id}",
          );

          // Show mini player
          final stateManager = MusicPlayerStateManager();
          stateManager.showMiniPlayerForMusicStart();

          print('[DEBUG] Music playback started via mini player');
        } else {
          print('[ERROR] No content found for this $apiType');

          // Fallback to traditional navigation if no content
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Music(
                _audioHandler,
                "${post.id}",
                apiType,
                const [],
                "",
                0,
                false,
                '',
              ),
            ),
          ).then((value) {
            debugPrint(value);
            _reload();
          });
        }
      } catch (e) {
        print('[ERROR] Failed to load and play content: $e');

        // Fallback to traditional navigation on error
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Music(
              _audioHandler,
              "${post.id}",
              apiType,
              const [],
              "",
              0,
              false,
              '',
            ),
          ),
        ).then((value) {
          debugPrint(value);
          _reload();
        });
      }
    }
  }

  /// Load user's favorite songs from the API to track state
  Future<void> _loadFavorites() async {
    if (_favoritesLoaded) return;

    try {
      final token = await sharePrefs.getToken();
      if (token.isEmpty) return;

      print('💖 Loading favorites for AllCategoryByName state management...');

      // Use the FavMusicPresenter to get favorites list
      final favPresenter = FavMusicPresenter();
      final favList = await favPresenter.getFavMusicList(token);

      // Extract favorite IDs from the response
      _favoriteIds.clear();
      for (final song in favList.data) {
        _favoriteIds.add(song.id.toString());
      }

      _favoritesLoaded = true;
      print('💖 Loaded ${_favoriteIds.length} favorites for AllCategoryByName');

      if (mounted) {
        setState(() {}); // Update UI with favorite states
      }
    } catch (e) {
      print('💖 Error loading favorites: $e');
      // Continue without favorites - not critical
    }
  }
}
