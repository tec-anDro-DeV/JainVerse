import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:jainverse/models/downloaded_music.dart';
import 'package:path_provider/path_provider.dart';

/// Service for handling file downloads and local storage operations
class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final Map<String, CancelToken> _activeDownloads = {};
  final Map<String, double> _downloadProgress = {};

  /// Initialize the download service
  Future<void> initialize() async {
    // Configure Dio timeout settings
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(minutes: 5);
    _dio.options.sendTimeout = const Duration(seconds: 30);

    developer.log('DownloadService initialized', name: 'DownloadService');
  }

  /// Get the app's documents directory for storing downloads
  Future<Directory> get _documentsDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${directory.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// Get the downloads directory for audio files
  Future<Directory> get _audioDirectory async {
    final downloadsDir = await _documentsDirectory;
    final audioDir = Directory('${downloadsDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Get the downloads directory for image files
  Future<Directory> get _imageDirectory async {
    final downloadsDir = await _documentsDirectory;
    final imageDir = Directory('${downloadsDir.path}/images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir;
  }

  /// Download an audio file and return the local path
  Future<String?> downloadAudioFile({
    required String url,
    required String fileName,
    required String trackId,
    Function(double)? onProgress,
    Function(String)? onError,
  }) async {
    try {
      developer.log(
        'Starting audio download for track: $trackId',
        name: 'DownloadService',
      );

      if (url.isEmpty) {
        onError?.call('Audio URL is empty');
        return null;
      }

      final audioDir = await _audioDirectory;
      final filePath = '${audioDir.path}/$fileName';

      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        developer.log(
          'Audio file already exists: $filePath',
          name: 'DownloadService',
        );
        return filePath;
      }

      // Create cancel token for this download
      final cancelToken = CancelToken();
      _activeDownloads[trackId] = cancelToken;

      await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _downloadProgress[trackId] = progress;
            onProgress?.call(progress);
          }
        },
      );

      // Clean up progress tracking
      _downloadProgress.remove(trackId);
      _activeDownloads.remove(trackId);

      developer.log(
        'Audio download completed: $filePath',
        name: 'DownloadService',
      );
      return filePath;
    } catch (e) {
      developer.log(
        'Audio download failed for track $trackId: $e',
        name: 'DownloadService',
      );
      _downloadProgress.remove(trackId);
      _activeDownloads.remove(trackId);
      onError?.call(e.toString());
      return null;
    }
  }

  /// Download an image file and return the local path
  Future<String?> downloadImageFile({
    required String url,
    required String fileName,
    required String trackId,
    Function(String)? onError,
  }) async {
    try {
      if (url.isEmpty) {
        onError?.call('Image URL is empty');
        return null;
      }

      final imageDir = await _imageDirectory;
      final filePath = '${imageDir.path}/$fileName';

      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        developer.log(
          'Image file already exists: $filePath',
          name: 'DownloadService',
        );
        return filePath;
      }

      await _dio.download(url, filePath);
      developer.log(
        'Image download completed: $filePath',
        name: 'DownloadService',
      );
      return filePath;
    } catch (e) {
      developer.log(
        'Image download failed for track $trackId: $e',
        name: 'DownloadService',
      );
      onError?.call(e.toString());
      return null;
    }
  }

  /// Delete downloaded files for a track
  Future<bool> deleteDownloadedFiles(DownloadedMusic downloadedMusic) async {
    try {
      bool success = true;

      // Delete audio file
      if (downloadedMusic.localAudioPath.isNotEmpty) {
        final audioFile = File(downloadedMusic.localAudioPath);
        if (await audioFile.exists()) {
          await audioFile.delete();
          developer.log(
            'Deleted audio file: ${downloadedMusic.localAudioPath}',
            name: 'DownloadService',
          );
        }
      }

      // Delete image file
      if (downloadedMusic.localImagePath.isNotEmpty) {
        final imageFile = File(downloadedMusic.localImagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
          developer.log(
            'Deleted image file: ${downloadedMusic.localImagePath}',
            name: 'DownloadService',
          );
        }
      }

      return success;
    } catch (e) {
      developer.log(
        'Failed to delete files for track ${downloadedMusic.id}: $e',
        name: 'DownloadService',
      );
      return false;
    }
  }

  /// Check if a file exists at the given path
  Future<bool> fileExists(String path) async {
    if (path.isEmpty) return false;
    final file = File(path);
    return await file.exists();
  }

  /// Cancel an active download
  void cancelDownload(String trackId) {
    final cancelToken = _activeDownloads[trackId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Download cancelled by user');
      _activeDownloads.remove(trackId);
      _downloadProgress.remove(trackId);
      developer.log(
        'Download cancelled for track: $trackId',
        name: 'DownloadService',
      );
    }
  }

  /// Get download progress for a track
  double getDownloadProgress(String trackId) {
    return _downloadProgress[trackId] ?? 0.0;
  }

  /// Check if a track is currently downloading
  bool isDownloading(String trackId) {
    return _activeDownloads.containsKey(trackId);
  }

  /// Generate a safe filename from a string
  String generateSafeFileName(String input) {
    // Remove special characters and replace spaces with underscores
    return input
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  /// Get download storage statistics
  Future<Map<String, int>> getStorageStats() async {
    try {
      final audioDir = await _audioDirectory;
      final imageDir = await _imageDirectory;

      int totalFiles = 0;
      int totalSize = 0;

      // Count audio files
      if (await audioDir.exists()) {
        final audioFiles = audioDir.listSync();
        for (final file in audioFiles) {
          if (file is File) {
            totalFiles++;
            totalSize += await file.length();
          }
        }
      }

      // Count image files
      if (await imageDir.exists()) {
        final imageFiles = imageDir.listSync();
        for (final file in imageFiles) {
          if (file is File) {
            totalFiles++;
            totalSize += await file.length();
          }
        }
      }

      return {'totalFiles': totalFiles, 'totalSizeBytes': totalSize};
    } catch (e) {
      developer.log('Failed to get storage stats: $e', name: 'DownloadService');
      return {'totalFiles': 0, 'totalSizeBytes': 0};
    }
  }

  /// Clean up orphaned files (files that don't have corresponding metadata)
  Future<void> cleanupOrphanedFiles(
    List<DownloadedMusic> validDownloads,
  ) async {
    try {
      final validAudioPaths =
          validDownloads.map((d) => d.localAudioPath).toSet();
      final validImagePaths =
          validDownloads.map((d) => d.localImagePath).toSet();

      // Clean audio directory
      final audioDir = await _audioDirectory;
      if (await audioDir.exists()) {
        final audioFiles = audioDir.listSync();
        for (final file in audioFiles) {
          if (file is File && !validAudioPaths.contains(file.path)) {
            await file.delete();
            developer.log(
              'Deleted orphaned audio file: ${file.path}',
              name: 'DownloadService',
            );
          }
        }
      }

      // Clean image directory
      final imageDir = await _imageDirectory;
      if (await imageDir.exists()) {
        final imageFiles = imageDir.listSync();
        for (final file in imageFiles) {
          if (file is File && !validImagePaths.contains(file.path)) {
            await file.delete();
            developer.log(
              'Deleted orphaned image file: ${file.path}',
              name: 'DownloadService',
            );
          }
        }
      }
    } catch (e) {
      developer.log(
        'Failed to cleanup orphaned files: $e',
        name: 'DownloadService',
      );
    }
  }
}
