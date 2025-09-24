import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Manages background audio functionality and battery optimization
class BackgroundAudioManager with WidgetsBindingObserver {
  static final BackgroundAudioManager _instance =
      BackgroundAudioManager._internal();
  factory BackgroundAudioManager() => _instance;
  BackgroundAudioManager._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.jainverse.background_audio',
  );

  bool _isInitialized = false;
  bool _wakeLockEnabled = false;
  bool _playbackPausedForFocusLoss = false;
  Map<String, dynamic>? _lastPlayback;

  /// When true, allow the manager to start a native foreground service to
  /// continue playback while the app is backgrounded. Default is false so
  /// killing the app will not keep audio playing.
  bool _allowBackgroundPlayback = false;
  static const _kLastTrackKey = 'bg_last_track';

  /// Initialize background audio management
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      developer.log(
        '[DEBUG][BackgroundAudioManager] Initializing background audio manager',
        name: 'BackgroundAudioManager',
      );

      // Setup method call handlers for native communication
      _channel.setMethodCallHandler(_handleMethodCall);

      // Register for app lifecycle callbacks
      WidgetsBinding.instance.addObserver(this);

      // Request battery optimization exemption on Android
      if (Platform.isAndroid) {
        await _requestBatteryOptimizationExemption();
      }

      // Attempt to restore last playback metadata so UI (mini-player) can be
      // reconstructed after a full app restart. We do not auto-play.
      await _restoreLastPlayback();

      _isInitialized = true;
      // Notify native that our audio service is initialized (best-effort)
      await _setNativeServiceRunning(true);
      developer.log(
        '[DEBUG][BackgroundAudioManager] Background audio manager initialized successfully',
        name: 'BackgroundAudioManager',
      );
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to initialize: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Inform native iOS code about Dart player's playing state.
  Future<void> _setNativePlayingState(bool playing) async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('setNativePlayingState', {
          'playing': playing,
        });
      }
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to set native playing state: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Inform native iOS code whether the audio service is running.
  Future<void> _setNativeServiceRunning(bool running) async {
    try {
      if (Platform.isIOS) {
        await _channel.invokeMethod('setNativeServiceRunning', {
          'running': running,
        });
      }
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to set native service running: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Public helper to notify native that the Dart player started/stopped.
  /// Call this from your player code when playback starts/stops so native
  /// iOS queries reflect the Dart player's state.
  Future<void> notifyNativePlayingState(bool playing) async {
    await _setNativePlayingState(playing);
    // Persist playing state to disk so the app can restore UI on restart.
    await _persistLastPlayback();
  }

  /// Persist last playback metadata (track id, title, position, playing)
  Future<void> persistPlaybackState(Map<String, dynamic> playback) async {
    _lastPlayback = playback;
    await _persistLastPlayback();
  }

  Future<void> _persistLastPlayback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastPlayback == null) return;
      // store as JSON for robust parsing
      await prefs.setString(_kLastTrackKey, jsonEncode(_lastPlayback));
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to persist last playback: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  Future<void> _restoreLastPlayback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_kLastTrackKey)) return;
      final raw = prefs.getString(_kLastTrackKey);
      if (raw == null || raw.isEmpty) return;
      // parse JSON, but fall back to old map.toString parsing for older installs
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _lastPlayback = decoded;
      } on FormatException {
        // stored as map.toString() previously; attempt a best-effort parse
        final parsed = <String, dynamic>{};
        final trimmed = raw.replaceAll(RegExp(r'[{}]'), '');
        for (final part in trimmed.split(',')) {
          final kv = part.split(':');
          if (kv.length < 2) continue;
          final key = kv[0].trim();
          final value = kv.sublist(1).join(':').trim();
          parsed[key] = value;
        }
        _lastPlayback = parsed;
      }
      developer.log(
        '[DEBUG][BackgroundAudioManager] Restored last playback metadata: $_lastPlayback',
        name: 'BackgroundAudioManager',
      );
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to restore last playback: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Return the last persisted playback metadata, if any.
  Map<String, dynamic>? getLastPlaybackState() => _lastPlayback;

  /// Public helper to notify native whether the audio service is running.
  Future<void> notifyNativeServiceRunning(bool running) async {
    await _setNativeServiceRunning(running);
  }

  /// Handle method calls from native platforms
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onBatteryOptimizationResult':
          final isExempt = call.arguments['isExempt'] as bool? ?? false;
          _handleBatteryOptimizationResult(isExempt);
          break;
        case 'onAudioFocusChanged':
          final hasFocus = call.arguments['hasFocus'] as bool? ?? false;
          _handleAudioFocusChanged(hasFocus);
          break;
        default:
          developer.log(
            '[WARNING][BackgroundAudioManager] Unknown method call: ${call.method}',
            name: 'BackgroundAudioManager',
          );
      }
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Error handling method call: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _handleAppLifecycleState(state);
  }

  /// Request battery optimization exemption for uninterrupted background playback
  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      developer.log(
        '[DEBUG][BackgroundAudioManager] Requesting battery optimization exemption',
        name: 'BackgroundAudioManager',
      );

      final result = await _channel.invokeMethod(
        'requestBatteryOptimizationExemption',
      );
      developer.log(
        '[DEBUG][BackgroundAudioManager] Battery optimization exemption result: $result',
        name: 'BackgroundAudioManager',
      );
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to request battery optimization exemption: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Handle battery optimization result
  void _handleBatteryOptimizationResult(bool isExempt) {
    developer.log(
      '[DEBUG][BackgroundAudioManager] Battery optimization exemption: $isExempt',
      name: 'BackgroundAudioManager',
    );

    if (!isExempt) {
      developer.log(
        '[WARNING][BackgroundAudioManager] App is not exempt from battery optimization - background playback may be interrupted',
        name: 'BackgroundAudioManager',
      );
    }
  }

  /// Handle audio focus changes
  void _handleAudioFocusChanged(bool hasFocus) {
    developer.log(
      '[DEBUG][BackgroundAudioManager] Audio focus changed: $hasFocus',
      name: 'BackgroundAudioManager',
    );
    // Add proper playback state management
    if (hasFocus) {
      // Resume playback if it was paused due to focus loss
      _resumePlaybackIfNeeded();
    } else {
      // Pause playback when losing focus
      _pausePlaybackForFocusLoss();
    }
  }

  /// Check if playback is currently active (asks native/audio service)
  Future<bool> _isPlaying() async {
    try {
      final result = await _channel.invokeMethod('isPlaying');
      return result as bool? ?? false;
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to check isPlaying: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
      return false;
    }
  }

  /// Pause playback when losing audio focus and remember that we paused it
  Future<void> _pausePlaybackForFocusLoss() async {
    try {
      final playing = await _isPlaying();
      if (playing) {
        developer.log(
          '[DEBUG][BackgroundAudioManager] Pausing playback due to focus loss',
          name: 'BackgroundAudioManager',
        );
        await _channel.invokeMethod('pausePlayback');
        _playbackPausedForFocusLoss = true;
        // Sync native playing state (iOS best-effort)
        await _setNativePlayingState(false);
      }
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to pause for focus loss: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Resume playback if it was paused due to audio focus loss
  Future<void> _resumePlaybackIfNeeded() async {
    try {
      if (_playbackPausedForFocusLoss) {
        developer.log(
          '[DEBUG][BackgroundAudioManager] Resuming playback after focus gain',
          name: 'BackgroundAudioManager',
        );
        await _channel.invokeMethod('resumePlayback');
        _playbackPausedForFocusLoss = false;
        // Sync native playing state (iOS best-effort)
        await _setNativePlayingState(true);
      }
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to resume playback: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Start foreground service for background playback
  Future<void> startForegroundService() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('startForegroundService');
        developer.log(
          '[DEBUG][BackgroundAudioManager] Requested startForegroundService',
          name: 'BackgroundAudioManager',
        );
        // Inform native that the service should be running (no-op on Android/iOS mix)
        await _setNativeServiceRunning(true);
      }
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to start foreground service: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Monitor app lifecycle state
  void _handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // App is backgrounded or hidden
        _onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        // App is foregrounded
        _onAppForegrounded();
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        dispose();
        break;
      case AppLifecycleState.inactive:
        // no-op for now
        break;
    }
  }

  void _onAppBackgrounded() {
    developer.log(
      '[DEBUG][BackgroundAudioManager] App backgrounded - ensuring foreground service',
      name: 'BackgroundAudioManager',
    );
    // Only start the audio service as a foreground service if background
    // playback is explicitly allowed. Default is to NOT start it so that
    // killing the app stops playback.
    if (_allowBackgroundPlayback) {
      // Start the foreground service only when playback is active.
      _isPlaying().then((playing) {
        if (playing) {
          startForegroundService();
        } else {
          developer.log(
            '[DEBUG][BackgroundAudioManager] Not playing; skipping startForegroundService',
            name: 'BackgroundAudioManager',
          );
        }
      });
    } else {
      developer.log(
        '[DEBUG][BackgroundAudioManager] Background playback disabled; stopping playback and native service to avoid background audio',
        name: 'BackgroundAudioManager',
      );
      // Ensure any ongoing playback or native foreground service is stopped
      // so killing the app or backgrounding from special screens doesn't
      // leave audio playing.
      stopPlaybackAndService();
    }
    // Keep wake lock if already enabled
    if (_wakeLockEnabled) {
      enableWakeLock();
    }
  }

  /// Stop the native foreground service (Android) if running.
  Future<void> stopForegroundService() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('stopForegroundService');
        developer.log(
          '[DEBUG][BackgroundAudioManager] Requested stopForegroundService',
          name: 'BackgroundAudioManager',
        );
        await _setNativeServiceRunning(false);
      }
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to stop foreground service: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Stop playback and the native foreground service. Use when the app is
  /// being disposed or when the user explicitly wants playback to stop when
  /// the app is closed.
  Future<void> stopPlaybackAndService() async {
    try {
      if (Platform.isAndroid) {
        // Ask native to stop playback first, then stop the service.
        await _channel.invokeMethod('stopPlayback');
        developer.log(
          '[DEBUG][BackgroundAudioManager] Requested stopPlayback',
          name: 'BackgroundAudioManager',
        );
        await stopForegroundService();
      } else {
        // For iOS, inform native the service is no longer running.
        await _setNativeServiceRunning(false);
      }
      // Update local state
      _wakeLockEnabled = false;
      _playbackPausedForFocusLoss = false;
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to stop playback/service: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  void _onAppForegrounded() {
    developer.log(
      '[DEBUG][BackgroundAudioManager] App foregrounded',
      name: 'BackgroundAudioManager',
    );
    // Optionally release wake lock when returning to foreground
    // leave as-is to avoid interrupting playback
  }

  /// Check if audio service is still running
  Future<bool> isAudioServiceRunning() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('isAudioServiceRunning');
        return result as bool? ?? false;
      }
      return true;
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to check audio service running: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
      return false;
    }
  }

  /// Restart audio service if crashed
  Future<void> restartAudioServiceIfNeeded() async {
    try {
      final isRunning = await isAudioServiceRunning();
      if (!isRunning) {
        developer.log(
          '[WARNING][BackgroundAudioManager] Audio service crashed, restarting...',
          name: 'BackgroundAudioManager',
        );
        await initialize();
      }
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to restart audio service: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Call this before attempting to resume playback
  Future<bool> ensureAudioServiceReady() async {
    try {
      await restartAudioServiceIfNeeded();

      // Give the service a moment to initialize
      await Future.delayed(Duration(milliseconds: 500));

      final status = await getBackgroundPlaybackStatus();
      return !status.containsKey('error');
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to ensure audio service ready: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
      return false;
    }
  }

  /// Enable wake lock for continuous playback
  Future<void> enableWakeLock() async {
    if (_wakeLockEnabled) return;

    try {
      developer.log(
        '[DEBUG][BackgroundAudioManager] Enabling wake lock',
        name: 'BackgroundAudioManager',
      );

      if (Platform.isAndroid) {
        await _channel.invokeMethod('acquireWakeLock');
      }

      _wakeLockEnabled = true;
      developer.log(
        '[DEBUG][BackgroundAudioManager] Wake lock enabled successfully',
        name: 'BackgroundAudioManager',
      );
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to enable wake lock: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Disable wake lock when playback stops
  Future<void> disableWakeLock() async {
    if (!_wakeLockEnabled) return;

    try {
      developer.log(
        '[DEBUG][BackgroundAudioManager] Disabling wake lock',
        name: 'BackgroundAudioManager',
      );

      if (Platform.isAndroid) {
        await _channel.invokeMethod('releaseWakeLock');
      }

      _wakeLockEnabled = false;
      developer.log(
        '[DEBUG][BackgroundAudioManager] Wake lock disabled successfully',
        name: 'BackgroundAudioManager',
      );
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to disable wake lock: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Check if device has battery optimization exemption
  Future<bool> isBatteryOptimizationExempt() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod(
          'isBatteryOptimizationExempted',
        );
        return result as bool? ?? false;
      }
      return true; // iOS doesn't have this concept
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to check battery optimization status: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
      return false;
    }
  }

  /// Show battery optimization settings to user
  Future<void> showBatteryOptimizationSettings() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('showBatteryOptimizationSettings');
        developer.log(
          '[DEBUG][BackgroundAudioManager] Opened battery optimization settings',
          name: 'BackgroundAudioManager',
        );
      }
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to show battery optimization settings: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Monitor background playback health
  Future<Map<String, dynamic>> getBackgroundPlaybackStatus() async {
    try {
      final status = <String, dynamic>{
        'wakeLockEnabled': _wakeLockEnabled,
        'isInitialized': _isInitialized,
        'batteryOptimizationExempt': await isBatteryOptimizationExempt(),
        'platform': Platform.operatingSystem,
      };

      developer.log(
        '[DEBUG][BackgroundAudioManager] Background playback status: $status',
        name: 'BackgroundAudioManager',
      );

      return status;
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Failed to get background playback status: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
      return {'error': e.toString()};
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      // Unregister lifecycle observer
      WidgetsBinding.instance.removeObserver(this);
      await disableWakeLock();
      // Ensure native playback and any foreground service are stopped so the
      // app being killed doesn't leave audio playing in the background.
      await stopPlaybackAndService();
      _isInitialized = false;
      developer.log(
        '[DEBUG][BackgroundAudioManager] Background audio manager disposed',
        name: 'BackgroundAudioManager',
      );
    } catch (e) {
      developer.log(
        '[ERROR][BackgroundAudioManager] Error during disposal: $e',
        name: 'BackgroundAudioManager',
        error: e,
      );
    }
  }

  /// Call this to allow/disallow background playback (default: false).
  /// When false the manager will not start a native foreground service when
  /// the app is backgrounded, and will stop playback/service on dispose.
  void enableBackgroundPlayback(bool allow) {
    _allowBackgroundPlayback = allow;
    developer.log(
      '[DEBUG][BackgroundAudioManager] Background playback allowed: $_allowBackgroundPlayback',
      name: 'BackgroundAudioManager',
    );
  }
}
