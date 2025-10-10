import 'dart:async';
// existing imports

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/videoplayer/screens/common_video_player_screen.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/models/video_list_view_model.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';

class VideoListScreen extends StatelessWidget {
  const VideoListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Videos')),
      body: const VideoListBody(),
    );
  }
}

/// Embeddable video list widget (no scaffold) so it can be placed inside other screens.
class VideoListBody extends StatefulWidget {
  const VideoListBody({Key? key}) : super(key: key);

  @override
  State<VideoListBody> createState() => _VideoListBodyState();
}

class _VideoListBodyState extends State<VideoListBody> {
  final ScrollController _scrollController = ScrollController();
  late final VideoListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = VideoListViewModel(perPage: 10);
    _scrollController.addListener(_onScroll);
    _viewModel.addListener(_onViewModel);
    _viewModel.refresh();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _viewModel.removeListener(_onViewModel);
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModel() {
    if (!mounted) return;
    setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_viewModel.isLoading &&
        _viewModel.page < _viewModel.totalPages) {
      _viewModel.loadNext();
    }
  }

  Future<void> _refresh() async {
    await _viewModel.refresh();
  }

  void _openPlayer(VideoItem item) {
    // Try to replace the current player if possible, otherwise push.
    final nav = Navigator.of(context);
    final route = MaterialPageRoute(
      builder:
          (_) => CommonVideoPlayerScreen(
            videoUrl: item.videoUrl,
            videoTitle: item.title,
            videoItem: item,
          ),
    );
    if (nav.canPop()) {
      nav.pushReplacement(route);
    } else {
      nav.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add bottom padding so list content isn't hidden behind the
    // app's bottom navigation or the mini player. We reuse AppSizes
    // to keep sizing consistent across the app.
    return RefreshIndicator(
      onRefresh: _refresh,
      // Use a CustomScrollView so padding becomes part of the scrollable area
      // and the RefreshIndicator works reliably for both the list and the
      // empty/error state.
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              0.w,
              20.h,
              12.w,
              (AppSizes.basePadding + AppSizes.miniPlayerPadding + 8.w),
            ),
            sliver:
                _viewModel.hasError && _viewModel.items.isEmpty
                    ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 60.h),
                          Center(
                            child: Text('Error: ${_viewModel.errorMessage}'),
                          ),
                          SizedBox(height: 8.h),
                          Center(
                            child: ElevatedButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ),
                        ],
                      ),
                    )
                    : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index >= _viewModel.items.length) {
                          // footer slot: show loader while loading, otherwise
                          // provide some spacing so content isn't flush to bottom.
                          if (_viewModel.isLoading) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return SizedBox(height: 40.h);
                        }

                        final item = _viewModel.items[index];
                        return VideoCard(
                          item: item,
                          onTap: () => _openPlayer(item),
                        );
                      }, childCount: _viewModel.items.length + 1),
                    ),
          ),
        ],
      ),
    );
  }
}
