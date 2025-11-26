import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/home_models.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/UI/AllCategoryByName.dart';
import 'package:jainverse/UI/MusicList.dart';
import 'package:jainverse/controllers/home_controller.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/models/song_playback_payload.dart';
import 'package:jainverse/presentation/home/channel_directory_screen.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:jainverse/utils/video_player_launcher.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/screens/channel_videos_screen.dart';
import 'package:jainverse/videoplayer/screens/video_list_screen.dart';
import 'package:jainverse/widgets/cards/video_card_small.dart';
import 'package:jainverse/UI/AccountPage.dart';
import 'package:jainverse/widgets/common/app_header.dart';
import 'package:jainverse/widgets/common/loader.dart';
import 'package:jainverse/widgets/music/circular_card.dart';
import 'package:jainverse/widgets/music/genre_card.dart';
import 'package:jainverse/widgets/music/home_section_header.dart';
import 'package:jainverse/widgets/music/popular_song_card.dart';
import 'package:jainverse/widgets/music/song_card.dart';
import 'package:session_storage/session_storage.dart';

AudioPlayerHandler? _audioHandler;

class HomeDiscover extends StatefulWidget {
  const HomeDiscover({super.key});

  @override
  State<HomeDiscover> createState() => _HomeDiscoverState();
}

