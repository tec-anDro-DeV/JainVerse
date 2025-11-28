import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Presenter encapsulating server interactions for the user's video watch history.
class VideoHistoryPresenter {
  final Dio _dio;
  final SharedPref _sharedPref = SharedPref();

  // Prevent re-posting the same watch entry multiple times in rapid succession.
  static final Map<int, DateTime> _lastWatchTimestamps = {};
  static const Duration _watchDebounce = Duration(seconds: 2);

  VideoHistoryPresenter({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  /// Convenience method for watchers that just want to mark a video as watched.
  Future<void> trackVideoWatch(int videoId) async {
    if (videoId <= 0) return;
    final token = await _resolveToken();
    if (token.isEmpty) return;

    try {
      await addVideoHistory(videoId, token);
    } catch (_) {
      // Intentionally swallow errors; watch history should never block playback.
    }
  }

  Future<bool> addVideoHistory(int videoId, [String? overrideToken]) async {
    final authToken = await _resolveToken(overrideToken);
    if (authToken.isEmpty || videoId <= 0) return false;

    final now = DateTime.now();
    final last = _lastWatchTimestamps[videoId];
    if (last != null && now.difference(last) < _watchDebounce) {
      return true;
    }
    _lastWatchTimestamps[videoId] = now;

    final formData = FormData.fromMap({'video_id': videoId.toString()});

    try {
      final response = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_WATCH_HISTORY,
        data: formData,
        options: _buildOptions(authToken),
      );
      await TokenExpirationHandler().checkAndHandleResponse(response);
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return false;
    }
  }

  Future<String> getHistory([String? overrideToken]) async {
    final authToken = await _resolveToken(overrideToken);
    if (authToken.isEmpty) return '{}';

    try {
      final response = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_GET_VIDEO_HISTORY,
        options: _buildOptions(authToken),
      );
      await TokenExpirationHandler().checkAndHandleResponse(response);
      return _stringifyResponse(response);
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return '{}';
    }
  }

  Future<bool> removeVideoHistory(int videoId) async {
    final authToken = await _resolveToken();
    if (authToken.isEmpty || videoId <= 0) return false;

    final formData = FormData.fromMap({'video_id': videoId.toString()});
    try {
      final response = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_REMOVE_VIDEO_HISTORY,
        data: formData,
        options: _buildOptions(authToken),
      );
      await TokenExpirationHandler().checkAndHandleResponse(response);
      _lastWatchTimestamps.remove(videoId);
      return response.statusCode == 200;
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return false;
    }
  }

  Future<bool> clearVideoHistory() async {
    final authToken = await _resolveToken();
    if (authToken.isEmpty) return false;

    try {
      final response = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_CLEAR_VIDEO_HISTORY,
        options: _buildOptions(authToken),
      );
      await TokenExpirationHandler().checkAndHandleResponse(response);
      _lastWatchTimestamps.clear();
      return response.statusCode == 200;
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return false;
    }
  }

  Options _buildOptions(String token) {
    return Options(
      headers: {
        'Accept': 'application/json',
        if (token.isNotEmpty) 'authorization': 'Bearer $token',
      },
    );
  }

  Future<String> _resolveToken([String? overrideToken]) async {
    final provided = overrideToken?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    final stored = await _sharedPref.getToken();
    if (stored == null) return '';
    final normalized = stored.toString().trim();
    return normalized;
  }

  String _stringifyResponse(Response response) {
    final data = response.data;
    if (data == null) return '{}';
    if (data is String) return data;
    try {
      return json.encode(data);
    } catch (_) {
      return data.toString();
    }
  }
}
