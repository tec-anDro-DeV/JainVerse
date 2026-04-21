import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'package:jainverse/UI/CreateChannel.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';
import 'package:jainverse/features/reels/data/repository/reels_repository.dart';
import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/screens/reel_upload_screen.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_action_bar.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_info_overlay.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_progress_bar.dart';
import 'package:jainverse/features/reels/presentation/widgets/reels_ui_mode_scope.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Full-screen vertical reels player scoped to a single channel.
/// Opened from the Shorts tab in [ChannelVideosScreen].
class ChannelReelsScreen extends ConsumerStatefulWidget {
  final int channelId;
  final List<ReelItem> reels;
  final int startIndex;

  const ChannelReelsScreen({
    super.key,
    required this.channelId,
    required this.reels,
    this.startIndex = 0,
  });

  @override
  ConsumerState<ChannelReelsScreen> createState() => _ChannelReelsScreenState();
}

class _ChannelReelsScreenState extends ConsumerState<ChannelReelsScreen> {
  late final PageController _pageController;
  late List<ReelItem> _reels;

  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initialized = {};
  final Set<int> _buffering = {};
  final Set<VideoPlayerController> _disposedControllers = {};

  bool _isMuted = false;
  bool _isLoadingMore = false;
  bool _wasPlayingBeforeLongPress = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _currentIndex = 0;

  /// null = not yet fetched, false = no channel, true = has channel.
  bool? _userHasChannel;

  final ReelsRepository _repository = ReelsRepository();

