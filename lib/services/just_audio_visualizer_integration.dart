import 'dart:io';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Helper service to integrate audio visualizer with just_audio player
class JustAudioVisualizerIntegration {
  static const MethodChannel _channel = MethodChannel(
    'just_audio_visualizer_integration',
  );

  /// Get the audio session ID from just_audio player (Android only)
  /// Returns null on iOS or if unable to get session ID
  static Future<int?> getAudioSessionId(AudioPlayer player) async {
    if (!Platform.isAndroid) {
      return null; // iOS doesn't need audio session ID
    }

    try {
      // Try to get the audio session ID from just_audio
      // Note: This may require modifications to just_audio plugin or custom implementation
      final int? sessionId = await _channel.invokeMethod('getAudioSessionId', {
        'playerId': player.hashCode.toString(),
      });

      return sessionId;
    } catch (e) {
      // Fallback: Use a default session ID or handle gracefully
      return 0; // AudioManager.AUDIO_SESSION_ID_GENERATE
    }
  }

  /// Setup method channel handler for just_audio integration
  static void setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAudioSessionIdChanged':
          // Handle session ID changes if needed
          // final int? sessionId = call.arguments['sessionId'];
          // final String? playerId = call.arguments['playerId'];
          break;
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: 'Method ${call.method} not implemented',
          );
      }
    });
  }
}

/// Enhanced wrapper around AudioPlayer with visualizer integration
class VisualizerAudioPlayer {
  final AudioPlayer _player;
  int? _audioSessionId;

  VisualizerAudioPlayer() : _player = AudioPlayer() {
    _initializeVisualizerIntegration();
  }

  /// Get the underlying AudioPlayer instance
  AudioPlayer get player => _player;

  /// Get the current audio session ID (Android only)
  int? get audioSessionId => _audioSessionId;

  /// Initialize visualizer integration
  Future<void> _initializeVisualizerIntegration() async {
    try {
      _audioSessionId = await JustAudioVisualizerIntegration.getAudioSessionId(
        _player,
      );
    } catch (e) {
      // Handle error gracefully
      _audioSessionId = null;
    }
  }

  /// Set audio source and update session ID
  Future<Duration?> setAudioSource(AudioSource source) async {
    final duration = await _player.setAudioSource(source);

    // Update audio session ID after setting new source
    await _updateAudioSessionId();

    return duration;
  }

  /// Play audio and update session ID
  Future<void> play() async {
    await _player.play();
    await _updateAudioSessionId();
  }

  /// Update audio session ID
  Future<void> _updateAudioSessionId() async {
    try {
      _audioSessionId = await JustAudioVisualizerIntegration.getAudioSessionId(
        _player,
      );
    } catch (e) {
      // Handle error gracefully
    }
  }

  /// Dispose of resources
  void dispose() {
    _player.dispose();
  }

  // Delegate all other methods to the underlying player
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration position) => _player.seek(position);

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  PlayerState get playerState => _player.playerState;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  SequenceState? get sequenceState => _player.sequenceState;

  bool get playing => _player.playing;
  ProcessingState get processingState => _player.processingState;

  set volume(double volume) => _player.setVolume(volume);
  set speed(double speed) => _player.setSpeed(speed);
  set shuffleModeEnabled(bool enabled) =>
      _player.setShuffleModeEnabled(enabled);
  set loopMode(LoopMode mode) => _player.setLoopMode(mode);
}
