import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../ThemeMain/appColors.dart';
import '../services/offline_mode_service.dart';

/// Floating prompt widget that appears when connectivity is lost
/// Allows user to choose whether to switch to offline mode
class OfflineModePrompt extends StatefulWidget {
  const OfflineModePrompt({super.key});

  @override
  State<OfflineModePrompt> createState() => _OfflineModePromptState();
}

class _OfflineModePromptState extends State<OfflineModePrompt>
    with SingleTickerProviderStateMixin {
  final OfflineModeService _offlineModeService = OfflineModeService();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen to offline prompt requests
    _offlineModeService.offlinePromptStream.listen((shouldShow) {
      if (mounted) {
        if (shouldShow && !_isVisible) {
          _showPrompt();
        } else if (!shouldShow && _isVisible) {
          _hidePrompt();
        }
      }
    });

    // Check initial state
    if (!_offlineModeService.hasConnectivity &&
        _offlineModeService.isUserLoggedIn &&
        !_offlineModeService.isOfflineMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPrompt();
      });
    }
  }

  void _showPrompt() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });
      _animationController.forward();
    }
  }

  void _hidePrompt() {
    if (_isVisible) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isVisible = false;
          });
        }
      });
    }
  }

  void _switchToOffline() {
    debugPrint('[OfflineModePrompt] User chose to switch to offline mode');
    _hidePrompt();
    // Switch immediately without delays
    _offlineModeService.switchToOfflineMode();
  }

  void _stayOnline() {
    debugPrint('[OfflineModePrompt] User chose to stay online');
    _hidePrompt();
    _offlineModeService.declineOfflineMode();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16.w,
      left: 16.w,
      right: 16.w,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[700]!, Colors.orange[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'No Internet Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.w),
                  Text(
                    'Would you like to switch to offline mode to continue using the app with your downloaded content?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14.sp,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 16.w),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _stayOnline,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12.w),
                          ),
                          child: Text(
                            'Stay Online',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _switchToOffline,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12.w),
                            elevation: 2,
                          ),
                          child: Text(
                            'Go Offline',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating action button that appears when user is offline
/// Allows quick access to switch back to online mode when connectivity is restored
class OfflineModeFAB extends StatefulWidget {
  const OfflineModeFAB({super.key});

  @override
  State<OfflineModeFAB> createState() => _OfflineModeFABState();
}

class _OfflineModeFABState extends State<OfflineModeFAB>
    with SingleTickerProviderStateMixin {
  final OfflineModeService _offlineModeService = OfflineModeService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _shouldShow = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen to both offline mode and connectivity changes
    _offlineModeService.offlineModeStream.listen((_) {
      _updateVisibility();
    });

    _offlineModeService.connectivityStream.listen((_) {
      _updateVisibility();
    });

    // Listen to connectivity restoration events
    _offlineModeService.connectivityRestoredStream.listen((restored) {
      if (restored) {
        _updateVisibility();
      }
    });

    // Check initial state
    _updateVisibility();
  }

  void _updateVisibility() {
    if (mounted) {
      // Show FAB when:
      // 1. User is in offline mode AND logged in, OR
      // 2. User is in offline mode AND connectivity is restored (so they can switch back)
      final shouldShow =
          _offlineModeService.isOfflineMode &&
          _offlineModeService.isUserLoggedIn;

      if (shouldShow != _shouldShow) {
        setState(() {
          _shouldShow = shouldShow;
        });

        if (_shouldShow) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      }
    }
  }

  void _toggleOfflineMode() {
    if (_offlineModeService.hasConnectivity &&
        _offlineModeService.isOfflineMode) {
      // If we have connectivity and are offline, go back online
      debugPrint('[OfflineModeFAB] Switching to online mode');
      _offlineModeService.switchToOnlineMode().catchError((error) {
        debugPrint('[OfflineModeFAB] Error switching to online mode: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Failed to switch to online mode. Please check your connection.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: appColors().primaryColorApp.withOpacity(0.6),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          );
        }
      });
    } else if (!_offlineModeService.hasConnectivity) {
      // If no connectivity, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'No internet connection available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FloatingActionButton.extended(
        onPressed: _shouldShow ? _toggleOfflineMode : null,
        backgroundColor:
            _offlineModeService.hasConnectivity
                ? appColors().primaryColorApp
                : Colors.orange[600],
        foregroundColor: Colors.white,
        icon: Icon(
          _offlineModeService.hasConnectivity
              ? Icons.wifi_rounded
              : Icons.wifi_off_rounded,
          size: 20.sp,
        ),
        label: Text(
          _offlineModeService.hasConnectivity ? 'Go Online' : 'Offline Mode',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
        elevation: 4,
        extendedPadding: EdgeInsets.symmetric(horizontal: 16.w),
      ),
    );
  }
}

/// Connectivity restoration notification widget
class ConnectivityRestoredNotification extends StatefulWidget {
  const ConnectivityRestoredNotification({super.key});

  @override
  State<ConnectivityRestoredNotification> createState() =>
      _ConnectivityRestoredNotificationState();
}

class _ConnectivityRestoredNotificationState
    extends State<ConnectivityRestoredNotification>
    with SingleTickerProviderStateMixin {
  final OfflineModeService _offlineModeService = OfflineModeService();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen to connectivity restoration events
    _offlineModeService.connectivityRestoredStream.listen((restored) {
      if (restored && mounted) {
        _showNotification();
        // Auto-hide after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _hideNotification();
        });
      }
    });
  }

  void _showNotification() {
    if (!_isVisible) {
      setState(() {
        _isVisible = true;
      });
      _animationController.forward();
    }
  }

  void _hideNotification() {
    if (_isVisible) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isVisible = false;
          });
        }
      });
    }
  }

  void _goOnline() {
    _hideNotification();
    _offlineModeService.switchToOnlineMode();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16.w,
      right: 16.w,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              width: 280.w,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[700]!, Colors.green[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wifi_rounded,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Internet Restored!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _hideNotification,
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.w),
                  Text(
                    'You can now switch back to online mode.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12.sp,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 12.w),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _goOnline,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8.w),
                        elevation: 0,
                      ),
                      child: Text(
                        'Go Online',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