  @override
  void initState() {
    super.initState();
    _reels = List.of(widget.reels);
    _currentIndex = widget.startIndex.clamp(0, _reels.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _fetchChannelStatus();

    // Seed like provider with initial reels
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(reelLikeProvider.notifier).seedFromReels(_reels);
        _onPageChanged(_currentIndex);
      }
    });
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

  Future<void> _checkAndUpload() async {
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
    _controllers[_currentIndex]?.pause();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReelUploadScreen()),
    );
    if (mounted) _controllers[_currentIndex]?.play();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      if (!_disposedControllers.contains(c)) {
        _disposedControllers.add(c);
        c.dispose();
      }
    }
    _controllers.clear();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Video controller management (±1 window)
  // ---------------------------------------------------------------------------

  Future<void> _onPageChanged(int index) async {
    if (!mounted) return;
    setState(() => _currentIndex = index);

    final keepIndices = {index, index + 1}
      ..removeWhere((i) => i < 0 || i >= _reels.length);

    // Dispose controllers outside window
    final toRemove = _controllers.keys
        .where((i) => !keepIndices.contains(i))
        .toList();
    for (final i in toRemove) {
      final c = _controllers.remove(i);
      _initialized.remove(i);
      _buffering.remove(i);
      if (c != null && !_disposedControllers.contains(c)) {
        _disposedControllers.add(c);
        c.dispose();
      }
    }

    // Init controllers in window
    for (final i in keepIndices) {
      if (!_controllers.containsKey(i)) {
        _initController(i);
      }
    }

    // Pause all except current
    for (final entry in _controllers.entries) {
      if (entry.key != index && entry.value.value.isInitialized) {
        entry.value.pause();
      }
    }

    // Play current
    final current = _controllers[index];
    if (current != null && current.value.isInitialized) {
      current.setLooping(true);
      if (_isMuted) await current.setVolume(0);
      await current.play();
    }

    // Pagination
    if (index >= _reels.length - 2) {
      _loadMore();
    }
  }

  Future<void> _initController(int index) async {
    if (!mounted) return;
    if (index < 0 || index >= _reels.length) return;
    if (_controllers.containsKey(index)) return;

    final url = _reels[index].videoUrl;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[index] = controller;

    controller.addListener(() {
      if (!mounted) return;
      final isNowBuffering =
          controller.value.isInitialized &&
          !controller.value.isPlaying &&
          controller.value.isBuffering;

      final wasBuffering = _buffering.contains(index);
      if (isNowBuffering != wasBuffering) {
        setState(() {
          isNowBuffering ? _buffering.add(index) : _buffering.remove(index);
        });
      }
    });

    try {
      await controller.initialize();
      if (!mounted || _disposedControllers.contains(controller)) return;

      controller.setLooping(true);
      if (_isMuted) await controller.setVolume(0);

      setState(() => _initialized.add(index));

      // Auto-play if this is the current index
      if (index == _currentIndex) {
        await controller.play();
      }
    } catch (_) {
      // Silently ignore init failures — thumbnail shows as fallback
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _currentPage >= _totalPages) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _repository.getChannelReels(
        channelId: widget.channelId,
        page: _currentPage + 1,
      );
      _currentPage = result.currentPage;
      _totalPages = result.totalPages;
      final existingIds = _reels.map((r) => r.id).toSet();
      final newItems = result.items
          .where((r) => !existingIds.contains(r.id))
          .toList();
      if (newItems.isNotEmpty) {
        ref.read(reelLikeProvider.notifier).seedFromReels(newItems);
        setState(() => _reels.addAll(newItems));
      }
    } catch (_) {
      // Non-critical — just stop loading indicator
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    for (final c in _controllers.values) {
      c.setVolume(_isMuted ? 0 : 1);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final double navBarBottom = 120.h + MediaQuery.of(context).padding.bottom;
    return ReelsUIModeScope(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          body: Padding(
            padding: EdgeInsets.only(bottom: navBarBottom),
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _reels.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final reel = _reels[index];
                    final controller = _controllers[index];
                    final isInit = _initialized.contains(index);
                    final isBuffering = _buffering.contains(index);

                    return GestureDetector(
                      onTap: _toggleMute,
                      onLongPressStart: (_) {
                        final ctrl = _controllers[index];
                        if (ctrl != null && ctrl.value.isPlaying) {
                          _wasPlayingBeforeLongPress = true;
                          ctrl.pause();
                        }
                      },
                      onLongPressEnd: (_) {
                        if (_wasPlayingBeforeLongPress) {
                          _controllers[_currentIndex]?.play();
                          _wasPlayingBeforeLongPress = false;
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _VideoLayer(
                            reel: reel,
                            controller: controller,
                            isInitialized: isInit,
                          ),
                          if (isBuffering)
                            Center(
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 2.5.w,
                              ),
                            ),
                          if (_isMuted)
                            const Align(
                              alignment: Alignment.center,
                              child: _MuteIndicator(),
                            ),
                          const Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _BottomGradient(),
                          ),
                          Positioned(
                            bottom: 16.h,
                            left: 16.w,
                            right: 72.w,
                            child: ReelInfoOverlay(reel: reel),
                          ),
                          Positioned(
                            bottom: 16.h,
                            right: 12.w,
                            child: ReelActionBar(reel: reel),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: controller != null && isInit
                                ? ReelProgressBar(controller: controller)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8.h,
                  left: 8.w,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 22.w,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                // Upload button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8.h,
                  right: 8.w,
                  child: IconButton(
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 28.w,
                    ),
                    tooltip: 'Upload Reel',
                    onPressed: _checkAndUpload,
                  ),
                ),

                // Loading indicator at bottom when fetching more
                if (_isLoadingMore)
                  Positioned(
                    bottom: 32.h,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2.w,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _VideoLayer extends StatelessWidget {
  final ReelItem reel;
  final VideoPlayerController? controller;
  final bool isInitialized;

  const _VideoLayer({
    required this.reel,
    required this.controller,
    required this.isInitialized,
  });

  @override
  Widget build(BuildContext context) {
    if (isInitialized && controller != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: VideoPlayer(controller!),
          ),
        ),
      );
    }
    return reel.thumbnailUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: reel.thumbnailUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, __) => const ColoredBox(color: Colors.black),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Colors.black12),
          )
        : const ColoredBox(color: Colors.black);
  }
}

class _BottomGradient extends StatelessWidget {
  const _BottomGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
        ),
      ),
    );
  }
}

class _MuteIndicator extends StatelessWidget {
  const _MuteIndicator();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.volume_off_rounded, color: Colors.white, size: 32.w),
      ),
    );
  }
}
