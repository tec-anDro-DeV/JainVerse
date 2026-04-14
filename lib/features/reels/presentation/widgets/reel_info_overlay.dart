import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';

/// Bottom-left overlay showing channel avatar, name, and reel title.
class ReelInfoOverlay extends StatelessWidget {
  final ReelItem reel;

  const ReelInfoOverlay({super.key, required this.reel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Avatar(url: reel.channelImageUrl),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                reel.channelName.isNotEmpty
                    ? reel.channelName
                    : reel.channelHandle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ],
        ),
        if (reel.title.isNotEmpty) ...[
          SizedBox(height: 6.h),
          Text(
            reel.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
        if (reel.description != null && reel.description!.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            reel.description!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16.r,
      backgroundColor: Colors.white24,
      child: ClipOval(
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                width: 32.w,
                height: 32.w,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  color: Colors.white70,
                  size: 18.w,
                ),
              )
            : Icon(Icons.person, color: Colors.white70, size: 18.w),
      ),
    );
  }
}
