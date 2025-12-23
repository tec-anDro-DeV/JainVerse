import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/video_player_state.dart';

typedef PipAsyncCallback = FutureOr<void> Function();
typedef PipStateChangedCallback = void Function(bool isInPip);

typedef _MethodArguments = Map<dynamic, dynamic>?;

/// Callbacks invoked when the native PiP host triggers actions.
class PictureInPictureCallbacks {
  const PictureInPictureCallbacks({
    this.onTogglePlayPause,
    this.onStateChanged,
    this.onClosed,
  });

  final PipAsyncCallback? onTogglePlayPause;
  final PipStateChangedCallback? onStateChanged;

  /// Called when PiP is closed via the system close button
  final PipAsyncCallback? onClosed;
}

/// Thin wrapper around the platform channel that manages Picture-in-Picture
/// requests and action callbacks for the video player experience.
class VideoPipService {
  VideoPipService._();

  static final VideoPipService instance = VideoPipService._();

  static const MethodChannel _channel = MethodChannel('com.jainverse.pip');

  PictureInPictureCallbacks? _callbacks;
  bool _initialized = false;
  bool? _supportsPiPCache;
  double? _lastAspectRatio;

  void _ensureInitialized() {
    if (_initialized) return;
    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
  }

  void registerCallbacks(PictureInPictureCallbacks callbacks) {
    _ensureInitialized();
    _callbacks = callbacks;
  }

  void clearCallbacks() {
    _callbacks = null;
  }

  Future<bool> isPictureInPictureSupported() async {
    _ensureInitialized();
    // PiP is disabled on iOS.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _supportsPiPCache = false;
      return false;
    }
    if (_supportsPiPCache != null) {
      return _supportsPiPCache!;
    }
    try {
      final supported =
          await _channel.invokeMethod<bool>('isPictureInPictureSupported') ??
          false;
      _supportsPiPCache = supported;
      return supported;
    } catch (e) {
      debugPrint('[VideoPiP] Failed to query support: $e');
      _supportsPiPCache = false;
      return false;
    }
  }

  Future<bool> enterPictureInPicture(
    VideoPlayerState state, {
    bool autoTriggered = false,
  }) async {
    _ensureInitialized();
    // Block PiP entirely on iOS.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return false;
    }
    if (!await isPictureInPictureSupported()) {
      return false;
    }

    final aspectRatio = _resolveAspectRatio(state.controller);
    _lastAspectRatio = aspectRatio;

    try {
      final videoUrl = state.currentVideoItem?.videoUrl;
      debugPrint(
        '[VideoPiP][Dart] enterPictureInPicture - videoUrl: $videoUrl, position: ${state.position.inMilliseconds}ms, isPlaying: ${state.isPlaying}',
      );
      if (videoUrl == null || videoUrl.isEmpty) {
        debugPrint(
          '[VideoPiP][Dart] No videoUrl available; currentVideoItem: ${state.currentVideoItem}',
        );
        return false;
      }
      final success =
          await _channel
              .invokeMethod<bool>('enterPictureInPicture', <String, dynamic>{
                'title': state.currentVideoTitle,
                'subtitle': state.currentVideoSubtitle,
                'thumbnail': state.thumbnailUrl,
                'isPlaying': state.isPlaying,
                'positionMs': state.position.inMilliseconds,
                'durationMs': state.duration.inMilliseconds,
                'aspectRatio': aspectRatio,
                'autoTriggered': autoTriggered,
                'videoUrl': videoUrl,
              }) ??
          false;
      return success;
    } catch (e, st) {
      debugPrint('[VideoPiP] enterPictureInPicture failed: $e\n$st');
      return false;
    }
  }

  Future<void> updatePlaybackState(bool isPlaying) async {
    if (!_initialized) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>(
        'updatePlaybackState',
        <String, dynamic>{
          'isPlaying': isPlaying,
          'aspectRatio': _lastAspectRatio,
        },
      );
    } catch (e) {
      debugPrint('[VideoPiP] Failed to update playback state: $e');
    }
  }

  Future<void> exitPictureInPicture() async {
    if (!_initialized) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('exitPictureInPicture');
    } catch (e) {
      debugPrint('[VideoPiP] Failed to exit PiP: $e');
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPipAction':
      case 'onAction':
        final action =
            (call.arguments as _MethodArguments)?['action'] as String?;
        if (action == null) return;
        if (action == 'togglePlayback') {
          await _invokeAsync(_callbacks?.onTogglePlayPause);
        }
        break;
      case 'onPipClosed':
        // System close button was used - pause the video and update state
        await _invokeAsync(_callbacks?.onClosed);
        _callbacks?.onStateChanged?.call(false);
        break;
      case 'onPipExpanded':
        // PiP expanded back to full screen — just update state, no pause
        _callbacks?.onStateChanged?.call(false);
        break;
      case 'onPipStateChanged':
        final isInPip =
            (call.arguments as _MethodArguments)?['isInPip'] as bool? ?? false;
        _callbacks?.onStateChanged?.call(isInPip);
        break;
    }
  }

  Future<void> _invokeAsync(PipAsyncCallback? callback) async {
    if (callback == null) return;
    await Future.sync(callback);
  }

  double _resolveAspectRatio(VideoPlayerController? controller) {
    if (controller == null) return 16 / 9;
    try {
      if (controller.value.isInitialized) {
        final ratio = controller.value.aspectRatio;
        if (ratio.isFinite && ratio > 0) {
          return max(0.1, min(ratio, 5));
        }
      }
    } catch (_) {
      // ignore invalid controller states
    }
    return 16 / 9;
  }
}
