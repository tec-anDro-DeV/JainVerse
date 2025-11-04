import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Enum to track which media player is currently active
enum ActiveMediaPlayer { none, music, video }

/// State notifier to coordinate between music and video players
/// Ensures only one mini player is shown at a time
class MediaCoordinatorNotifier extends Notifier<ActiveMediaPlayer> {
  @override
  ActiveMediaPlayer build() => ActiveMediaPlayer.none;

  /// Set music player as active (hides video mini player)
  void setMusicActive() {
    if (state != ActiveMediaPlayer.music) {
      state = ActiveMediaPlayer.music;
    }
  }

  /// Set video player as active (hides music mini player)
  void setVideoActive() {
    if (state != ActiveMediaPlayer.video) {
      state = ActiveMediaPlayer.video;
    }
  }

  /// Clear active player (hides all mini players)
  void clearActivePlayer() {
    if (state != ActiveMediaPlayer.none) {
      state = ActiveMediaPlayer.none;
    }
  }

  /// Check if music mini player should be visible
  bool get shouldShowMusicMiniPlayer => state == ActiveMediaPlayer.music;

  /// Check if video mini player should be visible
  bool get shouldShowVideoMiniPlayer => state == ActiveMediaPlayer.video;
}

/// Provider for media coordinator
final mediaCoordinatorProvider =
    NotifierProvider<MediaCoordinatorNotifier, ActiveMediaPlayer>(
      MediaCoordinatorNotifier.new,
    );
