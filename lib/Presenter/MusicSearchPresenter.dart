import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';

class MusicSearchPresenter extends BasePresenter {
  MusicSearchPresenter();

  Future<String> getMusicListBySearchNamePage(
    String search,
    String token,
    int pageNumber,
    int numberOfPostsPerRequest,
    BuildContext context,
  ) async {
    FormData formData = FormData.fromMap({
      AppConstant.search: search,
      "page": pageNumber,
      "limit": numberOfPostsPerRequest,
    });

    Response<String> response = await post<String>(
      AppConstant.BaseUrl + AppConstant.API_GET_SEARCH_MUSIC,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    return response.toString();
  }

  Future<String> getMusicListBySearchNamePageLegacy(
    String search,
    String token,
    int pageNumber,
    int numberOfPostsPerRequest,
  ) async {
    FormData formData = FormData.fromMap({
      AppConstant.search: search,
      "page": pageNumber,
      "limit": numberOfPostsPerRequest,
    });

    Response<String> response;
    try {
      response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_GET_SEARCH_MUSIC,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );
    } on DioException catch (dioError) {
      try {
        final handler = TokenExpirationHandler();
        await handler.checkAndHandleResponse(
          dioError.response,
          context: navigatorKey.currentContext,
        );
      } catch (_) {}

      return '{"status": false, "msg": "Network error: ${dioError.message}"}';
    }

    return response.toString();
  }

  Future<ModelMusicList> getMusicListBySearchName(
    String search,
    String token, [
    BuildContext? context,
  ]) async {
    if (search.trim().isEmpty) throw Exception('Search query cannot be empty');

    FormData formData = FormData.fromMap({AppConstant.search: search.trim()});

    try {
      Response<String> response;
      if (context != null) {
        response = await post<String>(
          AppConstant.BaseUrl + AppConstant.API_GET_SEARCH_MUSIC,
          data: formData,
          options: Options(headers: createAuthHeaders(token)),
          context: context,
        );
      } else {
        response = await dio.post(
          AppConstant.BaseUrl + AppConstant.API_GET_SEARCH_MUSIC,
          data: formData,
          options: Options(
            headers: {
              "Accept": "application/json",
              "authorization": "Bearer $token",
            },
          ),
        );
      }

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        if (parsed.containsKey('status') && parsed['status'] == false) {
          return ModelMusicList.fromJson({
            'status': true,
            'data': [],
            'msg': 'No results found',
          });
        }
        return ModelMusicList.fromJson(parsed);
      } else {
        throw Exception('Invalid response from server');
      }
    } on DioException catch (dioError) {
      try {
        final handler = TokenExpirationHandler();
        final handled = await handler.checkAndHandleResponse(
          dioError.response,
          context: context ?? navigatorKey.currentContext,
        );
        if (handled) {
          return ModelMusicList.fromJson({
            'status': true,
            'data': [],
            'msg': 'Session expired',
          });
        }
      } catch (e) {}

      switch (dioError.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw Exception(
            'Connection timeout. Please check your internet connection.',
          );
        case DioExceptionType.connectionError:
          throw Exception(
            'Network connection error. Please check your internet connection.',
          );
        case DioExceptionType.badResponse:
          if (dioError.response?.statusCode == 401) {
            try {
              await TokenExpirationHandler().checkAndHandleResponse(
                dioError.response,
                context: context ?? navigatorKey.currentContext,
              );
            } catch (_) {}

            return ModelMusicList.fromJson({
              'status': true,
              'data': [],
              'msg': 'Unauthorized',
            });
          }

          if (dioError.response?.statusCode == 404) {
            throw Exception(
              'Search service not found. Please try again later.',
            );
          }
          throw Exception('Server error. Please try again later.');
        default:
          throw Exception('Failed to search. Please try again.');
      }
    } catch (error) {
      throw Exception('An unexpected error occurred during search: $error');
    }
  }
}
