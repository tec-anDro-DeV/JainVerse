import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/videoplayer/models/channel_video_list_view_model.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/services/channel_video_service.dart';
import 'package:jainverse/videoplayer/screens/common_video_player_screen.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';

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

class _ChannelVideosScreenState extends State<ChannelVideosScreen> {
  late final ChannelVideoListViewModel _vm;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm = ChannelVideoListViewModel(
      service: ChannelVideoService(),
      perPage: 10,
    );
    _vm.addListener(_onVm);
    _scrollController.addListener(_onScroll);
    _vm.refresh(channelId: widget.channelId);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVm);
    _vm.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onVm() {
    if (!mounted) return;
    setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _vm.loadNext(channelId: widget.channelId);
    }
  }

  Future<void> _onRefresh() async {
    await _vm.refresh(channelId: widget.channelId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.channelName ?? 'Channel Videos')),
      body: RefreshIndicator(onRefresh: _onRefresh, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_vm.isLoading && _vm.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vm.hasError && _vm.items.isEmpty) {
      return _buildRetry();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
      itemCount: _vm.items.length + (_vm.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _vm.items.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final VideoItem v = _vm.items[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: VideoCard(
            item: v,
            onTap: () {
              final nav = Navigator.of(context);
              final route = MaterialPageRoute(
                builder:
                    (_) => CommonVideoPlayerScreen(
                      videoUrl: v.videoUrl,
                      videoTitle: v.title,
                      videoItem: v,
                    ),
              );
              if (nav.canPop()) {
                nav.pushReplacement(route);
              } else {
                nav.push(route);
              }
            },
            onMenuAction: (action) {
              // Handle menu actions for channel videos
              final messenger = ScaffoldMessenger.of(context);
              switch (action) {
                case 'watch_later':
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Saved to Watch Later'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  break;
                case 'add_playlist':
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Added to Playlist'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  break;
                case 'share':
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Share dialog opened'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  break;
                case 'not_interested':
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Marked not interested'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  break;
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildRetry() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Failed to load channel videos',
            style: TextStyle(fontSize: 14.sp),
          ),
          SizedBox(height: 12.h),
          ElevatedButton(
            onPressed: () => _vm.refresh(channelId: widget.channelId),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
