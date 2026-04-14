import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Manages the ±1 window of active [VideoPlayerController]s.
///
/// IMPORTANT: [VideoPlayerController] is mutable — this class must NOT be
/// used in equality checks based on controller values. The notifier stores
/// controllers in a private `_pool` map and copies the reference into this
/// state to trigger widget rebuilds.
@immutable
class ReelPlayerState {
  /// Controllers keyed by feed index. Only indices within ±1 of the current
  /// page are kept alive.
  final Map<int, VideoPlayerController> controllers;

  /// Indices whose controller is currently buffering.
  final Set<int> bufferingIndices;

  /// Indices whose controller has completed initialization.
  final Set<int> initializedIndices;

  final bool isMuted;

  const ReelPlayerState({
    this.controllers = const {},
    this.bufferingIndices = const {},
    this.initializedIndices = const {},
    this.isMuted = false,
  });

  ReelPlayerState copyWith({
    Map<int, VideoPlayerController>? controllers,
    Set<int>? bufferingIndices,
    Set<int>? initializedIndices,
    bool? isMuted,
  }) {
    return ReelPlayerState(
      controllers: controllers ?? this.controllers,
      bufferingIndices: bufferingIndices ?? this.bufferingIndices,
      initializedIndices: initializedIndices ?? this.initializedIndices,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
