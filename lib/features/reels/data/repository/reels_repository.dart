import 'package:flutter/foundation.dart';
import 'package:jainverse/features/reels/data/api/i_reels_api.dart';
import 'package:jainverse/features/reels/data/api/reels_api_impl.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';

/// Result type returned by feed-fetching methods.
class ReelsFeedResult {
  final List<ReelItem> items;
  final int currentPage;
  final int totalPages;

  const ReelsFeedResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
  });
}

/// Converts raw API responses into typed domain objects.
///
/// Accepts an [IReelsApi] dependency so it can be tested with a stub.
class ReelsRepository {
  final IReelsApi _api;

  ReelsRepository({IReelsApi? api}) : _api = api ?? ReelsApiImpl();

  // ---------------------------------------------------------------------------
  // Feed
  // ---------------------------------------------------------------------------

  Future<ReelsFeedResult> getReelsFeed({required int page}) async {
    final raw = await _api.fetchFeed(page: page);
    return _parseReelsFeedResult(raw, requestedPage: page);
  }

  Future<ReelsFeedResult> getChannelReels({
    required int channelId,
    required int page,
  }) async {
    final raw = await _api.fetchChannelReels(channelId: channelId, page: page);
    return _parseReelsFeedResult(raw, requestedPage: page);
  }

  // ---------------------------------------------------------------------------
  // Upload (called after successful CDN upload)
  // ---------------------------------------------------------------------------

  /// Saves reel metadata to the backend and returns the created [ReelItem].
  ///
  /// Throws on both network errors and API-level failures so the caller
  /// ([ReelUploadNotifier]) can surface a specific message and retry only
  /// the backend call without re-uploading to Bunny.
  Future<ReelItem> uploadReel({
    required String videoUrl,
    required String thumbnailUrl,
    required String title,
    String? description,
    required String duration,
    required String videoSize,
    required String videoFileName,
    required String thumbnailFileName,
  }) {
    return _api.uploadReel(
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      title: title,
      description: description,
      duration: duration,
      videoSize: videoSize,
      videoFileName: videoFileName,
      thumbnailFileName: thumbnailFileName,
    );
  }

  // ---------------------------------------------------------------------------
  // Like
  // ---------------------------------------------------------------------------

  /// Toggles like state for [shortId].
  ///
  /// [isLike] must be 0 (unlike) or 1 (like).
  /// Returns true on success. Throws [DioException] on network error so the
  /// notifier can roll back the optimistic UI update.
  Future<bool> toggleLike({required int shortId, required int isLike}) {
    return _api.toggleLike(shortId: shortId, isLike: isLike);
  }

  // ---------------------------------------------------------------------------
  // View count
  // ---------------------------------------------------------------------------

  /// Fire-and-forget view increment. Swallows all errors.
  Future<void> sendView({required int shortId}) async {
    try {
      await _api.sendView(shortId: shortId);
    } catch (_) {
      // Non-critical — ignore.
    }
  }

  // ---------------------------------------------------------------------------
  // Private — shared response parser
  // ---------------------------------------------------------------------------

  ReelsFeedResult _parseReelsFeedResult(
    Map<String, dynamic> raw, {
    required int requestedPage,
  }) {
    // Support both 'data' and 'videos' array keys.
    final List<dynamic> dataList = (raw['data'] is List)
        ? raw['data'] as List
        : (raw['videos'] is List)
        ? raw['videos'] as List
        : [];

    final items = dataList
        .whereType<Map<String, dynamic>>()
        .map((j) {
          try {
            return ReelItem.fromJson(j);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('ReelsRepository: failed to parse reel item: $e');
            }
            return null;
          }
        })
        .whereType<ReelItem>()
        .toList();

    // Support both snake_case and camelCase pagination fields.
    int toInt(dynamic v, {int fallback = 1}) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    final currentPage = toInt(
      raw['current_page'] ?? raw['currentPage'],
      fallback: requestedPage,
    );
    final totalPages = toInt(
      raw['total_pages'] ?? raw['totalPages'] ?? raw['last_page'],
      fallback: 1,
    );

    return ReelsFeedResult(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }
}
