import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/AppConstant.dart';

import '../controllers/download_controller.dart';
import '../services/image_url_normalizer.dart';
import '../services/startup_controller.dart';

/// Utility class for managing assets with offline support
class AssetManager {
  static final AssetManager _instance = AssetManager._internal();
  factory AssetManager() => _instance;
  AssetManager._internal();

  final DownloadController _downloadController = DownloadController();
  final StartupController _startupController = StartupController();

  /// Get the best available image widget for a track
  /// Prioritizes local files in offline mode, falls back to network in online mode
  Widget getTrackImage({
    required String trackId,
    required String networkImageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return FutureBuilder<String?>(
      future: _getBestImagePath(trackId, networkImageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder(width, height, placeholder);
        }

        final imagePath = snapshot.data;

        if (imagePath != null &&
            (imagePath.startsWith('/') || imagePath.startsWith('file://'))) {
          // Local file path - remove file:// prefix if present
          final localPath =
              imagePath.startsWith('file://')
                  ? imagePath.replaceFirst('file://', '')
                  : imagePath;

          return _buildLocalImage(
            localPath,
            width: width,
            height: height,
            fit: fit,
            errorWidget: errorWidget,
          );
        } else if (imagePath != null && imagePath.startsWith('http')) {
          // Network image
          return _buildNetworkImage(
            imagePath,
            width: width,
            height: height,
            fit: fit,
            placeholder: placeholder,
            errorWidget: errorWidget,
          );
        } else {
          // No image available
          return _buildErrorWidget(width, height, errorWidget);
        }
      },
    );
  }

  /// Get the best available audio source for a track
  Future<String?> getBestAudioSource(
    String trackId,
    String networkAudioUrl,
  ) async {
    return await _getBestAudioPath(trackId, networkAudioUrl);
  }

  /// Get the best available image path for static widgets
  Future<String?> getBestImageSource(
    String trackId,
    String networkImageUrl,
  ) async {
    return await _getBestImagePath(trackId, networkImageUrl);
  }

