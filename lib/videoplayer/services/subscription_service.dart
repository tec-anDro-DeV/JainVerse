import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';

/// Service to handle channel subscription/unsubscription
class SubscriptionService {
  final Dio _dio;
  final SharedPref _sharedPref;

  SubscriptionService({Dio? dio, SharedPref? sharedPref})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref() {
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 20);
  }

  /// Subscribe to a channel
  Future<bool> subscribeChannel({
    required int channelId,
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    try {
      final resp = await _dio.post(
        'https://musicvideo.techcronus.com/api/v2/subscribe_channel',
        data: {'channel_id': channelId},
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
        final success =
            data is Map<String, dynamic>
                ? (data['status'] == true || resp.statusCode == 200)
                : true;

        if (success) {
          // Update global state manager
          SubscriptionStateManager().updateSubscriptionState(channelId, true);
        }

        return success;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('SubscriptionService subscribe error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('SubscriptionService subscribe error: $e');
      throw Exception(e.toString());
    }
  }

  /// Unsubscribe from a channel
  Future<bool> unsubscribeChannel({
    required int channelId,
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    try {
      final resp = await _dio.post(
        'https://musicvideo.techcronus.com/api/v2/unsubscribe_channel',
        data: {'channel_id': channelId},
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
        final success =
            data is Map<String, dynamic>
                ? (data['status'] == true || resp.statusCode == 200)
                : true;

        if (success) {
          // Update global state manager
          SubscriptionStateManager().updateSubscriptionState(channelId, false);
        }

        return success;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('SubscriptionService unsubscribe error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('SubscriptionService unsubscribe error: $e');
      throw Exception(e.toString());
    }
  }
}
