import 'package:just_audio/just_audio.dart';

import '../common/audio_logger.dart';

/// Thin abstraction over [AudioPlayer] so higher-level modules never need to
/// juggle raw just_audio concerns (buffering state, speed, etc.).
class AudioPlayerCore {
  AudioPlayerCore({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  AudioPlayer get innerPlayer => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  Future<void> loadUri(Uri uri) async {
    AudioLogger.log('[DEBUG][AudioPlayerCore] Preparing source: $uri');
    await _player.setAudioSource(AudioSource.uri(uri));
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
