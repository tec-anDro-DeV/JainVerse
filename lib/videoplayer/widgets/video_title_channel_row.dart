import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jainverse/videoplayer/widgets/animated_subscribe_button.dart';
import '../services/video_player_theme_service.dart';

/// Reusable title + channel row used by video player screens
class VideoTitleChannelRow extends StatelessWidget {
  final String title;
  final String channelName;
  final String? avatarUrl;
  final int? subscriberCount;
  final bool isSubscribed;
  final bool isSubscriptionInProgress;
  final bool showSubscribe;
  final VoidCallback onSubscribePressed;
  final VoidCallback? onChannelTap;
  final VideoPlayerTheme theme;

  const VideoTitleChannelRow({
    super.key,
    required this.title,
    required this.channelName,
    this.avatarUrl,
    this.subscriberCount,
    required this.isSubscribed,
    required this.isSubscriptionInProgress,
    required this.onSubscribePressed,
    this.onChannelTap,
    this.showSubscribe = true,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              InkWell(
                onTap: onChannelTap,
                borderRadius: BorderRadius.circular(32.w),
                child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? CircleAvatar(
                        radius: 24.w,
                        backgroundColor: Colors.transparent,
                        backgroundImage: CachedNetworkImageProvider(avatarUrl!),
                      )
                    : CircleAvatar(
                        radius: 24.w,
                        backgroundColor: theme.primaryColor.withOpacity(0.2),
                        child: Icon(
                          Icons.person,
                          color: theme.textColor,
                          size: 24.w,
                        ),
                      ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InkWell(
                  onTap: onChannelTap,
                  borderRadius: BorderRadius.circular(4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channelName,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subscriberCount != null) SizedBox(height: 4.h),
                      if (subscriberCount != null)
                        Text(
                          '${subscriberCount} subscribers',
                          style: TextStyle(
                            color: theme.textColor.withOpacity(0.7),
                            fontSize: 12.sp,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: 8.w),
              if (showSubscribe)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AbsorbPointer(
                      absorbing: isSubscriptionInProgress,
                      child: AnimatedSubscribeButton(
                        isSubscribed: isSubscribed,
                        onPressed: onSubscribePressed,
                      ),
                    ),
                    if (isSubscriptionInProgress)
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
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}
