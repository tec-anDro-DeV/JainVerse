import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Helper service for caching video files.
class VideoCacheService {
  final BaseCacheManager _cacheManager;
  final Dio _dio;

  /// Default maximum cache size allowed for a single file (1000 MB)
  final int maxCacheSizeBytes;

  VideoCacheService({
    BaseCacheManager? cacheManager,
    Dio? dio,
    this.maxCacheSizeBytes = 1000 * 1024 * 1024,
  }) : _cacheManager = cacheManager ?? DefaultCacheManager(),
       _dio = dio ?? Dio();

  /// Returns cached [File] if available, otherwise null.
  Future<File?> getCachedFile(String url) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo != null && await fileInfo.file.exists())
        return fileInfo.file;
      return null;
    } catch (e) {
      if (kDebugMode) print('VideoCacheService.getCachedFile error: $e');
      return null;
    }
  }

  /// Starts background caching of the URL and returns the downloaded file when done.
  /// The returned [Future] completes once the file is downloaded (or fails).
  Future<File> cacheFile(String url) async {
    return _cacheManager.getSingleFile(url);
  }

  /// Checks Content-Length via a HEAD request to decide whether to cache.
  /// Returns true if the file size is known and <= [maxCacheSizeBytes].
  Future<bool> shouldCache(String url) async {
    try {
      final resp = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s! < 500,
        ),
      );
      if (resp.statusCode == 200 || resp.statusCode == 206) {
        final lenStr = resp.headers.value('content-length');
        if (lenStr != null) {
          final len = int.tryParse(lenStr);
          if (len != null) return len <= maxCacheSizeBytes;
        }
      }
    } catch (e) {
      if (kDebugMode) print('VideoCacheService.shouldCache error: $e');
    }
    // If we can't determine size, be conservative and do NOT cache
    return false;
  }

  /// Convenience to check whether file is already cached.
  Future<bool> isFileCached(String url) async {
    final f = await getCachedFile(url);
    return f != null;
  }

  /// Remove a specific cached file by URL
  /// Useful when a cached file is suspected to be corrupted
  Future<bool> removeCachedFile(String url) async {
    try {
      await _cacheManager.removeFile(url);
      if (kDebugMode) {
        print('VideoCacheService: Removed cached file for $url');
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('VideoCacheService.removeCachedFile error: $e');
      return false;
    }
  }

  /// Clear all cached video files
  /// Use with caution - will clear entire cache
  Future<void> clearAllCache() async {
    try {
      await _cacheManager.emptyCache();
      if (kDebugMode) {
        print('VideoCacheService: Cleared all cached files');
      }
    } catch (e) {
      if (kDebugMode) print('VideoCacheService.clearAllCache error: $e');
    }
  }
}
