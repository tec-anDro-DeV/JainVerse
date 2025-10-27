import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/managers/like_dislike_state_manager.dart';

class VideoItem {
  final int id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String duration;
  final String? description;
  final int? channelId;
  final String? channelName;
  final String? channelHandle;
  final String? channelImageUrl;
  final DateTime? createdAt;
  final bool? subscribed;
  final int? like; // 0 = neutral, 1 = liked, 2 = disliked
  final int? totalViews;
  final bool isOwn;

  VideoItem({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    this.description,
    this.channelId,
    this.channelName,
    this.channelHandle,
    this.channelImageUrl,
    this.createdAt,
    this.subscribed,
    this.like,
    this.totalViews,
    this.isOwn = false,
  });

  factory VideoItem.fromJson(Map<String, dynamic> j) {
    // Support multiple possible key names coming from the API
    String extractString(Map<String, dynamic> map, List<String> keys) {
      for (final k in keys) {
        if (map.containsKey(k) && map[k] != null) return map[k].toString();
      }
      return '';
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.tryParse(v.toString());
      } catch (_) {
        return null;
      }
    }

    // Parse subscribed which may be bool, int (0/1), or string ('0'/'1'/'true')
    bool? parseSubscribed(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is int) return v == 1;
      final s = v.toString().toLowerCase().trim();
      if (s == '1' || s == 'true') return true;
      if (s == '0' || s == 'false' || s == 'null') return false;
      return null;
    }

    // Parse like state: 0=neutral, 1=liked, 2=disliked
    int? parseLike(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      final parsed = int.tryParse(v.toString());
      if (parsed != null && (parsed == 0 || parsed == 1 || parsed == 2)) {
        return parsed;
      }
      return null;
    }

    bool parseIsOwn(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v == 1;
      final s = v.toString().toLowerCase().trim();
      if (s == '1' || s == 'true') return true;
      return false;
    }

    return VideoItem(
      id: parseInt(j['id']) ?? 0,
      title: extractString(j, ['title', 'name']),
      videoUrl: extractString(j, ['video_url', 'video']),
      thumbnailUrl: extractString(j, [
        'thumbnail_url',
        'thumbnail_image',
        'thumbnail',
      ]),
      duration: extractString(j, ['duration']),
      description: j['description'] != null
          ? j['description'].toString()
          : null,
      channelId: parseInt(j['channel_id']),
      channelName: j['channel_name'] != null
          ? j['channel_name'].toString()
          : null,
      channelHandle: j['channel_handle'] != null
          ? j['channel_handle'].toString()
          : null,
      channelImageUrl: j['channel_image_url'] != null
          ? j['channel_image_url'].toString()
          : null,
      createdAt: parseDate(j['created_at']),
      subscribed: parseSubscribed(j['subscribed']),
      like: parseLike(j['like']),
      totalViews: parseInt(j['total_views']),
      isOwn: parseIsOwn(j['is_own']),
    );
  }

  // Copy with method for updating subscription status
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
    bool? isOwn,
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
      isOwn: isOwn ?? this.isOwn,
    );
  }
}

// Extension to sync VideoItem with global subscription state
extension VideoItemSync on VideoItem {
  /// Returns a copy of this VideoItem with subscription status synced
  /// from the global SubscriptionStateManager if available
  VideoItem syncWithGlobalState() {
    if (channelId == null) return this;

    // Import at top of file if needed - will add in next step
    // Using dynamic import to avoid circular dependency
    try {
      // Check if we have a global state for this channel
      final manager = SubscriptionStateManager();
      final globalState = manager.getSubscriptionState(channelId!);

      // If global state exists and differs from current, use global
      if (globalState != null && globalState != subscribed) {
        return copyWith(subscribed: globalState);
      }
    } catch (e) {
      // If manager not available, return unchanged
    }

    return this;
  }

  /// Returns a copy of this VideoItem with like/dislike status synced
  /// from the global LikeDislikeStateManager if available
  VideoItem syncLikeWithGlobalState() {
    try {
      // Check if we have a global state for this video
      final manager = LikeDislikeStateManager();
      final globalState = manager.getLikeState(id);

      // If global state exists and differs from current, use global
      if (globalState != null && globalState != like) {
        return copyWith(like: globalState);
      }
    } catch (e) {
      // If manager not available, return unchanged
    }

    return this;
  }
}
