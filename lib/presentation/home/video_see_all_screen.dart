import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/channel_model.dart';
import 'package:jainverse/Model/video_model.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/presenters/video_see_all_presenter.dart';
import 'package:jainverse/utils/video_player_launcher.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/screens/channel_detail_screen.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';
import 'package:jainverse/widgets/common/loader.dart';
import 'package:jainverse/widgets/music/circular_card.dart';

class HomeSectionSeeAllScreen extends StatefulWidget {
  const HomeSectionSeeAllScreen({
    super.key,
    required this.sectionType,
    this.title,
    this.sharedTheme,
    this.pageSize = 15,
  });

  final SeeAllSectionType sectionType;
  final String? title;
  final ModelTheme? sharedTheme;
  final int pageSize;

  @override
  State<HomeSectionSeeAllScreen> createState() =>
      _HomeSectionSeeAllScreenState();
}

class _HomeSectionSeeAllScreenState extends State<HomeSectionSeeAllScreen> {
  late final HomeSectionSeeAllPresenter _presenter;
  late final ScrollController _scrollController;
  late ModelTheme _theme;
  bool _autoLoadScheduled = false;

  @override
  void initState() {
    super.initState();
    _theme = widget.sharedTheme ?? ModelTheme('', '', '', '', '', '');
    _presenter = HomeSectionSeeAllPresenter(
      type: widget.sectionType,
      pageSize: widget.pageSize,
    );
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presenter.initialize(context);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _presenter.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _maybeTriggerPagination();
  }

  Future<void> _onRefresh() {
    return _presenter.refresh(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? widget.sectionType.label;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AnimatedBuilder(
        animation: _presenter,
        builder: (context, _) {
          if (_presenter.isInitialLoading && !_presenter.hasContent) {
            return Center(child: CircleLoader(size: 270.w));
          }

          _scheduleAutoLoadCheck();

          return RefreshIndicator(
            color: appColors().primaryColorApp,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_presenter.hasError && !_presenter.hasContent)
                  _buildErrorState()
                else if (_presenter.isEmpty)
                  _buildEmptyState()
                else if (widget.sectionType.isVideo)
                  _buildVideoSection()
                else
                  _buildChannelSection(),
                _buildFooter(),
              ],
            ),
          );
        },
      ),
    );
  }

  void _scheduleAutoLoadCheck() {
    if (_autoLoadScheduled) return;
    _autoLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoadScheduled = false;
      if (!mounted) return;
      _maybeTriggerPagination();
    });
  }

  void _maybeTriggerPagination() {
    if (!_scrollController.hasClients || !_presenter.hasMore) return;
    if (_presenter.isInitialLoading ||
        _presenter.isLoadingMore ||
        _presenter.isRefreshing ||
        (_presenter.hasError && !_presenter.hasContent)) {
      return;
    }

    final position = _scrollController.position;
    final bool nearBottom = position.pixels >= position.maxScrollExtent - 200;
    final bool contentTooShort = position.extentAfter < 200;

    if (nearBottom || contentTooShort) {
      _presenter.loadMore(context);
    }
  }

  Widget _buildVideoSection() {
    final videos = _presenter.videos;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final video = videos[index];
          final item = VideoItem.fromVideoModel(
            video,
          ).syncWithGlobalState().syncLikeWithGlobalState();
          return Padding(
            padding: EdgeInsets.only(bottom: 18.h),
            child: VideoCard(item: item, onTap: () => _openVideo(video)),
          );
        }, childCount: videos.length),
      ),
    );
  }

  Widget _buildChannelSection() {
    final channels = _presenter.channels;
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100
        ? 6
        : width >= 900
        ? 5
        : width >= 700
        ? 4
        : width >= 500
        ? 3
        : 2;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final channel = channels[index];
          final subtitle = channel.handle.isNotEmpty
              ? '@${channel.handle}'
              : null;
          return CircularCard(
            imagePath: _resolveChannelImage(channel),
            title: channel.name,
            subtitle: subtitle,
            onTap: () => _openChannel(channel),
            sharedPreThemeData: _theme,
            size: 110,
          );
        }, childCount: channels.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 18.w,
          crossAxisSpacing: 12.w,
          childAspectRatio: 0.75,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _presenter.errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16.sp, color: appColors().colorText),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () => _presenter.refresh(context),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Text(
            'Nothing to show here yet. Please check back later.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16.sp, color: appColors().colorText),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 12.h, 0, AppPadding.bottom(context)),
        child: _presenter.isLoadingMore
            ? Center(
                child: SizedBox(
                  width: 32.w,
                  height: 32.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.w,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      appColors().primaryColorApp,
                    ),
                  ),
                ),
              )
            : !_presenter.hasMore && _presenter.hasContent
            ? Center(
                child: Text(
                  'You\'re all caught up.',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: appColors().colorText,
                  ),
                ),
              )
            : SizedBox(height: 8.h),
      ),
    );
  }

  void _openVideo(VideoModel video) {
    final url = video.videoUrl;
    if (url.isEmpty) {
      _showSnackbar('Video unavailable.');
      return;
    }

    final item = VideoItem.fromVideoModel(video);
    launchVideoPlayer(
      context,
      videoUrl: url,
      videoId: video.id.toString(),
      videoTitle: video.title,
      videoSubtitle: video.channelName,
      thumbnailUrl: video.thumbnailUrl,
      videoItem: item,
    );
  }

  void _openChannel(ChannelModel channel) {
    if (channel.id == 0) {
      _showSnackbar('Channel unavailable.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelVideosScreen(
          channelId: channel.id,
          channelName: channel.name,
        ),
      ),
    );
  }

  String _resolveChannelImage(ChannelModel channel) {
    if (channel.imageUrl.isNotEmpty) return channel.imageUrl;
    if (channel.image.isNotEmpty) return channel.image;
    return '';
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
