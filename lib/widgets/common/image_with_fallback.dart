import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageWithFallback extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final String fallbackAsset;
  final Widget? loadingWidget;
  final Color? backgroundColor;

  const ImageWithFallback({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.fallbackAsset = 'assets/images/song_placeholder.png',
    this.loadingWidget,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: _ImageWithErrorHandling(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        fallbackAsset: fallbackAsset,
        loadingWidget: loadingWidget,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _ImageWithErrorHandling extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final String fallbackAsset;
  final Widget? loadingWidget;
  final Color? backgroundColor;

  const _ImageWithErrorHandling({
    required this.imageUrl,
    this.width,
    this.height,
    required this.fit,
    required this.alignment,
    required this.fallbackAsset,
    this.loadingWidget,
    this.backgroundColor,
  });

  @override
  State<_ImageWithErrorHandling> createState() =>
      _ImageWithErrorHandlingState();
}

class _ImageWithErrorHandlingState extends State<_ImageWithErrorHandling> {
  bool _hasError = false;
  // _isLoading is now handled by CachedNetworkImage placeholders

  @override
  Widget build(BuildContext context) {
    // If URL is empty or null, show fallback immediately
    if (widget.imageUrl.isEmpty) {
      return _buildFallbackImage();
    }

    if (_hasError) {
      return _buildFallbackImage();
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      placeholder: (context, url) => _buildLoadingWidget(),
      errorWidget: (context, url, error) {
        debugPrint('CachedNetworkImage error for URL: $url, error: $error');
        return _buildFallbackImage();
      },
      imageBuilder: (context, imageProvider) {
        return Image(
          image: imageProvider,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          alignment: widget.alignment,
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    if (widget.loadingWidget != null) {
      return widget.loadingWidget!;
    }

    // Show the new song placeholder asset while the network image loads.
    // Ensure the placeholder covers the whole container by using BoxFit.cover
    // and making the asset expand to the available space.
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor ?? appColors().gray[200],
      child: Image.asset(
        'assets/images/song_placeholder.png',
        fit: BoxFit.cover,
        alignment: widget.alignment,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? appColors().gray[200],
        image: DecorationImage(
          image: AssetImage(widget.fallbackAsset),
          fit: widget.fit,
          alignment: widget.alignment,
          onError: (error, stackTrace) {
            debugPrint('Fallback image load error: $error');
          },
        ),
      ),
    );
  }
}

// Simple utility function for DecorationImage with fallback
ImageProvider getImageProviderWithFallback(
  String imageUrl, {
  String fallbackAsset = 'assets/images/song_placeholder.png',
}) {
  if (imageUrl.isEmpty) {
    return AssetImage(fallbackAsset);
  }

  return CachedNetworkImageProvider(imageUrl);
}
