import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/song_model.dart';
import 'package:jainverse/Model/video_model.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/models/song_playback_payload.dart';
import 'package:jainverse/presenters/channel_detail_presenter.dart';
import 'package:jainverse/repositories/channel_detail_repository.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/services/media_overlay_manager.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:jainverse/utils/video_player_launcher.dart';
import 'package:jainverse/videoplayer/managers/like_dislike_state_manager.dart';
import 'package:jainverse/videoplayer/managers/report_state_manager.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/services/subscription_service.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';
import 'package:jainverse/widgets/music/song_card.dart';

AudioPlayerHandler? _audioHandler;

class ChannelVideosScreen extends StatefulWidget {
  final int channelId;
  final String? channelName;

  const ChannelVideosScreen({
    super.key,
    required this.channelId,
    this.channelName,
  });

  @override
  State<ChannelVideosScreen> createState() => _ChannelVideosScreenState();
}

class _ChannelVideosScreenState extends State<ChannelVideosScreen>
    with SingleTickerProviderStateMixin {
  late final ChannelDetailPresenter _presenter;
  late final TabController _tabController;
  late final MusicActionHandler _musicActionHandler;
  final SubscriptionService _subscriptionService = SubscriptionService();
  final FavoriteService _favoriteService = FavoriteService();
  final SharedPref _sharedPref = SharedPref();
  final NumberFormat _numberFormat = NumberFormat.compact();
  final ScrollController _scrollController = ScrollController();

  ModelTheme _sharedTheme = ModelTheme('', '', '', '', '', '');
  int? _currentUserId;
  bool? _lastHasMiniPlayer;
  bool _isSubscriptionInFlight = false;
  bool _isHeaderExpanded = true;

  @override
  void initState() {
    super.initState();
    _audioHandler = const MyApp().called();
    _presenter = ChannelDetailPresenter()..addListener(_onPresenterChanged);
    _tabController = TabController(length: 2, vsync: this);
    _musicActionHandler = MusicActionHandlerFactory.create(
      context: context,
      audioHandler: _audioHandler,
      favoriteService: _favoriteService,
      onStateUpdate: () => mounted ? setState(() {}) : null,
    );

    _scrollController.addListener(_onScroll);
    SubscriptionStateManager().addListener(_onSubscriptionChanged);
    LikeDislikeStateManager().addListener(_onLikeDislikeChanged);
    ReportStateManager().addListener(_onReportChanged);

    _loadTheme();
    _loadCurrentUserId();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presenter.fetchChannelDetail(widget.channelId);
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final shouldExpand = _scrollController.offset < 100;
      if (shouldExpand != _isHeaderExpanded) {
        setState(() {
          _isHeaderExpanded = shouldExpand;
        });
      }
    }
  }

  Future<void> _loadTheme() async {
    try {
      final stored = await _sharedPref.getThemeData();
      if (!mounted) return;
      if (stored is ModelTheme) {
        setState(() {
          _sharedTheme = stored;
        });
      }
    } catch (error) {
      debugPrint('Error loading theme for channel screen: $error');
    }
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userData = await _sharedPref.getUserData();
      if (!mounted || userData == null) return;

      int? uid;
      try {
        if (userData is Map && userData['id'] != null) {
          uid = userData['id'] as int?;
        } else if (userData.runtimeType.toString().contains('UserModel')) {
          uid = (userData as dynamic).data.id as int?;
        } else if (userData.runtimeType.toString().contains('UserData')) {
          uid = (userData as dynamic).id as int?;
        }
      } catch (error) {
        debugPrint('Error extracting user id from stored user data: $error');
      }

      if (!mounted) return;
      setState(() {
        _currentUserId = uid;
      });
    } catch (error) {
      debugPrint('Error loading current user ID: $error');
    }
  }

  bool get _isOwnChannel {
    final channel = _presenter.state.channel;
    if (channel == null) return false;
    if (channel.isOwn) return true;
    if (_currentUserId != null && channel.userId == _currentUserId) {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _presenter.removeListener(_onPresenterChanged);
    _tabController.dispose();
    SubscriptionStateManager().removeListener(_onSubscriptionChanged);
    LikeDislikeStateManager().removeListener(_onLikeDislikeChanged);
    ReportStateManager().removeListener(_onReportChanged);
    super.dispose();
  }

  void _onPresenterChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onLikeDislikeChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onReportChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleSubscription() async {
    final channel = _presenter.state.channel;
    if (channel == null || _isOwnChannel || _isSubscriptionInFlight) {
      return;
    }

    final bool nextValue = !channel.isSubscribed;
    setState(() {
      _isSubscriptionInFlight = true;
    });
    _presenter.updateSubscription(nextValue);
    SubscriptionStateManager().updateSubscriptionState(
      widget.channelId,
      nextValue,
    );

    try {
      if (nextValue) {
        await _subscriptionService.subscribeChannel(
          channelId: widget.channelId,
        );
      } else {
        await _subscriptionService.unsubscribeChannel(
          channelId: widget.channelId,
        );
      }
    } catch (_) {
      _presenter.updateSubscription(!nextValue);
      SubscriptionStateManager().updateSubscriptionState(
        widget.channelId,
        !nextValue,
      );
      _showSnackBar('Failed to update subscription');
    } finally {
      if (mounted) {
        setState(() {
          _isSubscriptionInFlight = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _presenter.fetchChannelDetail(widget.channelId);
  }

  @override
  Widget build(BuildContext context) {
    final channel = _presenter.state.channel;
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: _buildTopAppBar(channel),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final state = _presenter.state;
    if (state.isLoading && !state.hasContent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && !state.hasContent) {
      return _buildErrorState(state.error!);
    }

    final AudioPlayerHandler audioHandler =
        _audioHandler ?? const MyApp().called();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final hasMiniPlayer = snapshot.hasData;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_lastHasMiniPlayer == hasMiniPlayer) return;
          _lastHasMiniPlayer = hasMiniPlayer;
          if (hasMiniPlayer) {
            MediaOverlayManager.instance.showMiniPlayer(
              type: MediaOverlayType.audioMini,
            );
          } else {
            MediaOverlayManager.instance.hideMiniPlayer();
          }
        });

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: appColors().primaryColorApp,
          child: NestedScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildModernHeader(state),
              SliverToBoxAdapter(child: _buildModernTabBar()),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [_buildVideosTab(state), _buildSongsTab(state)],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildTopAppBar(ChannelDetailInfo? channel) {
    final showCollapsedTitle = !_isHeaderExpanded && channel != null;
    final Color backgroundColor = _isHeaderExpanded
        ? Colors.transparent
        : Colors.white;
    final Color iconColor = _isHeaderExpanded
        ? Colors.white
        : Colors.grey.shade900;

    return AppBar(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: _isHeaderExpanded ? Colors.transparent : Colors.black12,
      elevation: _isHeaderExpanded ? 0 : 2,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 20.w),
        color: iconColor,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: showCollapsedTitle
            ? Text(
                channel.name,
                key: const ValueKey('channel_title_collapsed'),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              )
            : const SizedBox.shrink(key: ValueKey('channel_title_placeholder')),
      ),
      systemOverlayStyle: _isHeaderExpanded
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      iconTheme: IconThemeData(color: iconColor),
    );
  }

  Widget _buildModernHeader(ChannelDetailState state) {
    final channel = state.channel;
    if (channel == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final double avatarSize = 100.w;

    Widget buildBanner() {
      final Widget image = channel.bannerUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: channel.bannerUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Container(color: Colors.grey.shade200),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    appColors().primaryColorApp.shade400,
                    appColors().primaryColorApp.shade700,
                  ],
                ),
              ),
            );

      return Stack(
        fit: StackFit.expand,
        children: [
          image,
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.white,
                  Colors.white70,
                  Colors.white30,
                  Colors.white10,
                  Colors.transparent,
                ],
                stops: [0.0, 0.05, 0.12, 0.18, 1.0],
              ),
            ),
          ),
        ],
      );
    }

    Widget buildAvatar() {
      return Hero(
        tag: 'channel_avatar_${channel.userId}',
        child: Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            backgroundImage: channel.imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(channel.imageUrl)
                : null,
            child: channel.imageUrl.isEmpty
                ? Icon(Icons.person, size: 40.w, color: Colors.white)
                : null,
          ),
        ),
      );
    }

    final descriptionWidget = _buildDescriptionPreview(state);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: SizedBox(
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.w),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: buildBanner(),
                    ),
                  ),
                  Positioned(
                    left: 20.w,
                    bottom: -avatarSize / 1.5,
                    child: buildAvatar(),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: avatarSize + 20.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: avatarSize / 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        if (channel.handle.isNotEmpty) ...[
                          SizedBox(height: 6.h),
                          Text(
                            '@${channel.handle}',
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.w),
          _buildSubscriberRow(channel),
          SizedBox(height: 16.w),
          if (descriptionWidget != null) ...[
            descriptionWidget,
            SizedBox(height: 16.w),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriberRow(ChannelDetailInfo channel) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!_isOwnChannel) ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 100.w,
                      maxWidth: 240.w,
                    ),
                    child: _buildModernSubscribeButton(channel),
                  ),
                  SizedBox(width: 12.w),
                ],
                Expanded(
                  child: Text(
                    '${_numberFormat.format(channel.subscribersCount)} subscribers',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // If channel has no description, surface the More button here
                if ((channel.description ?? '').trim().isEmpty) ...[
                  SizedBox(width: 12.w),
                  _buildInfoMoreButton(_presenter.state),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildDescriptionPreview(ChannelDetailState state) {
    final channel = state.channel;
    if (channel == null) return null;
    final description = channel.description.trim();
    if (description.isEmpty) return null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          _buildInfoMoreButton(state),
        ],
      ),
    );
  }

  Widget _buildInfoMoreButton(ChannelDetailState state) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: state.channel == null
            ? null
            : () => _showChannelInfoSheet(state),
        borderRadius: BorderRadius.circular(16.w),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.w),
            border: Border.all(color: appColors().primaryColorApp, width: 1),
          ),
          child: Text(
            'More',
            style: TextStyle(
              color: appColors().primaryColorApp,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showChannelInfoSheet(ChannelDetailState state) {
    final channel = state.channel;
    if (channel == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final sheetHeight = (media.size.height * 0.78).clamp(
          320.0,
          media.size.height * 0.95,
        );

        return SizedBox(
          height: sheetHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.w)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: _buildChannelInfoContent(state, sheetContext),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernTabBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.w),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent, // Add this line
        labelColor: appColors().primaryColorApp,
        unselectedLabelColor: Colors.grey.shade700,
        labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
        indicator: BoxDecoration(
          color: appColors().primaryColorApp.withOpacity(0.12),
          borderRadius: BorderRadius.circular(28.w),
        ),
        indicatorPadding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 4.w),
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: NoSplash.splashFactory,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam, size: 18.w),
                SizedBox(width: 8.w),
                Text('Videos'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note, size: 18.w),
                SizedBox(width: 8.w),
                Text('Songs'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSubscribeButton(ChannelDetailInfo channel) {
    return SizedBox(
      height: 44.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            ignoring: _isSubscriptionInFlight,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.w),
                gradient: channel.isSubscribed
                    ? null
                    : LinearGradient(
                        colors: [
                          appColors().primaryColorApp.shade300,
                          appColors().primaryColorApp.shade600,
                        ],
                      ),
                color: channel.isSubscribed ? Colors.grey.shade200 : null,
                boxShadow: channel.isSubscribed
                    ? null
                    : [
                        BoxShadow(
                          color: appColors().primaryColorApp.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24.w),
                  onTap: _toggleSubscription,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 32.w,
                      vertical: 12.h,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          channel.isSubscribed ? Icons.check : Icons.add,
                          color: channel.isSubscribed
                              ? Colors.grey.shade700
                              : Colors.white,
                          size: 20.w,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          channel.isSubscribed ? 'Subscribed' : 'Subscribe',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: channel.isSubscribed
                                ? Colors.grey.shade700
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isSubscriptionInFlight)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.w),
                  color: Colors.white.withOpacity(0.7),
                ),
                child: Center(
                  child: SizedBox(
                    height: 20.w,
                    width: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideosTab(ChannelDetailState state) {
    final videos = state.videos;
    if (videos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.videocam_off_rounded,
        message: 'No videos yet',
        subtitle: 'Check back later for new content',
      );
    }

    final bottomPadding = AppPadding.bottom(context, extra: 150.w) + 16.h;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomPadding),
      itemCount: videos.length,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        final video = videos[index];
        final videoItem = VideoItem.fromVideoModel(
          video,
        ).syncWithGlobalState().syncLikeWithGlobalState();
        return _buildModernVideoCard(
          videoItem,
          () => _openVideo(videos, index),
        );
      },
    );
  }

  Widget _buildModernVideoCard(VideoItem videoItem, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.w),
          onTap: onTap,
          child: VideoCard(item: videoItem, onTap: onTap),
        ),
      ),
    );
  }

  Widget _buildSongsTab(ChannelDetailState state) {
    final songs = state.songs;
    if (songs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.music_note_outlined,
        message: 'No songs yet',
        subtitle: 'Check back later for new music',
      );
    }

    final width = MediaQuery.of(context).size.width;
    final bool isTablet = width >= 600;
    final crossAxisCount = isTablet ? 4 : 3;

    final bottomPadding = AppPadding.bottom(context, extra: 32.w) + 24.h;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 0.72,
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongCard(
          songId: song.id.toString(),
          imagePath: _resolveSongImage(song),
          songName: song.audioTitle,
          artistName: song.channelName,
          sharedPreThemeData: _sharedTheme,
          enableContextMenu: false,
          onTap: () => _handleInstantSongTap(songs, index),
        );
      },
    );
  }

  Widget _buildChannelInfoContent(
    ChannelDetailState state,
    BuildContext sheetContext,
  ) {
    final channel = state.channel;
    final bottomPadding = AppPadding.bottom(sheetContext, extra: 32.w) + 24.h;

    Widget buildBody() {
      if (channel == null) {
        return Center(
          child: _buildEmptyState(
            icon: Icons.info_outline,
            message: 'Information unavailable',
            subtitle: 'Channel details could not be loaded',
          ),
        );
      }

      return ListView(
        padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, bottomPadding),
        children: [
          _buildModernStatsCards(channel, state, sheetContext),
          SizedBox(height: 20.h),
          if (channel.description.isNotEmpty) ...[
            _buildInfoSection(
              title: 'About',
              child: Text(
                channel.description,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
          _buildInfoSection(
            title: 'Details',
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: 'Joined',
                  value: _formatDate(channel.createdAt),
                ),
                if (channel.handle.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  _buildInfoRow(
                    icon: Icons.alternate_email,
                    label: 'Handle',
                    value: '@${channel.handle}',
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(height: 12.h),
        Container(
          width: 44.w,
          height: 5.h,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        SizedBox(height: 12.h),
        Expanded(child: buildBody()),
      ],
    );
  }

  Widget _buildModernStatsCards(
    ChannelDetailInfo channel,
    ChannelDetailState state,
    BuildContext? sheetContext,
  ) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16.w),
              onTap: sheetContext == null
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      _tabController.animateTo(0);
                    },
              child: _buildStatCard(
                icon: Icons.video_library,
                label: 'Videos',
                value: state.videos.length,
                color: Colors.red,
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16.w),
              onTap: sheetContext == null
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      _tabController.animateTo(1);
                    },
              child: _buildStatCard(
                icon: Icons.music_note,
                label: 'Songs',
                value: state.songs.length,
                color: appColors().primaryColorApp,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 12.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.w),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24.w, color: color),
          ),
          SizedBox(height: 10.h),
          Text(
            _numberFormat.format(value),
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8.w),
          ),
          child: Icon(icon, size: 18.w, color: Colors.grey.shade700),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48.w, color: Colors.grey.shade400),
            ),
            SizedBox(height: 20.h),
            Text(
              message,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48.w,
                color: Colors.red.shade400,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () => _presenter.fetchChannelDetail(widget.channelId),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors().primaryColorApp,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.w),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVideo(List<VideoModel> videos, int tappedIndex) {
    if (tappedIndex < 0 || tappedIndex >= videos.length) return;
    final video = videos[tappedIndex];
    if (video.videoUrl.isEmpty) {
      _showSnackBar('Video unavailable.');
      return;
    }

    final contextItems = videos
        .map(
          (entry) => VideoItem.fromVideoModel(
            entry,
          ).syncWithGlobalState().syncLikeWithGlobalState(),
        )
        .toList(growable: false);
    final videoItem = contextItems[tappedIndex];
    final contextLabel =
        widget.channelName ??
        _presenter.state.channel?.name ??
        'Channel Videos';

    launchVideoPlayer(
      context,
      videoUrl: video.videoUrl,
      videoId: video.id.toString(),
      videoTitle: video.title,
      videoSubtitle: video.channelName,
      thumbnailUrl: video.thumbnailUrl,
      videoItem: videoItem,
      contextVideos: contextItems,
      contextLabel: contextLabel,
    );
  }

  Future<void> _handleInstantSongTap(
    List<SongModel> songs,
    int tappedIndex,
  ) async {
    if (tappedIndex < 0 || tappedIndex >= songs.length) return;
    final tappedSong = songs[tappedIndex];
    final fallbackSongId = tappedSong.id.toString();
    final identifier = fallbackSongId.isNotEmpty
        ? fallbackSongId
        : tappedSong.audioUrl.trim();

    if (identifier.isEmpty) {
      _showSnackBar('Song unavailable.');
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
      (payload) => payload.id == identifier,
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
      _showSnackBar('Song unavailable.');
      return;
    }
    await _musicActionHandler.handlePlaySong(songId, songTitle);
  }

  String _resolveSongImage(SongModel song) {
    if (song.imageUrl.isNotEmpty) return song.imageUrl;
    if ((song.bannerImage ?? '').isNotEmpty) return song.bannerImage!;
    return '';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.w),
        ),
        margin: EdgeInsets.all(16.w),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value);
      return DateFormat.yMMMMd().format(date);
    } catch (_) {
      return value;
    }
  }
}
