import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import 'package:jainverse/features/reels/presentation/state/reel_feed_state.dart';

import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/screens/reel_upload_screen.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_page_item.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_upload_progress_overlay.dart';
import 'package:jainverse/UI/CreateChannel.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

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

  /// null = not yet fetched, false = no channel, true = has channel.
  bool? _userHasChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _fetchChannelStatus();
  }

  /// Mirrors AccountPage._fetchProfileFromApi + _applyChannelPayload.
  Future<void> _fetchChannelStatus() async {
    try {
      final token = (await SharedPref().getToken())?.toString() ?? '';
      if (token.isEmpty) {
        if (mounted) setState(() => _userHasChannel = false);
        return;
      }
      final uri = Uri.parse('${AppConstant.BaseUrl}my_profile');
      final resp = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode != 200) {
        setState(() => _userHasChannel = false);
        return;
      }
      final jsonResp = json.decode(resp.body) as Map<String, dynamic>;
      final dynamic data = jsonResp['data'] ?? jsonResp;
      final dynamic channel =
          data is Map<String, dynamic> ? data['channel'] : null;
      setState(() {
        _userHasChannel =
            channel is Map<String, dynamic> && channel.isNotEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => _userHasChannel = false);
    }
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

  /// Pull-to-refresh on the live feed (only when at the top page).
  Future<void> _onRefresh() async {
    if (ref.read(reelFeedProvider).currentIndex != 0) return;
    await ref.read(reelFeedProvider.notifier).refresh();
  }

  /// Pull-to-refresh for error / empty states — does a full reload.
  Future<void> _onRefreshEmpty() async {
    await ref.read(reelFeedProvider.notifier).loadInitial();
  }

  /// Called when the user taps the Reels tab icon while already on this screen.
  /// If there is no feed content (error / empty), does a full reload.
  /// Otherwise scrolls to top and prepends any new reels.
  void _onNavReelsTap() {
    final feedState = ref.read(reelFeedProvider);

    if (feedState.reels.isEmpty) {
      ref.read(reelFeedProvider.notifier).loadInitial();
      return;
    }

    if (feedState.currentIndex != 0) {
      _pageController.jumpToPage(0);
      ref.read(reelFeedProvider.notifier).setCurrentIndex(0);
    }
    ref.read(reelFeedProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    // Listen for Reels tab re-taps signalled by MainNavigation.
    ref.listen(reelNavTapProvider, (prev, next) {
      if (prev != next) _onNavReelsTap();
    });

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
          child: RefreshIndicator(
            onRefresh: _onRefreshEmpty,
            color: Colors.white,
            backgroundColor: Colors.black54,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - navBarBottom,
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
          child: RefreshIndicator(
            onRefresh: _onRefreshEmpty,
            color: Colors.white,
            backgroundColor: Colors.black54,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - navBarBottom,
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
                        onPressed: _checkAndUpload,
                        icon: const Icon(Icons.add),
                        label: const Text('Post new short video'),
                      ),
                    ],
                  ),
                ),
              ),
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
            RefreshIndicator(
              onRefresh: _onRefresh,
              color: Colors.white,
              backgroundColor: Colors.black54,
              child: PageView.builder(
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
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(onUploadTap: _checkAndUpload),
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

  Future<void> _checkAndUpload() async {
    // If the initial fetch hasn't resolved yet, wait for it now.
    if (_userHasChannel == null) {
      await _fetchChannelStatus();
      if (!mounted) return;
    }

    if (_userHasChannel != true) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Channel Required'),
          content: const Text(
            'You need to create a channel before uploading a reel.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateChannel()),
                );
                _fetchChannelStatus();
              },
              child: const Text('Create Channel'),
            ),
          ],
        ),
      );
      return;
    }

    await _openUpload();
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
              'JainVerse Shorts',
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
              tooltip: 'Upload Jainverse Short',
            ),
          ],
        ),
      ),
    );
  }
}
