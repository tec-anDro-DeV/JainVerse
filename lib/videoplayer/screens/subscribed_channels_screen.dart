import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/videoplayer/models/channel_item.dart';
import 'package:jainverse/videoplayer/services/subscribed_channels_service.dart';
import 'package:jainverse/videoplayer/screens/channel_videos_screen.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/main.dart';

class SubscribedChannelsScreen extends StatefulWidget {
  const SubscribedChannelsScreen({super.key});

  @override
  State<SubscribedChannelsScreen> createState() =>
      _SubscribedChannelsScreenState();
}

class _SubscribedChannelsScreenState extends State<SubscribedChannelsScreen> {
  final SubscribedChannelsService _service = SubscribedChannelsService();
  List<ChannelItem> _channels = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSubscribedChannels();
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Subscribed Channels',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.black87),
              onPressed: _loadSubscribedChannels,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSubscribedChannels,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // Get audio handler from main app
    final audioHandler = const MyApp().called();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        // Check if mini player is visible (music is playing)
        final hasMiniPlayer = snapshot.hasData;

        // Calculate bottom padding based on mini player and nav bar
        final bottomPadding =
            hasMiniPlayer
                ? AppSizes.basePadding + AppSizes.miniPlayerPadding
                : AppSizes.basePadding;

        if (_isLoading) {
          return ListView.builder(
            padding: EdgeInsets.only(
              top: 16.w,
              left: 16.w,
              right: 16.w,
              bottom: bottomPadding,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => _buildChannelSkeleton(),
          );
        }

        if (_hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64.w,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Failed to load subscribed channels',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _errorMessage,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: _loadSubscribedChannels,
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (_channels.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.subscriptions_outlined,
                  size: 64.w,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16.h),
                Text(
                  'No subscribed channels',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Channels you subscribe to will appear here',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.only(
            top: 16.w,
            left: 16.w,
            right: 16.w,
            bottom: bottomPadding, // Dynamic padding for mini player
          ),
          itemCount: _channels.length,
          itemBuilder: (context, index) {
            final channel = _channels[index];
            return _buildChannelCard(channel);
          },
        );
      },
    );
  }

  Widget _buildChannelCard(ChannelItem channel) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8.w,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) => ChannelVideosScreen(
                    channelId: channel.id,
                    channelName: channel.name,
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12.w),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // Channel avatar
              CircleAvatar(
                radius: 32.w,
                backgroundImage: CachedNetworkImageProvider(channel.imageUrl),
                backgroundColor: Colors.grey.shade200,
              ),
              SizedBox(width: 16.w),
              // Channel info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '@${channel.handle}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (channel.description != null &&
                        channel.description!.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        channel.description!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Subscribed badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16.w),
                ),
                child: Text(
                  'Subscribed',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelSkeleton() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
      ),
      child: Row(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4.w),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 14.h,
                  width: 120.w,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4.w),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
