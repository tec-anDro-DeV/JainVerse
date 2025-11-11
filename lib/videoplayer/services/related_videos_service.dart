import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';

/// Service for fetching a random selection of publicly available videos.
///
/// The API response is shuffled locally so subsequent calls return the items
/// in a different order, while still respecting the requested `limit`.
class RelatedVideosService {
  final Dio _dio;
  final SharedPref _sharedPref;
  final Random _random;

  RelatedVideosService({Dio? dio, SharedPref? sharedPref, Random? random})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref(),
      _random = random ?? Random() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 30)
      ..sendTimeout = const Duration(seconds: 20);
  }

  /// Fetches up to [limit] videos from the `all_videos` endpoint.
  ///
  /// The returned list is shuffled to provide a lightweight randomized
  /// experience. The current playing video can be excluded via
  /// [excludeVideoId].
  Future<List<VideoItem>> fetchRandomVideos({
    int limit = 10,
    int? excludeVideoId,
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    try {
      final resp = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_ALL_VIDEOS,
        queryParameters: {'page': 1, 'per_page': limit},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.toString().isNotEmpty)
              'Authorization': 'Bearer ${token.toString()}',
          },
        ),
        cancelToken: cancelToken,
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final body = resp.data;
      if (body is! Map<String, dynamic>) {
        throw Exception('Unexpected response format');
      }

      final raw = body['data'];
      if (raw is! List) {
        throw Exception('Unexpected videos payload');
      }

      final List<VideoItem> videos = raw.map((item) {
        if (item is Map<String, dynamic>) {
          return VideoItem.fromJson(item);
        }
        return VideoItem.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      if (excludeVideoId != null) {
        videos.removeWhere((video) => video.id == excludeVideoId);
      }

      videos.shuffle(_random);

      if (videos.length > limit) {
        return videos.take(limit).toList(growable: false);
      }

      return videos;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('RelatedVideosService Dio error: $e');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RelatedVideosService error: $e');
      }
      throw Exception(e.toString());
    }
  }
}
