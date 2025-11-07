import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/Presenter/HistoryPresenter.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/hooks/favorites_hook.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/services/visualizer_music_integration.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/ConnectionCheck.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/widgets/common/app_header.dart';
import 'package:jainverse/widgets/common/music_context_menu.dart';
import 'package:jainverse/widgets/common/music_long_press_handler.dart';
import 'package:jainverse/widgets/common/search_bar.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;

import '../main.dart';
import 'MusicEntryPoint.dart';

// Dummy animation for ListView.builder compatibility
final alwaysCompleteAnimation = AlwaysStoppedAnimation<double>(1.0);

AudioPlayerHandler? _audioHandler;

String from = '';

class Favorite extends StatefulWidget {
  Favorite(String s, {super.key}) {
    from = s;
  }

  @override
  StateClass createState() {
    return StateClass();
  }
}

class StateClass extends State<Favorite> {
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  List<DataMusic> list = [];
  List<DataMusic> filteredList = []; // For search functionality
  String searchQuery = '';
  String pathImage = '', audioPath = '', token = '';
  bool showArrow = false, isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  // Modern scroll controller for header animations
  late ScrollController _scrollController;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  // AnimatedList key
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // Services for context menu actions
  late MusicActionHandler _musicActionHandler;
  final FavoriteService _favoriteService = FavoriteService();
  final Set<String> _favoriteIds = <String>{};

  // Consistent constants for design
  static const double _headerAnimationThreshold = 10.0;
  static const double _topScrollThreshold = 5.0;
  static const Duration _headerAnimationDuration = Duration(milliseconds: 300);
  static const Curve _headerAnimationCurve = Curves.easeInOut;

  Future<void> favAPI() async {
    ModelMusicList mList = await FavMusicPresenter().getFavMusicList(token);
    mList.data.length;
    pathImage = mList.imagePath;
    audioPath = mList.audioPath;
    list = mList.data;
    filteredList = List.from(list); // Initialize filtered list
    isLoading = false;

    // Update favorites after loading data
    _loadFavorites();

    // Rebuild AnimatedList safely
    if (_listKey.currentState != null) {
      try {
        _listKey.currentState!.setState(() {});
      } catch (_) {}
    }
    _safeSetState(() {});
  }

  Future<void> hisAPI() async {
    //
    String data = await HistoryPresenter().getHistory(token);
    final Map<String, dynamic> parsed = json.decode(data.toString());
    ModelMusicList mList = ModelMusicList.fromJson(parsed);
    mList.data.length;
    pathImage = mList.imagePath;
    audioPath = mList.audioPath;
    list = mList.data;
    filteredList = List.from(list); // Initialize filtered list
    isLoading = false;

    // Update favorites after loading data
    _loadFavorites();

    _safeSetState(() {});
  }

