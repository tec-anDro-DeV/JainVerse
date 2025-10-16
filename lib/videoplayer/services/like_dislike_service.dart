import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/videoplayer/managers/like_dislike_state_manager.dart';

/// Service to handle video like/dislike actions
/// Like states: 0 = neutral, 1 = liked, 2 = disliked
class LikeDislikeService {
  final Dio _dio;
  final SharedPref _sharedPref;

  LikeDislikeService({Dio? dio, SharedPref? sharedPref})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref() {
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 20);
  }

  /// Toggle like state for a video
  /// If currently liked (1), toggle to neutral (0)
  /// If not liked, toggle to liked (1)
  Future<bool> likeVideo({
    required int videoId,
    required int currentState, // Pass current state to determine action
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    // Determine new state: if already liked (1), go to neutral (0), else go to liked (1)
    final newState = currentState == 1 ? 0 : 1;

    try {
      final formData = FormData.fromMap({
        'video_id': videoId.toString(),
        'like': newState.toString(),
      });

      final resp = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_LIKE_DISLIKE_VIDEO,
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

        if (success) {
          // Update global state manager
          LikeDislikeStateManager().updateLikeState(videoId, newState);
        }

        return success;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('LikeDislikeService like error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('LikeDislikeService like error: $e');
      throw Exception(e.toString());
    }
  }

  /// Toggle dislike state for a video
  /// If currently disliked (2), toggle to neutral (0)
  /// If not disliked, toggle to disliked (2)
  Future<bool> dislikeVideo({
    required int videoId,
    required int currentState, // Pass current state to determine action
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    // Determine new state: if already disliked (2), go to neutral (0), else go to disliked (2)
    final newState = currentState == 2 ? 0 : 2;

    try {
      final formData = FormData.fromMap({
        'video_id': videoId.toString(),
        'like': newState.toString(),
      });

      final resp = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_LIKE_DISLIKE_VIDEO,
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

        if (success) {
          // Update global state manager
          LikeDislikeStateManager().updateLikeState(videoId, newState);
        }

        return success;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('LikeDislikeService dislike error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('LikeDislikeService dislike error: $e');
      throw Exception(e.toString());
    }
  }

  /// Set like state directly (useful for initial sync or forced state)
  Future<bool> setLikeState({
    required int videoId,
    required int likeState, // 0, 1, or 2
    CancelToken? cancelToken,
  }) async {
    assert(
      likeState == 0 || likeState == 1 || likeState == 2,
      'likeState must be 0, 1, or 2',
    );

    final token = await _sharedPref.getToken();

    try {
      final formData = FormData.fromMap({
        'video_id': videoId.toString(),
        'like': likeState.toString(),
      });

      final resp = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_LIKE_DISLIKE_VIDEO,
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

        if (success) {
          // Update global state manager
          LikeDislikeStateManager().updateLikeState(videoId, likeState);
        }

        return success;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('LikeDislikeService setLikeState error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('LikeDislikeService setLikeState error: $e');
      throw Exception(e.toString());
    }
  }
}
