import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/videoplayer/models/channel_item.dart';

/// Service to fetch user's subscribed channels
class SubscribedChannelsService {
  final Dio _dio;
  final SharedPref _sharedPref;

  SubscribedChannelsService({Dio? dio, SharedPref? sharedPref})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref() {
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 20);
  }

  /// Fetch all subscribed channels for the current user
  Future<List<ChannelItem>> getSubscribedChannels({
    CancelToken? cancelToken,
  }) async {
    final token = await _sharedPref.getToken();

    try {
      final resp = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_GET_SUBSCRIBED_CHANNELS,
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
          final List<dynamic> channelsJson = data['data'] ?? [];
          return channelsJson
              .map((json) => ChannelItem.fromJson(json))
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('SubscribedChannelsService error: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('SubscribedChannelsService error: $e');
      throw Exception(e.toString());
    }
  }
}
