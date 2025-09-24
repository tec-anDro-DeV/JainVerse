import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/services/token_expiration_handler.dart';

/// Base class for all presenters that provides automatic token expiration handling
abstract class BasePresenter {
  final Dio _dio = Dio();
  final TokenExpirationHandler _tokenHandler = TokenExpirationHandler();

  BasePresenter() {
    // Configure timeout settings
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  /// Get the configured Dio instance
  Dio get dio => _dio;

  /// Make a GET request with automatic token expiration handling
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    required BuildContext context,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

      // Check for token expiration
      await _tokenHandler.checkAndHandleResponse(response, context: context);

      return response;
    } on DioException catch (e) {
      // Check if the error response indicates token expiration
      await _tokenHandler.checkAndHandleResponse(e.response, context: context);
      rethrow;
    }
  }

  /// Make a POST request with automatic token expiration handling
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required BuildContext context,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      // Check for token expiration
      await _tokenHandler.checkAndHandleResponse(response, context: context);

      return response;
    } on DioException catch (e) {
      // Check if the error response indicates token expiration
      await _tokenHandler.checkAndHandleResponse(e.response, context: context);
      rethrow;
    }
  }

  /// Make a PUT request with automatic token expiration handling
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    required BuildContext context,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

      // Check for token expiration
      await _tokenHandler.checkAndHandleResponse(response, context: context);

      return response;
    } on DioException catch (e) {
      // Check if the error response indicates token expiration
      await _tokenHandler.checkAndHandleResponse(e.response, context: context);
      rethrow;
    }
  }

  /// Make a DELETE request with automatic token expiration handling
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required BuildContext context,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      // Check for token expiration
      await _tokenHandler.checkAndHandleResponse(response, context: context);

      return response;
    } on DioException catch (e) {
      // Check if the error response indicates token expiration
      await _tokenHandler.checkAndHandleResponse(e.response, context: context);
      rethrow;
    }
  }

  /// Helper method to create authorization headers
  Map<String, String> createAuthHeaders(String token) {
    return {"Accept": "application/json", "authorization": "Bearer $token"};
  }

  /// Helper method to create JSON headers with authorization
  Map<String, String> createJsonAuthHeaders(String token) {
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "authorization": "Bearer $token",
    };
  }
}
