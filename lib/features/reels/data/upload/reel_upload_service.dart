import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

import 'package:jainverse/utils/AppConstant.dart';

typedef ProgressCallback = void Function(int sent, int total);

/// Result returned by [ReelUploadService.uploadVideoComplete].
class BunnyUploadResult {
  /// Public CDN URL for the video (.mp4).
  final String videoUrl;

  /// Public CDN URL for the thumbnail (.jpg). Empty string if upload failed.
  final String thumbnailUrl;

  /// Duration formatted as "MM:SS".
  final String duration;

  /// File size of the uploaded (compressed) video in MB, e.g. "12.4".
  final String videoSize;

  const BunnyUploadResult({
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.videoSize,
  });
}

/// Upload service for reel (short-form vertical video) files.
///
/// Handles the full pipeline:
///   1. Validate the source file (size + extension).
///   2. Compress via [VideoCompress].
///   3. PUT compressed video directly to Bunny Storage.
///   4. Generate thumbnail and PUT to Bunny Storage (non-fatal).
///   5. Return a [BunnyUploadResult] with CDN URLs + metadata.
///
/// Bunny upload uses raw streaming (no multipart) with a 3-attempt retry.
class ReelUploadService {
  static const int _maxVideoBytes = 100 * 1024 * 1024; // 100 MB
  static const List<String> _allowedExtensions = ['mp4', 'mov', 'm4v', '3gp'];

  final Dio _dio;

  ReelUploadService()
      : _dio = Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    // sendTimeout is set per-attempt inside _bunnyPutWithRetry.
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Full pipeline: validate → compress → upload video → upload thumbnail.
  ///
  /// [fileName] is the base name without extension, e.g. "reel_1713000000000".
  /// [trimStartSec] / [trimDurationSec] clip the video before compression (seconds).
  /// [customThumbnailFile] overrides auto-generated thumbnail when provided.
  /// Throws on validation or video upload failure.
  /// Thumbnail generation/upload failure is non-fatal.
  Future<BunnyUploadResult> uploadVideoComplete({
    required File file,
    required String fileName,
    VideoQuality quality = VideoQuality.MediumQuality,
    int? trimStartSec,
    int? trimDurationSec,
    File? customThumbnailFile,
    ProgressCallback? onProgress,
  }) async {
    // 1. Validate raw file.
    await _validateVideoFile(file);

    // 2. Compress (with optional trim; fall back to raw file on failure).
    File uploadFile = file;
    try {
      uploadFile = await _compressVideo(
        file,
        quality: quality,
        startTimeSec: trimStartSec,
        durationSec: trimDurationSec,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ReelUploadService: compression failed, using raw: $e');
      }
    }

    // 3. Re-validate compressed size.
    final compressedSize = await uploadFile.length();
    if (compressedSize > _maxVideoBytes) {
      if (uploadFile.path != file.path) {
        try { uploadFile.deleteSync(); } catch (_) {}
      }
      throw Exception('Compressed video still exceeds 100 MB limit.');
    }

    // 4. Compute file size.
    final videoSizeMb = (compressedSize / (1024 * 1024)).toStringAsFixed(1);

    // 5. Build deterministic CDN URLs before uploading (no round-trip needed).
    final videoStorageUrl =
        '${AppConstant.BunnyStorageBase}'
        '${AppConstant.BunnyShortVideoPath}$fileName.mp4';
    final videoCdnUrl =
        '${AppConstant.BunnyCdnBase}'
        '${AppConstant.BunnyShortVideoPath}$fileName.mp4';
    final thumbStorageUrl =
        '${AppConstant.BunnyStorageBase}'
        '${AppConstant.BunnyThumbnailPath}$fileName.jpg';
    final thumbCdnUrl =
        '${AppConstant.BunnyCdnBase}'
        '${AppConstant.BunnyThumbnailPath}$fileName.jpg';

    // 6. Kick off local operations (media info + thumbnail) in parallel with
    //    the video upload so they don't add serial latency.
    final metaFuture = VideoCompress.getMediaInfo(uploadFile.path)
        .then((info) => _formatDuration(((info.duration ?? 0) / 1000).round()))
        .catchError((_) => '');
    final thumbBytesFuture = customThumbnailFile != null
        ? FlutterImageCompress.compressWithFile(
            customThumbnailFile.absolute.path,
            quality: 85,
            format: CompressFormat.jpeg,
          )
        : VideoCompress.getByteThumbnail(
            uploadFile.path,
            quality: 75,
            position: -1,
          ).then<Uint8List?>((b) => b).catchError((_) => null);

    await _bunnyPutWithRetry(
      file: uploadFile,
      storageUrl: videoStorageUrl,
      contentType: 'application/octet-stream',
      onProgress: onProgress,
    );

    // 7. Collect parallel results (both should be done by now).
    final duration = await metaFuture;
    final thumbBytes = await thumbBytesFuture;

    // 8. Upload thumbnail — non-fatal.
    String thumbnailCdnUrl = '';
    try {
      if (thumbBytes != null) {
        final thumbFile = await _writeTempFile(thumbBytes, '$fileName.jpg');
        await _bunnyPutWithRetry(
          file: thumbFile,
          storageUrl: thumbStorageUrl,
          contentType: 'image/jpeg',
        );
        thumbnailCdnUrl = thumbCdnUrl;
        try { thumbFile.deleteSync(); } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ReelUploadService: thumbnail upload failed (non-fatal): $e');
      }
    }

    // 9. Clean up compressed temp file.
    if (uploadFile.path != file.path) {
      try { uploadFile.deleteSync(); } catch (_) {}
    }

    return BunnyUploadResult(
      videoUrl: videoCdnUrl,
      thumbnailUrl: thumbnailCdnUrl,
      duration: duration,
      videoSize: videoSizeMb,
    );
  }

