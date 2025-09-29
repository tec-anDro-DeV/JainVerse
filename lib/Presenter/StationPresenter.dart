import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/Model/ModelStationResponse.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';

/// Presenter for handling station creation API calls
class StationPresenter {
  late final Dio _dio;

  StationPresenter() {
    _dio = Dio();
    // Configure timeout settings
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  /// Create a station based on the provided song ID
  /// Returns a list of similar songs for the station
  Future<ModelStationResponse> createStation(
    String songId,
    String token,
  ) async {
    if (kDebugMode) {
      print('[StationPresenter] Creating station for song ID: $songId');
    }

    FormData formData = FormData.fromMap({"song_id": songId});

    try {
      Response<String> response = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_CREATE_STATION,
        data: formData,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
        ),
      );

      if (kDebugMode) {
        print('[StationPresenter] Response status: ${response.statusCode}');
        print('[StationPresenter] Response data: ${response.data}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );

        if (kDebugMode) {
          print('[StationPresenter] Station created successfully');
          print(
            '[StationPresenter] Similar songs count: ${parsed['data']?.length ?? 0}',
          );
        }

        return ModelStationResponse.fromJson(parsed);
      } else {
        if (kDebugMode) {
          print('[StationPresenter] Non-200 response: ${response.statusCode}');
        }
        // Return empty response for non-200 status codes
        return ModelStationResponse(
          false,
          'Failed to create station',
          [],
          '',
          '',
        );
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('[StationPresenter] Dio error creating station: $e');
      }

      // If this was a token expiration, trigger the centralized handler
      try {
        await TokenExpirationHandler().checkAndHandleResponse(e.response);
      } catch (_) {}

      // Return empty response on error (safe fallback)
      return ModelStationResponse(false, 'Error creating station', [], '', '');
    } catch (error) {
      if (kDebugMode) {
        print('[StationPresenter] Error creating station: $error');
      }

      // Return empty response on error
      return ModelStationResponse(
        false,
        'Error creating station: $error',
        [],
        '',
        '',
      );
    }
  }
}
