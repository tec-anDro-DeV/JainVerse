import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/features/reels/data/api/i_reels_api.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Dio-based implementation of [IReelsApi].
///
/// All endpoints use JSON POST bodies and Bearer-token auth.
class ReelsApiImpl implements IReelsApi {
  final Dio _dio;
  final SharedPref _sharedPref;

  ReelsApiImpl({Dio? dio, SharedPref? sharedPref})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref() {
    _dio.options.baseUrl = AppConstant.BaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 20);
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Future<Options> _authOptions() async {
    final token = (await _sharedPref.getToken())?.toString() ?? '';
    return Options(
      headers: {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // fetchFeed — GET get_short_video (body carries pagination params)
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> fetchFeed({
    required int page,
    int perPage = 10,
  }) async {
    try {
      final resp = await _dio.get(
        AppConstant.API_GET_SHORT_VIDEO,
        data: {'per_page': perPage, 'page': page},
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data is Map<String, dynamic>) {
        return resp.data as Map<String, dynamic>;
      }
      return {};
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('ReelsApiImpl.fetchFeed: ${e.message}');
      throw Exception('Failed to fetch reels: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // uploadReel — POST upload_short_video
  // ---------------------------------------------------------------------------

  @override
  Future<ReelItem> uploadReel({
    required String videoUrl,
    required String thumbnailUrl,
    required String title,
    String? description,
    required String duration,
    required String videoSize,
    required String videoFileName,
    required String thumbnailFileName,
  }) async {
    try {
      final resp = await _dio.post(
        AppConstant.API_UPLOAD_SHORT_VIDEO,
        data: {
          'video_url': videoUrl,
          'thumbnail_url': thumbnailUrl,
          'video_file_name': videoFileName,
          'thumbnail_file_name': thumbnailFileName,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          'duration': duration,
          'video_size': videoSize,
        },
        options: await _authOptions(),
      );
      final body = resp.data;
      if (body is Map<String, dynamic> &&
          body['status'] == true &&
          body['data'] is Map<String, dynamic>) {
        return ReelItem.fromUploadResponse(
          body['data'] as Map<String, dynamic>,
        );
      }
      final msg = (body is Map<String, dynamic>)
          ? body['msg']?.toString()
          : null;
      throw Exception(msg ?? 'Failed to publish reel');
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('ReelsApiImpl.uploadReel: ${e.message}');
      rethrow; // Let the notifier decide whether to retry.
    }
  }

  // ---------------------------------------------------------------------------
  // toggleLike — POST like_dislike_short_video
  // ---------------------------------------------------------------------------

  @override
  Future<bool> toggleLike({required int shortId, required int isLike}) async {
    try {
      final resp = await _dio.post(
        AppConstant.API_LIKE_DISLIKE_SHORT_VIDEO,
        data: {'short_id': shortId, 'is_like': isLike},
        options: await _authOptions(),
      );
      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map<String, dynamic>) {
          return data['status'] == true || data['status'] == 'true';
        }
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('ReelsApiImpl.toggleLike: ${e.message}');
      rethrow; // Let the notifier roll back the optimistic update.
    }
  }

  // ---------------------------------------------------------------------------
  // sendView — POST shorts_view (best-effort, swallows errors)
  // ---------------------------------------------------------------------------

  @override
  Future<void> sendView({required int shortId}) async {
    try {
      await _dio.post(
        AppConstant.API_SHORTS_VIEW,
        data: {'short_id': shortId},
        options: await _authOptions(),
      );
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('ReelsApiImpl.sendView: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // fetchChannelReels — GET get_channel_shorts (body carries params)
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> fetchChannelReels({
    required int channelId,
    required int page,
    int perPage = 10,
  }) async {
    try {
      final resp = await _dio.get(
        AppConstant.API_GET_CHANNEL_SHORTS,
        data: {'channel_id': channelId, 'per_page': perPage, 'page': page},
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data is Map<String, dynamic>) {
        return resp.data as Map<String, dynamic>;
      }
      return {};
    } on DioException catch (e) {
      if (kDebugMode)
        debugPrint('ReelsApiImpl.fetchChannelReels: ${e.message}');
      throw Exception('Failed to fetch channel reels: ${e.message}');
    }
  }
}
