import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:jainverse/features/reels/presentation/state/reel_feed_state.dart';

import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/screens/reel_upload_screen.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_page_item.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_upload_progress_overlay.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final currentIndex = ref.read(reelFeedProvider).currentIndex;
    final playerState = ref.read(reelPlayerProvider);
    final controller = playerState.controllers[currentIndex];

    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive) {
      controller?.pause();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (playerState.initializedIndices.contains(currentIndex)) {
        controller?.play();
      }
    }
  }

  void _onPageChanged(int index) {
    ref.read(reelFeedProvider.notifier).setCurrentIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final feedState = ref.watch(reelFeedProvider);
    final double navBarBottom = 120.h + MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: _buildContent(feedState, navBarBottom),
    );
  }

  Widget _buildContent(ReelFeedState feedState, double navBarBottom) {
    // ── Loading initial ──────────────────────────────────────────────────────
    if (feedState.isLoadingInitial) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: EdgeInsets.only(bottom: navBarBottom),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    // ── Error with no data ───────────────────────────────────────────────────
    if (feedState.errorMessage != null && feedState.reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: EdgeInsets.only(bottom: navBarBottom),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white54,
                    size: 56.w,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Could not load reels',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    feedState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(reelFeedProvider.notifier).loadInitial(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Empty state ──────────────────────────────────────────────────────────
    if (feedState.reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: EdgeInsets.only(bottom: navBarBottom),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_rounded, color: Colors.white38, size: 64.w),
                SizedBox(height: 16.h),
                Text(
                  'All caught up on short videos!',
                  style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                ),
                SizedBox(height: 24.h),
                ElevatedButton.icon(
                  onPressed: _openUpload,
                  icon: const Icon(Icons.add),
                  label: const Text('Post new short video'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Feed ─────────────────────────────────────────────────────────────────
    final itemCount =
        feedState.reels.length + (feedState.isLoadingMore ? 1 : 0);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Padding(
        // Reserve space for the floating nav bar so content never slips behind it.
        padding: EdgeInsets.only(bottom: navBarBottom),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: itemCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                if (index >= feedState.reels.length) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white54,
                      strokeWidth: 2.w,
                    ),
                  );
                }
                return ReelPageItem(reel: feedState.reels[index], index: index);
              },
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(onUploadTap: _openUpload),
            ),

            Positioned(
              bottom: 16.h,
              right: 12.w,
              child: const ReelUploadProgressOverlay(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUpload() async {
    final playerNotifier = ref.read(reelPlayerProvider.notifier);
    final currentIndex = ref.read(reelFeedProvider).currentIndex;

    // Pause all pool controllers before entering the upload screen so that
    // the upload preview's VideoPlayerController doesn't compete for the
    // same Android ImageReader buffer slots (causes "Unable to acquire a
    // buffer item" spam with 3+ simultaneous hardware video decoders).
    await playerNotifier.pauseAll();

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReelUploadScreen()),
    );

    // Resume the current reel when returning from the upload screen.
    if (mounted) {
      playerNotifier.resumeAt(currentIndex);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onUploadTap;
  const _TopBar({required this.onUploadTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Row(
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20.w,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            const Spacer(),
            Text(
              'Reels',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16.sp,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.white,
                size: 28.w,
              ),
              onPressed: onUploadTap,
              tooltip: 'Upload Reel',
            ),
          ],
        ),
      ),
    );
  }
}
