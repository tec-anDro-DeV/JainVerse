import 'package:flutter/services.dart';

/// Helper to request native orientation-lock changes on iOS.
///
/// This uses a MethodChannel ('com.jainverse.orientation') implemented
/// in `ios/Runner/AppDelegate.swift` to update the mask returned by
/// application(_:supportedInterfaceOrientationsFor:).
class OrientationHelper {
  static const MethodChannel _channel = MethodChannel(
    'com.jainverse.orientation',
  );

  /// Set a named orientation lock on the native side.
  /// Allowed names: 'portrait', 'portraitUpsideDown', 'landscape',
  /// 'landscapeLeft', 'landscapeRight', 'all'.
  static Future<void> setOrientationLock(String name) async {
    try {
      await _channel.invokeMethod('setOrientationLock', {'orientation': name});
    } catch (_) {}
  }

  static Future<void> setLandscape() => setOrientationLock('landscape');
  static Future<void> setPortrait() => setOrientationLock('portrait');
  static Future<void> setAll() => setOrientationLock('all');
}
