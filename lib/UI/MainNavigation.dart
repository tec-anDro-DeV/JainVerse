import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:session_storage/session_storage.dart';
import 'PanchangCalendarScreen.dart';

import '../main.dart' show MyApp, tabNavigatorObservers;
import '../managers/media_coordinator.dart';
import '../services/audio_player_service.dart';
import '../services/offline_mode_service.dart';
import '../services/tab_navigation_service.dart';
import '../utils/music_player_state_manager.dart';
import '../videoplayer/managers/video_player_state_provider.dart';
import '../videoplayer/widgets/mini_video_player.dart';
import '../widgets/music/mini_music_player.dart';
import '../widgets/offline_mode_prompt.dart';
import 'HomeDiscover.dart';
import 'MyLibrary.dart';
import 'Search.dart';
import 'package:jainverse/features/reels/presentation/screens/reels_screen.dart';
import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/providers/screen_ui_mode_provider.dart';

class MainNavigationWrapper extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationWrapper({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigationWrapper> createState() =>
      _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper>
    with TickerProviderStateMixin {
  // FIXED: Standardized height constants (logical pixels, not .h)
  static const double kNavBarHeight = 80.0;
  // static const double kNavBarGradientHeight = 95.0;
  static const double kMiniPlayerGap =
      10.0; // Gap between mini player and nav bar

  late TabController _tabController;
  late int _previousTabIndex;
  final session = SessionStorage();

  /// Tracks whether the reels tab's nested navigator has a sub-route pushed.
  /// Used to revert the nav bar to normal styling on channel detail etc.
  final ValueNotifier<bool> _reelsHasSubRoute = ValueNotifier(false);

  // Offline mode services
  final OfflineModeService _offlineModeService = OfflineModeService();

  // Debug logging guards to avoid spamming identical messages every rebuild.
  String? _lastMusicManagerLog;
  String? _lastCoordinatorSummary;
  String? _lastVideoStateSummary;
  String? _lastMiniPlayerDecision;

  // Navigation keys for each tab to maintain separate navigation stacks
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // Home
    GlobalKey<NavigatorState>(), // Library
    GlobalKey<NavigatorState>(), // Search
    GlobalKey<NavigatorState>(), // Calendar
    GlobalKey<NavigatorState>(), // Reels
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _previousTabIndex = widget.initialIndex;

    // Update session storage when tab changes, pause media when entering the
    // Reels tab, and release reel controllers when leaving it.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final newIndex = _tabController.index;
        session['page'] = newIndex.toString();

        // Leaving the Reels tab → dispose all video controllers so their
        // Android ImageReader buffer slots are freed immediately.
        if (_previousTabIndex == 4 && newIndex != 4) {
          ref.read(reelPlayerProvider.notifier).releaseAll();
        }

        // Reset any globally-active reels UI mode on tab switch.
        // ChannelReelsScreen (opened from another tab) sets this via
        // ReelsUIModeScope; the dynamic AnnotatedRegion in build() handles
        // the status bar declaratively so no imperative SystemChrome call is needed.
        ref.read(reelsUIModeProvider.notifier).exitReelsMode();

        if (newIndex == 4) {
          // Pause audio (fire-and-forget; null-safe in case handler not ready).
          try {
            const MyApp().called().pause();
          } catch (_) {}
          // Pause video mini player if one is active.
          ref.read(videoPlayerProvider.notifier).pause();
          // Re-initialize the reel player for the current feed index so the
          // video starts from position 0 (controllers were released on leave).
          final feedState = ref.read(reelFeedProvider);
          if (feedState.reels.isNotEmpty) {
            ref
                .read(reelPlayerProvider.notifier)
                .onPageChanged(feedState.currentIndex, feedState.reels);
          }
        }

        _previousTabIndex = newIndex;
      }
    });

    // Set initial page in session
    session['page'] = widget.initialIndex.toString();

    // Register tab navigation service so other widgets can push into the
    // active tab's nested navigator after closing full player.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TabNavigationService().initialize(_tabController, _navigatorKeys);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reelsHasSubRoute.dispose();
    super.dispose();
  }

  // FIXED: Standardized bottom calculation
  double _getMiniPlayerBottom() {
    return kNavBarHeight +
        MediaQuery.of(context).padding.bottom +
        kMiniPlayerGap;
  }

  @override
  Widget build(BuildContext context) {
    // True when a reels-style screen is the top route, regardless of active tab.
    // Combines existing tab-4 logic (handled inside ListenableBuilder below)
    // with global provider set by ReelsUIModeScope for pushed screens.
    final isGlobalReelsMode = ref.watch(reelsUIModeProvider);

    // Set up media coordination listener (only runs during build, not in initState)
    ref.listen(videoPlayerProvider, (previous, next) {
      final coordinatorNotifier = ref.read(mediaCoordinatorProvider.notifier);
      final currentCoordinatorState = ref.read(mediaCoordinatorProvider);

      final wasMiniVisible = previous?.showMiniPlayer == true;
      final isMiniVisible = next.showMiniPlayer;

      if (isMiniVisible) {
        // Mini video player is visible, take control of the coordinator.
        coordinatorNotifier.setVideoActive();
        return;
      }

      final bool videoWasControlling =
          currentCoordinatorState == ActiveMediaPlayer.video;

      if (wasMiniVisible && !isMiniVisible && videoWasControlling) {
        // Mini video player was dismissed; release coordinator unless audio already took over.
        coordinatorNotifier.clearActivePlayer();
      }
    });

    // Get the global audio handler
    final audioHandler = const MyApp().called();

    return StreamBuilder<bool>(
      stream: _offlineModeService.offlineModeStream,
      builder: (context, offlineSnapshot) {
        // If in offline mode, don't render this widget at all - let router manager handle navigation
        final isOffline = offlineSnapshot.data ?? false;

        if (isOffline) {
          debugPrint(
            '[MainNavigation] Offline mode detected, not rendering MainNavigation',
          );
          // Return empty container to avoid interfering with navigation
          return const SizedBox.shrink();
        }

        return ListenableBuilder(
          listenable: Listenable.merge([
            MusicPlayerStateManager(),
            _tabController,
            _reelsHasSubRoute,
          ]),
          builder: (context, child) {
            final stateManager = MusicPlayerStateManager();

            // Debug: Log current state when builder is called
            final musicSummary =
                '${stateManager.isFullPlayerVisible}|${stateManager.shouldHideNavigation}|${stateManager.shouldHideMiniPlayer}';
            if (_lastMusicManagerLog != musicSummary) {
              debugPrint(
                '[MainNavigation] ListenableBuilder rebuild - isFullPlayerVisible: ${stateManager.isFullPlayerVisible}, shouldHideNavigation: ${stateManager.shouldHideNavigation}, shouldHideMiniPlayer: ${stateManager.shouldHideMiniPlayer}',
              );
              _lastMusicManagerLog = musicSummary;
            }

            // Unified reels-mode flag: active when on the Reels tab (no
            // sub-route), OR when a reels screen was pushed from another tab.
            final isReelsModeActive =
                (_tabController.index == 4 && !_reelsHasSubRoute.value) ||
                isGlobalReelsMode;

            return WillPopScope(
              onWillPop: () async {
                // Safety net: dismiss keyboard if visible.
                // The primary guard is AppKeyboardDismissHandler in
                // MaterialApp.builder (fires via didPopRoute before this).
                // This fallback covers iOS and any edge-cases where the
                // BackButtonListener does not fire first.
                if (MediaQuery.of(context).viewInsets.bottom > 0) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  return false;
                }
                // Handle back button for current tab's navigator
                final currentNavigator =
                    _navigatorKeys[_tabController.index].currentState;
                if (currentNavigator != null && currentNavigator.canPop()) {
                  currentNavigator.pop();
                  // Prevent default pop (exit app) when inner navigator can pop
                  return false;
                }
                // Exit app when on root of current tab
                return true;
              },
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isReelsModeActive
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isReelsModeActive
                      ? Brightness.dark
                      : Brightness.light,
                ),
                child: Scaffold(
                  backgroundColor: isReelsModeActive ? Colors.black : null,
                  resizeToAvoidBottomInset: false,
                  extendBodyBehindAppBar: true,
                  extendBody: true,
                  body: SafeArea(
                    bottom: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Determine if device should use centered 50% width layout (tablet/iPad)
                        final shortestSide = MediaQuery.of(
                          context,
                        ).size.shortestSide;
                        final bool useCenteredLayout = shortestSide >= 600;
                        // On tablets/iPad use 60% inner width for mini player -> left/right = 18% each
                        final double horizontalInset = useCenteredLayout
                            ? (MediaQuery.of(context).size.width * 0.18)
                            : 0.0;

                        return Stack(
                          children: [
                            // Tab content with separate navigators
                            TabBarView(
                              controller: _tabController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildTabNavigator(0, const HomeDiscover()),
                                _buildTabNavigator(1, const MyLibrary()),
                                _buildTabNavigator(2, Search("")),
                                _buildTabNavigator(
                                  3,
                                  const PanchangCalendarScreen(),
                                ),
                                _buildTabNavigator(4, const ReelsScreen()),
                              ],
                            ),

                            // Bottom navigation bar - Hide when full player is visible
                            if (!stateManager.shouldHideNavigation)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: BottomNavCustom(
                                  tabController: _tabController,
                                  navigatorKeys: _navigatorKeys,
                                  isReelsMode: isReelsModeActive,
                                  onSameReelsTabTapped: () {
                                    ref
                                        .read(reelNavTapProvider.notifier)
                                        .increment();
                                  },
                                ),
                              ),

                            // Hidden whenever reels mode is active (Reels tab or
                            // any reels screen pushed from another tab).
                            if (!stateManager.isFullPlayerVisible &&
                                !stateManager.shouldHideMiniPlayer &&
                                !isReelsModeActive)
                              Positioned(
                                left: useCenteredLayout ? horizontalInset : 0,
                                right: useCenteredLayout ? horizontalInset : 0,
                                bottom: _getMiniPlayerBottom(),
                                child: _buildCoordinatedMiniPlayers(
                                  audioHandler,
                                ),
                              ),

                            // Offline Mode Prompt - Shows when connectivity is lost
                            const OfflineModePrompt(),

                            // FIXED: Offline Mode FAB positioning
                            Positioned(
                              bottom: _getMiniPlayerBottom() + 8.0,
                              right: 16.w,
                              child: const OfflineModeFAB(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Build coordinated mini players (music OR video, never both)
  Widget _buildCoordinatedMiniPlayers(AudioPlayerHandler audioHandler) {
    final videoState = ref.watch(videoPlayerProvider);
    final coordinatorState = ref.watch(mediaCoordinatorProvider);

    // Show the appropriate mini player based on current state
    // Coordination is handled by ref.listen in build method
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final hasMusic = snapshot.hasData;
        final showVideoMini =
            videoState.showMiniPlayer && videoState.isMinimized;

        final coordinatorSummary = '$showVideoMini|$hasMusic|$coordinatorState';
        if (_lastCoordinatorSummary != coordinatorSummary) {
          debugPrint(
            '[MainNavigation] _buildCoordinatedMiniPlayers - showVideoMini: $showVideoMini, hasMusic: $hasMusic, coordinatorState: $coordinatorState',
          );
          _lastCoordinatorSummary = coordinatorSummary;
        }

        final videoStateSummary =
            '${videoState.showMiniPlayer}|${videoState.isMinimized}|${videoState.currentVideoId}';
        if (_lastVideoStateSummary != videoStateSummary) {
          debugPrint(
            '[MainNavigation] videoState - showMiniPlayer: ${videoState.showMiniPlayer}, isMinimized: ${videoState.isMinimized}, currentVideoId: ${videoState.currentVideoId}',
          );
          _lastVideoStateSummary = videoStateSummary;
        }

        // Respect explicit coordinator state when available
        if (coordinatorState == ActiveMediaPlayer.video) {
          // Coordinator says video should be visible
          if (showVideoMini) {
            if (_lastMiniPlayerDecision != 'video-coordinator') {
              debugPrint(
                '[MainNavigation] Showing MiniVideoPlayer (coordinator)',
              );
              _lastMiniPlayerDecision = 'video-coordinator';
            }
            return const MiniVideoPlayer();
          }
          // fallthrough to other checks if no video mini player should show
        } else if (coordinatorState == ActiveMediaPlayer.music) {
          // Coordinator says music should be visible
          if (hasMusic) {
            if (_lastMiniPlayerDecision != 'music-coordinator') {
              _lastMiniPlayerDecision = 'music-coordinator';
            }
            return MiniMusicPlayer(audioHandler).buildMiniPlayer(context);
          }
          // fallthrough to other checks if no music present
        }

        // Fallback priority: Video mini player > Music mini player
        if (showVideoMini) {
          if (_lastMiniPlayerDecision != 'video-fallback') {
            debugPrint('[MainNavigation] Showing MiniVideoPlayer (fallback)');
            _lastMiniPlayerDecision = 'video-fallback';
          }
          return const MiniVideoPlayer();
        } else if (hasMusic) {
          if (_lastMiniPlayerDecision != 'music-fallback') {
            _lastMiniPlayerDecision = 'music-fallback';
          }
          return MiniMusicPlayer(audioHandler).buildMiniPlayer(context);
        }

        if (_lastMiniPlayerDecision != 'none') {
          debugPrint('[MainNavigation] Showing nothing');
          _lastMiniPlayerDecision = 'none';
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTabNavigator(int tabIndex, Widget child) {
    return Navigator(
      key: _navigatorKeys[tabIndex],
      observers: [
        tabNavigatorObservers[tabIndex],
        if (tabIndex == 4) _ReelsRouteObserver(_reelsHasSubRoute),
      ],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => child,
          settings: settings,
        );
      },
    );
  }
}

/// Observes push/pop events on the reels tab's nested navigator and updates
/// [hasSubRoute] so the nav bar can revert to normal styling on sub-routes.
class _ReelsRouteObserver extends NavigatorObserver {
  _ReelsRouteObserver(this.hasSubRoute);
  final ValueNotifier<bool> hasSubRoute;

  void _update() {
    final canPop = navigator?.canPop() ?? false;
    if (hasSubRoute.value != canPop) hasSubRoute.value = canPop;
  }

  @override
  void didPush(Route route, Route? previousRoute) => _update();

  @override
  void didPop(Route route, Route? previousRoute) => _update();

  @override
  void didRemove(Route route, Route? previousRoute) => _update();

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => _update();
}

class BottomNavCustom extends StatefulWidget {
  final TabController? tabController;
  final List<GlobalKey<NavigatorState>>? navigatorKeys;

  /// Pre-computed reels-mode flag from [MainNavigationWrapper].
  /// When true the nav bar renders with the dark Reels gradient style.
  final bool isReelsMode;

  /// Called when the user taps the Reels tab icon (index 4) while already on
  /// that tab. [MainNavigationWrapper] uses this to trigger scroll-to-top and
  /// a non-destructive feed refresh in [ReelsScreen].
  final VoidCallback? onSameReelsTabTapped;

  const BottomNavCustom({
    super.key,
    this.tabController,
    this.navigatorKeys,
    this.isReelsMode = false,
    this.onSameReelsTabTapped,
  });

  @override
  State<BottomNavCustom> createState() => BottomNavCustomState();

  // Keep existing appBar method for backward compatibility
  PreferredSizeWidget appBar(String s, BuildContext context, int i) {
    return AppBar(title: Text(s), backgroundColor: appColors().colorBackground);
  }
}

class BottomNavCustomState extends State<BottomNavCustom>
    with TickerProviderStateMixin {
  // FIXED: Use the same constant from MainNavigationWrapper
  static const double kNavBarHeight = 80.0;
  static const double kNavBarGradientHeight = 95.0;

  final session = SessionStorage();

  // Navigation item data structure
  final List<Map<String, String>> navItems = [
    {
      'activeIcon': 'assets/images/discover_active.svg',
      'inactiveIcon': 'assets/images/discover_inactive.svg',
      'label': 'Home',
    },
    {
      'activeIcon': 'assets/images/library_active.svg',
      'inactiveIcon': 'assets/images/library_inactive.svg',
      'label': 'Library',
    },
    {
      'activeIcon': 'assets/images/search_active.svg',
      'inactiveIcon': 'assets/images/search_inactive.svg',
      'label': 'Search',
    },
    {
      'activeIcon': 'assets/images/calendar_active.svg',
      'inactiveIcon': 'assets/images/calendar_inactive.svg',
      'label': 'Calendar',
    },
    // Reels tab — uses a Material icon; replace with SVG assets when available.
    {'activeIcon': '', 'inactiveIcon': '', 'label': 'Reels'},
  ];

  // Animation controllers
  List<AnimationController> _animationControllers = [];

  @override
  void initState() {
    super.initState();

    // Initialize animations immediately instead of waiting for post-frame callback
    _initializeAnimations();

    // Add listener to sync with tab controller changes
    widget.tabController?.addListener(_onTabControllerChange);
  }

  void _onTabControllerChange() {
    if (widget.tabController != null &&
        !widget.tabController!.indexIsChanging &&
        mounted) {
      final newIndex = widget.tabController!.index;
      _updateAnimationsForIndex(newIndex);
    }
  }

  void _updateAnimationsForIndex(int selectedIndex) {
    if (_animationControllers.isNotEmpty && mounted) {
      for (int i = 0; i < _animationControllers.length; i++) {
        if (i == selectedIndex) {
          _animationControllers[i].forward();
        } else {
          _animationControllers[i].reverse();
        }
      }
      setState(() {}); // Force rebuild
    }
  }

  void _initializeAnimations() {
    // Create animation controllers for each nav item
    _animationControllers = List.generate(
      navItems.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );

    // Set initial selected index and start animation
    final currentIndex = widget.tabController?.index ?? 0;
    if (currentIndex >= 0 && currentIndex < _animationControllers.length) {
      _animationControllers[currentIndex].forward();
    }
  }

  @override
  void dispose() {
    // Remove listener and dispose all animation controllers
    widget.tabController?.removeListener(_onTabControllerChange);
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (widget.tabController != null && mounted) {
      final currentIndex = widget.tabController!.index;

      // Always update animations and navigate, even if same tab
      HapticFeedback.mediumImpact();

      // Update animations immediately (only for navigable tabs 0-2)
      _updateAnimationsForIndex(index);

      // If tapping same tab, pop to root
      if (currentIndex == index) {
        if (widget.navigatorKeys != null) {
          widget.navigatorKeys![index].currentState?.popUntil(
            (route) => route.isFirst,
          );
        }
        // Reels tab re-tap: notify ReelsScreen to scroll to top + refresh.
        if (index == 4) widget.onSameReelsTabTapped?.call();
      } else {
        // Navigate to new tab (only for tabs 0-2)
        widget.tabController!.animateTo(index);
      }

      if (mounted) {
        session['page'] = index.toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Use constant height + responsive padding only
    final double totalHeight =
        kNavBarGradientHeight + MediaQuery.of(context).padding.bottom;
    final bool isReelsTab = widget.isReelsMode;

    return Container(
      width: double.infinity,
      height: totalHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isReelsTab
              ? [
                  Colors.transparent,
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.70),
                  Colors.black.withOpacity(0.80),
                ]
              : [
                  const Color.fromARGB(0, 255, 255, 255),
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.7),
                  Colors.white.withOpacity(0.95),
                  Colors.white,
                ],
          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ),
      ),
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = MediaQuery.of(context).size.shortestSide;
            final bool useCenteredInner = shortestSide >= 600;
            final double innerWidth = useCenteredInner
                ? MediaQuery.of(context).size.width * 0.6
                : double.infinity;

            // iPad specific detection: iOS + large shortest side
            final bool isiPad =
                Theme.of(context).platform == TargetPlatform.iOS &&
                shortestSide >= 600;
            // FIXED: Small consistent bottom margin for iPad
            final double iPadBottomMargin = isiPad ? 8.0 : 0.0;

            return Container(
              height: kNavBarHeight, // FIXED: Use constant
              // FIXED: Consistent margins
              margin: useCenteredInner
                  ? EdgeInsets.only(bottom: iPadBottomMargin)
                  : EdgeInsets.fromLTRB(18.w, 0, 18.w, 8.0),
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: innerWidth),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  decoration: BoxDecoration(
                    color: isReelsTab
                        ? Colors.black.withOpacity(0.55)
                        : appColors().gray[100],
                    borderRadius: BorderRadius.circular(44.w),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          isReelsTab ? 0.25 : 0.08,
                        ),
                        blurRadius: 15.0,
                        spreadRadius: 1.0,
                        offset: const Offset(0, 3.0),
                      ),
                    ],
                    border: Border.all(
                      color: isReelsTab
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.9),
                      width: 0.6.w,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(navItems.length, (index) {
                      return _buildCustomNavItem(index, isReelsTab: isReelsTab);
                    }),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomNavItem(int index, {bool isReelsTab = false}) {
    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(44.w),
        child: AnimatedBuilder(
          animation: widget.tabController!,
          builder: (context, child) {
            final isSelected = widget.tabController!.index == index;
            final activeIconPath = navItems[index]['activeIcon']!;
            final inactiveIconPath = navItems[index]['inactiveIcon']!;

            final Color activeColor = isReelsTab
                ? appColors().primaryColorApp
                : appColors().primaryColorApp;
            final Color inactiveColor = isReelsTab
                ? Colors.white54
                : Colors.grey[500]!;
            final Color circleBg = isReelsTab ? Colors.white : Colors.white;

            return SizedBox(
              height: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle for selected item
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isSelected ? 58.w : 0,
                    height: isSelected ? 58.w : 0,
                    decoration: BoxDecoration(
                      color: isSelected ? circleBg : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Icon (SVG or Material fallback for tabs without SVG assets)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Transform.scale(
                      scale: isSelected ? 1.1 : 1.0,
                      child: activeIconPath.isNotEmpty
                          ? SvgPicture.asset(
                              isSelected ? activeIconPath : inactiveIconPath,
                              width: 26.w,
                              height: 26.w,
                              colorFilter: ColorFilter.mode(
                                isSelected ? activeColor : inactiveColor,
                                BlendMode.srcIn,
                              ),
                            )
                          : Icon(
                              isSelected
                                  ? Icons.play_circle_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 26.w,
                              color: isSelected ? activeColor : inactiveColor,
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