  Future<void> addRemoveAPI(String id, String tag) async {
    await FavMusicPresenter().getMusicAddRemove(id, token, tag);

    if (!from.contains('fav')) {
      showArrow = true;

      Future.delayed(const Duration(seconds: 3)).then((_) {
        _safeSetState(() {
          showArrow = false; //goes back to arrow Icon
        });
      });
    }
    if (from.contains('fav')) {
      favAPI();
    } else {
      hisAPI();
    }

    _safeSetState(() {});
  }

  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );

  // Safe setState wrapper to avoid calling setState after dispose
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _onRefresh() async {
    // monitor network fetch
    await Future.delayed(const Duration(milliseconds: 1000));
    if (from.contains('fav')) {
      await favAPI();
    } else {
      await hisAPI();
    }
    _safeSetState(() {});
    _refreshController.refreshCompleted();
  }

  Future<void> addRemoveHisAPI(String id) async {
    await HistoryPresenter().addHistory(id, token, 'remove');
    hisAPI();
  }

  Future<dynamic> value() async {
    token = await sharePrefs.getToken();
    model = await sharePrefs.getUserData();
    if (from.contains('fav')) {
      favAPI();
    } else {
      hisAPI();
    }
    sharedPreThemeData = await sharePrefs.getThemeData();
    _safeSetState(() {});
    return model;
  }

  @override
  void initState() {
    super.initState();
    _audioHandler = const MyApp().called();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    // Initialize the centralized music action handler
    _musicActionHandler = MusicActionHandlerFactory.create(
      context: context,
      audioHandler: _audioHandler,
      favoriteService: _favoriteService,
      onStateUpdate: () => _safeSetState(() {}),
    );

    // Load favorites for state management (non-blocking)
    _loadFavorites();

    checkConn();
    value();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll listener for header animation
  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final currentPosition = _scrollController.position.pixels;
    final scrollDelta = currentPosition - _lastScrollPosition;
    final isAtTop = currentPosition <= _topScrollThreshold;

    if (isAtTop) {
      if (!_isHeaderVisible) {
        _safeSetState(() {
          _isHeaderVisible = true;
        });
      }
    } else {
      if (scrollDelta > _headerAnimationThreshold && _isHeaderVisible) {
        // Scrolling down significantly - hide header
        _safeSetState(() {
          _isHeaderVisible = false;
        });
      } else if (scrollDelta < -_headerAnimationThreshold &&
          !_isHeaderVisible) {
        // Scrolling up significantly - show header
        _safeSetState(() {
          _isHeaderVisible = true;
        });
      }
    }

    _lastScrollPosition = currentPosition;
  }

  Future<void> checkConn() async {
    await ConnectionCheck().checkConnection();
    _safeSetState(() {});
  }

  // Load favorites for local state management
  Future<void> _loadFavorites() async {
    try {
      // Update favorite IDs from the current list
      _favoriteIds.clear();
      for (final song in list) {
        if (song.favourite == "1") {
          _favoriteIds.add(song.id.toString());
        }
      }
      _safeSetState(() {});
    } catch (e) {
      if (kDebugMode) {
        print('FavoriteOrHistory: Error loading favorites: $e');
      }
    }
  }

  // Compose full image URL safely, handling missing base/path segments.
  String _composeImageUrl(String imageName) {
    if (imageName.isEmpty) return '';
    // Ensure pathImage and AppConstant.ImageUrl are combined safely.
    final base = AppConstant.ImageUrl;
    String combined = '$base$pathImage$imageName';
    // Replace any double slashes (except after protocol) to avoid malformed URLs.
    combined = combined.replaceAll(RegExp(r'(?<!:)//+'), '/');
    return combined;
  }

  // Check if song is favorited using global provider
  bool _isSongFavorited(String songId, {FavoritesHook? favoritesHook}) {
    if (favoritesHook != null) {
      return favoritesHook.isFavorite(songId);
    }
    // Fallback to local state if global provider is not available
    return _favoriteIds.contains(songId);
  }

  // Title for the app bar based on the 'from' parameter
  String get pageTitle => from == 'fav' ? 'Favorites' : 'History';

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

    return FavoritesConsumer(
      builder: (context, favoritesHook, child) {
        return _buildMainContent(context, favoritesHook);
      },
    );
  }

  Widget _buildMainContent(BuildContext context, FavoritesHook favoritesHook) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: _buildContent(favoritesHook),
      ),
    );
  }

  Widget _buildContent(FavoritesHook favoritesHook) {
    return Stack(
      children: [
        // Background container - clean white
        Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          color: Colors.white,
        ),

        // Main scrollable content
        _buildMainScrollableContent(favoritesHook),

        // Animated header
        _buildAnimatedHeader(),
      ],
    );
  }

  Widget _buildAnimatedHeader() {
    return AnimatedSlide(
      offset: _isHeaderVisible ? Offset.zero : const Offset(0, -1),
      duration: _headerAnimationDuration,
      curve: _headerAnimationCurve,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          boxShadow:
              _scrollController.hasClients &&
                  _scrollController.offset > _topScrollThreshold
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8.0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            child: AppHeader(
              title: pageTitle,
              showBackButton: true,
              showProfileIcon: false,
              onBackPressed: () => Navigator.of(context).pop(),
              backgroundColor: Colors.transparent,
              scrollController: _scrollController,
              scrollAware: false,
              // trailingWidget: Container(
              //   decoration: BoxDecoration(
              //     color: appColors().gray[50],
              //     shape: BoxShape.circle,
              //   ),
              //   child: IconButton(
              //     icon: Icon(
              //       Icons.filter_list,
              //       color: appColors().primaryColorApp,
              //       size: AppSizes.iconSize,
              //     ),
              //     onPressed: () {}, // future feature
              //     constraints: BoxConstraints(minWidth: 46.w, minHeight: 46.w),
              //   ),
              // ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScrollableContent(FavoritesHook favoritesHook) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: appColors().primaryColorApp,
      backgroundColor: Colors.white,
      displacement: MediaQuery.of(context).padding.top + AppSizes.paddingL,
      child: StreamBuilder<MediaItem?>(
        stream: _audioHandler!.mediaItem,
        builder: (context, snapshot) {
          final hasMiniPlayer = snapshot.hasData;
          final bottomPadding = AppPadding.bottom(
            context,
            extra: hasMiniPlayer ? 90.w : 50.w,
          );

          return CustomScrollView(
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
                      60.w, // Adjust for new header design
                ),
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Main content
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.contentHorizontalPadding,
                  AppSizes.contentTopPadding,
                  AppSizes.contentHorizontalPadding,
                  bottomPadding,
                ),
                sliver: _buildContentSliver(favoritesHook),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContentSliver(FavoritesHook favoritesHook) {
    // Always show action buttons and search bar
    List<Widget> children = [];

    if (isLoading) {
      children.add(_buildLoadingWidget());
    } else if (filteredList.isEmpty) {
      children.add(_buildEmptyStateWidget());
    } else {
      children.add(_buildActionButtons());
      children.add(_buildSearchSection());
      // Use ListView.builder for search and list display to avoid index errors
      children.add(
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredList.length,
          itemBuilder: (context, i) {
            final song = filteredList[i];
            final originalIndex = list.indexOf(song);
            // Use a dummy animation for compatibility with _buildAnimatedMusicCard
            return _buildAnimatedMusicCard(
              song,
              originalIndex,
              i,
              alwaysCompleteAnimation,
              favoritesHook,
            );
          },
        ),
      );
    }

    return SliverList(delegate: SliverChildListDelegate(children));
  }

  Widget _buildLoadingWidget() {
    return SizedBox(
      height: 800.w,
      child: Center(
        child: CircularProgressIndicator(color: appColors().primaryColorApp),
      ),
    );
  }

  Widget _buildEmptyStateWidget() {
    return Container(
      height: 800.w,
      padding: EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 120.w,
            width: 120.w,
            padding: EdgeInsets.all(AppSizes.paddingL),
            decoration: BoxDecoration(
              color: appColors().primaryColorApp.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              searchQuery.isNotEmpty
                  ? Icons.search_off
                  : (from.contains('fav')
                        ? Icons.favorite_border
                        : Icons.history),
              size: 60.w,
              color: appColors().primaryColorApp.withOpacity(0.6),
            ),
          ),
          SizedBox(height: AppSizes.paddingL),
          Text(
            searchQuery.isNotEmpty
                ? 'No results found'
                : (from.contains('fav')
                      ? 'No favorites yet'
                      : 'No listening history'),
            style: TextStyle(
              fontSize: AppSizes.fontLarge,
              fontWeight: FontWeight.w600,
              color: appColors().colorTextHead,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : (from.contains('fav')
                      ? 'Start adding songs to your favorites\nand they\'ll appear here'
                      : 'Songs you\'ve played will\nappear in your history'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSizes.fontMedium,
              color: appColors().colorText,
              fontFamily: 'Poppins',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Action buttons (Play and Shuffle)
  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingS),
      margin: EdgeInsets.only(
        top: AppSizes.paddingM,
        bottom: AppSizes.paddingM,
      ),
      child: Row(
        children: [
          // Play button
          Expanded(
            child: _buildActionButton(
              icon: Icons.play_arrow,
              label: 'Play',
              onTap: () => _playAllSongs(shuffle: false),
              color: appColors().primaryColorApp,
            ),
          ),
          SizedBox(width: AppSizes.paddingM),
          // Shuffle button
          Expanded(
            child: _buildActionButton(
              icon: Icons.shuffle,
              label: 'Shuffle',
              onTap: () => _playAllSongs(shuffle: true),
              color: appColors().primaryColorApp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return SizedBox(
      height: 65.h,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 22.sp),
        label: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            fontFamily: 'Poppins',
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: appColors().primaryColorApp.withOpacity(0.3),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r), // pill shape
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          alignment: Alignment.center,
        ),
      ),
    );
  }

  // Search section using AnimatedSearchBar for consistent AllCategory design
  Widget _buildSearchSection() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 0,
      ).copyWith(bottom: AppSizes.paddingXS),
      child: CommonSearchBar(
        controller: _searchController,
        hintText: from.contains('fav') ? 'Search Favorites' : 'Search History',
        onChanged: (value) => _performSearch(value),
        onClear: () {
          _searchController.clear();
          _performSearch('');
        },
      ),
    );
  }

  void _performSearch(String query) {
    _safeSetState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredList = List.from(list);
      } else {
        filteredList = list.where((song) {
          return song.audio_title.toLowerCase().contains(query.toLowerCase()) ||
              song.artists_name.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
      // Keep the controller in sync if cleared externally
      if (_searchController.text != query) {
        _searchController.text = query;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
      }
    });
  }

  void _playAllSongs({required bool shuffle}) async {
    if (filteredList.isEmpty) return;

    try {
      final musicManager = MusicManager();
      final startIndex = shuffle ? (filteredList.length * 0.5).floor() : 0;

      await musicManager.replaceQueue(
        musicList: filteredList, // Use filtered list for search results
        startIndex: startIndex,
        pathImage: pathImage,
        audioPath: audioPath,
        callSource: 'FavoriteOrHistory._playAllSongs',
      );

      // Show mini player
      final stateManager = MusicPlayerStateManager();
      stateManager.showMiniPlayerForMusicStart();

      if (kDebugMode) {
        print(
          '🎯 FavoriteOrHistory: ${shuffle ? 'Shuffle' : 'Play'} all completed',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔥 FavoriteOrHistory: Play all failed: $e');
      }
    }
  }

  // Create menu data for context menu and long press
  MusicContextMenuData _createMenuData(
    DataMusic song,
    int index,
    FavoritesHook favoritesHook,
  ) {
    String imageUrl = '';
    if (song.image.isNotEmpty) {
      imageUrl = _composeImageUrl(song.image);
    }

    return MusicMenuDataFactory.createSongMenuData(
      title: song.audio_title,
      artist: song.artists_name.isNotEmpty
          ? song.artists_name
          : 'Unknown Artist',
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      onPlay: () => _handleSongTap(index),
      onPlayNext: () => _musicActionHandler.handlePlayNext(
        song.id.toString(),
        song.audio_title,
        song.artists_name,
        imagePath: imageUrl.isNotEmpty ? imageUrl : null,
        audioPath: audioPath,
      ),
      onAddToQueue: () => _musicActionHandler.handleAddToQueue(
        song.id.toString(),
        song.audio_title,
        song.artists_name,
        imagePath: imageUrl.isNotEmpty ? imageUrl : null,
        audioPath: audioPath,
      ),
      onDownload: () => _musicActionHandler.handleDownload(
        song.audio_title,
        "song",
        song.id.toString(),
        imagePath: imageUrl.isNotEmpty ? imageUrl : null,
        audioPath: audioPath,
      ),
      onAddToPlaylist: () => _musicActionHandler.handleAddToPlaylist(
        song.id.toString(),
        song.audio_title,
        song.artists_name,
        imagePath: imageUrl.isNotEmpty ? imageUrl : null,
      ),
      onShare: () => _musicActionHandler.handleShare(
        song.audio_title,
        "song",
        itemId: song.id.toString(),
        slug: song.audio_slug,
      ),
      onFavorite: () => _musicActionHandler.handleFavoriteToggle(
        song.id.toString(),
        song.audio_title,
        favoriteIds: _favoriteIds,
      ),
      isFavorite: _isSongFavorited(
        song.id.toString(),
        favoritesHook: favoritesHook,
      ),
    );
  }

  Widget _buildAnimatedMusicCard(
    DataMusic song,
    int index,
    int filteredIndex,
    Animation<double> animation,
    FavoritesHook favoritesHook,
  ) {
    // Animate removal with fade and slide
    return SizeTransition(
      sizeFactor: animation,
      axis: Axis.vertical,
      child: FadeTransition(
        opacity: animation,
        child: MusicCardWrapper(
          menuData: _createMenuData(song, index, favoritesHook),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            height: 72.h,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleSongTap(index),
                borderRadius: BorderRadius.circular(0),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Album Art with visualizer overlay when current
                      Builder(
                        builder: (context) {
                          final musicManager = MusicManager();
                          final currentItem = musicManager
                              .getCurrentMediaItem();
                          final currentAudioId = currentItem
                              ?.extras?['audio_id']
                              ?.toString();
                          final isCurrentItem =
                              currentAudioId == song.id.toString();

                          if (song.image.isEmpty) {
                            return Container(
                              width: 56.w,
                              height: 56.w,
                              decoration: BoxDecoration(
                                color: appColors().gray[100],
                                borderRadius: BorderRadius.circular(8.w),
                              ),
                              child: Icon(
                                Icons.music_note,
                                color: appColors().gray[300],
                                size: 24.w,
                              ),
                            );
                          }

                          final imageUrl = _composeImageUrl(song.image);

                          return SizedBox(
                            width: 56.w,
                            height: 56.w,
                            child: SmartAlbumArtWithVisualizer(
                              image: imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : const AssetImage(
                                          'assets/images/default_art.png',
                                        )
                                        as ImageProvider,
                              isCurrent: isCurrentItem,
                              musicManager: musicManager,
                              size: 56.w,
                              color: Colors.white.withOpacity(0.92),
                            ),
                          );
                        },
                      ),

                      SizedBox(width: 16.w),

                      // Song Info - Expanded to take available space
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.audio_title,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF212121),
                                fontFamily: 'Poppins',
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              song.artists_name.isNotEmpty
                                  ? song.artists_name
                                  : 'Unknown Artist',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF666666),
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 16.w),

                      // Action button: heart for Favorites screen, delete for History screen
                      from.contains('fav')
                          ? GestureDetector(
                              onTap: () => _toggleFavorite(song, filteredIndex),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  song.favourite == "1"
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  key: ValueKey(song.favourite),
                                  color: song.favourite == "1"
                                      ? appColors().primaryColorApp
                                      : const Color(0xFF666666),
                                  size: 24.w,
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: () async {
                                // Remove this song from history
                                await addRemoveHisAPI(song.id.toString());
                                // Optionally show a brief UI update: refresh handled by addRemoveHisAPI
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  Icons.delete_outline,
                                  key: ValueKey('delete_${song.id}'),
                                  color: appColors().primaryColorApp,
                                  size: 24.w,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleFavorite(DataMusic song, int filteredIndex) async {
    try {
      // Use the music action handler for consistent favorite handling
      await _musicActionHandler.handleFavoriteToggle(
        song.id.toString(),
        song.audio_title,
        favoriteIds: _favoriteIds,
      );

      // Update local song state
      song.favourite = song.favourite == "1" ? "0" : "1";

      // If unfavoriting from favorites screen, animate removal
      if (song.favourite == "0" && from.contains('fav')) {
        // Remove from filteredList and AnimatedList
        final removedSong = filteredList.removeAt(filteredIndex);
        _listKey.currentState?.removeItem(
          filteredIndex,
          (context, animation) => _buildAnimatedMusicCard(
            removedSong,
            list.indexOf(removedSong),
            filteredIndex,
            animation,
            context.favorites, // Use the context extension to get favoritesHook
          ),
          duration: const Duration(milliseconds: 400),
        );
        // Remove from main list as well
        list.removeWhere((s) => s.id == removedSong.id);
      }

      // Refresh favorites and trigger UI update
      _loadFavorites();
      _safeSetState(() {});
    } catch (e) {
      if (kDebugMode) {
        print('Error toggling favorite: $e');
      }
    }
  }

  void _handleSongTap(int index) async {
    if (kDebugMode) {
      print(
        '🔥 FavoriteOrHistory: Tapped song at index $index: ${list[index].audio_title}',
      );
    }

    try {
      // OPTIMIZED: For immediate playback, check if we can skip directly to the song
      final currentQueue = _audioHandler?.queue.value ?? [];
      final targetSong = list[index];

      // Find if the song is already in the current queue
      int existingIndex = -1;
      for (int i = 0; i < currentQueue.length; i++) {
        // Check by audio_id in extras or by title match
        final queueSong = currentQueue[i];
        final queueAudioId = queueSong.extras?['audio_id']?.toString();
        if (queueAudioId == targetSong.id.toString() ||
            queueSong.title == targetSong.audio_title) {
          existingIndex = i;
          break;
        }
      }

      if (existingIndex != -1 && _audioHandler != null) {
        // FAST PATH: Song is already in queue, just skip to it
        if (kDebugMode) {
          print(
            '🚀 FavoriteOrHistory: Fast skip to existing song at index $existingIndex',
          );
        }

        await _audioHandler!.skipToQueueItem(existingIndex);
        await _audioHandler!.play();

        if (kDebugMode) {
          print('🚀 FavoriteOrHistory: Fast playback started');
        }

        // Show mini player instead of navigating to full player
        final stateManager = MusicPlayerStateManager();
        stateManager.showMiniPlayerForMusicStart();

        return; // Early return to prevent further processing
      }

      // SMART FALLBACK: Check if current queue is already from favorites/history
      bool isCurrentQueueFromFavHistory = false;
      if (currentQueue.isNotEmpty && list.isNotEmpty) {
        // Check if at least 50% of songs match between current queue and favorites/history list
        int matchCount = 0;
        for (final queueItem in currentQueue) {
          final queueAudioId = queueItem.extras?['audio_id']?.toString();
          if (queueAudioId != null) {
            final matchExists = list.any(
              (favSong) => favSong.id.toString() == queueAudioId,
            );
            if (matchExists) matchCount++;
          }
        }
        isCurrentQueueFromFavHistory =
            (matchCount / currentQueue.length) >= 0.5;
      }

      if (isCurrentQueueFromFavHistory && _audioHandler != null) {
        // MEDIUM PATH: Current queue is already favorites/history, add single song and skip
        if (kDebugMode) {
          print(
            '🎯 FavoriteOrHistory: Adding single song to existing fav/history queue',
          );
        }

        // Create MediaItem for the target song
        Duration duration = Duration.zero;
        try {
          final durationStr = targetSong.audio_duration.trim();
          final parts = durationStr.split(':');
          if (parts.length >= 2) {
            final minutes = int.parse(parts[0]);
            final seconds = int.parse(parts[1]);
            duration = Duration(minutes: minutes, seconds: seconds);
          }
        } catch (e) {
          // Use default duration if parsing fails
          duration = Duration.zero;
        }

        final mediaItem = MediaItem(
          id: '${targetSong.audio}?fav_history=${DateTime.now().millisecondsSinceEpoch}',
          title: targetSong.audio_title,
          artist: targetSong.artists_name,
          duration: duration,
          artUri: (targetSong.image.isNotEmpty)
              ? Uri.parse(_composeImageUrl(targetSong.image))
              : null,
          extras: {
            'audio_id': targetSong.id.toString(),
            'actual_audio_url': targetSong.audio,
            'favourite': targetSong.favourite,
            'artist_id': targetSong.artist_id, // Add artist_id for navigation
          },
        );

        await _audioHandler!.addQueueItem(mediaItem);
        // Skip to the newly added song (it will be at the end)
        final newQueue = _audioHandler!.queue.value;
        if (newQueue.isNotEmpty) {
          await _audioHandler!.skipToQueueItem(newQueue.length - 1);
          await _audioHandler!.play();
        }

        // Show mini player instead of navigating to full player
        final stateManager = MusicPlayerStateManager();
        stateManager.showMiniPlayerForMusicStart();

        return; // Early return to prevent further processing
      }

      // FALLBACK: Song not in queue, use queue replacement
      if (kDebugMode) {
        print('🔄 FavoriteOrHistory: Using queue replacement');
      }

      final musicManager = MusicManager();
      await musicManager.replaceQueue(
        musicList: list,
        startIndex: index,
        pathImage: pathImage,
        audioPath: audioPath,
        callSource: 'FavoriteOrHistory.onSongTap',
      );

      if (kDebugMode) {
        print(
          '🎯 FavoriteOrHistory: Queue replacement completed, showing mini player',
        );
      }

      // Show mini player instead of navigating to full player
      final stateManager = MusicPlayerStateManager();
      stateManager.showMiniPlayerForMusicStart();
    } catch (e) {
      if (kDebugMode) {
        print(
          '🔥 FavoriteOrHistory: Error replacing queue and playing music: $e',
        );
      }
      // Fallback to old method if queue replacement fails
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Music(
              _audioHandler,
              "favorite_error", // idGet (source identifier)
              "error_fallback", // typeGet (path type)
              list, // listMain
              audioPath, // audioPath
              index, // index
              false, // isOpn - regular behavior
              () {
                // ontap callback for navigation
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      }
    }
  }
}
