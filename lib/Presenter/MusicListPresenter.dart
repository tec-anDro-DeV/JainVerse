import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/utils/AppConstant.dart';

class MusicListPresenter extends BasePresenter {
  MusicListPresenter();

  Future<String> getMusic({
    required String token,
    required String type,
    required int page,
    required int limit,
    required BuildContext context,
    String? search,
  }) async {
    final Map<String, dynamic> body = {
      'type': type,
      'page': page,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) {
      body[AppConstant.search] = search.trim();
    }

    final formData = FormData.fromMap(body);

    try {
      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_GETMUSIC,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      if (response.statusCode == 200) {
        return response.data ?? '{"status": false, "msg": "Empty response"}';
      }
      return '{"status": false, "msg": "Server returned ${response.statusCode}"}';
    } on DioException catch (_) {
      return '{"status": false, "msg": "Network error"}';
    } catch (e) {
      return '{"status": false, "msg": "Unexpected error: $e"}';
    }
  }

  Future<String> getMusicLegacy({
    required String token,
    required String type,
    required int page,
    required int limit,
    String? search,
  }) async {
    final Map<String, dynamic> body = {
      'type': type,
      'page': page,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) {
      body[AppConstant.search] = search.trim();
    }

    final formData = FormData.fromMap(body);

    try {
      Response<String> response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_GETMUSIC,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );

      if (response.statusCode == 200) {
        return response.data ?? '{"status": false, "msg": "Empty response"}';
      }
      return '{"status": false, "msg": "Server returned ${response.statusCode}"}';
    } on DioException catch (_) {
      return '{"status": false, "msg": "Network error"}';
    } catch (e) {
      return '{"status": false, "msg": "Unexpected error: $e"}';
    }
  }

  Future<ModelMusicList> getMusicListByCategory(
    String id,
    String type,
    String token, [
    BuildContext? context,
  ]) async {
    FormData formData = FormData.fromMap({
      AppConstant.type: type,
      AppConstant.id: id,
    });

    Response<String> response;
    if (context != null) {
      response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_GET_MUSIC_BY_CATEGORY,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );
    } else {
      try {
        response = await dio.post(
          AppConstant.BaseUrl + AppConstant.API_GET_MUSIC_BY_CATEGORY,
          data: formData,
          options: Options(
            headers: {
              "Accept": "application/json",
              "authorization": "Bearer $token",
            },
          ),
        );
      } on DioException catch (_) {
        return ModelMusicList.fromJson({
          'status': true,
          'data': [],
          'msg': 'Unauthorized',
        });
      }
    }

    try {
      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        if (parsed['status'].toString().contains('false')) {
          // swallow UI toast here if needed
        }
        return ModelMusicList.fromJson(parsed);
      } else {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        return ModelMusicList.fromJson(parsed);
      }
    } catch (error) {
      throw UnimplementedError();
    }
  }
}
