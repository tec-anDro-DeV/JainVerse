import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Presenter/CatSubCatMusicPresenter.dart';
import 'package:jainverse/Presenter/PlaylistMusicPresenter.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/visualizer_music_integration.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/widgets/playlist/playlist_service.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../Presenter/HistoryPresenter.dart';
// TODO: Add other services when needed
// import '../services/download_manager.dart';
// import '../services/asset_manager.dart';
import '../main.dart';
import '../providers/favorites_provider.dart';
import '../services/favorite_service.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/expandable_description.dart';
import '../widgets/common/loader.dart';
import '../widgets/common/music_context_menu.dart';
import '../widgets/common/music_long_press_handler.dart';
import 'AllCategoryByName.dart';

class MusicList extends StatefulWidget {
  final AudioPlayerHandler? audioHandler;
  final String mID;
  final String type;
  final String catName;

  const MusicList(
    this.audioHandler,
    this.mID,
    this.type,
    this.catName, {
    super.key,
  });

  @override
  State<StatefulWidget> createState() {
    return StateClass();
  }
}

class StateClass extends State<MusicList> {
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  late String catName;
  late String idTag;
  late String typ;
  String? _currentPlaylistId; // non-null when opened from PlaylistScreen
  AudioPlayerHandler? _audioHandler;
  List<DataMusic> list = [];
  String pathImage = '', audioPath = '';
  bool tillLoading = true;
  bool isOpen = false;
  String token = "";
  int indexNum = 0;
  SharedPref sharePrefs = SharedPref();

  late String pageTitle;
  String? _fallbackImageUrl; // Store a single fallback cover image URL
  ParentData? parentData; // Add parent data

  // Modern scroll controller for header animations
  late ScrollController _scrollController;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;

  // Theme data for media cards
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');

  // Add favorite service instance
  final FavoriteService _favoriteService = FavoriteService();

  // Add favorite state management
  final Set<String> _favoriteIds = <String>{};

  // Consistent constants for design
  static const double _headerAnimationThreshold = 10.0;
  static const double _topScrollThreshold = 5.0;
  static const Duration _headerAnimationDuration = Duration(milliseconds: 300);
  static const Curve _headerAnimationCurve = Curves.easeInOut;

  // Overlay entry for message management
  OverlayEntry? _currentOverlayEntry;

  // Centralized music action handler
  late MusicActionHandler _musicActionHandler;

  // Temporarily track the pending audio ID to avoid flash before stream update
  String? _pendingAudioId;

