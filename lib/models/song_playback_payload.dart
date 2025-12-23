import 'package:jainverse/Model/home_models.dart';

/// Lightweight DTO that carries everything we need to start playback instantly.
/// Values come directly from the home API (featuredSongs/latestSongs/etc.).
class SongPlaybackPayload {
  final String id;
  final String title;
  final String audioUrl;
  final String imageUrl;
  final Duration? duration;
  final String? channelName;
  final String? channelImageUrl;
  final Map<String, dynamic> extras;

  const SongPlaybackPayload({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.imageUrl,
    this.duration,
    this.channelName,
    this.channelImageUrl,
    this.extras = const {},
  });

  /// Create payload from the new SongModel (audio model)
  factory SongPlaybackPayload.fromSongModel(SongModel song) {
    return SongPlaybackPayload(
      id: song.id.toString(),
      title: song.audioTitle,
      audioUrl: song.audioUrl,
      imageUrl: song.imageUrl,
      duration: _parseDuration(song.audioDuration),
      channelName: song.channelName,
      channelImageUrl: song.channelImageUrl,
      extras: {
        'audio_id': song.id,
        'audio_slug': song.audioSlug,
        'audio_title': song.audioTitle,
        'actual_audio_url': song.audioUrl,
        'image_url': song.imageUrl,
        'channel_id': song.channelId,
        'channel_name': song.channelName,
        'channel_handle': song.channelHandle,
        'channel_image_url': song.channelImageUrl,
        'audio_duration': song.audioDuration,
        'listening_count': song.listeningCount,
        'is_featured': song.isFeatured,
        'is_trending': song.isTrending,
        'is_recommended': song.isRecommended,
        'copyright': song.copyright,
        'release_date': song.releaseDate,
        'is_favourite': song.isFavourite,
      }..removeWhere((key, value) => value == null),
    );
  }

  SongPlaybackPayload copyWith({
    String? id,
    String? title,
    String? audioUrl,
    String? imageUrl,
    Duration? duration,
    String? channelName,
    String? channelImageUrl,
    Map<String, dynamic>? extras,
  }) {
    return SongPlaybackPayload(
      id: id ?? this.id,
      title: title ?? this.title,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      duration: duration ?? this.duration,
      channelName: channelName ?? this.channelName,
      channelImageUrl: channelImageUrl ?? this.channelImageUrl,
      extras: extras ?? this.extras,
    );
  }
}

/// Parses a duration from "mm:ss" or "hh:mm:ss"
Duration? _parseDuration(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  final parts = raw.split(':');
  if (parts.isEmpty) return null;

  try {
    final numbers = parts.map(int.parse).toList();

    if (numbers.length == 3) {
      return Duration(
        hours: numbers[0],
        minutes: numbers[1],
        seconds: numbers[2],
      );
    }
    if (numbers.length == 2) {
      return Duration(minutes: numbers[0], seconds: numbers[1]);
    }
    if (numbers.length == 1) {
      return Duration(seconds: numbers[0]);
    }
  } catch (_) {
    return null;
  }

  return null;
}
