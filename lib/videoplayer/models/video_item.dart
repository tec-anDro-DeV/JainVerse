import 'package:jainverse/Model/video_model.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/managers/like_dislike_state_manager.dart';

class VideoItem {
  final int id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String duration;
  final String? description;

  final int channelId;
  final String channelName;
  final String channelHandle;
  final String channelImageUrl;

  final DateTime? createdAt;

  final bool? subscribed;
  final int? like; // 0 = neutral, 1 = liked, 2 = disliked

  final int totalViews;
  final int totalLikes;
  final int? report; // 1 = reported
  final int isOwn;

  /// Not in new model but present in previous version, kept for compatibility
  final int? block;
  final String? reason;

  const VideoItem({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    this.description,
    required this.channelId,
    required this.channelName,
    required this.channelHandle,
    required this.channelImageUrl,
    this.createdAt,
    this.subscribed,
    this.like,
    required this.totalViews,
    required this.totalLikes,
    this.report,
    this.block,
    this.reason,
    required this.isOwn,
  });

  /// 🔥 Preferred: create VideoItem from new global VideoModel
  factory VideoItem.fromVideoModel(VideoModel v) {
    return VideoItem(
      id: v.id,
      title: v.title,
      videoUrl: v.videoUrl,
      thumbnailUrl: v.thumbnailUrl,
      duration: v.duration,
      description: v.description,
      channelId: v.channelId,
      channelName: v.channelName,
      channelHandle: v.channelHandle,
      channelImageUrl: v.channelImageUrl,
      createdAt: DateTime.tryParse(v.createdAt),
      subscribed: v.subscribed == null ? null : v.subscribed == 1,
      like: v.like,
      totalViews: v.totalViews,
      totalLikes: v.totalLikes,
      report: v.report,
      block: null, // removed from API but kept
      reason: null,
      isOwn: v.isOwn,
    );
  }

  /// 🔥 Legacy JSON factory (kept so older screens won't break)
  factory VideoItem.fromJson(Map<String, dynamic> j) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    bool? parseSubscribed(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is int) return v == 1;
      final s = v.toString().trim().toLowerCase();
      return (s == '1' || s == 'true');
    }

    int? parseLike(dynamic v) {
      if (v == null) return null;
      final n = int.tryParse(v.toString());
      if (n == null) return null;
      if (n == 0 || n == 1 || n == 2) return n;
      return null;
    }

    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return VideoItem(
      id: toInt(j['id']) ?? 0,
      title: j['title']?.toString() ?? '',
      videoUrl: j['video_url']?.toString() ?? '',
      thumbnailUrl: j['thumbnail_url']?.toString() ?? '',
      duration: j['duration']?.toString() ?? '',
      description: j['description']?.toString(),
      channelId: toInt(j['channel_id']) ?? 0,
      channelName: j['channel_name']?.toString() ?? '',
      channelHandle: j['channel_handle']?.toString() ?? '',
      channelImageUrl: j['channel_image_url']?.toString() ?? '',
      createdAt: toDate(j['created_at']),
      subscribed: parseSubscribed(j['subscribed']),
      like: parseLike(j['like']),
      totalViews: toInt(j['total_views']) ?? 0,
      totalLikes: toInt(j['total_likes']) ?? 0,
      report: toInt(j['report']),
      block: toInt(j['block']),
      reason: j['reason']?.toString(),
      isOwn: toInt(j['is_own']) ?? 0,
    );
  }

  /// CopyWith
  VideoItem copyWith({
    int? id,
    String? title,
    String? videoUrl,
    String? thumbnailUrl,
    String? duration,
    String? description,
    int? channelId,
    String? channelName,
    String? channelHandle,
    String? channelImageUrl,
    DateTime? createdAt,
    bool? subscribed,
    int? like,
    int? totalViews,
    int? totalLikes,
    int? report,
    int? block,
    String? reason,
    int? isOwn,
  }) {
    return VideoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      channelHandle: channelHandle ?? this.channelHandle,
      channelImageUrl: channelImageUrl ?? this.channelImageUrl,
      createdAt: createdAt ?? this.createdAt,
      subscribed: subscribed ?? this.subscribed,
      like: like ?? this.like,
      totalViews: totalViews ?? this.totalViews,
      totalLikes: totalLikes ?? this.totalLikes,
      report: report ?? this.report,
      block: block ?? this.block,
      reason: reason ?? this.reason,
      isOwn: isOwn ?? this.isOwn,
    );
  }
}

/// Sync extensions
extension VideoItemSync on VideoItem {
  VideoItem syncWithGlobalState() {
    try {
      final global = SubscriptionStateManager().getSubscriptionState(channelId);
      if (global != null && global != subscribed) {
        return copyWith(subscribed: global);
      }
    } catch (_) {}
    return this;
  }

  VideoItem syncLikeWithGlobalState() {
    try {
      final global = LikeDislikeStateManager().getLikeState(id);
      if (global != null && global != like) {
        return copyWith(like: global);
      }
    } catch (_) {}
    return this;
  }
}