  // ---------------------------------------------------------------------------
  // Bunny PUT with retry
  // ---------------------------------------------------------------------------

  /// Sends [file] as a raw octet-stream to [storageUrl] via HTTP PUT.
  ///
  /// Uses `file.openRead()` (streaming) with a manual `Content-Length` header
  /// so that Dio's [onSendProgress] callback fires correctly for large files.
  ///
  /// Retries up to 3 times with 2 s / 4 s exponential backoff.
  /// Bunny Storage returns **201 Created** on success.
  Future<void> _bunnyPutWithRetry({
    required File file,
    required String storageUrl,
    required String contentType,
    ProgressCallback? onProgress,
  }) async {
    Exception? lastError;
    final fileSize = await file.length();

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final resp = await _dio.put<dynamic>(
          storageUrl,
          data: file.openRead(), // Stream<List<int>> — no full-memory load
          options: Options(
            headers: {
              'AccessKey': AppConstant.BunnyStorageApiKey,
              'Content-Type': contentType,
              'Content-Length': fileSize.toString(),
            },
            contentType: contentType,
            sendTimeout: Duration(minutes: 5 + (attempt - 1) * 2),
            receiveTimeout: const Duration(seconds: 30),
          ),
          onSendProgress: (sent, total) =>
              onProgress?.call(sent, total > 0 ? total : fileSize),
        );

        if (resp.statusCode == 201 || resp.statusCode == 200) return;
        // Non-2xx response — treat like a network error so the retry loop fires.
        throw Exception('Bunny PUT returned unexpected status ${resp.statusCode}');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (kDebugMode) {
          debugPrint('ReelUploadService._bunnyPutWithRetry attempt $attempt: $e');
        }
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2)); // 2 s, 4 s
        }
      }
    }
    throw lastError ?? Exception('Bunny upload failed after 3 attempts');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _validateVideoFile(File file) async {
    if (!await file.exists()) throw Exception('File does not exist');
    final size = await file.length();
    if (size == 0) throw Exception('File is empty');
    if (size > _maxVideoBytes) {
      throw Exception(
        'Video too large (${_formatSize(size)}). Maximum: ${_formatSize(_maxVideoBytes)}',
      );
    }
    final ext = file.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(ext)) {
      throw Exception(
        'Unsupported video format ".$ext". Allowed: ${_allowedExtensions.join(', ')}',
      );
    }
  }

  Future<File> _compressVideo(
    File file, {
    VideoQuality quality = VideoQuality.MediumQuality,
    int? startTimeSec,
    int? durationSec,
  }) async {
    if (kDebugMode) debugPrint('ReelUploadService: compressing video...');
    final info = await VideoCompress.compressVideo(
      file.path,
      quality: quality,
      deleteOrigin: false,
      includeAudio: true,
      frameRate: 30,
      startTime: startTimeSec,
      duration: durationSec,
    );
    if (info == null || info.file == null) {
      throw Exception('Video compression returned null result');
    }
    if (kDebugMode) {
      debugPrint(
        'ReelUploadService: compressed '
        '${_formatSize(await file.length())} → '
        '${_formatSize(await info.file!.length())}',
      );
    }
    return info.file!;
  }

  Future<File> _writeTempFile(Uint8List bytes, String name) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes);
    return f;
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
