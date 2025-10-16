import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';

/// Service to fetch user's liked videos
class LikedVideosService {
  final Dio _dio;
  final SharedPref _sharedPref;

  LikedVideosService({Dio? dio, SharedPref? sharedPref})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref() {
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 20);
  }

  /// Fetch all liked videos for the current user
  Future<List<VideoItem>> getLikedVideos({CancelToken? cancelToken}) async {
    final token = await _sharedPref.getToken();

    try {
      final resp = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_GET_LIKED_VIDEOS,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.toString().isNotEmpty)
              'Authorization': 'Bearer ${token.toString()}',
          },
        ),
        cancelToken: cancelToken,
      );

      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map<String, dynamic> && data['status'] == true) {
          final List<dynamic> videosJson = data['data'] ?? [];
          return videosJson.map((json) => VideoItem.fromJson(json)).toList();
        }
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('LikedVideosService error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('LikedVideosService error: $e');
      throw Exception(e.toString());
    }
  }
}
