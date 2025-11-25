import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:rxdart/rxdart.dart';

/// Manages audio session configuration and interruption/noisy events.
class AudioSessionManager {
  AudioSessionManager({
    required BehaviorSubject<PlaybackState> playbackState,
    required BehaviorSubject<double> volume,
    required Future<void> Function() pause,
    required Future<void> Function(double volume) setVolume,
  }) : _playbackState = playbackState,
       _volume = volume,
       _pause = pause,
       _setVolume = setVolume;

  final BehaviorSubject<PlaybackState> _playbackState;
  final BehaviorSubject<double> _volume;
  final Future<void> Function() _pause;
  final Future<void> Function(double volume) _setVolume;

  AudioSession? _session;

  Future<void> configure() async {
    final session = await AudioSession.instance;
    _session = session;

    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );

    await session.setActive(true);

    session.becomingNoisyEventStream.listen((_) {
      _handleBecomingNoisy();
    });

    session.interruptionEventStream.listen((event) {
      _handleAudioInterruption(event);
    });
  }

  Future<void> ensureActive() async {
    final session = _session ?? await AudioSession.instance;
    _session = session;
    await session.setActive(true);
  }

  Future<void> _handleAudioInterruption(AudioInterruptionEvent event) async {
    try {
      AudioLogger.log(
        '[DEBUG][AudioSessionManager] Audio interruption: ${event.type}',
        name: 'AudioSessionManager',
      );

      switch (event.type) {
        case AudioInterruptionType.pause:
          if (_playbackState.value.playing) {
            await _pause();
            AudioLogger.log(
              '[DEBUG][AudioSessionManager] Paused due to interruption',
              name: 'AudioSessionManager',
            );
          }
          break;
        case AudioInterruptionType.duck:
          if (_playbackState.value.playing) {
            final currentVolume = _volume.value;
            await _setVolume(currentVolume * 0.3);
            AudioLogger.log(
              '[DEBUG][AudioSessionManager] Audio ducked to 30% volume',
              name: 'AudioSessionManager',
            );

            Future.delayed(const Duration(seconds: 3), () async {
              if (_playbackState.value.playing) {
                await _setVolume(currentVolume);
                AudioLogger.log(
                  '[DEBUG][AudioSessionManager] Audio volume restored',
                  name: 'AudioSessionManager',
                );
              }
            });
          }
          break;
        case AudioInterruptionType.unknown:
          AudioLogger.log(
            '[DEBUG][AudioSessionManager] Unknown interruption type, no action taken',
            name: 'AudioSessionManager',
          );
          break;
      }
    } catch (e) {
      AudioLogger.log(
        '[ERROR][AudioSessionManager] Error handling interruption: $e',
        name: 'AudioSessionManager',
        error: e,
      );
    }
  }

  void _handleBecomingNoisy() {
    try {
      AudioLogger.log(
        '[DEBUG][AudioSessionManager] Audio becoming noisy - pausing playback',
        name: 'AudioSessionManager',
      );

      if (_playbackState.value.playing) {
        unawaited(_pause());
      }
    } catch (e) {
      AudioLogger.log(
        '[ERROR][AudioSessionManager] Error handling noisy event: $e',
        name: 'AudioSessionManager',
        error: e,
      );
    }
  }
}
