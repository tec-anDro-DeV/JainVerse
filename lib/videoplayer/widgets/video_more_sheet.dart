import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/video_player_theme_service.dart';
import '../models/video_item.dart';
import '../managers/subscription_state_manager.dart';
import '../services/channel_video_service.dart';
import 'animated_subscribe_button.dart';

/// Reusable bottom sheet used by the video player "More" action.
class VideoMoreSheet extends StatefulWidget {
  final VideoPlayerTheme theme;
  final String videoIdString;
  final int? videoIdInt;
  final String? videoTitle;
  final VideoItem? videoItem;

  /// Desired height for the sheet. When provided the sheet will use this
  /// height so its top aligns with the intended UI element (e.g. the
  /// bottom of the video player).
  final double? sheetHeight;

  /// Parent context used for SnackBars / navigation that should target the
  /// underlying scaffold rather than the sheet's local context.
  final BuildContext parentContext;

  /// Optional handler invoked when the user taps "Report". If provided it
  /// will be called after the sheet is dismissed.
  final VoidCallback? onReport;

  // Subscription state + handlers
  final bool isSubscribed;
  final bool isSubscriptionInProgress;
  final VoidCallback? onSubscribePressed;

  // Channel footer tap handler
  final VoidCallback? onChannelTap;

  // Local optimistic like count (may be null)
  final int? localTotalLikes;

  // channel metadata fallbacks
  final int? channelSubscriberCount;
  final String? channelAvatarUrl;
  final String? channelName;
  // explicit channel id to support cases where VideoItem is not provided
  final int? channelId;

  const VideoMoreSheet({
    super.key,
    required this.theme,
    required this.videoIdString,
    required this.parentContext,
    this.videoIdInt,
    this.videoTitle,
    this.videoItem,
    this.onReport,
    this.sheetHeight,
    this.isSubscribed = false,
    this.isSubscriptionInProgress = false,
    this.onSubscribePressed,
    this.onChannelTap,
    this.localTotalLikes,
    this.channelSubscriberCount,
    this.channelAvatarUrl,
    this.channelName,
    this.channelId,
  });

  @override
  State<VideoMoreSheet> createState() => _VideoMoreSheetState();
}

class _VideoMoreSheetState extends State<VideoMoreSheet> {
  bool _expanded = false;
  // Local mirror of subscription state so the sheet can update independently
  // of the parent widget (modal sheets don't rebuild when the caller's
  // state changes). These are initialized from the incoming props.
  bool _isSubscribedLocal = false;
  bool _isSubscriptionInProgressLocal = false;
  int? _channelId;
  VideoItem? _fetchedVideo;
  bool _isFetchingMetadata = false;

