import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Production-grade service to fetch channel videos with pagination and
/// robust error handling.
class ChannelVideoService {
  final Dio _dio;
  final SharedPref _sharedPref;

  ChannelVideoService({Dio? dio, SharedPref? sharedPref})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref() {
    // sensible defaults
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 20);
  }

  /// Fetch channel videos.
  /// Returns a Map with keys: data(List<VideoItem>), currentPage, perPage,
  /// totalPages, total
  Future<Map<String, dynamic>> fetchChannelVideos({
    required int channelId,
    int page = 1,
    int perPage = 10,
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    try {
      final resp = await _dio.post(
        'https://musicvideo.techcronus.com/api/v2/get_channel_videos',
        data: FormData.fromMap({
          'channel_id': channelId.toString(),
          'per_page': perPage.toString(),
          'page': page.toString(),
        }),
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            if (token != null && token.toString().isNotEmpty)
              'Authorization': 'Bearer ${token.toString()}',
          },
        ),
        cancelToken: cancelToken,
      );

      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map<String, dynamic>) {
          final raw = data['data'] as List<dynamic>? ?? [];
          final items =
              raw.map((e) {
                if (e is Map<String, dynamic>) return VideoItem.fromJson(e);
                return VideoItem.fromJson(Map<String, dynamic>.from(e));
              }).toList();

          return {
            'data': items,
            'currentPage': data['currentPage'] ?? page,
            'perPage': data['perPage'] ?? perPage,
            'totalPages': data['totalPages'] ?? 1,
            'total': data['total'] ?? items.length,
          };
        }
        throw Exception('Unexpected response format');
      }
      throw Exception('HTTP ${resp.statusCode}');
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('ChannelVideoService Dio error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('ChannelVideoService error: $e');
      throw Exception(e.toString());
    }
  }
}
