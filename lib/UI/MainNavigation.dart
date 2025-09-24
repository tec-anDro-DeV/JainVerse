import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:session_storage/session_storage.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:jainverse/utils/share_helper.dart';
import '../widgets/music/mini_music_player.dart';
import '../utils/music_player_state_manager.dart';
import '../services/offline_mode_service.dart';
import '../widgets/offline_mode_prompt.dart';
import '../main.dart';
import 'HomeDiscover.dart';
import 'MyLibrary.dart';
import 'Search.dart';
import '../services/tab_navigation_service.dart';

class MainNavigationWrapper extends StatefulWidget {
  final int initialIndex;

  const MainNavigationWrapper({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final session = SessionStorage();

  // Offline mode services
  final OfflineModeService _offlineModeService = OfflineModeService();

  // Navigation keys for each tab to maintain separate navigation stacks
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // Home
    GlobalKey<NavigatorState>(), // Library
    GlobalKey<NavigatorState>(), // Search
    GlobalKey<NavigatorState>(), // Account
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialIndex,
    );

    // Update session storage when tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        session['page'] = _tabController.index.toString();
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
    super.dispose();
  }

  // Calculate dynamic bottom navigation height for mini player positioning
  double _getBottomNavigationHeight() {
    // Total height includes gradient area (90.w) + SafeArea bottom
    return 90.w + MediaQuery.of(context).padding.bottom;
  }

