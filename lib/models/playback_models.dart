/// Queue state management data model
class QueueState {
  final List<String> queueItems;
  final int currentIndex;
  final bool isShuffled;
  final bool isRepeating;
  final RepeatMode repeatMode;

  const QueueState({
    required this.queueItems,
    required this.currentIndex,
    required this.isShuffled,
    required this.isRepeating,
    required this.repeatMode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueState &&
          runtimeType == other.runtimeType &&
          _listEquals(queueItems, other.queueItems) &&
          currentIndex == other.currentIndex &&
          isShuffled == other.isShuffled &&
          isRepeating == other.isRepeating &&
          repeatMode == other.repeatMode;

  @override
  int get hashCode =>
      queueItems.hashCode ^
      currentIndex.hashCode ^
      isShuffled.hashCode ^
      isRepeating.hashCode ^
      repeatMode.hashCode;

  QueueState copyWith({
    List<String>? queueItems,
    int? currentIndex,
    bool? isShuffled,
    bool? isRepeating,
    RepeatMode? repeatMode,
  }) {
    return QueueState(
      queueItems: queueItems ?? this.queueItems,
      currentIndex: currentIndex ?? this.currentIndex,
      isShuffled: isShuffled ?? this.isShuffled,
      isRepeating: isRepeating ?? this.isRepeating,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Repeat mode enumeration
enum RepeatMode { none, all, one }

/// Playback control state
class PlaybackControlState {
  final bool isPlaying;
  final bool isLoading;
  final bool canSkipNext;
  final bool canSkipPrevious;
  final bool canSeek;
  final Duration position;
  final Duration duration;
  final double speed;
  final double volume;

  const PlaybackControlState({
    required this.isPlaying,
    required this.isLoading,
    required this.canSkipNext,
    required this.canSkipPrevious,
    required this.canSeek,
    required this.position,
    required this.duration,
    required this.speed,
    required this.volume,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackControlState &&
          runtimeType == other.runtimeType &&
          isPlaying == other.isPlaying &&
          isLoading == other.isLoading &&
          canSkipNext == other.canSkipNext &&
          canSkipPrevious == other.canSkipPrevious &&
          canSeek == other.canSeek &&
          position == other.position &&
          duration == other.duration &&
          speed == other.speed &&
          volume == other.volume;

  @override
  int get hashCode =>
      isPlaying.hashCode ^
      isLoading.hashCode ^
      canSkipNext.hashCode ^
      canSkipPrevious.hashCode ^
      canSeek.hashCode ^
      position.hashCode ^
      duration.hashCode ^
      speed.hashCode ^
      volume.hashCode;

  PlaybackControlState copyWith({
    bool? isPlaying,
    bool? isLoading,
    bool? canSkipNext,
    bool? canSkipPrevious,
    bool? canSeek,
    Duration? position,
    Duration? duration,
    double? speed,
    double? volume,
  }) {
    return PlaybackControlState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      canSkipNext: canSkipNext ?? this.canSkipNext,
      canSkipPrevious: canSkipPrevious ?? this.canSkipPrevious,
      canSeek: canSeek ?? this.canSeek,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
    );
  }

  factory PlaybackControlState.initial() {
    return const PlaybackControlState(
      isPlaying: false,
      isLoading: false,
      canSkipNext: false,
      canSkipPrevious: false,
      canSeek: false,
      position: Duration.zero,
      duration: Duration.zero,
      speed: 1.0,
      volume: 1.0,
    );
  }
}
