import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/home_models.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Repository responsible for fetching and caching the unified home response.
class HomeRepository extends BasePresenter {
  HomeRepository._internal();

  static final HomeRepository _instance = HomeRepository._internal();

  factory HomeRepository() => _instance;

  final SharedPref _sharedPref = SharedPref();

  /// Fetch the latest home layout from the API or cache.
  Future<HomeResponse> fetchHomeList({bool forceRefresh = false}) async {
    final token = await _sharedPref.getToken();
    if (token.isEmpty) {
      throw Exception('Authentication token missing. Please login again.');
    }

    if (forceRefresh) {
      await CacheManager.forceRefreshCache(CacheManager.HOME_CONTENT_CACHE_KEY);
    } else {
      final cached = await _getCachedResponse();
      if (cached != null) {
        return cached;
      }
    }

    final BuildContext? context = navigatorKey.currentContext;
    if (context == null) {
      throw Exception('Unable to resolve navigation context for API call.');
    }

    try {
      CacheManager.setFreshDataLoading(true);
      final response = await get<String>(
        AppConstant.BaseUrl + AppConstant.API_HOME_LIST,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      final payload = response.data ?? '{}';
      await CacheManager.saveToCache(
        CacheManager.HOME_CONTENT_CACHE_KEY,
        payload,
      );

      return HomeResponse.fromJson(
        json.decode(payload) as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      final cached = await _getCachedResponse();
      if (cached != null) {
        return cached;
      }
      throw Exception(_mapDioError(error));
    } catch (error) {
      final cached = await _getCachedResponse();
      if (cached != null) {
        return cached;
      }
      throw Exception('Failed to load home data. Please try again.');
    } finally {
      CacheManager.setFreshDataLoading(false);
    }
  }

  /// Force a network refresh, bypassing the cache.
  Future<HomeResponse> refreshHomeList() {
    return fetchHomeList(forceRefresh: true);
  }

  Future<HomeResponse?> _getCachedResponse() async {
    final cached = await CacheManager.getFromCache(
      CacheManager.HOME_CONTENT_CACHE_KEY,
    );

    if (cached == null || cached['data'] == null) {
      return null;
    }

    try {
      final raw = cached['data'] as String;
      return HomeResponse.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      await CacheManager.clearCache(CacheManager.HOME_CONTENT_CACHE_KEY);
      return null;
    }
  }

  String _mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timeout. Please check your network and try again.';
      case DioExceptionType.badResponse:
        return 'Server error ${error.response?.statusCode ?? ''}. Please try again later.';
      case DioExceptionType.connectionError:
        return 'Network connection error. Please check your internet connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
