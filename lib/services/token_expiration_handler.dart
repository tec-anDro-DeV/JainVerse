import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/UI/Login.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TokenExpirationHandler {
  static final TokenExpirationHandler _instance =
      TokenExpirationHandler._internal();
  factory TokenExpirationHandler() => _instance;
  TokenExpirationHandler._internal();

  final SharedPref _sharePrefs = SharedPref();
  bool _isDialogShowing = false;

  /// True when the handler has already performed the logout/cleanup flow.
  /// This prevents repeated auto-logout cycles when background requests
  /// continue to receive 401 after we already cleared the token and
  /// navigated to the Login screen.
  bool _logoutPerformed = false;

  /// Check if the response indicates token expiration
  bool isTokenExpired(Response? response) {
    if (response?.statusCode != 401) return false;

    try {
      final responseData = response?.data;
      if (responseData == null) return false;

      Map<String, dynamic> data;
      if (responseData is String) {
        data = json.decode(responseData);
      } else if (responseData is Map<String, dynamic>) {
        data = responseData;
      } else {
        return false;
      }

      return data['status'] == false &&
          data['error'] == 'token_expired' &&
          data['message']?.toString().toLowerCase().contains('expired') == true;
    } catch (e) {
      return false;
    }
  }

  /// Handle token expiration by showing dialog and auto-logout.
  ///
  /// A [BuildContext] may be passed for cases where the caller has one, but we
  /// will prefer the global `navigatorKey.currentContext`/`currentState` so we
  /// don't keep a BuildContext across async gaps (which triggers analyzer
  /// warnings). If no context is available, we perform a best-effort cleanup
  /// and navigate to the login screen using the navigator key.
  Future<void> handleTokenExpiration([BuildContext? context]) async {
    if (_isDialogShowing || _logoutPerformed) return; // Prevent repeats
    _isDialogShowing = true;
    // Mark as performed early so concurrent callers bail out quickly.
    _logoutPerformed = true;

    try {
      // Show the login expired dialog using the navigatorKey if possible.
      await _showLoginExpiredDialog(context);

      // Auto logout after dialog (uses navigatorKey internally)
      await _performAutoLogout();
    } finally {
      _isDialogShowing = false;
    }
  }

  /// Reset the internal logout flag. Call this after a successful login to
  /// allow the token-expiration handler to run again in the future.
  void reset() {
    _logoutPerformed = false;
    _isDialogShowing = false;
  }

  /// Show the login expired dialog that auto-closes after 3 seconds
  Future<void> _showLoginExpiredDialog([BuildContext? context]) async {
    final completer = Completer<void>();

    final BuildContext? dialogContext = context ?? navigatorKey.currentContext;
    if (dialogContext == null) {
      // If we don't have a context we can't show the dialog; just wait a
      // short period to mimic the dialog's duration so the caller's flow is
      // preserved, then return.
      await Future.delayed(const Duration(seconds: 1));
      return;
    }

    showDialog<void>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (BuildContext builderDialogContext) {
        // Auto-close after 3 seconds
        Timer(const Duration(seconds: 3), () {
          if (Navigator.of(builderDialogContext).canPop()) {
            Navigator.of(builderDialogContext).pop();
          }
          completer.complete();
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320.w,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.w),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container with background
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5722).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    size: 40.w,
                    color: const Color(0xFFFF5722),
                  ),
                ),

                SizedBox(height: 24.w),

                // Title
                Text(
                  'Login Expired',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),

                SizedBox(height: 12.w),

                // Message
                Text(
                  'Your account may have been logged in on another device.\nPlease log in again to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'Poppins',
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 24.w),

                // Auto-close indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.w,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF5722),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Auto-closing in 3 seconds...',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12.sp,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return completer.future;
  }

  /// Perform automatic logout
  Future<void> _performAutoLogout() async {
    try {
      // We intentionally skip calling the remote Logout API here to avoid
      // relying on widget BuildContext across async gaps. Remote logout can
      // still be triggered from UI flows where a BuildContext is available.

      // Clear all cache data including images
      await CacheManager.clearAllCacheIncludingImages();

      // Clear shared preferences
      await _sharePrefs.removeValues();

      // Clear static variables in AccountPage if they exist
      _clearStaticVariables();

      // Stop playback and hide music UI to fully reset app state
      try {
        final musicManager = MusicManager();
        await musicManager.stop();
      } catch (e) {
        // ignore errors - best-effort
        print('Error stopping music manager during logout: $e');
      }

      try {
        final stateManager = MusicPlayerStateManager();
        // Ensure full player is hidden and bottom navigation/mini player are hidden
        stateManager.hideFullPlayer();
        stateManager.setNavigationVisibility(false);
      } catch (e) {
        print('Error updating music UI state during logout: $e');
      }

      // Navigate to login screen using the global navigator key if possible.
      try {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (BuildContext _) => const Login()),
          (Route<dynamic> route) => false,
        );
      } catch (e) {
        // ignore navigation errors
      }
    } catch (e) {
      print('Error during auto-logout: $e');
      // Still attempt to navigate to login even if cleanup fails
      try {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (BuildContext _) => const Login()),
          (Route<dynamic> route) => false,
        );
      } catch (_) {}
    }
  }

  /// Clear static variables (similar to AccountPage implementation)
  void _clearStaticVariables() {
    // This would typically clear static variables from AccountPage
    // Since we can't import AccountPage directly to avoid circular dependencies,
    // we'll handle this in the integration phase
  }

  /// Create a Dio interceptor for automatic token expiration handling
  Interceptor createTokenExpirationInterceptor(BuildContext context) {
    return InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) {
        if (isTokenExpired(error.response)) {
          // Handle token expiration. We deliberately avoid passing the
          // original BuildContext into the handler to prevent using the
          // context across async gaps; the handler will fall back to the
          // global navigator key if needed.
          handleTokenExpiration();
        }
        // Continue with the error
        handler.next(error);
      },
    );
  }

  /// Manually check response for token expiration (for existing API calls)
  /// Check response for token expiration. If [context] is null, the method will
  /// try to resolve a BuildContext from the global `navigatorKey` defined in
  /// `main.dart` so the dialog can still be presented.
  Future<bool> checkAndHandleResponse(
    Response? response, {
    BuildContext? context,
  }) async {
    if (!isTokenExpired(response)) return false;
    if (_logoutPerformed) return true; // already handled
    // Trigger the handler which will use the navigator key internally and
    // perform the full cleanup + navigation. We intentionally do not pass
    // the BuildContext here to avoid analyzer warnings about using a
    // BuildContext across async gaps.
    await handleTokenExpiration();
    return true;
  }
}
