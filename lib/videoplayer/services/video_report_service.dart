import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/videoplayer/models/report_option.dart';

/// Service to handle video reporting functionality
class VideoReportService {
  final Dio _dio;
  final SharedPref _sharedPref;

  VideoReportService({Dio? dio, SharedPref? sharedPref})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref() {
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 20);
  }

  /// Fetch available report options from the API
  Future<List<ReportOption>> fetchReportOptions({
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    try {
      final resp = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_VIDEO_REPORT_OPTIONS,
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

        if (data is Map<String, dynamic> && data['status'] == true) {
          final dataList = data['data'] as List?;
          if (dataList != null) {
            return dataList
                .map(
                  (json) => ReportOption.fromJson(json as Map<String, dynamic>),
                )
                .toList();
          }
        }
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode)
        debugPrint('VideoReportService fetchReportOptions error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode)
        debugPrint('VideoReportService fetchReportOptions error: $e');
      throw Exception(e.toString());
    }
  }

  /// Submit a video report
  Future<bool> reportVideo({
    required int videoId,
    required int reportId,
    required String comment,
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    try {
      final formData = FormData.fromMap({
        'video_id': videoId.toString(),
        'report_id': reportId.toString(),
        'comment': comment,
      });

      final resp = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_REPORT_VIDEO,
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
        final success = data is Map<String, dynamic>
            ? (data['status'] == true || resp.statusCode == 200)
            : true;

        return success;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('VideoReportService reportVideo error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('VideoReportService reportVideo error: $e');
      throw Exception(e.toString());
    }
  }
}
