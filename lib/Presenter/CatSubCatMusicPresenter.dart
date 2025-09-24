import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/ModelCatSubcatMusic.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/main.dart';

class CatSubcatMusicPresenter extends BasePresenter {
  // Track if we're already fetching to prevent duplicate requests
  bool _isFetchingCategories = false;

  // Enhanced constructor with timeout configuration
  CatSubcatMusicPresenter() {
    print('[DEBUG][CatSubcatMusicPresenter] Instance created');
  }

  // New method to get cached categories first, then refresh in background
  Future<ModelCatSubcatMusic?> getCachedMusicCategories() async {
    final cachedData = await CacheManager.getFromCache(
      CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
    );

    if (cachedData != null) {
      try {
        final parsedData = json.decode(cachedData['data']);
        return ModelCatSubcatMusic.fromJson(parsedData);
      } catch (e) {
        print('[ERROR] Failed to parse cached categories: $e');
        return null;
      }
    }

    return null;
  }

  // New method with token expiration handling
  Future<String> getMusicCategory(
    String token,
    String type,
    int pageNumber,
    int numberOfPostsPerRequest,
    BuildContext context,
  ) async {
    // Delegate to generic getMusic for a single code path
    return getMusic(
      token: token,
      type: type,
      page: pageNumber,
      limit: numberOfPostsPerRequest,
      context: context,
    );
  }

  // Legacy method for backward compatibility (without token expiration handling)
  Future<String> getMusicCategoryLegacy(
    String token,
    String type,
    int pageNumber,
    int numberOfPostsPerRequest,
  ) async {
    // Delegate to generic getMusic for a single code path
    return getMusicLegacy(
      token: token,
      type: type,
      page: pageNumber,
      limit: numberOfPostsPerRequest,
    );
  }

