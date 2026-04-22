import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';
import 'package:jainverse/videoplayer/widgets/video_card_skeleton.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_overlay_helper.dart';

class MyVideosSection extends StatefulWidget {
  final List<VideoItem> videos;
  final List<ReelItem> shorts;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final Function(VideoItem) onTap;
  final Function(String, VideoItem) onMenuAction;
  final Function(ReelItem)? onShortTap;
  final void Function(String, ReelItem)? onShortMenuAction;
  final void Function(ReelItem)? onShortEdited;
  final void Function(int)? onShortDeleted;
  final VoidCallback? onAddShort;

  const MyVideosSection({
    super.key,
    required this.videos,
    this.shorts = const [],
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onTap,
    required this.onMenuAction,
    this.onShortTap,
    this.onShortMenuAction,
    this.onShortEdited,
    this.onShortDeleted,
    this.onAddShort,
  });

  @override
  State<MyVideosSection> createState() => _MyVideosSectionState();
}

class _MyVideosSectionState extends State<MyVideosSection> {
  late List<ReelItem> _shorts;

  @override
  void initState() {
    super.initState();
    _shorts = List<ReelItem>.from(widget.shorts);
  }

  @override
  void didUpdateWidget(covariant MyVideosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.shorts, widget.shorts)) {
      _shorts = List<ReelItem>.from(widget.shorts);
    }
  }

  Widget _buildLoading() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: 16.w),
          child: const VideoCardSkeleton(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12.w),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48.w, color: Colors.red.shade400),
          SizedBox(height: 16.w),
          Text(
            'Failed to load videos',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8.w),
          Text(
            widget.error ?? 'Unknown error',
            style: TextStyle(fontSize: 13.sp, color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.w),
          ElevatedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.w),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64.w,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16.w),
          Text(
            'No Video or Song Found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8.w),
          Text(
            'Check back later or add new content to your channel',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return _buildLoading();
    if (widget.error != null) return _buildError();
    if (widget.videos.isEmpty && _shorts.isEmpty) return _buildEmpty();

    final children = <Widget>[];

    if (_shorts.isNotEmpty) {
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Shorts',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.onAddShort != null)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: widget.onAddShort,
                      tooltip: 'Upload Short',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12.w,
              crossAxisSpacing: 12.w,
              childAspectRatio: 9 / 16,
              children: _shorts.map((reel) {
                return GestureDetector(
                  onTap: widget.onShortTap != null
                      ? () => widget.onShortTap!(reel)
                      : null,
                  onLongPress: reel.isOwn == 1
                      ? () {
                          HapticFeedback.mediumImpact();
                          ReelOverlayHelper.showOptions(
                            context: context,
                            reel: reel,
                            onEdited: (updated) {
                              setState(() {
                                final idx = _shorts.indexWhere(
                                  (r) => r.id == reel.id,
                                );
                                if (idx >= 0) _shorts[idx] = updated;
                              });
                              widget.onShortEdited?.call(updated);
                            },
                            onDeleted: () {
                              setState(
                                () =>
                                    _shorts.removeWhere((r) => r.id == reel.id),
                              );
                              widget.onShortDeleted?.call(reel.id);
                            },
                          );
                        }
                      : null,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.w),
                        child: Image.network(
                          reel.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey.shade200),
                        ),
                      ),
                      Positioned(
                        left: 8.w,
                        top: 8.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.w,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6.w),
                          ),
                          child: Text(
                            reel.duration,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                      ),
                      // bottom overlay: title and views
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 6.w,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(8.w),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  reel.title.isNotEmpty ? reel.title : '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Row(
                                children: [
                                  Icon(
                                    Icons.remove_red_eye,
                                    size: 12.w,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${reel.totalViews}',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16.w),
          ],
        ),
      );
    }

    if (widget.videos.isNotEmpty) {
      children.addAll(
        widget.videos.map((video) {
          return Padding(
            padding: EdgeInsets.only(bottom: 16.w),
            child: VideoCard(
              item: video,
              onTap: () => widget.onTap(video),
              showPopupMenu: true,
              onMenuAction: (action) => widget.onMenuAction(action, video),
            ),
          );
        }).toList(),
      );
    }

    return Column(children: children);
  }
}
