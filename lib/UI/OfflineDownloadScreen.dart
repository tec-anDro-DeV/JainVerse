import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../UI/Download.dart';
import '../widgets/music/mini_music_player.dart';
import '../services/audio_player_service.dart';
import '../widgets/offline_mode_prompt.dart';
import 'dart:developer' as developer;

class OfflineDownloadScreen extends StatefulWidget {
  const OfflineDownloadScreen({super.key});

  @override
  State<OfflineDownloadScreen> createState() => _OfflineDownloadScreenState();
}

class _OfflineDownloadScreenState extends State<OfflineDownloadScreen> {
  AudioPlayerHandler? _audioHandler;

  @override
  void initState() {
    super.initState();
    debugPrint('[OfflineDownloadScreen] Initializing...');
    // Initialize audio handler in background - don't block UI
    _initializeAudioHandlerInBackground();
  }

  void _initializeAudioHandlerInBackground() {
    // Run audio handler initialization in background without blocking UI
    Future(() async {
      try {
        // Try to get the existing global audio handler from main.dart
        _audioHandler =
            _audioHandler ??
            await AudioService.init(
              builder: () => AudioPlayerHandlerImpl(),
              config: const AudioServiceConfig(
                androidNotificationChannelId: 'com.jainverse.music.channel.audio',
                androidNotificationChannelName: 'Music playback',
                androidNotificationOngoing: true,
              ),
            );
        debugPrint(
          '[OfflineDownloadScreen] Audio handler initialized successfully',
        );
      } catch (e) {
        debugPrint(
          '[OfflineDownloadScreen] Error initializing audio handler: $e',
        );
        // Continue without audio handler - offline mode can still work
      }

      // Update UI only after audio handler is ready
      if (mounted) {
        setState(() {});
      }
    });
  }

  // Calculate dynamic bottom navigation height for mini player positioning
  double _getBottomNavigationHeight() {
    // Total height includes gradient area (90.w) + SafeArea bottom
    return 90.w + MediaQuery.of(context).padding.bottom;
  }

  void _showOfflineModeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 20.sp),
            SizedBox(width: 8.w),
            const Text('You are in offline mode'),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: _getBottomNavigationHeight() + 16.w,
          left: 16.w,
          right: 16.w,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[OfflineDownloadScreen] Building widget...');

    return _ErrorBoundary(
      context: 'OfflineDownloadScreen.build',
      child: PopScope(
        canPop: false, // Prevent back navigation when offline
        onPopInvoked: (didPop) {
          if (!didPop && mounted) {
            _showOfflineModeMessage();
          }
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              // Always show Download content immediately - don't wait for audio handler
              _ErrorBoundary(
                context: 'Download Widget',
                child: const Download(),
              ),

              // Mini Player - only show if audio handler is ready
              if (_audioHandler != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _getBottomNavigationHeight(),
                  child: StreamBuilder<MediaItem?>(
                    stream: _audioHandler!.mediaItem,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return _ErrorBoundary(
                          context: 'MiniMusicPlayer',
                          child: MiniMusicPlayer(
                            _audioHandler!,
                          ).buildMiniPlayer(context),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),

              // Main Navigation but non-touchable with offline message
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _ErrorBoundary(
                  context: 'OfflineBottomNavigation',
                  child: OfflineBottomNavigation(
                    onTap: _showOfflineModeMessage,
                  ),
                ),
              ),

              // Connectivity restoration notification
              const ConnectivityRestoredNotification(),

              // Offline mode FAB for going back online
              // const Positioned(bottom: 100, right: 16, child: OfflineModeFAB()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offline-specific bottom navigation that looks like main navigation but shows message when tapped
class OfflineBottomNavigation extends StatelessWidget {
  final VoidCallback onTap;

  const OfflineBottomNavigation({super.key, required this.onTap});

  // Navigation item data structure (same as MainNavigation)
  final List<Map<String, String>> navItems = const [
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

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 75.w,
            margin: EdgeInsets.fromLTRB(28.w, 0, 28.w, 12.w),
            decoration: BoxDecoration(
              color: Colors.grey[100]?.withOpacity(0.8), // Slightly more muted
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
                color:
                    Colors.orange.shade200, // Orange border to indicate offline
                width: 1.w,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(navItems.length, (index) {
                return _buildOfflineNavItem(index);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineNavItem(int index) {
    // Show Downloads tab as "selected" (index 1 = Library/Downloads)
    final isSelected = index == 1; // Downloads tab appears selected
    final activeIconPath = navItems[index]['activeIcon']!;
    final inactiveIconPath = navItems[index]['inactiveIcon']!;

    return Expanded(
      child: SizedBox(
        height: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle for selected item (Downloads tab)
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
            // SVG icon - but muted to show it's not interactive
            Container(
              child: Transform.scale(
                scale: isSelected ? 1.1 : 1.0,
                child: SvgPicture.asset(
                  isSelected ? activeIconPath : inactiveIconPath,
                  width: 25.w,
                  height: 25.w,
                  colorFilter: ColorFilter.mode(
                    isSelected
                        ? Colors
                            .orange[600]! // Orange for offline downloads tab
                        : Colors.grey[400]!, // More muted for other tabs
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBoundary extends StatelessWidget {
  final Widget child;
  final String context;

  const _ErrorBoundary({required this.child, required this.context});

  @override
  Widget build(BuildContext buildContext) {
    return Builder(
      builder: (buildContext) {
        try {
          return child;
        } catch (e, stackTrace) {
          developer.log(
            'Error in $context: $e',
            name: 'OfflineDownloadScreen',
            error: e,
            stackTrace: stackTrace,
          );
          return Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48.sp, color: Colors.red),
                  SizedBox(height: 16.w),
                  Text(
                    'Error in $context',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.w),
                  Text(
                    e.toString(),
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
