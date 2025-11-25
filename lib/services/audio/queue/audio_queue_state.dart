import 'package:audio_service/audio_service.dart';

/// Immutable snapshot of the audio queue shared across UI and service layers.
class AudioQueueState {
  const AudioQueueState({
    required this.queue,
    required this.queueIndex,
    this.shuffleIndices,
    this.repeatMode = AudioServiceRepeatMode.none,
  });

  static const AudioQueueState empty = AudioQueueState(
    queue: <MediaItem>[],
    queueIndex: 0,
    shuffleIndices: <int>[],
    repeatMode: AudioServiceRepeatMode.none,
  );

  final List<MediaItem> queue;
  final int? queueIndex;
  final List<int>? shuffleIndices;
  final AudioServiceRepeatMode repeatMode;

  int? get currentIndex => queueIndex;

  bool get hasPrevious =>
      repeatMode != AudioServiceRepeatMode.none || (queueIndex ?? 0) > 0;

  bool get hasNext =>
      repeatMode != AudioServiceRepeatMode.none ||
      (queueIndex ?? 0) + 1 < queue.length;

  List<int> get indices =>
      shuffleIndices ?? List.generate(queue.length, (index) => index);

  AudioQueueState copyWith({
    List<MediaItem>? queue,
    int? queueIndex,
    List<int>? shuffleIndices,
    AudioServiceRepeatMode? repeatMode,
  }) {
    return AudioQueueState(
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      shuffleIndices: shuffleIndices ?? this.shuffleIndices,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

/// Backwards-compatible alias for legacy imports while migrating modules.
typedef QueueState = AudioQueueState;
