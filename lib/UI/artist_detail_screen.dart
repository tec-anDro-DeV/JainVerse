import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Presenter/CatSubCatMusicPresenter.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/visualizer_music_integration.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../Presenter/HistoryPresenter.dart';
import '../providers/favorites_provider.dart';
import '../services/favorite_service.dart';
// TODO: Add other services when needed
// import '../services/download_manager.dart';
// import '../services/asset_manager.dart';
import '../widgets/common/loader.dart';
import '../widgets/common/music_context_menu.dart';
import '../widgets/common/music_long_press_handler.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String catName;
  final String idTag;
  final String typ;
  final AudioPlayerHandler? audioHandler;

  const ArtistDetailScreen({
    super.key,
    required this.audioHandler,
    required this.idTag,
    required this.typ,
    required this.catName,
  });

  @override
  State<StatefulWidget> createState() {
    return _ArtistDetailScreenState();
  }
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  // Dominant color for status bar
  List<DataMusic> list = [];
  String pathImage = '', audioPath = '';
  bool tillLoading = true;
  bool isOpen = false;
  String token = "";
  int indexNum = 0;
  final SharedPref sharePrefs = SharedPref();

  String pageTitle = '';
  String? _fallbackImageUrl; // Store a single fallback cover image URL
  ParentData? parentData; // Add parent data

  // Modern scroll controller for header animations
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  bool _isCollapsed = false;

  // Theme data for media cards
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');

  // Add favorite service instance
  final FavoriteService _favoriteService = FavoriteService();

  // Add favorite state management
  final Set<String> _favoriteIds = <String>{};

  // Updated constants for better scroll behavior
  // Responsive header dimensions
  // Max height equals screen width for a square header
  double get _headerMaxHeight => MediaQuery.of(context).size.width * 0.8;
  static const double _headerMinHeight =
      70.0; // Minimum header height (for back button area)
  static const double _headerScrollRange = 200.0; // Range for header animation

  // Overlay entry for message management
  OverlayEntry? _currentOverlayEntry;

  // Centralized music action handler
  late MusicActionHandler _musicActionHandler;

  // Get audio handler safely
  AudioPlayerHandler? get _audioHandler => widget.audioHandler;

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

  Future<void> getCate() async {
    try {
      token = await sharePrefs.getToken();
      sharedPreThemeData = await sharePrefs.getThemeData();
      ModelMusicList mList = await CatSubcatMusicPresenter()
          .getMusicListByCategory(widget.idTag, widget.typ, token);

      if (mounted) {
        setState(() {
          list = mList.data;
          pathImage = mList.imagePath;
          audioPath = mList.audioPath;
          parentData = mList.parent; // Store parent data

          // Initialize a single fallback image URL if not set
          if (_fallbackImageUrl == null) {
            final songsWithImages =
                list.where((song) => song.image.isNotEmpty).toList();
            if (songsWithImages.isNotEmpty) {
              final randomSong =
                  songsWithImages[math.Random().nextInt(
                    songsWithImages.length,
                  )];
              _fallbackImageUrl =
                  '${AppConstant.ImageUrl}images/audio/thumb/${randomSong.image}';
            }
          }
          tillLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading category data: $e');
      }
      if (mounted) {
        setState(() {
          tillLoading = false;
        });
      }
    }
  }

  Future<void> addRemoveHisAPI(String id) async {
    try {
      await HistoryPresenter().addHistory(id, token, 'add');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding to history: $e');
      }
    }
  }

  Future<void> addToQueue(DataMusic item) async {
    if (_audioHandler == null) return;

    try {
      String s = item.audio_duration.trim();
      s = s.replaceAll('\n', '').trim();

      Duration duration;
      try {
        List<String> idx = s.split(':');

        if (idx.length == 3) {
          duration = Duration(
            hours: int.parse(idx[0]),
            minutes: int.parse(idx[1]),
            seconds: int.parse(double.parse(idx[2]).round().toString()),
          );
        } else if (idx.length == 2) {
          duration = Duration(
            minutes: int.parse(idx[0]),
            seconds: int.parse(idx[1]),
          );
        } else {
          duration = const Duration(minutes: 3); // Default fallback
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            'Error parsing duration "${item.audio_duration}" for ${item.audio_title}: $e',
          );
        }
        duration = const Duration(minutes: 3); // Default to 3 minutes
      }

      String imageUrl =
          '${AppConstant.ImageUrl}images/audio/thumb/${item.image}';

      // Create unique MediaItem ID for queue addition
      final uniqueId =
          '${item.audio}?addQueue=musicList&ts=${DateTime.now().millisecondsSinceEpoch}';

      var mItem = MediaItem(
        id: uniqueId,
        title: item.audio_title,
        artist: item.artists_name,
        duration: duration,
        artUri: Uri.parse(imageUrl),
        extras: {
          'audio_id': item.id.toString(),
          'actual_audio_url': item.audio,
          'lyrics': item.lyrics,
          'favourite': item.favourite,
          'artist_id': item.artist_id,
        },
      );

      await _audioHandler!.addQueueItem(mItem);

      ValueStream<List<MediaItem>> mList = _audioHandler!.queue;
      int count = mList.value.length;

      if (kDebugMode) {
        print('Queue length: $count');
        for (var queueItem in mList.value) {
          print('Queue Item: ${queueItem.title} - ${queueItem.artist}');
        }
      }

      _setupPlaybackListener();
    } catch (e) {
      if (kDebugMode) {
        print('Error adding to queue: $e');
      }
    }
  }

  void _setupPlaybackListener() {
    if (_audioHandler == null) return;

    _audioHandler!.playbackState.listen((playbackState) {
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

    getCate();
    pageTitle = (widget.catName.isNotEmpty) ? widget.catName : widget.typ;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreNavigationState();
      }
    });

    // Do not call _extractAndSetStatusBarColor here; call it after getCate() completes.
  }

  @override
  void dispose() {
    _scrollController.dispose();

    // Clean up overlay entry
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;

    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    setState(() {
      _scrollOffset = _scrollController.offset;
      // Update collapsed state for SliverAppBar
      _isCollapsed =
          _scrollController.offset > (_headerMaxHeight - _headerMinHeight);
    });
  }

  // Calculate header opacity based on scroll position
  double _getHeaderOpacity() {
    final progress = (_scrollOffset / _headerScrollRange).clamp(0.0, 1.0);
    return 1.0 - (progress * 0.3); // Only reduce opacity by 30% maximum
  }

  // Calculate title opacity (for glassmorphism label)
  double _getTitleOpacity() {
    final progress = (_scrollOffset / (_headerScrollRange * 0.7)).clamp(
      0.0,
      1.0,
    );
    return 1.0 - progress;
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color using extracted color (fallback to black)
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Show loader for the whole screen if loading
    if (tillLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (_scrollController.hasClients) {
              final collapsed =
                  _scrollController.offset >
                  (_headerMaxHeight - _headerMinHeight);
              if (_isCollapsed != collapsed) {
                setState(() {
                  _isCollapsed = collapsed;
                });
              }
            }
            return false;
          },
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // Flexible header that shrinks on scroll
        _buildFlexibleHeader(),
        // Main content
        _buildContentSliver(),
        // Bottom padding for mini player
        _buildBottomPadding(),
      ],
    );
  }

  Widget _buildFlexibleHeader() {
    final headerOpacity = _getHeaderOpacity();
    final titleOpacity = _getTitleOpacity();

    final String? artistImage =
        (parentData != null && parentData!.image.isNotEmpty)
            ? parentData!.image
            : null;

    return SliverAppBar(
      expandedHeight: _headerMaxHeight,
      collapsedHeight: _headerMinHeight,
      pinned: true,
      elevation: 0,
      // Make sure this matches your desired collapsed background
      backgroundColor: Colors.white,
      // Add surfaceTintColor to prevent any material color tinting
      surfaceTintColor: Colors.transparent,
      // Ensure the foreground color is appropriate
      foregroundColor: Colors.black87,
      leadingWidth: 70.w,
      automaticallyImplyLeading: false,
      // Move the back button into the leading slot to avoid clipping in
      // collapsed/expanded states. This ensures the AppBar manages layout
      // and hit testing for the button correctly.
      leading: Padding(
        // Use fixed padding so the leading area remains consistent across screens.
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 0.0, 12.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // Keep a circular hit area independent of the icon size
            borderRadius: BorderRadius.circular(24.0),
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              // Fixed container size (independent of icon size)
              width: 44.w,
              height: 44.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              // Use a fixed icon size that doesn't scale with AppSizes
              child: Icon(Icons.arrow_back, color: Colors.black87, size: 22.w),
            ),
          ),
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // Back button is provided via SliverAppBar.leading now; keep
          // the title row simple so nothing overlaps or clips the button.
          // Animated artist label in toolbar
          Expanded(
            child: AnimatedOpacity(
              opacity: _isCollapsed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Padding(
                padding: EdgeInsets.only(left: 18.w, top: 12.w),
                child: Text(
                  _getPlaylistTitle(),
                  style: TextStyle(
                    color: Colors.black87, // Always black for collapsed state
                    fontSize: AppSizes.fontLarge,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    letterSpacing: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          // Ensure full coverage with solid white background
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: Stack(
            children: [
              // Background image with opacity animation
              Opacity(
                opacity: headerOpacity,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(36.r),
                      bottomRight: Radius.circular(36.r),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(36.r),
                      bottomRight: Radius.circular(36.r),
                    ),
                    child:
                        (() {
                          Widget imageWidget =
                              artistImage != null
                                  ? Image.network(
                                    artistImage,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _getDefaultCoverImage(),
                                  )
                                  : _getDefaultCoverImage();
                          return imageWidget;
                        })(),
                  ),
                ),
              ),

              // Glassmorphism effect for artist name label with fade animation
              if (titleOpacity > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18.w,
                  child: Opacity(
                    opacity: titleOpacity,
                    child: Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.r),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.44),
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getPlaylistTitle(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: AppSizes.fontMedium,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.18),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                  // Divider between genre and description if available
                                  if ((parentData != null &&
                                          parentData!
                                              .artistGenreName
                                              .isNotEmpty) ||
                                      (parentData?.description != null &&
                                          parentData!
                                              .description!
                                              .isNotEmpty)) ...[
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 4.h,
                                      ),
                                      child: Divider(
                                        color: Colors.white54,
                                        thickness: 1,
                                        height: 1,
                                      ),
                                    ),
                                    // Show genre and description separated by a middle dot, with larger dot
                                    Builder(
                                      builder: (context) {
                                        final List<String> parts = [
                                          if (parentData != null &&
                                              parentData!
                                                  .artistGenreName
                                                  .isNotEmpty)
                                            parentData!.artistGenreName,
                                          if (parentData != null &&
                                              parentData!.description != null &&
                                              parentData!
                                                  .description!
                                                  .isNotEmpty)
                                            parentData!.description!,
                                        ];
                                        if (parts.isEmpty)
                                          return SizedBox.shrink();
                                        if (parts.length == 1) {
                                          return Text(
                                            parts.first,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: AppSizes.fontNormal,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'Poppins',
                                            ),
                                            textAlign: TextAlign.left,
                                          );
                                        }
                                        // If two parts, use a Row with a centered circular dot
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                parts[0],
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: AppSizes.fontNormal,
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Poppins',
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10.0,
                                                  ),
                                              child: Container(
                                                width: 9.w,
                                                height: 9.w,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                            Flexible(
                                              child: Text(
                                                parts[1],
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: AppSizes.fontNormal,
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Poppins',
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
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
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return _buildActionButtons();
        } else {
          final songIndex = index - 1;
          final song = list[songIndex];
          return _buildSongListItem(song, songIndex);
        }
      }, childCount: list.length + 1),
    );
  }

  Widget _buildBottomPadding() {
    return SliverToBoxAdapter(
      child: StreamBuilder<MediaItem?>(
        stream: _audioHandler?.mediaItem,
        builder: (context, snapshot) {
          final hasMiniPlayer = snapshot.hasData;
          final bottomPadding =
              hasMiniPlayer
                  ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 100.w
                  : AppSizes.basePadding + AppSizes.miniPlayerPadding;

          return SizedBox(height: bottomPadding);
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
      margin: EdgeInsets.only(
        bottom: AppSizes.paddingM,
        top: AppSizes.paddingM,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.play_arrow,
              label: 'Play',
              onTap: () => _playAllSongs(shuffle: false),
              color: appColors().primaryColorApp,
            ),
          ),
          SizedBox(width: AppSizes.paddingM),
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
          backgroundColor: color.withOpacity(0.3),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          alignment: Alignment.center,
        ),
      ),
    );
  }

  Widget _buildSongListItem(DataMusic song, int index) {
    String imageUrl = '';
    if (song.image.isNotEmpty) {
      imageUrl = '${AppConstant.ImageUrl}images/audio/thumb/${song.image}';
    }

    // Show dot if any of the flags are 1
    final bool showDot = (song.is_trending == 1);

    final musicManager = MusicManager.instance;
    final songAudioId = song.id.toString();
    final audioHandler = _audioHandler;

    return MusicCardWrapper(
      menuData: _createMenuData(song, index),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(
              left: AppSizes.paddingM,
              right: AppSizes.paddingS,
              bottom: 0,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12.r),
                onTap: () => _playMusic(index),
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Row(
                    children: [
                      // Dot indicator for trending only (always reserve space)
                      Container(
                        width: 8.w,
                        height: 8.w,
                        margin: EdgeInsets.only(right: 8.w),
                        decoration: BoxDecoration(
                          color:
                              showDot
                                  ? appColors().primaryColorApp
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border:
                              showDot
                                  ? null
                                  : Border.all(color: Colors.transparent),
                        ),
                      ),
                      // Song thumbnail with visualizer overlay
                      StreamBuilder<MediaItem?>(
                        stream: audioHandler?.mediaItem,
                        builder: (context, snapshot) {
                          final currentItem = snapshot.data;
                          final currentAudioId =
                              currentItem?.extras?['audio_id']?.toString();
                          final isCurrentItem = currentAudioId == songAudioId;
                          return Container(
                            width: 56.w,
                            height: 56.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              color: appColors().gray[100],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: AutoManagedVisualizerOverlay(
                                show: isCurrentItem,
                                musicManager: musicManager,
                                child:
                                    imageUrl.isNotEmpty
                                        ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return _buildPlaceholderImage();
                                          },
                                        )
                                        : _buildPlaceholderImage(),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 12.w),
                      SizedBox(width: 12.w),
                      // Song info - determine current item via MusicManager snapshot
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final currentItem =
                                MusicManager.instance.getCurrentMediaItem();
                            final currentAudioId =
                                currentItem?.extras?['audio_id']?.toString();
                            final localIsCurrent =
                                currentAudioId == songAudioId;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.audio_title,
                                  style: TextStyle(
                                    fontSize: AppSizes.fontNormal,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        localIsCurrent
                                            ? appColors().primaryColorApp
                                            : Colors.black87,
                                    fontFamily: 'Poppins',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Removed artist name from song list
                              ],
                            );
                          },
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
              ),
            ),
          ),
          // Bottom border with horizontal padding matching content
          Padding(
            padding: EdgeInsets.only(
              left: AppSizes.paddingL,
              right: AppSizes.paddingL,
            ),
            child: Divider(
              height: 0,
              thickness: 1,
              color: appColors().gray[200],
            ),
          ),
        ],
      ),
    );
  }

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
      artist:
          song.artists_name.isNotEmpty ? song.artists_name : 'Unknown Artist',
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      onPlay: () => _playMusic(index),
      onPlayNext:
          () => _musicActionHandler.handlePlayNext(
            song.id.toString(),
            song.audio_title,
            song.artists_name,
            imagePath: imageUrl,
            audioPath: audioPath,
          ),
      onAddToQueue:
          () => _musicActionHandler.handleAddToQueue(
            song.id.toString(),
            song.audio_title,
            song.artists_name,
            imagePath: imageUrl,
            audioPath: audioPath,
          ),
      onDownload:
          () => _musicActionHandler.handleDownload(
            song.audio_title,
            "song",
            song.id.toString(),
          ),
      onAddToPlaylist:
          () => _musicActionHandler.handleAddToPlaylist(
            song.id.toString(),
            song.audio_title,
            song.artists_name,
          ),
      onShare:
          () => _musicActionHandler.handleShare(
            song.audio_title,
            "song",
            itemId: song.id.toString(),
            slug: song.audio_slug,
          ),
      onFavorite:
          () => _musicActionHandler.handleFavoriteToggle(
            song.id.toString(),
            song.audio_title,
            favoriteIds: _favoriteIds,
          ),
      isFavorite: isFavorite, // Use global favorites
    );
  }

  void _showContextMenu(DataMusic song, int index) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

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

  Widget _getDefaultCoverImage() {
    // Only show this if there is no image or image fails to load
    return Container(
      decoration: BoxDecoration(color: appColors().primaryColorApp),
      child: Center(
        child: Icon(Icons.music_note, size: 80.w, color: Colors.white),
      ),
    );
  }

  String _getPlaylistTitle() {
    if (parentData != null && parentData!.title.isNotEmpty) {
      return parentData!.title;
    }

    if (pageTitle.isNotEmpty) {
      return pageTitle;
    }

    if (widget.catName.isNotEmpty) {
      return widget.catName;
    }

    if (widget.typ.isNotEmpty) {
      switch (widget.typ.toLowerCase()) {
        case 'songs':
          return 'All Songs';
        case 'albums':
          return 'Albums';
        case 'artists':
          return 'Artists';
        case 'playlists':
          return 'Playlists';
        default:
          return widget.typ;
      }
    }

    return 'Music Collection';
  }

  void _playAllSongs({required bool shuffle}) async {
    if (list.isEmpty) return;

    final musicManager = MusicManager.instance;
    final startIndex =
        shuffle ? (list.length * math.Random().nextDouble()).floor() : 0;

    try {
      await musicManager.replaceQueue(
        musicList: list,
        startIndex: startIndex,
        pathImage: pathImage,
        audioPath: audioPath,
        callSource: 'ArtistDetailScreen._playAllSongs',
      );

      // Only call history API after successful queue replacement
      await addRemoveHisAPI(list[startIndex].id.toString());

      final stateManager = MusicPlayerStateManager();
      stateManager.showMiniPlayerForMusicStart();

      developer.log(
        '[ArtistDetailScreen] ${shuffle ? 'Shuffle' : 'Play'} all completed',
      );
    } catch (e) {
      developer.log('[ArtistDetailScreen] Play all failed: $e');
    }
  }

  void _playMusic(int index) async {
    if (index < 0 || index >= list.length) return;

    final musicManager = MusicManager.instance;

    try {
      await musicManager.replaceQueue(
        musicList: list,
        startIndex: index,
        pathImage: pathImage,
        audioPath: audioPath,
        callSource: 'ArtistDetailScreen._playMusic',
      );

      // Only call history API after successful queue replacement
      await addRemoveHisAPI(list[index].id.toString());

      final stateManager = MusicPlayerStateManager();
      stateManager.showMiniPlayerForMusicStart();

      developer.log(
        '[ArtistDetailScreen] Queue replacement completed, mini player should be visible',
      );
    } catch (e) {
      developer.log('[ArtistDetailScreen] Queue replacement failed: $e');
    }
  }

  void _restoreNavigationState() async {
    try {
      final stateManager = MusicPlayerStateManager();
      stateManager.showNavigationAndMiniPlayer();
      if (mounted) setState(() {});
    } catch (e) {
      print('🔥 ERROR: ArtistDetailScreen failed to restore navigation: $e');
      try {
        final stateManager = MusicPlayerStateManager();
        stateManager.forceResetState();
      } catch (fallbackError) {
        print(
          '🔥 ERROR: ArtistDetailScreen fallback also failed: $fallbackError',
        );
      }
    }
  }
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}