  /// Get the best available image path/URL
  Future<String?> _getBestImagePath(
    String trackId,
    String networkImageUrl,
  ) async {
    try {
      // Check if we have a local copy
      final downloadedTrack =
          _downloadController.downloadedTracks
              .where((track) => track.id == trackId && track.isDownloadComplete)
              .firstOrNull;

      final localPath = downloadedTrack?.localImagePath;

      if (localPath != null &&
          localPath.isNotEmpty &&
          await _fileExists(localPath)) {
        return localPath;
      }

      // If offline mode or no connectivity, return null (will show placeholder)
      if (_startupController.shouldRestrictToDownloadsOnly()) {
        return null;
      }

      // Return network URL if available and we have connectivity
      if (networkImageUrl.isNotEmpty && _startupController.hasConnectivity) {
        // Use ImageUrlNormalizer for consistent URL construction
        String finalImageUrl;
        if (networkImageUrl.startsWith('http')) {
          finalImageUrl = networkImageUrl;
        } else {
          // Construct URL using the normalizer
          finalImageUrl = ImageUrlNormalizer.normalizeImageUrl(
            imageFileName: networkImageUrl,
            pathImage: 'images/audio/thumb/',
          );
        }
        return finalImageUrl;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting best image path: $e');
      // Even if there's an error, try to return a valid network URL
      if (networkImageUrl.isNotEmpty) {
        String finalImageUrl = networkImageUrl;
        if (!finalImageUrl.startsWith('http')) {
          const baseUrl = '${AppConstant.SiteUrl}public/';
          if (finalImageUrl.startsWith('/')) {
            finalImageUrl = '$baseUrl${finalImageUrl.substring(1)}';
          } else {
            finalImageUrl = '${baseUrl}images/audio/thumb/$finalImageUrl';
          }
        }
        return finalImageUrl;
      }
      return null;
    }
  }

  /// Get the best available audio path/URL
  Future<String?> _getBestAudioPath(
    String trackId,
    String networkAudioUrl,
  ) async {
    try {
      // Check if we have a local copy
      final downloadedTrack =
          _downloadController.downloadedTracks
              .where((track) => track.id == trackId && track.isDownloadComplete)
              .firstOrNull;

      final localPath = downloadedTrack?.localAudioPath;

      if (localPath != null &&
          localPath.isNotEmpty &&
          await _fileExists(localPath)) {
        return 'file://$localPath'; // Return file:// URL for local files
      }

      // If offline mode or no connectivity, return null
      if (_startupController.shouldRestrictToDownloadsOnly()) {
        return null;
      }

      // Return network URL if available and we have connectivity
      if (networkAudioUrl.isNotEmpty && _startupController.hasConnectivity) {
        // Ensure the network URL is properly constructed
        String finalAudioUrl = networkAudioUrl;
        if (!finalAudioUrl.startsWith('http')) {
          const baseUrl = '${AppConstant.SiteUrl}public/';
          if (finalAudioUrl.startsWith('/')) {
            finalAudioUrl = '$baseUrl${finalAudioUrl.substring(1)}';
          } else {
            finalAudioUrl = '${baseUrl}images/audio/$finalAudioUrl';
          }
        }
        return finalAudioUrl;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting best audio path: $e');
      // Even if there's an error, try to return a valid network URL
      if (networkAudioUrl.isNotEmpty) {
        String finalAudioUrl = networkAudioUrl;
        if (!finalAudioUrl.startsWith('http')) {
          const baseUrl = '${AppConstant.SiteUrl}public/';
          if (finalAudioUrl.startsWith('/')) {
            finalAudioUrl = '$baseUrl${finalAudioUrl.substring(1)}';
          } else {
            finalAudioUrl = '${baseUrl}images/audio/$finalAudioUrl';
          }
        }
        return finalAudioUrl;
      }
      return null;
    }
  }

  /// Check if a file exists
  Future<bool> _fileExists(String path) async {
    try {
      final file = File(path);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Build local image widget
  Widget _buildLocalImage(
    String imagePath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    return Image.file(
      File(imagePath),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Local image error: $error');
        return _buildErrorWidget(width, height, errorWidget);
      },
    );
  }

  /// Build network image widget
  Widget _buildNetworkImage(
    String imageUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder:
          (context, url) => _buildPlaceholder(width, height, placeholder),
      errorWidget: (context, url, error) {
        debugPrint('Network image error: $error');
        return _buildErrorWidget(width, height, errorWidget);
      },
      // Cache images for better performance
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
    );
  }

  /// Build placeholder widget
  Widget _buildPlaceholder(double? width, double? height, Widget? placeholder) {
    if (placeholder != null) {
      return placeholder;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: appColors().gray[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        color: appColors().gray[500],
        size: (width != null && height != null) ? (width + height) / 6 : 32,
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget(double? width, double? height, Widget? errorWidget) {
    if (errorWidget != null) {
      return errorWidget;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: appColors().gray[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.broken_image,
        color: appColors().gray[500],
        size: (width != null && height != null) ? (width + height) / 6 : 32,
      ),
    );
  }

  /// Get offline placeholder image for use in lists
  Widget getOfflinePlaceholder({
    double? width,
    double? height,
    bool showOfflineIcon = true,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: appColors().gray[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.music_note,
              color: appColors().gray[400],
              size:
                  (width != null && height != null) ? (width + height) / 6 : 32,
            ),
          ),
          if (showOfflineIcon)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.offline_bolt, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }

  /// Preload images for better UX
  Future<void> preloadImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        try {
          await precacheImage(CachedNetworkImageProvider(url), context);
        } catch (e) {
          debugPrint('Error preloading image $url: $e');
        }
      }
    }
  }

  /// Clear cached images
  Future<void> clearImageCache() async {
    try {
      await CachedNetworkImage.evictFromCache('');
      // This will clear all cached images
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }

  /// Get image size information
  Future<Size?> getImageSize(String imagePath) async {
    try {
      if (imagePath.startsWith('/')) {
        // Local file
        final file = File(imagePath);
        if (await file.exists()) {
          // You would need to use a package like flutter_image_compress
          // or similar to get actual image dimensions
          return const Size(300, 300); // Placeholder
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting image size: $e');
      return null;
    }
  }

  /// Check if track assets are fully downloaded
  Future<bool> areTrackAssetsComplete(String trackId) async {
    try {
      final downloadedTrack =
          _downloadController.downloadedTracks
              .where((track) => track.id == trackId && track.isDownloadComplete)
              .firstOrNull;

      if (downloadedTrack == null) return false;

      final audioPath = downloadedTrack.localAudioPath;
      bool hasAudio = false;

      if (audioPath.isNotEmpty) {
        hasAudio = await _fileExists(audioPath);
      }

      // Consider complete if we have audio (artwork is optional)
      return hasAudio;
    } catch (e) {
      debugPrint('Error checking track assets: $e');
      return false;
    }
  }

  /// Get assets status for a track
  Future<Map<String, bool>> getTrackAssetsStatus(String trackId) async {
    try {
      final downloadedTrack =
          _downloadController.downloadedTracks
              .where((track) => track.id == trackId && track.isDownloadComplete)
              .firstOrNull;

      final audioPath = downloadedTrack?.localAudioPath;
      final artworkPath = downloadedTrack?.localImagePath;

      bool hasAudio = false;
      bool hasArtwork = false;

      if (audioPath != null) {
        hasAudio = await _fileExists(audioPath);
      }

      if (artworkPath != null) {
        hasArtwork = await _fileExists(artworkPath);
      }

      return {
        'hasAudio': hasAudio,
        'hasArtwork': hasArtwork,
        'isComplete': hasAudio,
      };
    } catch (e) {
      debugPrint('Error getting track assets status: $e');
      return {'hasAudio': false, 'hasArtwork': false, 'isComplete': false};
    }
  }
}
