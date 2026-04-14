import 'package:flutter/foundation.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';

/// Data model for a single Reel (short-form vertical video).
///
/// Intentionally separate from [VideoItem] to keep reel-specific
/// lifecycle and state concerns isolated from the full-screen video player.
@immutable
class ReelItem {
  final int id;
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final String? description;
  final String duration;

  final int channelId;
  final String channelName;
  final String channelHandle;
  final String channelImageUrl;

  /// 0 = neutral, 1 = liked, 2 = disliked — matches VideoItem convention.
  final int like;
  final int totalLikes;
  final int totalViews;

  /// 1 if the reel belongs to the authenticated user.
  final int isOwn;

  final DateTime? createdAt;

  const ReelItem({
    required this.id,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    this.description,
    required this.duration,
    required this.channelId,
    required this.channelName,
    required this.channelHandle,
    required this.channelImageUrl,
    required this.like,
    required this.totalLikes,
    required this.totalViews,
    required this.isOwn,
    this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  factory ReelItem.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    int parseLike(dynamic v) {
      final n = toInt(v);
      return (n == 0 || n == 1 || n == 2) ? n : 0;
    }

    return ReelItem(
      id: toInt(j['id']),
      videoUrl: j['video_url']?.toString() ?? '',
      thumbnailUrl: j['thumbnail_url']?.toString() ?? '',
      title: j['title']?.toString() ?? '',
      description: j['description']?.toString(),
      duration: j['duration']?.toString() ?? '',
      channelId: toInt(j['channel_id']),
      channelName: j['channel_name']?.toString() ?? '',
      channelHandle: j['channel_handle']?.toString() ?? '',
      channelImageUrl: j['channel_image_url']?.toString() ?? '',
      like: parseLike(j['like']),
      totalLikes: toInt(j['total_likes']),
      totalViews: toInt(j['total_views']),
      isOwn: toInt(j['is_own']),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
    );
  }

  /// Promote an existing [VideoItem] to a [ReelItem] cheaply.
  /// Useful when the backend serves reels through the shared all_videos endpoint.
  factory ReelItem.fromVideoItem(VideoItem v) {
    return ReelItem(
      id: v.id,
      videoUrl: v.videoUrl,
      thumbnailUrl: v.thumbnailUrl,
      title: v.title,
      description: v.description,
      duration: v.duration,
      channelId: v.channelId,
      channelName: v.channelName,
      channelHandle: v.channelHandle,
      channelImageUrl: v.channelImageUrl,
      like: v.like ?? 0,
      totalLikes: v.totalLikes,
      totalViews: v.totalViews,
      isOwn: v.isOwn,
      createdAt: v.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'title': title,
        'description': description,
        'duration': duration,
        'channel_id': channelId,
        'channel_name': channelName,
        'channel_handle': channelHandle,
        'channel_image_url': channelImageUrl,
        'like': like,
        'total_likes': totalLikes,
        'total_views': totalViews,
        'is_own': isOwn,
        'created_at': createdAt?.toIso8601String(),
      };

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  ReelItem copyWith({
    int? id,
    String? videoUrl,
    String? thumbnailUrl,
    String? title,
    String? description,
    String? duration,
    int? channelId,
    String? channelName,
    String? channelHandle,
    String? channelImageUrl,
    int? like,
    int? totalLikes,
    int? totalViews,
    int? isOwn,
    DateTime? createdAt,
  }) {
    return ReelItem(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      channelHandle: channelHandle ?? this.channelHandle,
      channelImageUrl: channelImageUrl ?? this.channelImageUrl,
      like: like ?? this.like,
      totalLikes: totalLikes ?? this.totalLikes,
      totalViews: totalViews ?? this.totalViews,
      isOwn: isOwn ?? this.isOwn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReelItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
