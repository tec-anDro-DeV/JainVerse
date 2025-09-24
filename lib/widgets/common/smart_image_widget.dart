import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

/// Smart image widget that can handle both local files and network images
class SmartImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final FilterQuality filterQuality; // Image quality setting

  const SmartImageWidget({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
    this.filterQuality = FilterQuality.high, // Default to high quality
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    Widget imageWidget;

    if (imageUrl!.startsWith('file://') || imageUrl!.startsWith('/')) {
      // Local file - use Image.file
      final filePath = imageUrl!.replaceFirst('file://', '');
      imageWidget = _buildLocalImage(filePath);
    } else if (imageUrl!.startsWith('http://') ||
        imageUrl!.startsWith('https://')) {
      // Network image - use CachedNetworkImage
      imageWidget = _buildNetworkImage();
    } else {
      // Invalid URL format
      imageWidget = _buildErrorWidget();
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }

  Widget _buildLocalImage(String filePath) {
    return Image.file(
      File(filePath),
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality, // Use the specified filter quality
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Local image error: $error for path: $filePath');
        return _buildErrorWidget();
      },
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      filterQuality: filterQuality, // Use the specified filter quality
      placeholder:
          placeholder != null
              ? (context, url) => placeholder!
              : (context, url) => _buildPlaceholder(),
      errorWidget:
          errorWidget != null
              ? (context, url, error) => errorWidget!
              : (context, url, error) {
                debugPrint('Network image error: $error for URL: $url');
                return _buildErrorWidget();
              },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: appColors().gray[200],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.music_note,
        color: appColors().gray[500],
        size: _calculateIconSize(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: appColors().gray[200],
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.broken_image,
        color: appColors().gray[500],
        size: _calculateIconSize(),
      ),
    );
  }

  double _calculateIconSize() {
    if (width != null && height != null) {
      return (width! + height!) / 6;
    }
    return 32;
  }
}

/// Simple utility function to get the appropriate image provider with high quality settings
ImageProvider getSmartImageProvider(String imageUrl) {
  if (imageUrl.startsWith('file://') || imageUrl.startsWith('/')) {
    // Local file
    final filePath = imageUrl.replaceFirst('file://', '');
    return FileImage(File(filePath));
  } else if (imageUrl.startsWith('http://') ||
      imageUrl.startsWith('https://')) {
    // Network image with high quality caching
    return CachedNetworkImageProvider(
      imageUrl,
      cacheKey: imageUrl, // Explicit cache key
    );
  } else {
    // Invalid URL - use a placeholder asset
    return const AssetImage('assets/images/song_placeholder.png');
  }
}

/// High quality image provider specifically for album art that needs scaling
ImageProvider getHighQualityImageProvider(String imageUrl, {int? targetSize}) {
  if (imageUrl.startsWith('file://') || imageUrl.startsWith('/')) {
    // Local file
    final filePath = imageUrl.replaceFirst('file://', '');
    return FileImage(File(filePath));
  } else if (imageUrl.startsWith('http://') ||
      imageUrl.startsWith('https://')) {
    // Network image with optimized caching for scaling
    return CachedNetworkImageProvider(
      imageUrl,
      cacheKey: targetSize != null ? '${imageUrl}_$targetSize' : imageUrl,
    );
  } else {
    // Invalid URL - use a placeholder asset
    return const AssetImage('assets/images/song_placeholder.png');
  }
}
