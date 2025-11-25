import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Handles broadcasting playback state updates to listeners.
class StateBroadcaster {
  StateBroadcaster({
    required AudioPlayer player,
    required BehaviorSubject<PlaybackState> playbackState,
  }) : _player = player,
       _playbackState = playbackState;

  final AudioPlayer _player;
  final BehaviorSubject<PlaybackState> _playbackState;

  void broadcast(PlaybackEvent event) {
    try {
      final isPlaying = _player.playing;
      final processingState = _player.processingState;
      final speed = _player.speed;
      final position = _player.position;
      final bufferedPosition = _player.bufferedPosition;
      final currentIndex = _player.currentIndex;

      _playbackState.add(
        _playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState: const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[processingState]!,
          playing: isPlaying,
          updatePosition: position,
          bufferedPosition: bufferedPosition,
          speed: speed,
          queueIndex: currentIndex,
        ),
      );
    } catch (e) {
      AudioLogger.log(
        '[ERROR][StateBroadcaster] Error broadcasting state: $e',
        name: 'StateBroadcaster',
        error: e,
      );
    }
  }

  void performBroadcast(PlaybackEvent event) => broadcast(event);
}
