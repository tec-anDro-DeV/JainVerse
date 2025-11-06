import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Represents the current state of the video player
@immutable
class VideoPlayerState {
  final VideoPlayerController? controller;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isMuted;
  final bool isFullScreen;
  final bool showControls;
  final String? currentVideoId;
  final String? currentVideoTitle;
  final String? currentVideoSubtitle;
  final String? thumbnailUrl;
  // Channel metadata (used for showing avatar/subscribe in mini/full UI)
  final int? channelId;
  final String? channelAvatarUrl;
  final bool isLoading;
  final String? errorMessage;
  final bool repeatMode;
  final List<String>? playlist;
  final int? currentIndex;

  // Mini player state
  final bool isMinimized;
  final bool showMiniPlayer;

  const VideoPlayerState({
    this.controller,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.isFullScreen = false,
    this.showControls = true,
    this.currentVideoId,
    this.isMinimized = false,
    this.showMiniPlayer = false,
    this.currentVideoTitle,
    this.currentVideoSubtitle,
    this.thumbnailUrl,
    this.channelId,
    this.channelAvatarUrl,
    this.isLoading = false,
    this.errorMessage,
    this.repeatMode = false,
    this.playlist,
    this.currentIndex,
  });

  VideoPlayerState copyWith({
    VideoPlayerController? controller,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isMuted,
    bool? isFullScreen,
    bool? showControls,
    String? currentVideoId,
    String? currentVideoTitle,
    String? currentVideoSubtitle,
    String? thumbnailUrl,
    int? channelId,
    String? channelAvatarUrl,
    bool? isLoading,
    String? errorMessage,
    bool? repeatMode,
    List<String>? playlist,
    int? currentIndex,
    bool? isMinimized,
    bool? showMiniPlayer,
  }) {
    return VideoPlayerState(
      controller: controller ?? this.controller,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isFullScreen: isFullScreen ?? this.isFullScreen,
      showControls: showControls ?? this.showControls,
      currentVideoId: currentVideoId ?? this.currentVideoId,
      currentVideoTitle: currentVideoTitle ?? this.currentVideoTitle,
      currentVideoSubtitle: currentVideoSubtitle ?? this.currentVideoSubtitle,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channelId: channelId ?? this.channelId,
      channelAvatarUrl: channelAvatarUrl ?? this.channelAvatarUrl,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      repeatMode: repeatMode ?? this.repeatMode,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isMinimized: isMinimized ?? this.isMinimized,
      showMiniPlayer: showMiniPlayer ?? this.showMiniPlayer,
    );
  }

  /// Check if there's a next video in playlist
  bool get hasNext {
    if (playlist == null || currentIndex == null) return false;
    return currentIndex! < playlist!.length - 1;
  }

  /// Check if there's a previous video in playlist
  bool get hasPrevious {
    if (currentIndex == null) return false;
    return currentIndex! > 0;
  }

  /// Check if video is ready to play
  bool get isReady {
    return controller != null &&
        controller!.value.isInitialized &&
        !isLoading &&
        errorMessage == null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VideoPlayerState &&
        other.controller == controller &&
        other.isPlaying == isPlaying &&
        other.isBuffering == isBuffering &&
        other.isCompleted == isCompleted &&
        other.position == position &&
        other.duration == duration &&
        other.volume == volume &&
        other.isMuted == isMuted &&
        other.isFullScreen == isFullScreen &&
        other.showControls == showControls &&
        other.currentVideoId == currentVideoId &&
        other.currentVideoTitle == currentVideoTitle &&
        other.currentVideoSubtitle == currentVideoSubtitle &&
        other.thumbnailUrl == thumbnailUrl &&
        other.channelId == channelId &&
        other.channelAvatarUrl == channelAvatarUrl &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage &&
        other.repeatMode == repeatMode &&
        other.currentIndex == currentIndex;
  }

  @override
  int get hashCode {
    return controller.hashCode ^
        isPlaying.hashCode ^
        isBuffering.hashCode ^
        isCompleted.hashCode ^
        position.hashCode ^
        duration.hashCode ^
        volume.hashCode ^
        isMuted.hashCode ^
        isFullScreen.hashCode ^
        showControls.hashCode ^
        currentVideoId.hashCode ^
        currentVideoTitle.hashCode ^
        currentVideoSubtitle.hashCode ^
        thumbnailUrl.hashCode ^
        isLoading.hashCode ^
        errorMessage.hashCode ^
        repeatMode.hashCode ^
        currentIndex.hashCode;
  }
}
