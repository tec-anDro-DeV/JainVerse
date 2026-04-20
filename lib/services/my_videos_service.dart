import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';
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

  /// Fetch shorts (reels) from the same channel detail endpoint.
  Future<List<ReelItem>> getMyShorts({CancelToken? cancelToken}) async {
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
        final List<dynamic> shortsJson = _extractShortList(payload);
        final items = <ReelItem>[];
        for (final entry in shortsJson) {
          if (entry is Map<String, dynamic>) {
            items.add(ReelItem.fromJson(entry));
            continue;
          }
          if (entry is Map) {
            items.add(ReelItem.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
        return items;
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('MyVideosService.getMyShorts error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('MyVideosService.getMyShorts error: $e');
      throw Exception(e.toString());
    }
  }

  /// Update a short's metadata (title/description). Returns the updated
  /// ReelItem on success or null on failure.
  Future<ReelItem?> updateShortVideo({
    required int shortId,
    String? title,
    String? description,
  }) async {
    final token = await _sharedPref.getToken();
    try {
      final resp = await _dio.post(
        AppConstant.BaseUrl + 'update_short_video',
        data: {
          'short_id': shortId,
          if (title != null) 'title': title,
          if (description != null) 'description': description,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.toString().isNotEmpty)
              'Authorization': 'Bearer ${token.toString()}',
          },
        ),
      );

      if (resp.statusCode == 200) {
        final body = _normalizeResponse(resp.data);
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          return ReelItem.fromJson(data);
        }
      }
      return null;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('MyVideosService.updateShortVideo error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('MyVideosService.updateShortVideo error: $e');
      throw Exception(e.toString());
    }
  }

  /// Delete a short. Returns true on successful deletion.
  Future<bool> deleteShortVideo({required int shortId}) async {
    final token = await _sharedPref.getToken();
    try {
      final resp = await _dio.post(
        AppConstant.BaseUrl + 'delete_short_video',
        data: {'short_id': shortId},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.toString().isNotEmpty)
              'Authorization': 'Bearer ${token.toString()}',
          },
        ),
      );
      if (resp.statusCode == 200) {
        final body = _normalizeResponse(resp.data);
        final status = body['status'];
        if (status == true || status == 'true') return true;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('MyVideosService.deleteShortVideo error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('MyVideosService.deleteShortVideo error: $e');
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

List<dynamic> _extractShortList(Map<String, dynamic> payload) {
  List<dynamic> candidate = [];

  final directShorts = payload['shorts'];
  if (directShorts is List) return directShorts;

  final dataSection = payload['data'];
  if (dataSection is List) return dataSection;
  if (dataSection is Map<String, dynamic>) {
    final nestedShorts = dataSection['shorts'];
    if (nestedShorts is List) return nestedShorts;

    final nestedData = dataSection['data'];
    if (nestedData is List) return nestedData;
    if (nestedData is Map<String, dynamic>) {
      final deepShorts = nestedData['shorts'];
      if (deepShorts is List) return deepShorts;
      final deepData = nestedData['data'];
      if (deepData is List) return deepData;
    }
  }

  // Fallback: sometimes API returns shorts inside 'videos' map
  final directVideos = payload['videos'];
  if (directVideos is List) return directVideos;
  if (directVideos is Map<String, dynamic>) {
    final nested = directVideos['shorts'];
    if (nested is List) return nested;
    final nestedData = directVideos['data'];
    if (nestedData is List) return nestedData;
  }

  return candidate;
}
