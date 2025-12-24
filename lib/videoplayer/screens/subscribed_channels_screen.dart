import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/videoplayer/models/channel_item.dart';
import 'package:jainverse/videoplayer/services/subscribed_channels_service.dart';
import 'package:jainverse/videoplayer/screens/channel_detail_screen.dart';
import 'package:jainverse/videoplayer/services/subscription_service.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/widgets/animated_subscribe_button.dart';
import 'package:jainverse/widgets/common/loader.dart';

/// Ultra-modern minimalist subscribed channels screen
class SubscribedChannelsScreen extends StatefulWidget {
  const SubscribedChannelsScreen({super.key});

  @override
  State<SubscribedChannelsScreen> createState() =>
      _SubscribedChannelsScreenState();
}

class _SubscribedChannelsScreenState extends State<SubscribedChannelsScreen> {
  final SubscribedChannelsService _service = SubscribedChannelsService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final SubscriptionStateManager _subscriptionManager =
      SubscriptionStateManager();
  final Set<int> _loadingChannels = <int>{};

  List<ChannelItem> _channels = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _subscriptionManager.addListener(_onSubscriptionStateChanged);
    _loadSubscribedChannels();
  }

  @override
  void dispose() {
    _subscriptionManager.removeListener(_onSubscriptionStateChanged);
    super.dispose();
  }

  void _onSubscriptionStateChanged() {
    if (!mounted) return;
    _channels.removeWhere((channel) => !_isChannelSubscribed(channel));
    if (!mounted) return;
    setState(() {
      // Refresh list and buttons whenever the shared state mutates.
    });
  }

  Future<void> _loadSubscribedChannels() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final channels = await _service.getSubscribedChannels();
      if (mounted) {
        setState(() {
          _channels = channels;
          _isLoading = false;
        });
        _syncSubscriptionState(channels);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final channels = await _service.getSubscribedChannels();
      if (mounted) {
        setState(() {
          _channels = channels;
          _hasError = false;
        });
      }
      _syncSubscriptionState(channels);
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to refresh channels');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Subscribed Channels',
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
      body: RefreshIndicator(
        color: appColors().primaryColorApp,
        onRefresh: _onRefresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _channels.isEmpty) {
      return Center(child: CircleLoader(size: 270.w));
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_isRefreshing)
          SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 2,
              color: appColors().primaryColorApp,
              backgroundColor: Colors.transparent,
            ),
          ),
        if (_hasError && _channels.isEmpty)
          _buildErrorState()
        else if (_channels.isEmpty)
          _buildEmptyState()
        else
          _buildChannelList(),
        _buildBottomSpacer(),
      ],
    );
  }

  Widget _buildChannelList() {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final channel = _channels[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildChannelCard(channel),
          );
        }, childCount: _channels.length),
      ),
    );
  }

  Widget _buildChannelCard(ChannelItem channel) {
    final bool isSubscribed = _isChannelSubscribed(channel);
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
                child: channel.imageUrl.isNotEmpty
                    ? Image.network(
                        channel.imageUrl,
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
                      '@${channel.handle}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              // Subscribe button (animated) - hide if this is the user's own channel
              SizedBox(
                child: channel.isOwn
                    ? const SizedBox.shrink()
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          IgnorePointer(
                            ignoring: isLoading,
                            child: AnimatedSubscribeButton(
                              isSubscribed: isSubscribed,
                              onPressed: () => _toggleSubscription(channel),
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

  Widget _placeholderAvatar() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: const Icon(Icons.person_rounded, color: Color(0xFFBDBDBD)),
    );
  }

  bool _isChannelSubscribed(ChannelItem channel) {
    final bool? cached = _subscriptionManager.getSubscriptionState(channel.id);
    if (cached != null) {
      return cached;
    }
    return channel.subscribed ?? true;
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
                'Failed to load subscribed channels',
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
                onPressed: _loadSubscribedChannels,
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
                Icons.subscriptions_outlined,
                size: 56.sp,
                color: const Color(0xFFBDBDBD),
              ),
              SizedBox(height: 20.h),
              Text(
                'No subscribed channels',
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
                'Channels you subscribe to will appear here',
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

  Widget _buildBottomSpacer() {
    return SliverToBoxAdapter(
      child: SizedBox(height: AppPadding.bottom(context, extra: 50.w)),
    );
  }

  Future<void> _toggleSubscription(ChannelItem channel) async {
    final int channelId = channel.id;
    if (_loadingChannels.contains(channelId)) return;

    final bool currentState = _isChannelSubscribed(channel);
    final bool nextState = !currentState;
    setState(() {
      _loadingChannels.add(channelId);
    });

    // Optimistic UI update
    _subscriptionManager.updateSubscriptionState(channelId, nextState);

    try {
      if (nextState) {
        await _subscriptionService.subscribeChannel(channelId: channelId);
      } else {
        await _subscriptionService.unsubscribeChannel(channelId: channelId);
        // Remove from list when unsubscribed
        if (mounted) {
          setState(() {
            _channels.removeWhere((c) => c.id == channelId);
          });
        }
      }
    } catch (e) {
      // Revert optimistic update
      _subscriptionManager.updateSubscriptionState(channelId, currentState);
      _showSnackbar('Unable to update subscription');
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingChannels.remove(channelId);
      });
    }
  }

  void _syncSubscriptionState(List<ChannelItem> channels) {
    for (final channel in channels) {
      _subscriptionManager.updateSubscriptionState(channel.id, true);
    }
  }

  void _openChannel(ChannelItem channel) {
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
