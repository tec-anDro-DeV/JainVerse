import 'dart:developer' as developer;
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/services/image_url_normalizer.dart';

/// Service to ensure MediaItems have consistent and valid image URLs
/// This fixes the image loading issue during queue navigation
class MediaItemImageFixer {
  static final MediaItemImageFixer _instance = MediaItemImageFixer._internal();
  factory MediaItemImageFixer() => _instance;
  MediaItemImageFixer._internal();

  /// Fix MediaItem to ensure consistent image URL
  static MediaItem fixMediaItemImageUrl(
    MediaItem mediaItem, {
    String? pathImage,
    String? originalImageFileName,
  }) {
    try {
      // Extract original image filename if not provided
      String? imageFileName = originalImageFileName;
      if (imageFileName == null || imageFileName.isEmpty) {
        // Try to extract from current artUri
        final currentUri = mediaItem.artUri?.toString();
        if (currentUri != null) {
          imageFileName = ImageUrlNormalizer.extractImageFileName(currentUri);
        }
      }

      // Get normalized image URL
      final normalizedImageUrl = ImageUrlNormalizer.normalizeImageUrl(
        imageFileName: imageFileName,
        pathImage: pathImage,
      );

      developer.log(
        '[MediaItemImageFixer] Fixed image URL for ${mediaItem.title}: $normalizedImageUrl',
        name: 'MediaItemImageFixer',
      );

      // Create new MediaItem with fixed image URL
      return mediaItem.copyWith(artUri: Uri.parse(normalizedImageUrl));
    } catch (e) {
      developer.log(
        '[MediaItemImageFixer] Error fixing MediaItem image: $e',
        name: 'MediaItemImageFixer',
        error: e,
      );
      return mediaItem;
    }
  }

  /// Fix an entire queue of MediaItems
  static List<MediaItem> fixQueueImageUrls(
    List<MediaItem> queue, {
    String? pathImage,
    List<DataMusic>? originalMusicList,
  }) {
    developer.log(
      '[MediaItemImageFixer] Fixing image URLs for ${queue.length} items',
      name: 'MediaItemImageFixer',
    );

    return queue.asMap().entries.map((entry) {
      final index = entry.key;
      final mediaItem = entry.value;

      // Get original image filename if available
      String? originalImageFileName;
      if (originalMusicList != null && index < originalMusicList.length) {
        originalImageFileName = originalMusicList[index].image;
      }

      return fixMediaItemImageUrl(
        mediaItem,
        pathImage: pathImage,
        originalImageFileName: originalImageFileName,
      );
    }).toList();
  }

  /// Create MediaItem with guaranteed valid image URL
  static MediaItem createMediaItemWithValidImage({
    required String id,
    required String title,
    required String artist,
    required Duration duration,
    required String? imageFileName,
    required String? pathImage,
    Map<String, dynamic>? extras,
    String? album,
  }) {
    final normalizedImageUrl = ImageUrlNormalizer.normalizeImageUrl(
      imageFileName: imageFileName,
      pathImage: pathImage,
    );

    developer.log(
      '[MediaItemImageFixer] Creating MediaItem with normalized image: $normalizedImageUrl',
      name: 'MediaItemImageFixer',
    );

    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album ?? artist,
      duration: duration,
      artUri: Uri.parse(normalizedImageUrl),
      extras: extras ?? {},
    );
  }

  /// Update MediaItem with refreshed image URL during queue navigation
  static MediaItem refreshMediaItemImageUrl(
    MediaItem mediaItem, {
    String? pathImage,
    String? imageFileName,
  }) {
    // Get fresh normalized URL
    final refreshedImageUrl = ImageUrlNormalizer.normalizeImageUrl(
      imageFileName: imageFileName,
      pathImage: pathImage,
    );

    developer.log(
      '[MediaItemImageFixer] Refreshing image URL for ${mediaItem.title}: $refreshedImageUrl',
      name: 'MediaItemImageFixer',
    );

    return mediaItem.copyWith(artUri: Uri.parse(refreshedImageUrl));
  }
}

/// Extension to add image fixing capabilities to MediaItem
extension MediaItemImageExtension on MediaItem {
  /// Fix this MediaItem's image URL
  MediaItem withFixedImageUrl({
    String? pathImage,
    String? originalImageFileName,
  }) {
    return MediaItemImageFixer.fixMediaItemImageUrl(
      this,
      pathImage: pathImage,
      originalImageFileName: originalImageFileName,
    );
  }
}
