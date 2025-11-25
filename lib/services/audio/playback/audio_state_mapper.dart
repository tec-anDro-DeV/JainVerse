import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Utility that keeps AudioService's [PlaybackState] in sync with the underlying
/// just_audio [PlayerState]. Centralizes repeat/shuffle mapping logic.
class AudioStateMapper {
  const AudioStateMapper();

  PlaybackState fromPlayerState(
    PlayerState state, {
    required Duration position,
    required Duration bufferedPosition,
    required double speed,
  }) {
    return PlaybackState(
      controls: state.playing
          ? [MediaControl.pause, MediaControl.stop]
          : [MediaControl.play, MediaControl.stop],
      processingState: _mapProcessingState(state.processingState),
      playing: state.playing,
      updatePosition: position,
      bufferedPosition: bufferedPosition,
      speed: speed,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}