  @override
  Widget build(BuildContext context) {
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
          listenable: MusicPlayerStateManager(),
          builder: (context, child) {
            final stateManager = MusicPlayerStateManager();

            // Debug: Log current state when builder is called
            debugPrint(
              '[MainNavigation] ListenableBuilder rebuild - isFullPlayerVisible: ${stateManager.isFullPlayerVisible}, shouldHideNavigation: ${stateManager.shouldHideNavigation}, shouldHideMiniPlayer: ${stateManager.shouldHideMiniPlayer}',
            );

            return WillPopScope(
              onWillPop: () async {
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
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                extendBodyBehindAppBar: true,
                extendBody: true,
                body: SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Determine if device should use centered 50% width layout (tablet/iPad)
                      final shortestSide =
                          MediaQuery.of(context).size.shortestSide;
                      final bool useCenteredLayout = shortestSide >= 600;
                      // On tablets/iPad use 60% inner width for mini player -> left/right = 18% each
                      final double horizontalInset =
                          useCenteredLayout
                              ? (MediaQuery.of(context).size.width * 0.18)
                              : 0.0;

                      return Stack(
                        children: [
                          // Tab content with separate navigators (only first 3 tabs are navigable)
                          TabBarView(
                            controller: _tabController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildTabNavigator(0, const HomeDiscover()),
                              _buildTabNavigator(1, const MyLibrary()),
                              _buildTabNavigator(2, Search("")),
                              // 4th tab is just a placeholder since it triggers share action
                              Container(), // Empty placeholder for share tab
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
                              ),
                            ),

                          // Global Persistent Mini Player - Hidden when full player is visible or on restricted pages
                          if (!stateManager.isFullPlayerVisible &&
                              !stateManager.shouldHideMiniPlayer)
                            Positioned(
                              left: horizontalInset,
                              right: horizontalInset,
                              bottom: _getBottomNavigationHeight(),
                              child: StreamBuilder<MediaItem?>(
                                stream: audioHandler.mediaItem,
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return MiniMusicPlayer(
                                      audioHandler,
                                    ).buildMiniPlayer(context);
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),

                          // Offline Mode Prompt - Shows when connectivity is lost
                          const OfflineModePrompt(),

                          // Offline Mode FAB - Shows when in offline mode
                          Positioned(
                            bottom: _getBottomNavigationHeight() + 16.w,
                            right: 16.w,
                            child: const OfflineModeFAB(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTabNavigator(int tabIndex, Widget child) {
    return Navigator(
      key: _navigatorKeys[tabIndex],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => child,
          settings: settings,
        );
      },
    );
  }
}

class BottomNavCustom extends StatefulWidget {
  final TabController? tabController;
  final List<GlobalKey<NavigatorState>>? navigatorKeys;

  const BottomNavCustom({super.key, this.tabController, this.navigatorKeys});

  @override
  State<BottomNavCustom> createState() => BottomNavCustomState();

  // Keep existing appBar method for backward compatibility
  PreferredSizeWidget appBar(String s, BuildContext context, int i) {
    return AppBar(title: Text(s), backgroundColor: appColors().colorBackground);
  }
}

class BottomNavCustomState extends State<BottomNavCustom>
    with TickerProviderStateMixin {
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
      'activeIcon': 'assets/images/global.svg',
      'inactiveIcon': 'assets/images/global.svg',
      'label': 'Share',
    },
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

    // Remove the post-frame callback to prevent setState after dispose
    // The initial state will be handled by the AnimatedBuilder
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

      // Check if this is the global/share icon (index 3)
      if (index == 3) {
        _showShareDialog();
        // Don't update animations or navigate for share button
        return;
      }

      // Update animations immediately (only for navigable tabs 0-2)
      _updateAnimationsForIndex(index);

      // If tapping same tab, pop to root
      if (currentIndex == index) {
        if (widget.navigatorKeys != null) {
          widget.navigatorKeys![index].currentState?.popUntil(
            (route) => route.isFirst,
          );
        }
      } else {
        // Navigate to new tab (only for tabs 0-2)
        widget.tabController!.animateTo(index);
      }

      if (mounted) {
        session['page'] = index.toString();
      }
    }
  }

  void _showShareDialog() {
    // Share the app URL with a nice message using modern SharePlus API
    final message =
        'Check out JainVerse - Your Ultimate Music Experience! 🎵\n\nDiscover, stream, and enjoy amazing music at https://jainverse.com/\n\nDownload the app now and join the musical journey!';
    final rect = computeSharePosition(context);
    if (rect != null) {
      Share.share(message, sharePositionOrigin: rect);
    } else {
      Share.share(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep outer container full width to preserve the gradient look.
    // Only the inner rounded navigation box will be constrained to 50% width on tablets.
    return Container(
      width: double.infinity,
      height: 150.w,
      decoration: BoxDecoration(
        // Gradient background for floating effect
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
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
            final double innerWidth =
                useCenteredInner
                    ? MediaQuery.of(context).size.width * 0.6
                    : double.infinity;

            // iPad specific detection: iOS + large shortest side
            final bool isiPad =
                Theme.of(context).platform == TargetPlatform.iOS &&
                shortestSide >= 600;
            // Add a small bottom margin for iPad to avoid overlap with system UI
            final double iPadBottomMargin = isiPad ? 12.w : 0.0;

            return Container(
              height: 75.w,
              // No top margin; allow a small bottom margin only on iPad
              margin:
                  useCenteredInner
                      ? EdgeInsets.only(bottom: iPadBottomMargin)
                      : EdgeInsets.fromLTRB(28.w, 0, 28.w, 12.w),
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: innerWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: appColors().gray[100],
                    borderRadius: BorderRadius.circular(44.w),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15.w,
                        spreadRadius: 1.w,
                        offset: Offset(0, 3.w),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: 0.6.w,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(navItems.length, (index) {
                      return _buildCustomNavItem(index);
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

  Widget _buildCustomNavItem(int index) {
    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(44.w),
        child: AnimatedBuilder(
          animation: widget.tabController!,
          builder: (context, child) {
            // For share button (index 3), never show as selected
            final isSelected =
                index == 3 ? false : widget.tabController!.index == index;
            final activeIconPath = navItems[index]['activeIcon']!;
            final inactiveIconPath = navItems[index]['inactiveIcon']!;

            return SizedBox(
              height: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle for selected item
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isSelected ? 62.w : 0,
                    height: isSelected ? 62.w : 0,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // SVG icon with direct color handling
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Transform.scale(
                      scale: isSelected ? 1.1 : 1.0,
                      child: SvgPicture.asset(
                        isSelected ? activeIconPath : inactiveIconPath,
                        width: 25.w,
                        height: 25.w,
                        colorFilter: ColorFilter.mode(
                          isSelected
                              ? appColors().primaryColorApp
                              : Colors.grey[500]!,
                          BlendMode.srcIn,
                        ),
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
