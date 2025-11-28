import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Service to fetch user's uploaded videos (my videos)
class MyVideosService {
  final Dio _dio;
  final SharedPref _sharedPref;

  MyVideosService({Dio? dio, SharedPref? sharedPref})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref() {
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 20);
  }

  /// Fetch all uploaded videos for the current user
  Future<List<VideoItem>> getMyVideos({CancelToken? cancelToken}) async {
    final token = await _sharedPref.getToken();

    try {
      final resp = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_MY_CHANNEL_DETAIL,
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
        final payload = _normalizeResponse(resp.data);
        final List<dynamic> videosJson = _extractVideoList(payload);
        final items = <VideoItem>[];
        for (final entry in videosJson) {
          if (entry is Map<String, dynamic>) {
            items.add(VideoItem.fromJson(entry));
            continue;
          }
          if (entry is Map) {
            items.add(VideoItem.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
        return items;
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('MyVideosService error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('MyVideosService error: $e');
      throw Exception(e.toString());
    }
  }
}

Map<String, dynamic> _normalizeResponse(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
  }
  return const <String, dynamic>{};
}

List<dynamic> _extractVideoList(Map<String, dynamic> payload) {
  List<dynamic> candidate = [];

  final directVideos = payload['videos'];
  if (directVideos is List) return directVideos;

  final dataSection = payload['data'];
  if (dataSection is List) return dataSection;
  if (dataSection is Map<String, dynamic>) {
    final nestedVideos = dataSection['videos'];
    if (nestedVideos is List) return nestedVideos;
    final nestedData = dataSection['data'];
    if (nestedData is List) return nestedData;
  }

  if (directVideos is Map<String, dynamic>) {
    final nestedData = directVideos['data'];
    if (nestedData is List) return nestedData;
  }

  return candidate;
}
