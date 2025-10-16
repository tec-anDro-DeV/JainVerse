import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Service to handle watch history tracking
class WatchHistoryService {
  final Dio _dio;
  final SharedPref _sharedPref;

  WatchHistoryService({Dio? dio, SharedPref? sharedPref})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref() {
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 20);
  }

  /// Mark a video as watched in the user's watch history
  /// This should be called when a video starts playing (not for autoplay)
  Future<bool> markVideoAsWatched({
    required int videoId,
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    try {
      final formData = FormData.fromMap({'video_id': videoId.toString()});

      final resp = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_WATCH_HISTORY,
        data: formData,
        options: Options(
          headers: {
            if (token != null && token.toString().isNotEmpty)
              'Authorization': 'Bearer ${token.toString()}',
          },
        ),
        cancelToken: cancelToken,
      );

      if (resp.statusCode == 200) {
        final data = resp.data;
        final success =
            data is Map<String, dynamic>
                ? (data['status'] == true || resp.statusCode == 200)
                : true;

        if (kDebugMode) {
          debugPrint('Watch history marked for video $videoId: $success');
        }

        return success;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('WatchHistoryService markVideoAsWatched error: $e');
      }
      // Don't rethrow - watch history is not critical, so we don't want to break the video player
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WatchHistoryService markVideoAsWatched error: $e');
      }
      // Don't rethrow - watch history is not critical
      return false;
    }
  }
}