  /// Load favorites for state management
  Future<void> _loadFavorites() async {
    try {
      // For now, we'll extract favorite IDs from the song list itself
      // since DataMusic has a 'favourite' field
      if (mounted) {
        setState(() {
          _favoriteIds.clear();
          for (final song in list) {
            if (song.favourite == "1") {
              _favoriteIds.add(song.id.toString());
            }
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading favorites: $e');
      }
    }
  }

  // TODO: Add DownloadManager and AssetManager usage in future iterations

  Future<void> getCate() async {
    token = await sharePrefs.getToken();
    sharedPreThemeData = await sharePrefs.getThemeData();
    ModelMusicList mList = await CatSubcatMusicPresenter()
        .getMusicListByCategory(idTag, typ, token);
    list = mList.data;
    pathImage = mList.imagePath;
    audioPath = mList.audioPath;
    parentData = mList.parent; // Store parent data
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[MusicList] getCate - fetched ${list.length} songs, pathImage=$pathImage, audioPath=$audioPath, parent=${parentData?.toString()}',
      );
    }
    // Initialize a single fallback image URL if not set
    if (_fallbackImageUrl == null) {
      final songsWithImages = list
          .where((song) => song.image.isNotEmpty)
          .toList();
      if (songsWithImages.isNotEmpty) {
        final randomSong =
            songsWithImages[math.Random().nextInt(songsWithImages.length)];
        _fallbackImageUrl =
            '${AppConstant.ImageUrl}images/audio/thumb/${randomSong.image}';
      }
    }
    tillLoading = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> addRemoveHisAPI(String id) async {
    await HistoryPresenter().addHistory(id, token, 'add');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> addToQueue(var item) async {
    String s = item.audio_duration.trim();

    // Remove any newline characters from the duration string
    s = s.replaceAll('\n', '').trim();

    Duration duration;
    try {
      List idx = s.split(':');

      if (idx.length == 3) {
        duration = Duration(
          hours: int.parse(idx[0]),
          minutes: int.parse(idx[1]),
          seconds: int.parse(double.parse(idx[2]).round().toString()),
        );
      } else {
        duration = Duration(
          minutes: int.parse(idx[0]),
          seconds: int.parse(idx[1]),
        );
      }
    } catch (e) {
      // Fallback to a default duration if parsing fails
      if (kDebugMode) {
        print('Error parsing duration "${item.audio_duration}": $e');
      }
      duration = const Duration(minutes: 3); // Default to 3 minutes
    }

    String imageUrl = '${AppConstant.ImageUrl}images/audio/thumb/${item.image}';
    // Create unique MediaItem ID for queue addition to ensure proper queue management
    final uniqueId =
        '${item.audio}?addQueue=musicList&ts=${DateTime.now().millisecondsSinceEpoch}';

    var mItem = MediaItem(
      id: uniqueId, // Use unique ID for proper queue management
      title: item.audio_title,
      artist: item.artists_name,
      duration: duration,
      artUri: Uri.parse(imageUrl),
      extras: {
        'audio_id': item.id.toString(),
        'actual_audio_url':
            item.audio, // Store the actual audio URL for playback
        'lyrics': item.lyrics,
        'favourite': item.favourite, // Include favorite status
        'artist_id': item.artist_id, // Add artist_id for navigation
      },
    );

    _audioHandler?.addQueueItem(mItem);

    if (_audioHandler == null) return;
    ValueStream<List<MediaItem>> mList = _audioHandler!.queue;
    int count = mList.value.length;

    if (count == 0) {
      // Handle empty queue case - this logic seems incorrect, commenting out
      // List<DataMusic>? listMain;
      // listMain![0] = item;
      // Music(_audioHandler, "", "", listMain, "fromBottom", 0, false, '');
      if (kDebugMode) {
        print('Queue is empty, consider starting playback');
      }
    }

    if (kDebugMode) {
      print('Queue length: $count');
      for (var queueItem in mList.value) {
        print('Queue Item: ${queueItem.title} - ${queueItem.artist}');
      }
    }

    // Clean up the playback state listener
    _setupPlaybackListener();
  }

  void _setupPlaybackListener() {
    if (_audioHandler == null) return;
    _playbackStateSubscription = _audioHandler!.playbackState.listen((
      playbackState,
    ) {
      ValueStream<List<MediaItem>> mList = _audioHandler!.queue;

      if (kDebugMode) {
        print('Playback state changed. Queue length: ${mList.value.length}');
      }

      final isPlaying = playbackState.playing;

      // Handle queue navigation when track completes
      if (playbackState.processingState == AudioProcessingState.completed) {
        if (mList.value.length > 1) {
          indexNum = (indexNum < mList.value.length - 1) ? indexNum + 1 : 0;
          _audioHandler!.skipToNext();
        }
      }

      if (kDebugMode) {
        print('Current index: $indexNum, Is playing: $isPlaying');
        print('Queue items: ${mList.value.map((item) => item.title).toList()}');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    catName = widget.catName;
    typ = widget.type;
    idTag = widget.mID;
    // If opened from PlaylistScreen, type is "User Playlist" and mID is playlist id
    if (typ == 'User Playlist') {
      _currentPlaylistId = idTag;
    }
    _audioHandler = widget.audioHandler ?? const MyApp().called();
    pageTitle = (catName.isNotEmpty) ? catName : typ;
    getCate();

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[MusicList] initState - received idTag=$idTag, typ=$typ, catName=$catName, pageTitle=$pageTitle',
      );
    }

    // Listen for mediaItem updates to clear pendingAudioId when matched
    _mediaItemSubscription = _audioHandler?.mediaItem.listen((mediaItem) {
      final id = mediaItem?.extras?['audio_id']?.toString();
      if (_pendingAudioId != null && id == _pendingAudioId) {
        if (mounted) {
          setState(() {
            _pendingAudioId = null;
          });
        }
      }
    });

    // Initialize the centralized music action handler
    _musicActionHandler = MusicActionHandlerFactory.create(
      context: context,
      audioHandler: _audioHandler,
      favoriteService: _favoriteService,
      onStateUpdate: () => setState(() {}),
    );

    // Load favorites for state management (non-blocking)
    _loadFavorites();

    // Ensure navigation and mini player are visible when this page loads
    // This is important when navigating from the full music player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreNavigationState();
      }
    });
  }

  @override
  void dispose() {
    _mediaItemSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _scrollController.dispose();

    // Clean up overlay entry
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;

    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final currentPosition = _scrollController.position.pixels;
    final scrollDelta = currentPosition - _lastScrollPosition;
    final isAtTop = currentPosition <= _topScrollThreshold;

    if (isAtTop) {
      if (!_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    } else {
      if (scrollDelta > _headerAnimationThreshold && _isHeaderVisible) {
        setState(() {
          _isHeaderVisible = false;
        });
      } else if (scrollDelta < -_headerAnimationThreshold &&
          !_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    }

    _lastScrollPosition = currentPosition;
  }

  @override
  Widget build(BuildContext context) {
    // Consistent status bar styling
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarBrightness: Brightness.light),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        // Main scrollable content
        _buildMainScrollableContent(),

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
                    offset: const Offset(0, 0),
                  ),
                ]
              : null,
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            child: AppHeader(
              title: '',
              showBackButton: true,
              showProfileIcon: false,
              backgroundColor: Colors.transparent,
              scrollController: _scrollController,
              scrollAware: true,
              showGridToggle: false, // Remove grid toggle
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScrollableContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await getCate();
      },
      color: appColors().primaryColorApp,
      backgroundColor: Colors.white,
      displacement: MediaQuery.of(context).padding.top + AppSizes.paddingL,
      child: StreamBuilder<MediaItem?>(
        stream: _audioHandler?.mediaItem,
        builder: (context, snapshot) {
          final hasMiniPlayer = snapshot.hasData;
          final bottomPadding = hasMiniPlayer
              ? AppPadding.bottom(context, extra: 100.w)
              : AppPadding.bottom(context);

          return CustomScrollView(
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
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // Main content
              _buildContentSliver(),

              // Bottom padding for mini player
              SliverPadding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContentSliver() {
    if (tillLoading) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: CircleLoader(
              size: 250.w,
              showBackground: false,
              showLogo: true,
            ),
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_note_outlined,
                  size: 80.w,
                  color: appColors().gray[300],
                ),
                SizedBox(height: 16.w),
                Text(
                  'No music found',
                  style: TextStyle(
                    fontSize: AppSizes.fontLarge,
                    color: appColors().gray[500],
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.w),
                Text(
                  'Try refreshing or check back later',
                  style: TextStyle(
                    fontSize: AppSizes.fontNormal,
                    color: appColors().gray[400],
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 16.w),
                SizedBox(
                  width: 200.w,
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: () {
                      // Replace this screen with the Songs category listing
                      // so user doesn't return to the empty "No music found" page.
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AllCategoryByName(_audioHandler, "Songs"),
                          settings: const RouteSettings(
                            name: '/MusicList/ExploreSongs',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColors().primaryColorApp,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'Explore Songs',
                      style: TextStyle(
                        fontSize: AppSizes.fontNormal,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
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

    // Build the new custom list view with header
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            // First item is the playlist/album cover section
            return _buildPlaylistHeader();
          } else if (index == 1) {
            // Second item is the action buttons
            return _buildActionButtons();
          } else {
            // Rest are song items
            final songIndex = index - 2;
            final song = list[songIndex];
            return _buildSongListItem(song, songIndex);
          }
        },
        childCount: list.length + 2, // +2 for header and buttons
      ),
    );
  }

  // Playlist header with cover image and title
  Widget _buildPlaylistHeader() {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        children: [
          // Cover image
          Container(
            width: 240.w,
            height: 240.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: _getCoverImage(),
            ),
          ),
          SizedBox(height: AppSizes.paddingM),
          // Title
          Text(
            _getPlaylistTitle(),
            style: TextStyle(
              fontSize: AppSizes.fontH2,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          if (parentData?.description != null &&
              parentData!.description!.isNotEmpty) ...[
            SizedBox(height: AppSizes.paddingXS),
            ExpandableDescription(
              text: parentData!.description!,
              style: TextStyle(
                fontSize: AppSizes.fontNormal - 1.sp,
                fontWeight: FontWeight.w500,
                color: appColors().gray[500],
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // Action buttons (Play and Shuffle)
  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
      margin: EdgeInsets.only(bottom: AppSizes.paddingM),
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

  // Custom song list item with three dots menu and long press
  Widget _buildSongListItem(DataMusic song, int index) {
    String imageUrl = '';
    if (song.image.isNotEmpty) {
      imageUrl = '${AppConstant.ImageUrl}images/audio/thumb/${song.image}';
    }

    // Determine if the dot should be visible
    final bool showDot = (song.is_trending == 1);

    // Create music manager and check current playing state
    final musicManager = MusicManager();
    final currentItem = musicManager.getCurrentMediaItem();

    // Use audio_id from extras to match, which is the actual song ID
    final currentAudioId = currentItem?.extras?['audio_id']?.toString();
    final songAudioId = song.id.toString();
    // Consider pendingAudioId to avoid flash before stream emits
    final isCurrentItem =
        (_pendingAudioId != null && _pendingAudioId == songAudioId) ||
        (currentAudioId == songAudioId);

    // Debug information to help troubleshoot
    if (kDebugMode && currentItem != null) {
      print('MusicList - Current audio_id: $currentAudioId');
      print('MusicList - Song audio_id: $songAudioId');
      print('MusicList - Is current item: $isCurrentItem');
      print('MusicList - Is playing: ${musicManager.isPlaying}');
    }
    return MusicCardWrapper(
      menuData: _createMenuData(song, index),
      child: Container(
        margin: EdgeInsets.only(
          left: AppSizes.paddingM,
          right: AppSizes.paddingS,
          bottom: 1.w,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => _playMusic(index),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Row(
                    children: [
                      // Dot indicator for trending/recommended
                      Container(
                        width: 14.w,
                        height: 56.w,
                        alignment: Alignment.center,
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: showDot
                                ? appColors().primaryColorApp
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      // Song thumbnail with visualizer overlay
                      Container(
                        width: 56.w,
                        height: 56.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.r),
                          color: appColors().gray[100],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: AutoManagedVisualizerOverlay(
                            show: isCurrentItem, // Only show when current
                            musicManager: musicManager,
                            child: imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        _buildPlaceholderImage(),
                                    errorWidget: (context, url, error) =>
                                        _buildPlaceholderImage(),
                                  )
                                : _buildPlaceholderImage(),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Song info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.audio_title,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: isCurrentItem
                                    ? appColors().primaryColorApp
                                    : Colors.black87,
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              song.artists_name,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: appColors().gray[500],
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Three dots menu
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: appColors().primaryColorApp,
                          size: 20.sp,
                        ),
                        onPressed: () => _showContextMenu(song, index),
                      ),
                    ],
                  ),
                ),
                // Bottom border with same horizontal padding as content
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: appColors().gray[200],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Create menu data for context menu and long press
  MusicContextMenuData _createMenuData(DataMusic song, int index) {
    String imageUrl = '';
    if (song.image.isNotEmpty) {
      imageUrl = '${AppConstant.ImageUrl}images/audio/thumb/${song.image}';
    }

    // Use global favorites provider
    final isFavorite = context.read<FavoritesProvider>().isFavorite(
      song.id.toString(),
    );

    return MusicMenuDataFactory.createSongMenuData(
      title: song.audio_title,
      artist: song.artists_name.isNotEmpty
          ? song.artists_name
          : 'Unknown Artist',
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      onPlay: () => _playMusic(index),
      onPlayNext: () => _musicActionHandler.handlePlayNext(
        song.id.toString(),
        song.audio_title,
        song.artists_name,
        imagePath: imageUrl,
        audioPath: audioPath,
      ),
      onAddToQueue: () => _musicActionHandler.handleAddToQueue(
        song.id.toString(),
        song.audio_title,
        song.artists_name,
        imagePath: imageUrl,
        audioPath: audioPath,
      ),
      onDownload: () => _musicActionHandler.handleDownload(
        song.audio_title,
        "song",
        song.id.toString(),
      ),
      onAddToPlaylist: () => _musicActionHandler.handleAddToPlaylist(
        song.id.toString(),
        song.audio_title,
        song.artists_name,
      ),
      // If this screen was opened for a specific playlist, offer remove action
      onRemove: (typ == 'User Playlist' && _currentPlaylistId != null)
          ? () => _removeSongFromPlaylist(song, _currentPlaylistId!)
          : null,
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
      isFavorite: isFavorite, // Use global favorites
    );
  }

  Future<void> _removeSongFromPlaylist(
    DataMusic song,
    String playlistId,
  ) async {
    // Confirm intent quickly using a dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          'Remove from playlist',
          style: TextStyle(
            color: appColors().primaryColorApp,
            fontSize: AppSizes.fontLarge,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text('Remove "${song.audio_title}" from this playlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: appColors().gray[800]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              'Remove',
              style: TextStyle(color: appColors().primaryColorApp),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Call presenter to remove and update service cache
    try {
      final token = await sharePrefs.getToken();
      if (token.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not logged in')));
        return;
      }

      await PlaylistMusicPresenter().removeMusicFromPlaylist(
        song.id.toString(),
        playlistId,
        token,
      );

      // Invalidate playlist cache so PlaylistService returns fresh data next time
      PlaylistService().clearCache();

      // Remove from local list and refresh UI
      if (!mounted) return;
      setState(() {
        list.removeWhere((s) => s.id == song.id);
      });
    } catch (e) {
      if (kDebugMode) print('Failed to remove song from playlist: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to remove song. Try again.'),
          backgroundColor: appColors().primaryColorApp,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Show context menu for three-dot button
  void _showContextMenu(DataMusic song, int index) {
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;

    // Create menu data and show context menu
    final menuData = _createMenuData(song, index);

    MusicContextMenuHelper.show(
      context: context,
      data: menuData,
      position: Offset(size.width / 2, size.height / 2),
      cardSize: Size(size.width, 60.h),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: appColors().gray[100],
      child: Icon(Icons.music_note, color: appColors().gray[300], size: 24.w),
    );
  }

  Widget _getCoverImage() {
    Widget imageWidget;
    // Try parent image first
    if (parentData?.image != null && parentData!.image.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: parentData!.image,
        fit: BoxFit.cover,
        placeholder: (context, url) => _getDefaultCoverImage(),
        errorWidget: (context, url, error) => _getFallbackCoverImage(),
      );
    } else {
      // If we have 4 or more songs, show a 2x2 collage of the first 4 thumbnails.
      // This provides a visually richer cover for larger playlists.
      if (list.length >= 4) {
        imageWidget = _buildCollage(list);
      } else {
        // Fallback to random song image or default for small lists
        imageWidget = _getFallbackCoverImage();
      }
    }

    // Return the image widget directly without visualizer overlay
    return imageWidget;
  }

  Widget _getFallbackCoverImage() {
    // Use stored fallback image URL
    if (_fallbackImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: _fallbackImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _getDefaultCoverImage(),
        errorWidget: (context, url, error) => _getDefaultCoverImage(),
      );
    }
    return _getDefaultCoverImage();
  }

  // Build a simple 2x2 collage using the first 4 song thumbnails.
  Widget _buildCollage(List<DataMusic> songs) {
    // Safeguard: ensure there are at least 4 items
    final items = songs.length >= 4 ? songs.sublist(0, 4) : songs;

    // Prepare image widgets (use placeholder when image missing)
    final tiles = items.map((s) {
      if (s.image.isNotEmpty) {
        final url = '${AppConstant.ImageUrl}images/audio/thumb/${s.image}';
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholderImage(),
          errorWidget: (context, url, error) => _buildPlaceholderImage(),
        );
      }
      return _buildPlaceholderImage();
    }).toList();

    // If fewer than 4 tiles (defensive), fill with placeholders
    while (tiles.length < 4) tiles.add(_buildPlaceholderImage());

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: appColors().gray[100],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: SizedBox(
          width: 240.w,
          height: 240.w,
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 0.w,
            crossAxisSpacing: 0.w,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: tiles,
          ),
        ),
      ),
    );
  }

  Widget _getDefaultCoverImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            appColors().primaryColorApp.withOpacity(0.8),
            appColors().primaryColorApp.withOpacity(0.4),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note, size: 80.w, color: Colors.white),
      ),
    );
  }

  String _getPlaylistTitle() {
    if (parentData?.title != null && parentData!.title.isNotEmpty) {
      return parentData!.title;
    }

    // Fallback logic based on type and category
    if (pageTitle.isNotEmpty) {
      return pageTitle;
    }

    if (catName.isNotEmpty) {
      return catName;
    }

    if (typ.isNotEmpty) {
      // Format the type to be more readable
      switch (typ.toLowerCase()) {
        case 'songs':
          return 'All Songs';
        case 'albums':
          return 'Albums';
        case 'artists':
          return 'Artists';
        case 'playlists':
          return 'Playlists';
        default:
          return typ;
      }
    }

    return 'Music Collection';
  }

  void _playAllSongs({required bool shuffle}) async {
    if (list.isEmpty) return;
    final musicManager = MusicManager();

    // Prepare the list we'll pass to the manager. If shuffle is requested,
    // create a shuffled copy of the current list so the playback order is
    // actually randomized. We still pick a startIndex inside the shuffled
    // list so playback begins at a random song.
    List<DataMusic> queueForPlayback;
    int startIndex;

    if (shuffle) {
      queueForPlayback = List<DataMusic>.from(list);
      queueForPlayback.shuffle(math.Random());
      startIndex = math.Random().nextInt(queueForPlayback.length);
    } else {
      queueForPlayback = list;
      startIndex = 0;
    }

    // Optimistically mark pending audio to avoid flash. Use the ID from the
    // shuffled queue so UI highlights the correct upcoming track.
    _pendingAudioId = queueForPlayback[startIndex].id.toString();
    if (mounted) setState(() {});

    try {
      await musicManager.replaceQueue(
        musicList: queueForPlayback,
        startIndex: startIndex,
        pathImage: pathImage,
        audioPath: audioPath,
        callSource: 'MusicList._playAllSongs',
      );

      // Ensure audio handler queue reflects the new queue and explicitly
      // skip to the intended startIndex and play to avoid race conditions.
      final handler = _audioHandler;
      if (handler != null) {
        final timeout = Duration(seconds: 5);
        final deadline = DateTime.now().add(timeout);
        while (DateTime.now().isBefore(deadline)) {
          try {
            final q = handler.queue.value;
            if (q.length > startIndex) break;
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 100));
        }

        try {
          await handler.skipToQueueItem(startIndex);
        } catch (_) {}
        try {
          await handler.play();
        } catch (_) {}
      }

      // Add first song to history
      addRemoveHisAPI(list[startIndex].id.toString());

      // Show mini player
      final stateManager = MusicPlayerStateManager();
      stateManager.showMiniPlayerForMusicStart();

      developer.log(
        '[MusicList] ${shuffle ? 'Shuffle' : 'Play'} all completed',
      );
    } catch (e) {
      developer.log('[MusicList] Play all failed: $e');
    } finally {
      // Clear pending state after queue setup
      _pendingAudioId = null;
      if (mounted) setState(() {});
    }
  }

  // Update _playMusic to work with filtered index
  void _playMusic(int index) async {
    if (index < 0 || index >= list.length) return;

    // Optimistically mark pending audio to avoid flash
    _pendingAudioId = list[index].id.toString();
    setState(() {});
    // Use the simplified music manager for queue replacement and playback
    final musicManager = MusicManager();

    try {
      await musicManager.replaceQueue(
        musicList: list,
        startIndex: index,
        pathImage: pathImage,
        audioPath: audioPath,
        callSource: 'MusicList._playMusic',
      );

      // Add to history in background without blocking UI
      addRemoveHisAPI(list[index].id.toString());

      // Ensure mini player is shown and navigation remains visible
      final stateManager = MusicPlayerStateManager();
      stateManager.showMiniPlayerForMusicStart();

      // Show mini player only - don't navigate to full player
      // The mini player will automatically appear when queue is set up
      developer.log(
        '[MusicList] Queue replacement completed, mini player should be visible',
      );
    } catch (e) {
      developer.log('[MusicList] Queue replacement failed: $e');
    } finally {
      // Clear pending state after queue setup
      _pendingAudioId = null;
      if (mounted) setState(() {});
    }

    // NO NAVIGATION TO FULL PLAYER - let mini player handle this
    // User can tap mini player to open full player if needed
  }

  /// Restores navigation state when coming from the full music player
  /// Uses multiple attempts and delays to ensure the navigation is properly restored
  void _restoreNavigationState() async {
    try {
      final stateManager = MusicPlayerStateManager();
      // Always force show navigation and mini player when entering this page
      stateManager.showNavigationAndMiniPlayer();
      // Optionally, force a rebuild if needed
      if (mounted) setState(() {});
    } catch (e) {
      print('🔥 ERROR: MusicList failed to restore navigation: $e');
      // Fallback - try to force a basic state reset
      try {
        final stateManager = MusicPlayerStateManager();
        stateManager.forceResetState();
      } catch (fallbackError) {
        print('🔥 ERROR: MusicList fallback also failed: $fallbackError');
      }
    }
  }
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}
