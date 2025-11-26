import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelCatSubcatMusic.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';

class MusicCategoryPresenter extends BasePresenter {
  bool _isFetchingCategories = false;

  MusicCategoryPresenter();

  Future<ModelCatSubcatMusic?> getCachedMusicCategories() async {
    final cachedData = await CacheManager.getFromCache(
      CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
    );

    if (cachedData != null) {
      try {
        final parsedData = json.decode(cachedData['data']);
        return ModelCatSubcatMusic.fromJson(parsedData);
      } catch (e) {
        print(
          '[ERROR][MusicCategoryPresenter] Failed to parse cached categories: $e',
        );
        return null;
      }
    }

    return null;
  }

  Future<ModelCatSubcatMusic> getCatSubCatMusicList(
    String token,
    BuildContext context,
  ) async {
    if (_isFetchingCategories) {
      final cached = await getCachedMusicCategories();
      if (cached != null) return cached;
      await Future.delayed(const Duration(milliseconds: 500));
      return getCatSubCatMusicList(token, context);
    }

    _isFetchingCategories = true;

    try {
      Response<String> response = await get<String>(
        AppConstant.BaseUrl + AppConstant.API_GET_MUSIC_CATEGORIES,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      if (response.statusCode == 200) {
        final responseData = response.data.toString();

        await CacheManager.saveToCache(
          CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
          responseData,
        );

        final Map<String, dynamic> parsed = json.decode(responseData);

        _isFetchingCategories = false;
        return ModelCatSubcatMusic.fromJson(parsed);
      } else {
        _isFetchingCategories = false;
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Server returned ${response.statusCode}',
        );
      }
    } on DioException catch (dioError) {
      _isFetchingCategories = false;

      final cached = await getCachedMusicCategories();
      if (cached != null) return cached;

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
          throw Exception('Server error. Please try again later.');
        default:
          throw Exception('Failed to load data. Please try again.');
      }
    } catch (error) {
      _isFetchingCategories = false;
      final cached = await getCachedMusicCategories();
      if (cached != null) return cached;
      throw Exception('An unexpected error occurred: $error');
    }
  }

  Future<ModelCatSubcatMusic> getCatSubCatMusicListLegacy(String token) async {
    if (_isFetchingCategories) {
      final cached = await getCachedMusicCategories();
      if (cached != null) return cached;
      await Future.delayed(const Duration(milliseconds: 500));
      return getCatSubCatMusicListLegacy(token);
    }

    _isFetchingCategories = true;

    try {
      Response<String> response = await dio.get(
        AppConstant.BaseUrl + AppConstant.API_GET_MUSIC_CATEGORIES,
        options: Options(headers: createAuthHeaders(token)),
      );

      if (response.statusCode == 200) {
        final responseData = response.data.toString();

        await CacheManager.saveToCache(
          CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
          responseData,
        );

        final Map<String, dynamic> parsed = json.decode(responseData);

        _isFetchingCategories = false;
        return ModelCatSubcatMusic.fromJson(parsed);
      } else {
        _isFetchingCategories = false;
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Server returned ${response.statusCode}',
        );
      }
    } on DioException catch (dioError) {
      _isFetchingCategories = false;

      final cached = await getCachedMusicCategories();
      if (cached != null) return cached;

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
          throw Exception('Server error. Please try again later.');
        default:
          throw Exception('Failed to load data. Please try again.');
      }
    } catch (error) {
      _isFetchingCategories = false;
      final cached = await getCachedMusicCategories();
      if (cached != null) return cached;
      throw Exception('An unexpected error occurred: $error');
    }
  }
}
