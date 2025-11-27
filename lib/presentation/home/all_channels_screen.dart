import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/Model/channel_model.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/presenters/video_see_all_presenter.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/screens/channel_detail_screen.dart';
import 'package:jainverse/videoplayer/services/subscription_service.dart';
import 'package:jainverse/videoplayer/widgets/animated_subscribe_button.dart';
import 'package:jainverse/widgets/common/loader.dart';

/// Ultra-modern minimalist channels screen
class AllChannelsScreen extends StatefulWidget {
  const AllChannelsScreen({super.key, this.title, this.pageSize = 15});

  final String? title;
  final int pageSize;

  @override
  State<AllChannelsScreen> createState() => _AllChannelsScreenState();
}

class _AllChannelsScreenState extends State<AllChannelsScreen> {
  late final HomeSectionSeeAllPresenter _presenter;
  late final ScrollController _scrollController;
  bool _autoLoadScheduled = false;
  final SubscriptionService _subscriptionService = SubscriptionService();
  final SubscriptionStateManager _subscriptionManager =
      SubscriptionStateManager();
  final Set<int> _loadingChannels = <int>{};
  final NumberFormat _numberFormat = NumberFormat.compact();

  @override
  void initState() {
    super.initState();
    _presenter = HomeSectionSeeAllPresenter(
      type: SeeAllSectionType.channels,
      pageSize: widget.pageSize,
    );
    _scrollController = ScrollController()..addListener(_onScroll);
    _subscriptionManager.addListener(_onSubscriptionStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presenter.initialize(context);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _subscriptionManager.removeListener(_onSubscriptionStateChanged);
    _presenter.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _maybeTriggerPagination();
  }

  void _onSubscriptionStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onRefresh() {
    return _presenter.refresh(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Channels';
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
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
                if (_presenter.isRefreshing)
                  SliverToBoxAdapter(
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: appColors().primaryColorApp,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                if (_presenter.hasError && !_presenter.hasContent)
                  _buildErrorState()
                else if (_presenter.isEmpty)
                  _buildEmptyState()
                else
                  _buildChannelList(),
                _buildFooter(),
                _buildBottomSpacer(),
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

  Widget _buildChannelList() {
    final channels = _presenter.channels;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final channel = channels[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildChannelCard(channel),
          );
        }, childCount: channels.length),
      ),
    );
  }

  Widget _buildChannelCard(ChannelModel channel) {
    final bool isSubscribed =
        _subscriptionManager.getSubscriptionState(channel.id) ??
        channel.subscribed;
    final bool isLoading = _loadingChannels.contains(channel.id);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => _openChannel(channel),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              // Clean avatar
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.r),
                ),
                clipBehavior: Clip.antiAlias,
                child: channel.imageUrl.isNotEmpty || channel.image.isNotEmpty
                    ? Image.network(
                        channel.imageUrl.isNotEmpty
                            ? channel.imageUrl
                            : channel.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderAvatar(),
                      )
                    : _placeholderAvatar(),
              ),
              SizedBox(width: 14.w),
              // Channel info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${_formatSubscriberCount(channel.subscribersCount)} subscribers',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              // Subscribe button (animated)
              SizedBox(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IgnorePointer(
                      ignoring: isLoading,
                      child: AnimatedSubscribeButton(
                        isSubscribed: isSubscribed,
                        onPressed: () =>
                            _toggleSubscription(channel, isSubscribed),
                      ),
                    ),
                    if (isLoading)
                      SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            appColors().primaryColorApp,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMinimalButton({
    required bool isSubscribed,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    // This helper is no longer used. Keep a simple placeholder in case
    // other code references it in the future.
    return const SizedBox.shrink();
  }

  Widget _placeholderAvatar() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: const Icon(Icons.person_rounded, color: Color(0xFFBDBDBD)),
    );
  }

  Widget _buildErrorState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 56.sp,
                color: const Color(0xFFBDBDBD),
              ),
              SizedBox(height: 20.h),
              Text(
                _presenter.errorMessage ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Please try again',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF666666),
                ),
              ),
              SizedBox(height: 24.h),
              TextButton(
                onPressed: () => _presenter.refresh(context),
                style: TextButton.styleFrom(
                  backgroundColor: appColors().primaryColorApp,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
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
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 56.sp,
                color: const Color(0xFFBDBDBD),
              ),
              SizedBox(height: 20.h),
              Text(
                'No channels yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Check back later for new content',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 16.h, 0, 0),
        child: _presenter.isLoadingMore
            ? Center(
                child: SizedBox(
                  width: 32.w,
                  height: 32.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      appColors().primaryColorApp,
                    ),
                  ),
                ),
              )
            : !_presenter.hasMore && _presenter.hasContent
            ? Center(
                child: Text(
                  'All caught up',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF999999),
                  ),
                ),
              )
            : SizedBox(height: 12.h),
      ),
    );
  }

  Widget _buildBottomSpacer() {
    return SliverToBoxAdapter(
      child: SizedBox(height: AppPadding.bottom(context, extra: 50.w)),
    );
  }

  Future<void> _toggleSubscription(
    ChannelModel channel,
    bool isSubscribed,
  ) async {
    final int channelId = channel.id;
    if (_loadingChannels.contains(channelId)) return;

    final bool nextState = !isSubscribed;
    setState(() {
      _loadingChannels.add(channelId);
    });

    _subscriptionManager.updateSubscriptionState(channelId, nextState);

    try {
      if (nextState) {
        await _subscriptionService.subscribeChannel(channelId: channelId);
      } else {
        await _subscriptionService.unsubscribeChannel(channelId: channelId);
      }
    } catch (e) {
      _subscriptionManager.updateSubscriptionState(channelId, isSubscribed);
      _showSnackbar('Unable to update subscription');
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingChannels.remove(channelId);
      });
    }
  }

  void _openChannel(ChannelModel channel) {
    if (channel.id == 0) {
      _showSnackbar('Channel unavailable');
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

  String _formatSubscriberCount(int count) {
    if (count <= 0) return '0';
    return _numberFormat.format(count);
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }
}