  /// Generic getMusic caller with optional search parameter - WITH token expiration handling
  /// Keeps return type as String for backward compatibility with existing parsers
  Future<String> getMusic({
    required String token,
    required String type,
    required int page,
    required int limit,
    required BuildContext context,
    String? search,
  }) async {
    print('[DEBUG][getMusic] Called');
    print(
      '[DEBUG][getMusic] Params: token=${token.isNotEmpty ? token.substring(0, token.length > 20 ? 20 : token.length) : ''}..., type=$type, page=$page, limit=$limit, search=${search ?? ''}',
    );

    final Map<String, dynamic> body = {
      'type': type,
      'page': page,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) {
      body[AppConstant.search] = search.trim();
    }

    final formData = FormData.fromMap(body);

    print(
      '[DEBUG][getMusic] Requesting: ${AppConstant.BaseUrl + AppConstant.API_GETMUSIC}',
    );
    print(
      '[DEBUG][getMusic] FormData fields: ${body.keys.map((k) => '$k=${body[k]}').join(', ')}',
    );

    try {
      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_GETMUSIC,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      print('[DEBUG][getMusic] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[DEBUG][getMusic] Success response received');
        return response.data ?? '{"status": false, "msg": "Empty response"}';
      } else {
        print('[DEBUG][getMusic] Non-200 response: ${response.statusCode}');
        return '{"status": false, "msg": "Server returned ${response.statusCode}"}';
      }
    } on DioException catch (dioError) {
      print('[ERROR][getMusic] DioException: ${dioError.message}');
      print('[ERROR][getMusic] DioException type: ${dioError.type}');
      print(
        '[ERROR][getMusic] Response status: ${dioError.response?.statusCode}',
      );

      if (dioError.response?.statusCode == 500) {
        print(
          '[ERROR][getMusic] Server error 500 - likely invalid type parameter: $type',
        );
        return '{"status": false, "msg": "Server error: Invalid category type"}';
      }

      return '{"status": false, "msg": "Network error: ${dioError.message}"}';
    } catch (e) {
      print('[ERROR][getMusic] General Exception: $e');
      return '{"status": false, "msg": "Unexpected error: $e"}';
    }
  }

  /// Legacy getMusic method WITHOUT token expiration handling
  Future<String> getMusicLegacy({
    required String token,
    required String type,
    required int page,
    required int limit,
    String? search,
  }) async {
    print('[DEBUG][getMusicLegacy] Called');
    print(
      '[DEBUG][getMusicLegacy] Params: token=${token.isNotEmpty ? token.substring(0, token.length > 20 ? 20 : token.length) : ''}..., type=$type, page=$page, limit=$limit, search=${search ?? ''}',
    );

    final Map<String, dynamic> body = {
      'type': type,
      'page': page,
      'limit': limit,
    };
    if (search != null && search.trim().isNotEmpty) {
      body[AppConstant.search] = search.trim();
    }

    final formData = FormData.fromMap(body);

    print(
      '[DEBUG][getMusicLegacy] Requesting: ${AppConstant.BaseUrl + AppConstant.API_GETMUSIC}',
    );
    print(
      '[DEBUG][getMusicLegacy] FormData fields: ${body.keys.map((k) => '$k=${body[k]}').join(', ')}',
    );

    try {
      Response<String> response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_GETMUSIC,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );

      print('[DEBUG][getMusicLegacy] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[DEBUG][getMusicLegacy] Success response received');
        return response.data ?? '{"status": false, "msg": "Empty response"}';
      } else {
        print(
          '[DEBUG][getMusicLegacy] Non-200 response: ${response.statusCode}',
        );
        return '{"status": false, "msg": "Server returned ${response.statusCode}"}';
      }
    } on DioException catch (dioError) {
      print('[ERROR][getMusicLegacy] DioException: ${dioError.message}');
      print('[ERROR][getMusicLegacy] DioException type: ${dioError.type}');
      print(
        '[ERROR][getMusicLegacy] Response status: ${dioError.response?.statusCode}',
      );

      if (dioError.response?.statusCode == 500) {
        print(
          '[ERROR][getMusicLegacy] Server error 500 - likely invalid type parameter: $type',
        );
        return '{"status": false, "msg": "Server error: Invalid category type"}';
      }

      return '{"status": false, "msg": "Network error: ${dioError.message}"}';
    } catch (e) {
      print('[ERROR][getMusicLegacy] General Exception: $e');
      return '{"status": false, "msg": "Unexpected error: $e"}';
    }
  }

  // New method with token expiration handling
  Future<ModelCatSubcatMusic> getCatSubCatMusicList(
    String token,
    BuildContext context,
  ) async {
    print('[DEBUG][getCatSubCatMusicList] Called');

    // If we're already fetching, just wait for the result
    if (_isFetchingCategories) {
      print('[DEBUG][getCatSubCatMusicList] Already fetching, waiting...');
      // Try to get from cache while waiting
      final cached = await getCachedMusicCategories();
      if (cached != null) {
        return cached;
      }

      // If no cache, wait for a bit and try again
      await Future.delayed(const Duration(milliseconds: 500));
      return getCatSubCatMusicList(token, context);
    }

    _isFetchingCategories = true;

    try {
      print('[DEBUG][getCatSubCatMusicList] Params: token=$token');
      print(
        '[DEBUG][getCatSubCatMusicList] Requesting: ${AppConstant.BaseUrl + AppConstant.API_GET_MUSIC_CATEGORIES}',
      );

      Response<String> response = await get<String>(
        AppConstant.BaseUrl + AppConstant.API_GET_MUSIC_CATEGORIES,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      print(
        '[DEBUG][getCatSubCatMusicList] Response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final responseData = response.data.toString();

        // Save to cache immediately
        await CacheManager.saveToCache(
          CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
          responseData,
        );

        final Map<String, dynamic> parsed = json.decode(responseData);
        print('[DEBUG][getCatSubCatMusicList] Parsed JSON successfully');

        // Log basic info without full response for better performance
        if (parsed.containsKey('data')) {
          print(
            '[DEBUG][getCatSubCatMusicList] Categories count: ${parsed['data'].length}',
          );
        }

        _isFetchingCategories = false;
        return ModelCatSubcatMusic.fromJson(parsed);
      } else {
        print(
          '[ERROR][getCatSubCatMusicList] Non-200 response: ${response.statusCode}',
        );
        _isFetchingCategories = false;
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Server returned ${response.statusCode}',
        );
      }
    } on DioException catch (dioError) {
      _isFetchingCategories = false;
      print('[ERROR][getCatSubCatMusicList] DioException: ${dioError.message}');
      print(
        '[ERROR][getCatSubCatMusicList] DioException type: ${dioError.type}',
      );

      // Check cache on error
      final cached = await getCachedMusicCategories();
      if (cached != null) {
        return cached;
      }

      // Handle different types of network errors
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
      print('[ERROR][getCatSubCatMusicList] General Exception: $error');

      // Check cache on error
      final cached = await getCachedMusicCategories();
      if (cached != null) {
        return cached;
      }

      throw Exception('An unexpected error occurred: $error');
    }
  }

  // Legacy method for backward compatibility (without token expiration handling)
  Future<ModelCatSubcatMusic> getCatSubCatMusicListLegacy(String token) async {
    print('[DEBUG][getCatSubCatMusicListLegacy] Called');

    // If we're already fetching, just wait for the result
    if (_isFetchingCategories) {
      print(
        '[DEBUG][getCatSubCatMusicListLegacy] Already fetching, waiting...',
      );
      // Try to get from cache while waiting
      final cached = await getCachedMusicCategories();
      if (cached != null) {
        return cached;
      }

      // If no cache, wait for a bit and try again
      await Future.delayed(const Duration(milliseconds: 500));
      return getCatSubCatMusicListLegacy(token);
    }

    _isFetchingCategories = true;

    try {
      print('[DEBUG][getCatSubCatMusicListLegacy] Params: token=$token');
      print(
        '[DEBUG][getCatSubCatMusicListLegacy] Requesting: ${AppConstant.BaseUrl + AppConstant.API_GET_MUSIC_CATEGORIES}',
      );

      Response<String> response = await dio.get(
        AppConstant.BaseUrl + AppConstant.API_GET_MUSIC_CATEGORIES,
        options: Options(headers: createAuthHeaders(token)),
      );

      print(
        '[DEBUG][getCatSubCatMusicListLegacy] Response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final responseData = response.data.toString();

        // Save to cache immediately
        await CacheManager.saveToCache(
          CacheManager.MUSIC_CATEGORIES_CACHE_KEY,
          responseData,
        );

        final Map<String, dynamic> parsed = json.decode(responseData);
        print('[DEBUG][getCatSubCatMusicListLegacy] Parsed JSON successfully');

        // Log basic info without full response for better performance
        if (parsed.containsKey('data')) {
          print(
            '[DEBUG][getCatSubCatMusicListLegacy] Categories count: ${parsed['data'].length}',
          );
        }

        _isFetchingCategories = false;
        return ModelCatSubcatMusic.fromJson(parsed);
      } else {
        print(
          '[ERROR][getCatSubCatMusicListLegacy] Non-200 response: ${response.statusCode}',
        );
        _isFetchingCategories = false;
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Server returned ${response.statusCode}',
        );
      }
    } on DioException catch (dioError) {
      _isFetchingCategories = false;
      print(
        '[ERROR][getCatSubCatMusicListLegacy] DioException: ${dioError.message}',
      );
      print(
        '[ERROR][getCatSubCatMusicListLegacy] DioException type: ${dioError.type}',
      );

      // Check cache on error
      final cached = await getCachedMusicCategories();
      if (cached != null) {
        return cached;
      }

      // Handle different types of network errors
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
      print('[ERROR][getCatSubCatMusicListLegacy] General Exception: $error');

      // Check cache on error
      final cached = await getCachedMusicCategories();
      if (cached != null) {
        return cached;
      }

      throw Exception('An unexpected error occurred: $error');
    }
  }

  // New method with token expiration handling
  Future<String> getMusicListBySearchNamePage(
    String search,
    String token,
    int pageNumber,
    int numberOfPostsPerRequest,
    BuildContext context,
  ) async {
    print('[DEBUG][getMusicListBySearchNamePage] Called');
    print(
      '[DEBUG][getMusicListBySearchNamePage] Params: search=$search, token=$token, pageNumber=$pageNumber, numberOfPostsPerRequest=$numberOfPostsPerRequest',
    );
    FormData formData = FormData.fromMap({
      AppConstant.search: search,
      "page": pageNumber,
      "limit": numberOfPostsPerRequest,
    });

    print(
      '[DEBUG][getMusicListBySearchNamePage] Requesting: ${AppConstant.BaseUrl + AppConstant.API_GET_SEARCH_MUSIC}',
    );
    print('[DEBUG][getMusicListBySearchNamePage] FormData: $formData');

    Response<String> response = await post<String>(
      AppConstant.BaseUrl + AppConstant.API_GET_SEARCH_MUSIC,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    print(
      '[DEBUG][getMusicListBySearchNamePage] Response status: ${response.statusCode}',
    );
    print(
      '[DEBUG][getMusicListBySearchNamePage] Response data: ${response.data}',
    );
    print('[DEBUG][getMusicListBySearchNamePage] Returning response as string');
    return response.toString();
  }

  // Legacy method for backward compatibility (without token expiration handling)
  Future<String> getMusicListBySearchNamePageLegacy(
    String search,
    String token,
    int pageNumber,
    int numberOfPostsPerRequest,
  ) async {
    print('[DEBUG][getMusicListBySearchNamePageLegacy] Called');
    print(
      '[DEBUG][getMusicListBySearchNamePageLegacy] Params: search=$search, token=$token, pageNumber=$pageNumber, numberOfPostsPerRequest=$numberOfPostsPerRequest',
    );
    FormData formData = FormData.fromMap({
      AppConstant.search: search,
      "page": pageNumber,
      "limit": numberOfPostsPerRequest,
    });

    print(
      '[DEBUG][getMusicListBySearchNamePageLegacy] Requesting: ${AppConstant.BaseUrl + AppConstant.API_GET_SEARCH_MUSIC}',
    );
    print('[DEBUG][getMusicListBySearchNamePageLegacy] FormData: $formData');

    Response<String> response;
    try {
      response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_GET_SEARCH_MUSIC,
        data: formData,
        options: Options(headers: createAuthHeaders(token)),
      );
    } on DioException catch (dioError) {
      // Ensure centralized token-expiration handling runs for legacy callers
      try {
        final handler = TokenExpirationHandler();
        await handler.checkAndHandleResponse(
          dioError.response,
          context: navigatorKey.currentContext,
        );
      } catch (_) {}

      // Return an error string instead of throwing so navigation isn't blocked
      return '{"status": false, "msg": "Network error: ${dioError.message}"}';
    }

    print(
      '[DEBUG][getMusicListBySearchNamePageLegacy] Response status: ${response.statusCode}',
    );
    print(
      '[DEBUG][getMusicListBySearchNamePageLegacy] Response data: ${response.data}',
    );
    print(
      '[DEBUG][getMusicListBySearchNamePageLegacy] Returning response as string',
    );
    return response.toString();
  }

  Future<ModelMusicList> getMusicListBySearchName(
    String search,
    String token, [
    BuildContext? context,
  ]) async {
    print('[DEBUG][getMusicListBySearchName] Called');
    print(
      '[DEBUG][getMusicListBySearchName] Params: search=$search, token=$token',
    );

    // Validate search input
    if (search.trim().isEmpty) {
      throw Exception('Search query cannot be empty');
    }

    FormData formData;
    formData = FormData.fromMap({AppConstant.search: search.trim()});

    print(
      '[DEBUG][getMusicListBySearchName] Requesting: ${AppConstant.BaseUrl + AppConstant.API_GET_SEARCH_MUSIC}',
    );
    print('[DEBUG][getMusicListBySearchName] FormData: $formData');

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

      print(
        '[DEBUG][getMusicListBySearchName] Response status: ${response.statusCode}',
      );
      print(
        '[DEBUG][getMusicListBySearchName] Response data: ${response.data}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        print('[DEBUG][getMusicListBySearchName] Parsed JSON: $parsed');

        // Check if the response indicates success
        if (parsed.containsKey('status') && parsed['status'] == false) {
          print('[DEBUG][getMusicListBySearchName] API returned false status');
          // Return empty result instead of throwing error
          return ModelMusicList.fromJson({
            'status': true,
            'data': [],
            'imagePath': '',
            'audioPath': '',
            'msg': 'No results found',
          });
        }

        return ModelMusicList.fromJson(parsed);
      } else {
        throw Exception('Invalid response from server');
      }
    } on DioException catch (dioError) {
      print(
        '[ERROR][getMusicListBySearchName] DioException: ${dioError.message}',
      );
      print(
        '[ERROR][getMusicListBySearchName] DioException type: ${dioError.type}',
      );

      // Try centralized token-expiration handling first. If the token is expired
      // this will show the dialog and perform auto-logout (using navigatorKey
      // fallback when [context] is null). If handled, return an empty result so
      // UI navigation doesn't hang.
      try {
        final handler = TokenExpirationHandler();
        final handled = await handler.checkAndHandleResponse(
          dioError.response,
          context: context ?? navigatorKey.currentContext,
        );
        if (handled) {
          // Return an empty successful payload so callers can continue safely.
          return ModelMusicList.fromJson({
            'status': true,
            'data': [],
            'imagePath': '',
            'audioPath': '',
            'msg': 'Session expired',
          });
        }
      } catch (e) {
        // swallow - we'll fall back to regular error handling below
      }

      // Handle different types of network errors if not token-related
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
            // If we reach here and it's 401, attempt best-effort handler and
            // then return empty list to avoid UI hang.
            try {
              await TokenExpirationHandler().checkAndHandleResponse(
                dioError.response,
                context: context ?? navigatorKey.currentContext,
              );
            } catch (_) {}

            return ModelMusicList.fromJson({
              'status': true,
              'data': [],
              'imagePath': '',
              'audioPath': '',
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
      print('[ERROR][getMusicListBySearchName] General Exception: $error');
      throw Exception('An unexpected error occurred during search: $error');
    }
  }

  Future<ModelMusicList> getMusicListByCategory(
    String id,
    String type,
    String token, [
    BuildContext? context,
  ]) async {
    print('[DEBUG][getMusicListByCategory] Called');
    print(
      '[DEBUG][getMusicListByCategory] Params: id=$id, type=$type, token=$token',
    );
    FormData formData;
    formData = FormData.fromMap({AppConstant.type: type, AppConstant.id: id});

    print(
      '[DEBUG][getMusicListByCategory] Requesting: ${AppConstant.BaseUrl + AppConstant.API_GET_MUSIC_BY_CATEGORY}',
    );
    print('[DEBUG][getMusicListByCategory] FormData: $formData');
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
      } on DioException catch (dioError) {
        // Run centralized handler (dialog + auto-logout) if needed
        try {
          final handler = TokenExpirationHandler();
          await handler.checkAndHandleResponse(
            dioError.response,
            context: navigatorKey.currentContext,
          );
        } catch (_) {}

        // Return an empty list ModelMusicList so navigation doesn't hang
        return ModelMusicList.fromJson({
          'status': true,
          'data': [],
          'imagePath': '',
          'audioPath': '',
          'msg': 'Unauthorized',
        });
      }
    }
    print(
      '[DEBUG][getMusicListByCategory] Response status: ${response.statusCode}',
    );
    print('[DEBUG][getMusicListByCategory] Response data: ${response.data}');

    try {
      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        print('[DEBUG][getMusicListByCategory] Parsed JSON: $parsed');

        if (parsed['status'].toString().contains('false')) {
          print(
            '[DEBUG][getMusicListByCategory] status is false, msg: ${parsed['msg']}',
          );
          Fluttertoast.showToast(
            msg: parsed['msg'],
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 1,
            backgroundColor: appColors().black,
            textColor: appColors().colorBackground,
            fontSize: 14.0,
          );
        }
        return ModelMusicList.fromJson(parsed);
      } else {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        print('[DEBUG][getMusicListByCategory] Parsed JSON (non-200): $parsed');
        return ModelMusicList.fromJson(parsed);
      }
    } catch (error) {
      print('[ERROR][getMusicListByCategory] Exception: $error');
      throw UnimplementedError();
    }
  }
}
