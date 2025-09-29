import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';

class FavMusicPresenter extends BasePresenter {
  FavMusicPresenter() : super();

  /// Context-aware: use this from widgets where a BuildContext is available
  Future<ModelMusicList> getFavMusicListWithContext(
    BuildContext context,
    String token,
  ) async {
    final FormData formData = FormData.fromMap({AppConstant.type: "audio"});

    final Response<dynamic> response = await post<dynamic>(
      AppConstant.BaseUrl + AppConstant.API_GET_FAVOURITE_LIST,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    try {
      final dynamic responseData = response.data;
      final Map<String, dynamic> parsed;
      if (responseData is Map<String, dynamic>) {
        parsed = responseData;
      } else if (responseData is String) {
        parsed = json.decode(responseData) as Map<String, dynamic>;
      } else {
        // Fallback - try decoding string representation
        parsed =
            json.decode(responseData?.toString() ?? '{}')
                as Map<String, dynamic>;
      }
      return ModelMusicList.fromJson(parsed);
    } catch (e) {
      rethrow;
    }
  }

  /// Legacy (no BuildContext) - kept for backward compatibility
  Future<ModelMusicList> getFavMusicList(String token) async {
    final FormData formData = FormData.fromMap({AppConstant.type: "audio"});

    Response<dynamic> response;
    try {
      response = await dio.post<dynamic>(
        AppConstant.BaseUrl + AppConstant.API_GET_FAVOURITE_LIST,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );
      // If token expired, handle it (best-effort)
      await TokenExpirationHandler().checkAndHandleResponse(response);
    } on DioException catch (e) {
      // If we have a response, check for token expiration and rethrow
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      rethrow;
    }

    try {
      final dynamic responseData = response.data;
      final Map<String, dynamic> parsed;
      if (responseData is Map<String, dynamic>) {
        parsed = responseData;
      } else if (responseData is String) {
        parsed = json.decode(responseData) as Map<String, dynamic>;
      } else {
        parsed =
            json.decode(responseData?.toString() ?? '{}')
                as Map<String, dynamic>;
      }
      return ModelMusicList.fromJson(parsed);
    } catch (e) {
      rethrow;
    }
  }

  /// Context-aware add/remove favorite
  Future<void> getMusicAddRemoveWithContext(
    BuildContext context,
    String id,
    String token,
    String tag,
  ) async {
    final FormData formData = FormData.fromMap({
      AppConstant.id: id,
      AppConstant.type: "audio",
    });

    final Response<dynamic> response = await post<dynamic>(
      AppConstant.BaseUrl + AppConstant.API_ADD_FAVOURITE_LIST,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    try {
      final dynamic responseData = response.data;
      final Map<String, dynamic> parsed;
      if (responseData is Map<String, dynamic>) {
        parsed = responseData;
      } else if (responseData is String) {
        parsed = json.decode(responseData) as Map<String, dynamic>;
      } else {
        parsed =
            json.decode(responseData?.toString() ?? '{}')
                as Map<String, dynamic>;
      }
      // ignore: avoid_print
      print('FavMusicPresenter (withContext): ${parsed['msg'] ?? parsed}');
    } catch (e) {
      // swallow - caller handles UI
    }
  }

  /// Legacy add/remove favorite (no BuildContext)
  Future<void> getMusicAddRemove(String id, String token, String tag) async {
    final FormData formData = FormData.fromMap({
      AppConstant.id: id,
      AppConstant.type: "audio",
    });

    try {
      final Response<dynamic> response = await dio.post<dynamic>(
        AppConstant.BaseUrl + AppConstant.API_ADD_FAVOURITE_LIST,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );

      // Best-effort token expiration check
      await TokenExpirationHandler().checkAndHandleResponse(response);

      try {
        final dynamic responseData = response.data;
        final Map<String, dynamic> parsed;
        if (responseData is Map<String, dynamic>) {
          parsed = responseData;
        } else if (responseData is String) {
          parsed = json.decode(responseData) as Map<String, dynamic>;
        } else {
          parsed =
              json.decode(responseData?.toString() ?? '{}')
                  as Map<String, dynamic>;
        }
        // ignore: avoid_print
        print('FavMusicPresenter: ${parsed['msg'] ?? parsed}');
      } catch (e) {
        // swallow parsing errors
      }
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      rethrow;
    }
  }
}