class _HomeDiscoverState extends State<HomeDiscover>
    with RouteAware, WidgetsBindingObserver {
  final SessionStorage session = SessionStorage();
  final NumberFormat _numberFormat = NumberFormat.compact();

  late final ScrollController _scrollController;
  late final HomeController _controller;
  late final FavoriteService _favoriteService;
  late MusicActionHandler _musicActionHandler;
  bool _isHeaderVisible = true;
  double _lastScrollPosition = 0;
  bool _isRouteObserverAttached = false;
  bool _isFocusRefreshRunning = false;

  @override
  void initState() {
    super.initState();
    session['page'] = '0';
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _controller = HomeController();
    _favoriteService = FavoriteService();
    _audioHandler = const MyApp().called();
    _musicActionHandler = MusicActionHandlerFactory.create(
      context: context,
      audioHandler: _audioHandler,
      favoriteService: _favoriteService,
      onStateUpdate: () => setState(() {}),
    );
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.initialize();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_isRouteObserverAttached) {
      try {
        routeObserver.unsubscribe(this);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteObserverAttached) return;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
      _isRouteObserverAttached = true;
    }
  }

  @override
  void didPush() {
    _handleFocusGained();
  }

  @override
  void didPopNext() {
    _handleFocusGained(allowWhenEmpty: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleFocusGained(allowWhenEmpty: true);
    }
  }

  Future<void> _handleFocusGained({bool allowWhenEmpty = false}) async {
    if (!mounted || _isFocusRefreshRunning) return;
    if (_controller.isLoading || _controller.isRefreshing) return;
    if (!_controller.hasContent && !allowWhenEmpty) return;

    _isFocusRefreshRunning = true;
    try {
      if (_controller.hasContent) {
        await _controller.refresh();
      } else {
        await _controller.loadContent(forceRefresh: true);
      }
    } catch (_) {
      // Silently ignore focus refresh failures; pull-to-refresh remains available.
    } finally {
      if (mounted) {
        _isFocusRefreshRunning = false;
      }
    }
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: appColors().colorBackground,
          body: SafeArea(child: _buildBody()),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && !_controller.hasContent) {
      return const Center(child: CircleLoader(size: 140));
    }

    if (_controller.hasError && !_controller.hasContent) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      color: appColors().primaryColorApp,
      onRefresh: _controller.refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildAnimatedHeader()),
          if (_controller.isRefreshing)
            SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2,
                color: appColors().primaryColorApp,
                backgroundColor: appColors().gray[200],
              ),
            ),
          ..._buildSections(),
          SliverToBoxAdapter(
            child: SizedBox(height: AppPadding.bottom(context, extra: 50.w)),
          ),
        ],
      ),
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
              title: 'Discover',
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

  void _scrollListener() {
    if (!_scrollController.hasClients || !mounted) return;

    final currentPosition = _scrollController.position.pixels;
    final scrollDelta = currentPosition - _lastScrollPosition;
    const double hideThreshold = 10.0;
    const double showThreshold = -3.0;
    final isAtTop = currentPosition <= 5.0;

    if (isAtTop) {
      if (!_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    } else {
      if (scrollDelta > hideThreshold && _isHeaderVisible) {
        setState(() {
          _isHeaderVisible = false;
        });
      } else if (scrollDelta < showThreshold && !_isHeaderVisible) {
        setState(() {
          _isHeaderVisible = true;
        });
      }
    }

    _lastScrollPosition = currentPosition;
  }

  List<Widget> _buildSections() {
    final theme = _controller.theme;
    final sections = <Widget>[];
    final updateStamp = _controller.lastUpdated?.millisecondsSinceEpoch ?? 0;

    void addAnimatedSection({
      required Widget? child,
      required String identity,
    }) {
      if (child == null) return;
      sections.add(
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: KeyedSubtree(
              key: ValueKey('$identity-$updateStamp'),
              child: child,
            ),
          ),
        ),
      );
    }

    addAnimatedSection(
      child: _buildVideoSection(
        title: 'Featured Videos',
        videos: _controller.featuredVideos,
        section: _HomeSection.featuredVideos,
        theme: theme,
      ),
      identity: 'featuredVideos-${_controller.featuredVideos.length}',
    );
    addAnimatedSection(
      child: _buildChannelSection(_controller.channelList, theme),
      identity: 'channels-${_controller.channelList.length}',
    );
    addAnimatedSection(
      child: _buildSongCarousel(
        title: 'Featured Songs',
        songs: _controller.featuredSongs,
        section: _HomeSection.featuredSongs,
        theme: theme,
      ),
      identity: 'featuredSongs-${_controller.featuredSongs.length}',
    );
    addAnimatedSection(
      child: _buildLatestSongs(songs: _controller.latestSongs, theme: theme),
      identity: 'latestSongs-${_controller.latestSongs.length}',
    );
    addAnimatedSection(
      child: _buildVideoSection(
        title: 'Popular Videos',
        videos: _controller.popularVideos,
        section: _HomeSection.popularVideos,
        theme: theme,
      ),
      identity: 'popularVideos-${_controller.popularVideos.length}',
    );
    addAnimatedSection(
      child: _buildGenreSection(_controller.trendingGenres, theme),
      identity: 'trendingGenres-${_controller.trendingGenres.length}',
    );
    addAnimatedSection(
      child: _buildVideoSection(
        title: 'New Videos',
        videos: _controller.newVideos,
        section: _HomeSection.newVideos,
        theme: theme,
      ),
      identity: 'newVideos-${_controller.newVideos.length}',
    );

    return sections;
  }

  Widget? _buildVideoSection({
    required String title,
    required List<VideoModel> videos,
    required _HomeSection section,
    required ModelTheme theme,
  }) {
    if (videos.isEmpty) return null;

    return Padding(
      padding: EdgeInsets.only(top: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            title: title,
            sharedPreThemeData: theme,
            onViewAllPressed: () => _handleViewAll(section),
          ),
          SizedBox(
            height: 250.w,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemBuilder: (context, index) {
                final video = videos[index];
                return VideoCardSmall(
                  title: video.title,
                  thumbnailUrl: _resolveVideoThumb(video),
                  duration: video.duration,
                  channelName: video.channelName,
                  channelImageUrl: video.channelImageUrl,
                  totalViews: video.totalViews,
                  publishedAt: video.createdAt,
                  onTap: () => _openVideo(video),
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

  Widget? _buildChannelSection(List<ChannelModel> channels, ModelTheme theme) {
    if (channels.isEmpty) return null;

    return Padding(
      padding: EdgeInsets.only(top: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            title: 'Channels',
            sharedPreThemeData: theme,
            onViewAllPressed: () => _handleViewAll(_HomeSection.channels),
          ),
          SizedBox(
            height: 150.w,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return CircularCard(
                  imagePath: _resolveChannelImage(channel),
                  title: channel.name,
                  subtitle: channel.handle.trim().isNotEmpty
                      ? '@${channel.handle.trim()}'
                      : null,
                  onTap: () => _openChannel(channel),
                  sharedPreThemeData: theme,
                );
              },
              separatorBuilder: (context, _) => SizedBox(width: 16.w),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildSongCarousel({
    required String title,
    required List<SongModel> songs,
    required _HomeSection section,
    required ModelTheme theme,
  }) {
    if (songs.isEmpty) return null;

    return Padding(
      padding: EdgeInsets.only(top: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            title: title,
            sharedPreThemeData: theme,
            onViewAllPressed: () => _handleViewAll(section),
          ),
          SizedBox(
            height: 190.w,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemBuilder: (context, index) {
                final song = songs[index];
                return _buildSongCard(song, theme, songs, index);
              },
              separatorBuilder: (context, _) => SizedBox(width: 12.w),
              itemCount: songs.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildLatestSongs({
    required List<SongModel> songs,
    required ModelTheme theme,
  }) {
    if (songs.isEmpty) return null;

    return Padding(
      padding: EdgeInsets.only(top: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            title: 'Latest Songs',
            sharedPreThemeData: theme,
            onViewAllPressed: () => _handleViewAll(_HomeSection.latestSongs),
          ),
          SizedBox(
            height: 340.w,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12.w,
                crossAxisSpacing: 12.w,
                mainAxisExtent: 320.w,
              ),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return _buildLatestSongCard(song, theme, songs, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildGenreSection(List<GenreModel> genres, ModelTheme theme) {
    if (genres.isEmpty) return null;

    return Padding(
      padding: EdgeInsets.only(top: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            title: 'Trending Genres',
            sharedPreThemeData: theme,
            onViewAllPressed: () => _handleViewAll(_HomeSection.trendingGenres),
          ),
          SizedBox(
            height: 170.w,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemBuilder: (context, index) {
                final genre = genres[index];
                return GenreCard(
                  imagePath: _resolveGenreImage(genre),
                  genreName: genre.name,
                  description: genre.description,
                  onTap: () => _handleGenreTap(genre),
                  sharedPreThemeData: theme,
                );
              },
              separatorBuilder: (context, _) => SizedBox(width: 12.w),
              itemCount: genres.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongCard(
    SongModel song,
    ModelTheme theme,
    List<SongModel> sectionSongs,
    int sectionIndex,
  ) {
    final songId = song.id.toString();
    final bool hasSongId = songId.isNotEmpty;
    final imageUrl = _resolveSongImage(song);
    final artistName = _artistName(song);

    return SongCard(
      songId: songId,
      imagePath: imageUrl,
      songName: song.audioTitle,
      artistName: artistName,
      sharedPreThemeData: theme,
      onTap: hasSongId
          ? () => _handleInstantHomeSongTap(sectionSongs, sectionIndex)
          : () => _showSnackbar('Song unavailable.'),
      onPlay: hasSongId
          ? () => _handleInstantHomeSongTap(sectionSongs, sectionIndex)
          : null,
      onPlayNext: hasSongId
          ? () => _musicActionHandler.handlePlayNext(
              songId,
              song.audioTitle,
              artistName,
              imagePath: imageUrl,
            )
          : null,
      onAddToQueue: hasSongId
          ? () => _musicActionHandler.handleAddToQueue(
              songId,
              song.audioTitle,
              artistName,
              imagePath: imageUrl,
            )
          : null,
      onDownload: hasSongId
          ? () => _musicActionHandler.handleDownload(
              song.audioTitle,
              'song',
              songId,
              imagePath: imageUrl,
            )
          : null,
      onAddToPlaylist: hasSongId
          ? () => _musicActionHandler.handleAddToPlaylist(
              songId,
              song.audioTitle,
              artistName,
              imagePath: imageUrl,
            )
          : null,
      onShare: () => _musicActionHandler.handleShare(
        song.audioTitle,
        'song',
        itemId: songId,
        slug: song.audioSlug,
      ),
      onFavorite: hasSongId
          ? () => _musicActionHandler.handleFavoriteToggle(
              songId,
              song.audioTitle,
            )
          : null,
    );
  }

  Widget _buildLatestSongCard(
    SongModel song,
    ModelTheme theme,
    List<SongModel> sectionSongs,
    int sectionIndex,
  ) {
    final songId = song.id.toString();
    final bool hasSongId = songId.isNotEmpty;
    final imageUrl = _resolveSongImage(song);
    final artistName = _artistName(song);
    final listens = _formatListenCount(song.listeningCount);

    return PopularSongCard(
      songId: songId,
      imagePath: imageUrl,
      songName: song.audioTitle,
      artistName: artistName,
      listenerCount: listens,
      sharedPreThemeData: theme,
      onTap: hasSongId
          ? () => _handleInstantHomeSongTap(sectionSongs, sectionIndex)
          : () => _showSnackbar('Song unavailable.'),
      onPlay: hasSongId
          ? () => _handleInstantHomeSongTap(sectionSongs, sectionIndex)
          : null,
      onPlayNext: hasSongId
          ? () => _musicActionHandler.handlePlayNext(
              songId,
              song.audioTitle,
              artistName,
              imagePath: imageUrl,
            )
          : null,
      onAddToQueue: hasSongId
          ? () => _musicActionHandler.handleAddToQueue(
              songId,
              song.audioTitle,
              artistName,
              imagePath: imageUrl,
            )
          : null,
      onDownload: hasSongId
          ? () => _musicActionHandler.handleDownload(
              song.audioTitle,
              'song',
              songId,
              imagePath: imageUrl,
            )
          : null,
      onAddToPlaylist: hasSongId
          ? () => _musicActionHandler.handleAddToPlaylist(
              songId,
              song.audioTitle,
              artistName,
              imagePath: imageUrl,
            )
          : null,
      onShare: () => _musicActionHandler.handleShare(
        song.audioTitle,
        'song',
        itemId: songId,
        slug: song.audioSlug,
      ),
      onFavorite: hasSongId
          ? () => _musicActionHandler.handleFavoriteToggle(
              songId,
              song.audioTitle,
            )
          : null,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _controller.errorMessage ?? 'Unable to load content.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: appColors().colorText,
              ),
            ),
            SizedBox(height: 16.w),
            ElevatedButton(
              onPressed: _controller.loadContent,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInstantHomeSongTap(
    List<SongModel> songs,
    int tappedIndex,
  ) async {
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

    await _musicActionHandler.handleInstantPlay(
      payload: payloads[normalizedIndex],
      context: payloads,
      contextIndex: normalizedIndex,
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

  void _handleViewAll(_HomeSection section) {
    switch (section) {
      case _HomeSection.featuredVideos:
      case _HomeSection.popularVideos:
      case _HomeSection.newVideos:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VideoListScreen()),
        );
        break;
      case _HomeSection.channels:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChannelDirectoryScreen(
              channels: _controller.channelList,
              sharedTheme: _controller.theme,
            ),
          ),
        );
        break;
      case _HomeSection.featuredSongs:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllCategoryByName(_audioHandler, 'Featured Songs'),
          ),
        );
        break;
      case _HomeSection.latestSongs:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllCategoryByName(_audioHandler, 'New Songs'),
          ),
        );
        break;
      case _HomeSection.trendingGenres:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllCategoryByName(_audioHandler, 'Trending Genres'),
          ),
        );
        break;
    }
  }

  void _openVideo(VideoModel video) {
    final videoUrl = video.videoUrl;

    if (videoUrl.isEmpty) {
      _showSnackbar('Video unavailable.');
      return;
    }

    final item = _toVideoItem(video, videoUrl);

    launchVideoPlayer(
      context,
      videoUrl: videoUrl,
      videoId: video.id.toString(),
      videoTitle: video.title,
      videoSubtitle: video.channelName,
      thumbnailUrl: item.thumbnailUrl,
      videoItem: item,
    );
  }

  VideoItem _toVideoItem(VideoModel video, String videoUrl) {
    return VideoItem(
      id: video.id,
      title: video.title,
      videoUrl: videoUrl,
      thumbnailUrl: _resolveVideoThumb(video),
      duration: video.duration,
      description: video.description,
      channelId: video.channelId,
      channelName: video.channelName,
      channelHandle: video.channelHandle,
      channelImageUrl: video.channelImageUrl,
      createdAt: DateTime.tryParse(video.createdAt),
      subscribed: video.subscribed == null ? null : video.subscribed == 1,
      like: video.like,
      totalViews: video.totalViews,
      totalLikes: video.totalLikes,
      isOwn: video.isOwn,
    );
  }

  void _openChannel(ChannelModel channel) {
    final channelId = channel.id;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelVideosScreen(
          channelId: channelId,
          channelName: channel.name,
        ),
      ),
    );
  }

  void _handleGenreTap(GenreModel genre) {
    final genreId = genre.id?.toString();
    if (genreId == null || genreId.isEmpty) {
      _showSnackbar('Genre unavailable.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MusicList(_audioHandler, genreId, 'Trending Genres', genre.name),
      ),
    );
  }

  String _resolveVideoThumb(VideoModel video) {
    if (video.thumbnailUrl.isNotEmpty) return video.thumbnailUrl;
    return '';
  }

  String _resolveSongImage(SongModel song) {
    if (song.imageUrl.isNotEmpty) return song.imageUrl;
    if (song.bannerImage?.isNotEmpty == true) {
      final raw = song.bannerImage!;
      if (raw.startsWith('http')) return raw;
      return '${AppConstant.ImageUrl}$raw';
    }
    return '';
  }

  String _resolveChannelImage(ChannelModel channel) {
    if (channel.imageUrl.isNotEmpty) return channel.imageUrl;
    if (channel.image.isNotEmpty) return channel.image;
    return '';
  }

  String _resolveGenreImage(GenreModel genre) {
    if (genre.imageUrl?.isNotEmpty == true) return genre.imageUrl!;
    if (genre.image?.isNotEmpty == true) {
      final raw = genre.image!;
      if (raw.startsWith('http')) return raw;
      return '${AppConstant.ImageUrl}$raw';
    }
    return '';
  }

  String _artistName(SongModel song) {
    final name = song.channelName.trim();
    if (name.isNotEmpty) return name;
    return 'Unknown Artist';
  }

  String? _formatListenCount(int? listens) {
    if (listens == null || listens <= 0) return null;
    return '${_numberFormat.format(listens)} listens';
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _HomeSection {
  featuredVideos,
  channels,
  featuredSongs,
  latestSongs,
  popularVideos,
  trendingGenres,
  newVideos,
}
