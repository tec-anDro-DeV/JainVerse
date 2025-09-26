import 'dart:developer' as developer;

import 'package:jainverse/utils/AppConstant.dart';

/// Service to normalize and validate image URLs consistently across the app
/// This fixes the issue where images don't load during queue navigation
class ImageUrlNormalizer {
  static final ImageUrlNormalizer _instance = ImageUrlNormalizer._internal();
  factory ImageUrlNormalizer() => _instance;
  ImageUrlNormalizer._internal();

  static const String _baseServerUrl = '${AppConstant.SiteUrl}public/';
  static const String _defaultImagePath = 'images/audio/thumb/';
  static const String _fallbackImageUrl =
      ''; // Empty string to prevent network errors

  /// Normalize image URL to ensure consistent format across all MediaItems
  /// This is the main fix for the image loading issue during queue navigation
  static String normalizeImageUrl({
    required String? imageFileName,
    required String? pathImage,
    String? fallbackUrl,
  }) {
    try {
      // Handle null or empty image
      if (imageFileName == null || imageFileName.isEmpty) {
        developer.log(
          '[ImageUrlNormalizer] Empty image filename, using fallback',
          name: 'ImageUrlNormalizer',
        );
        return fallbackUrl ?? _fallbackImageUrl;
      }

      // CRITICAL FIX: If imageFileName is already a local file path, return it as-is
      if (imageFileName.startsWith('file://') ||
          imageFileName.startsWith('/')) {
        developer.log(
          '[ImageUrlNormalizer] Local file path detected, returning as-is: $imageFileName',
          name: 'ImageUrlNormalizer',
        );
        return imageFileName;
      }

      // If already a complete URL, validate and return
      if (imageFileName.startsWith('http://') ||
          imageFileName.startsWith('https://')) {
        if (_isValidUrl(imageFileName)) {
          developer.log(
            '[ImageUrlNormalizer] Using complete URL: $imageFileName',
            name: 'ImageUrlNormalizer',
          );
          return imageFileName;
        } else {
          developer.log(
            '[ImageUrlNormalizer] Invalid complete URL, using fallback: $imageFileName',
            name: 'ImageUrlNormalizer',
          );
          return fallbackUrl ?? _fallbackImageUrl;
        }
      }

      // Construct URL from base + path + filename
      String normalizedUrl = _constructImageUrl(imageFileName, pathImage);

      developer.log(
        '[ImageUrlNormalizer] Normalized URL: $normalizedUrl',
        name: 'ImageUrlNormalizer',
      );

      return normalizedUrl;
    } catch (e) {
      developer.log(
        '[ImageUrlNormalizer] Error normalizing URL: $e',
        name: 'ImageUrlNormalizer',
        error: e,
      );
      return fallbackUrl ?? _fallbackImageUrl;
    }
  }

  /// Construct image URL with proper path handling
  static String _constructImageUrl(String imageFileName, String? pathImage) {
    // Clean the filename
    String cleanFileName = imageFileName.trim();
    if (cleanFileName.startsWith('/')) {
      cleanFileName = cleanFileName.substring(1);
    }

    // Determine the path to use
    String imagePath = pathImage ?? _defaultImagePath;

    // Clean the path
    if (imagePath.startsWith('/')) {
      imagePath = imagePath.substring(1);
    }
    if (!imagePath.endsWith('/') && imagePath.isNotEmpty) {
      imagePath = '$imagePath/';
    }

    // CRITICAL FIX: Better path duplication detection
    // Check multiple ways the path might already be included in filename
    final pathWithoutSlash = imagePath.replaceAll('/', '');
    final hasPathInFilename =
        cleanFileName.contains('thumb/') ||
        cleanFileName.contains('audio/') ||
        cleanFileName.contains(pathWithoutSlash) ||
        cleanFileName.startsWith('images/');

    if (hasPathInFilename) {
      // Filename already contains path, just add base URL
      return '$_baseServerUrl$cleanFileName';
    }

    // Construct full URL: baseUrl + path + filename
    final fullUrl = '$_baseServerUrl$imagePath$cleanFileName';

    return fullUrl;
  }

  /// Validate if URL is properly formed
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Extract image filename from a complete URL for processing
  static String extractImageFileName(String url) {
    try {
      if (url.startsWith('http')) {
        final uri = Uri.parse(url);
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      }
      return url;
    } catch (e) {
      return url;
    }
  }

  /// Validate and fix existing MediaItem artUri
  static String validateAndFixMediaItemImageUrl({
    required String? currentArtUri,
    required String? imageFileName,
    required String? pathImage,
  }) {
    // First try to use the current artUri if it's valid
    if (currentArtUri != null &&
        currentArtUri.isNotEmpty &&
        _isValidUrl(currentArtUri)) {
      return currentArtUri;
    }

    // If current artUri is invalid, construct a new one
    return normalizeImageUrl(
      imageFileName: imageFileName,
      pathImage: pathImage,
    );
  }

  /// Get consistent image URL for specific contexts
  static String getImageUrlForContext({
    required String? imageFileName,
    required String context, // 'music_player', 'mini_player', 'queue', etc.
    String? pathImage,
  }) {
    final normalizedUrl = normalizeImageUrl(
      imageFileName: imageFileName,
      pathImage: pathImage,
    );

    developer.log(
      '[ImageUrlNormalizer] Image URL for $context: $normalizedUrl',
      name: 'ImageUrlNormalizer',
    );

    return normalizedUrl;
  }
}
