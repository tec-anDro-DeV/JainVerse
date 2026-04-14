/// Abstract contract for the Reels API layer.
///
/// Implementations can be swapped without touching the repository or notifiers —
/// useful for testing or migrating endpoints.
abstract class IReelsApi {
  /// POST get_short_video — paginated feed.
  Future<Map<String, dynamic>> fetchFeed({
    required int page,
    int perPage = 10,
  });

  /// POST upload_short_video — publishes full metadata after CDN upload.
  Future<bool> publishReel({
    required String videoUrl,
    required String thumbnailUrl,
    required String title,
    String? description,
    required String duration,  // "MM:SS"
    required String videoSize, // MB as string, e.g. "12.3"
  });

  /// POST like_dislike_short_video — [isLike] is 0 or 1.
  Future<bool> toggleLike({
    required int shortId,
    required int isLike,
  });

  /// POST shorts_view — fire-and-forget view count increment.
  Future<void> sendView({required int shortId});

  /// POST get_channel_shorts — reels belonging to a specific channel.
  Future<Map<String, dynamic>> fetchChannelReels({
    required int channelId,
    required int page,
    int perPage = 10,
  });
}