  String _formatNumber(int? n) {
    if (n == null) return '0';
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildMetricCard(IconData icon, String mainText, String caption) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      constraints: BoxConstraints(minHeight: 64.h),
      decoration: BoxDecoration(
        // black translucent background for metric cards (no border)
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10.w),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20.w,
                color: widget.theme.textColor.withOpacity(0.9),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  mainText,
                  style: TextStyle(
                    color: widget.theme.textColor.withOpacity(0.95),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            caption,
            style: TextStyle(
              color: widget.theme.textColor.withOpacity(0.74),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _isSubscribedLocal = widget.isSubscribed;
    _isSubscriptionInProgressLocal = widget.isSubscriptionInProgress;
    // Prefer an explicit channelId prop; fall back to the passed VideoItem
    _channelId = widget.channelId ?? widget.videoItem?.channelId;

    // Register a global subscription listener so this sheet updates when
    // subscription state changes elsewhere in the app.
    if (_channelId != null) {
      SubscriptionStateManager().addListener(_onGlobalSubscriptionChanged);
      // seed initial value from manager if available
      final global = SubscriptionStateManager().getSubscriptionState(
        _channelId!,
      );
      if (global != null) {
        _isSubscribedLocal = global;
      }
    }

    // If the caller didn't provide a full VideoItem (common after minimize),
    // attempt to fetch the video's metadata from the channel's video list so
    // likes/views/description can be shown in the sheet.
    if (widget.videoItem == null &&
        widget.videoIdInt != null &&
        _channelId != null) {
      _fetchMetadata(widget.videoIdInt!, _channelId!);
    }
  }

  Future<void> _fetchMetadata(int videoId, int channelId) async {
    if (_isFetchingMetadata) return;
    _isFetchingMetadata = true;
    try {
      final svc = ChannelVideoService();
      final resp = await svc.fetchChannelVideos(
        channelId: channelId,
        perPage: 50,
      );
      final List<dynamic> data = resp['data'] ?? [];
      for (final item in data) {
        if (item is VideoItem) {
          if (item.id == videoId) {
            if (!mounted) return;
            setState(() {
              _fetchedVideo = item;
            });
            break;
          }
        }
      }
    } catch (e) {
      // ignore - optional metadata fetch
    } finally {
      _isFetchingMetadata = false;
    }
  }

  void _onGlobalSubscriptionChanged() {
    if (!mounted || _channelId == null) return;
    final global = SubscriptionStateManager().getSubscriptionState(_channelId!);
    if (global == null) return;
    if (global != _isSubscribedLocal) {
      setState(() {
        _isSubscribedLocal = global;
        // When subscription toggles globally, clear any in-progress flag
        _isSubscriptionInProgressLocal = false;
      });
    }
  }

  @override
  void dispose() {
    try {
      if (_channelId != null) {
        SubscriptionStateManager().removeListener(_onGlobalSubscriptionChanged);
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height =
        widget.sheetHeight ?? MediaQuery.of(context).size.height * 0.46;

    final video = widget.videoItem ?? _fetchedVideo;
    final title = widget.videoTitle ?? video?.title ?? '';
    final likes = widget.localTotalLikes ?? video?.totalLikes ?? 0;
    final views = video?.totalViews;
    final uploadedAt = video?.createdAt;
    final description = video?.description ?? '';
    final channelAvatar = video?.channelImageUrl ?? widget.channelAvatarUrl;
    final channelName = video?.channelName ?? widget.channelName ?? '';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
            child: Container(
              decoration: BoxDecoration(
                color: widget.theme.backgroundColor.withOpacity(0.75),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12.w)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top bar: center drag handle + close button on the right
                  // Use a Row with a left spacer so the handle is visually centered
                  // while the close button sits flush at the right.
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Row(
                      children: [
                        // left spacer equal to the close button area so the handle
                        // is centered visually within the available width
                        SizedBox(width: 48.w),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: 48.w,
                                height: 4.h,
                                decoration: BoxDecoration(
                                  color: widget.theme.textColor.withOpacity(
                                    0.45,
                                  ),
                                  borderRadius: BorderRadius.circular(2.w),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: widget.theme.textColor,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 6.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              color: widget.theme.textColor,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 10.h),

                          // Metrics as three small cards in a row
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  Icons.thumb_up_alt_outlined,
                                  _formatNumber(likes),
                                  'Likes',
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _buildMetricCard(
                                  Icons.visibility_outlined,
                                  views != null ? _formatNumber(views) : '-',
                                  'Views',
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _buildMetricCard(
                                  Icons.access_time,
                                  uploadedAt != null
                                      ? _timeAgo(uploadedAt)
                                      : '',
                                  'Uploaded',
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20.h),

                          // Description (collapsible) with heading and bordered container
                          if (description.isNotEmpty) ...[
                            Text(
                              'Description',
                              style: TextStyle(
                                color: widget.theme.textColor,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                color: widget.theme.backgroundColor.withOpacity(
                                  0.2,
                                ),
                                borderRadius: BorderRadius.circular(10.w),
                                border: Border.all(
                                  color: widget.theme.textColor.withOpacity(
                                    0.1,
                                  ),
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color: widget.theme.textColor.withOpacity(
                                        0.9,
                                      ),
                                      fontSize: 14.sp,
                                    ),
                                    maxLines: _expanded ? null : 3,
                                    overflow: _expanded
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 6.h),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                        () => _expanded = !_expanded,
                                      ),
                                      child: Text(
                                        _expanded ? 'less' : '...more',
                                        style: TextStyle(
                                          color: widget.theme.primaryColor,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12.h),
                          ],

                          // Channel footer
                          Divider(
                            color: widget.theme.textColor.withOpacity(0.08),
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  if (widget.onChannelTap != null)
                                    widget.onChannelTap!();
                                },
                                borderRadius: BorderRadius.circular(20.w),
                                child:
                                    (channelAvatar != null &&
                                        channelAvatar.isNotEmpty)
                                    ? CircleAvatar(
                                        radius: 20.w,
                                        backgroundColor: Colors.transparent,
                                        backgroundImage:
                                            CachedNetworkImageProvider(
                                              channelAvatar,
                                            ),
                                      )
                                    : CircleAvatar(
                                        radius: 20.w,
                                        backgroundColor: widget
                                            .theme
                                            .primaryColor
                                            .withOpacity(0.2),
                                        child: Icon(
                                          Icons.person,
                                          color: widget.theme.textColor,
                                          size: 20.w,
                                        ),
                                      ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    if (widget.onChannelTap != null)
                                      widget.onChannelTap!();
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        channelName,
                                        style: TextStyle(
                                          color: widget.theme.textColor,
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (widget.channelSubscriberCount != null)
                                        SizedBox(height: 4.h),
                                      if (widget.channelSubscriberCount != null)
                                        Text(
                                          '${widget.channelSubscriberCount} subscribers',
                                          style: TextStyle(
                                            color: widget.theme.textColor
                                                .withOpacity(0.7),
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  AbsorbPointer(
                                    absorbing: _isSubscriptionInProgressLocal,
                                    child: AnimatedSubscribeButton(
                                      isSubscribed: _isSubscribedLocal,
                                      onPressed: () {
                                        // Optimistically show progress in the sheet
                                        // until global state updates via the
                                        // SubscriptionStateManager listener.
                                        setState(() {
                                          _isSubscriptionInProgressLocal = true;
                                        });

                                        if (widget.onSubscribePressed != null)
                                          widget.onSubscribePressed!();
                                      },
                                    ),
                                  ),
                                  if (_isSubscriptionInProgressLocal)
                                    Positioned(
                                      right: -6.w,
                                      child: SizedBox(
                                        width: 18.w,
                                        height: 18.w,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
