import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:jainverse/utils/AppConstant.dart';

typedef ProgressCallback = void Function(int sent, int total);

/// Custom HTTP client that supports progress tracking for uploads
class _ProgressTrackingHttpClient extends http.BaseClient {
  final http.Client _inner;
  final ProgressCallback? onProgress;
  final int totalBytes;

  _ProgressTrackingHttpClient(this._inner, this.totalBytes, this.onProgress);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request && onProgress != null) {
      // For progress tracking, we'll simulate progress during the send
      onProgress?.call(0, totalBytes);

      final response = await _inner.send(request);

      // Simulate progress completion when response starts
      onProgress?.call(totalBytes, totalBytes);

      return response;
    }
    return _inner.send(request);
  }
}

/// Clean and simple file upload service for DigitalOcean Spaces
class FileUploadService {
  final Dio _dio = Dio();
  static const int _maxFileSize = 10 * 1024 * 1024; // 10MB max

  FileUploadService() {
    _initializeDio();
  }

  void _initializeDio() {
    // Configure Dio with reasonable timeouts
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(minutes: 2);
    _dio.options.sendTimeout = const Duration(minutes: 2);

    // Add logging for debugging
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: false, // Don't log file data
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (object) => print('🌐 $object'),
      ),
    );
  }

  /// Step 1: Get pre-signed URL from backend
  Future<Map<String, dynamic>> getPresignedUrl(
    String fileName,
    String authToken,
  ) async {
    try {
      final url = AppConstant.BaseUrl + AppConstant.API_BUCKET_UPLOAD_URL;

      // Log request details (mask Authorization)
      final maskedAuth = authToken.length > 10
          ? '${authToken.substring(0, 6)}...${authToken.substring(authToken.length - 4)}'
          : '***';
      print('🚀 Requesting pre-signed URL for: $fileName');
      print('➡️ HTTP POST $url');
      print(
        '📋 Request headers: {Content-Type: application/x-www-form-urlencoded, Authorization: Bearer $maskedAuth}',
      );

      final response = await _dio.post(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Bearer $authToken',
          },
        ),
        data: {
          'filename': fileName,
          'content_type':
              lookupMimeType(fileName) ?? 'application/octet-stream',
        },
      );

      // Log response summary
      print('✅ Pre-signed URL response: ${response.statusCode}');
      try {
        print('📥 Response headers: ${response.headers.map}');
      } catch (_) {}

      if (response.statusCode == 200) {
        // Response should contain: presigned_url, public_url, headers
        return response.data;
      } else {
        throw Exception(
          'Failed to get pre-signed URL: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      print('❌ Error getting pre-signed URL: ${e.message}');
      throw Exception('Network error: ${e.message}');
    }
  }

  /// Step 2: Upload file to pre-signed URL using http package
  Future<void> uploadFile(
    File file,
    String presignedUrl,
    Map<String, String> headers, {
    ProgressCallback? onProgress,
  }) async {
    try {
      final fileName = basename(file.path);
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // Log upload request details. Mask sensitive header values like Authorization or x-amz-security-token
      final maskedHeaders = headers.map((k, v) {
        final lower = k.toLowerCase();
        if (lower.contains('authorization') ||
            lower.contains('x-amz-security-token') ||
            lower.contains('x-amz-signature')) {
          final mask = v.length > 10
              ? '${v.substring(0, 6)}...${v.substring(v.length - 4)}'
              : '***';
          return MapEntry(k, mask);
        }
        return MapEntry(k, v);
      });

      print('📤 Uploading file: $fileName');
      print(
        '🎭 MIME type detected: $mimeType (not sent in headers to avoid signature mismatch)',
      );
      print('➡️ HTTP PUT ${_shortenUrlForLog(presignedUrl)}');
      print('📋 Upload headers: $maskedHeaders');

      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;

      // Use http package instead of Dio to avoid Uint8List content-type issues
      final request = http.Request('PUT', Uri.parse(presignedUrl));

      // Add only the headers provided by the pre-signed URL response
      // Do NOT add Content-Type or any other headers to avoid SignatureDoesNotMatch
      request.headers.addAll(headers);
      request.bodyBytes = bytes;

      // Use custom client for progress tracking
      final client = _ProgressTrackingHttpClient(
        http.Client(),
        fileSize,
        onProgress,
      );
      late http.Response response;
      try {
        final streamedResponse = await client.send(request);
        response = await http.Response.fromStream(streamedResponse);
      } finally {
        client.close();
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ File uploaded successfully! Status: ${response.statusCode}');
        print('📥 Upload response headers: ${response.headers}');
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Upload failed: $e');
      if (e is http.ClientException) {
        print('� Client error: ${e.message}');
      }
      throw Exception('Upload failed: $e');
    }
  }

  /// Upload file with retry-specific configuration using http package
  Future<void> uploadFileWithRetry(
    File file,
    String presignedUrl,
    Map<String, String> headers,
    int attempt, {
    ProgressCallback? onProgress,
  }) async {
    // Adjust timeout based on attempt number
    final timeoutMinutes =
        2 + (attempt - 1); // 2, 3, 4 minutes for attempts 1, 2, 3
    final timeout = Duration(minutes: timeoutMinutes);

    try {
      final fileName = basename(file.path);
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      final maskedHeaders = headers.map((k, v) {
        final lower = k.toLowerCase();
        if (lower.contains('authorization') ||
            lower.contains('x-amz-security-token') ||
            lower.contains('x-amz-signature')) {
          final mask = v.length > 10
              ? '${v.substring(0, 6)}...${v.substring(v.length - 4)}'
              : '***';
          return MapEntry(k, mask);
        }
        return MapEntry(k, v);
      });

      print('📤 Uploading file (attempt $attempt): $fileName');
      print(
        '🎭 MIME type detected: $mimeType (not sent in headers to avoid signature mismatch)',
      );
      print('⏱️ Timeout: ${timeoutMinutes} minutes');
      print('➡️ HTTP PUT ${_shortenUrlForLog(presignedUrl)}');
      print('📋 Upload headers (attempt $attempt): $maskedHeaders');

      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;

      // Use http package instead of Dio to avoid Uint8List content-type issues
      final request = http.Request('PUT', Uri.parse(presignedUrl));

      // Add only the headers provided by the pre-signed URL response
      // Do NOT add Content-Type or any other headers to avoid SignatureDoesNotMatch
      request.headers.addAll(headers);
      request.bodyBytes = bytes;

      // Use custom client for progress tracking with timeout
      final client = _ProgressTrackingHttpClient(
        http.Client(),
        fileSize,
        onProgress,
      );
      late http.Response response;
      try {
        final streamedResponse = await client.send(request).timeout(timeout);
        response = await http.Response.fromStream(streamedResponse);
      } finally {
        client.close();
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        print(
          '✅ File uploaded successfully on attempt $attempt! Status: ${response.statusCode}',
        );
        print(
          '📥 Upload response headers (attempt $attempt): ${response.headers}',
        );
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Upload attempt $attempt failed: $e');
      if (e is http.ClientException) {
        print('🔍 Client error type: ${e.message}');
      } else if (e.toString().contains('TimeoutException')) {
        print('� Error type: Timeout');
      }
      throw Exception('Upload failed: $e');
    }
  }

  // Helper to shorten long URLs for logs while keeping query params masked
  String _shortenUrlForLog(String url, {int keep = 120}) {
    if (url.length <= keep) return url;
    // attempt to mask querystring values
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.isEmpty) return url.substring(0, keep) + '...';
      final maskedParts = uri.queryParameters.entries.map((e) {
        final v = e.value;
        if (v.length > 10) {
          return '${e.key}=${v.substring(0, 6)}...${v.substring(v.length - 4)}';
        }
        return '${e.key}=***';
      }).toList();
      final maskedQuery = maskedParts.join('&');
      final base = '${uri.scheme}://${uri.host}${uri.path}';
      return '$base?$maskedQuery';
    } catch (_) {
      return url.substring(0, keep) + '...';
    }
  }

  /// Complete upload process with retry logic
  Future<String> uploadFileComplete({
    required File file,
    required String filename,
    required String token,
    String? contentType, // Optional - will be auto-detected if not provided
    int maxRetries = 3, // For compatibility
    ProgressCallback? onProgress,
  }) async {
    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔄 Upload attempt $attempt/$maxRetries');

        // Validate file
        await _validateFile(file);

        // Step 1: Get pre-signed URL
        final presignedData = await getPresignedUrl(filename, token);

        // The API returns 'upload_url' and 'public_url'
        final presignedUrl = presignedData['upload_url'] as String?;
        final publicUrl = presignedData['public_url'] as String?;
        final uploadHeaders = presignedData['headers'] ?? <String, dynamic>{};

        if (presignedUrl == null || presignedUrl.isEmpty) {
          throw Exception('No upload URL received from server');
        }

        if (publicUrl == null || publicUrl.isEmpty) {
          throw Exception('No public URL received from server');
        }

        // Convert headers to Map<String, String>
        final headers = <String, String>{};
        uploadHeaders.forEach((key, value) {
          headers[key.toString()] = value.toString();
        });

        print('🔗 Pre-signed URL: ${presignedUrl.substring(0, 80)}...');
        print('🌐 Public URL: $publicUrl');
        print('📋 Upload headers: ${headers.keys.join(', ')}');

        // Step 2: Upload the file with retry-specific timeout
        await uploadFileWithRetry(
          file,
          presignedUrl,
          headers,
          attempt,
          onProgress: onProgress,
        );

        print(
          '🎊 Upload completed successfully on attempt $attempt! Public URL: $publicUrl',
        );
        return publicUrl;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('💥 Upload attempt $attempt failed: $e');

        // Check if this is a recoverable network error
        if (_isNetworkError(e) && attempt < maxRetries) {
          final delay = Duration(seconds: attempt * 2); // Progressive delay
          print('⏳ Waiting ${delay.inSeconds}s before retry...');
          await Future.delayed(delay);
          continue;
        } else if (attempt < maxRetries) {
          // Non-network error, but still have retries left
          await Future.delayed(Duration(seconds: 1));
          continue;
        } else {
          // No more retries or non-recoverable error
          break;
        }
      }
    }

    print('💔 All upload attempts failed');
    throw lastError ?? Exception('Upload failed after $maxRetries attempts');
  }

  /// Check if error is a recoverable network error
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('broken pipe') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection timed out') ||
        errorString.contains('socketexception') ||
        errorString.contains('network unreachable') ||
        errorString.contains('connection refused') ||
        errorString.contains('timeoutexception') ||
        errorString.contains('clientexception') ||
        errorString.contains('handshake') ||
        errorString.contains('connection closed');
  }

  /// Validate file before upload
  Future<void> _validateFile(File file) async {
    if (!await file.exists()) {
      throw Exception('File does not exist');
    }

    final fileSize = await file.length();
    if (fileSize > _maxFileSize) {
      throw Exception(
        'File too large. Maximum size: ${formatFileSize(_maxFileSize)}',
      );
    }

    if (fileSize == 0) {
      throw Exception('File is empty');
    }

    final filename = basename(file.path);
    if (!isAllowedFileType(filename)) {
      throw Exception('File type not allowed: ${getFileExtension(filename)}');
    }
  }

  // Utility methods
  String getMimeType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  bool isAllowedFileType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    const allowedExtensions = [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'pdf',
      'doc',
      'docx',
      'txt',
    ];
    return allowedExtensions.contains(extension);
  }

  String getFileExtension(String filename) {
    return filename.toLowerCase().split('.').last;
  }

  String getFileTypeDescription(String filename) {
    final extension = getFileExtension(filename);
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return 'Image';
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'txt':
        return 'Text File';
      default:
        return 'Unknown';
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Cleanup resources
  void dispose() {
    _dio.close();
  }
}
