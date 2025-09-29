import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

/// Optimized image widget with memory management and performance improvements
class OptimizedImageWidget extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableMemoryCache;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Duration fadeInDuration;

  const OptimizedImageWidget({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  @override
  State<OptimizedImageWidget> createState() => _OptimizedImageWidgetState();
}

class _OptimizedImageWidgetState extends State<OptimizedImageWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Monitor frame performance when building images
    FramePerformanceMonitor.markFrameStart();

    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    // Check memory usage and clear cache if necessary
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ImageCacheOptimizer.clearExcessiveCache();
    });

    return CachedNetworkImage(
      imageUrl: widget.imageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: widget.fadeInDuration,

      // Memory optimizations
      memCacheWidth: widget.memCacheWidth ?? _calculateOptimalCacheWidth(),
      memCacheHeight: widget.memCacheHeight ?? _calculateOptimalCacheHeight(),
      maxWidthDiskCache: widget.width?.toInt() ?? 400,
      maxHeightDiskCache: widget.height?.toInt() ?? 400,

      // Placeholder with shimmer effect
      placeholder:
          (context, url) => widget.placeholder ?? _buildShimmerPlaceholder(),

      // Error widget
      errorWidget: (context, url, error) {
        developer.log(
          '[OptimizedImageWidget] Failed to load image: $url, Error: $error',
        );
        return widget.errorWidget ?? _buildErrorWidget();
      },

      // Performance optimizations
      fadeOutDuration: const Duration(milliseconds: 200),
      useOldImageOnUrlChange: true,

      // HTTP headers for better caching
      httpHeaders: const {
        'Cache-Control': 'max-age=86400',
        'Accept': 'image/webp,image/jpeg,image/png,*/*',
      },
    );
  }

  int _calculateOptimalCacheWidth() {
    if (widget.width != null) {
      final screenDensity = MediaQuery.of(context).devicePixelRatio;
      return (widget.width! * screenDensity).toInt().clamp(50, 800);
    }
    return 200; // Default reasonable size
  }

  int _calculateOptimalCacheHeight() {
    if (widget.height != null) {
      final screenDensity = MediaQuery.of(context).devicePixelRatio;
      return (widget.height! * screenDensity).toInt().clamp(50, 800);
    }
    return 200; // Default reasonable size
  }

  Widget _buildShimmerPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[300]!, Colors.grey[100]!, Colors.grey[300]!],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note,
          size: (widget.width ?? 50) * 0.3,
          color: appColors().gray[300],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: appColors().gray[100],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image,
              size: (widget.width ?? 50) * 0.3,
              color: appColors().gray[300],
            ),
            if (widget.width != null && widget.width! > 60)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Image Error',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Memory-efficient image cache manager
class ImageCacheOptimizer {
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const int _maxCacheObjects = 1000;

  /// Initialize the image cache optimizer
  static void initialize() {
    optimizeCache();
    developer.log('[ImageCacheOptimizer] Initialized with optimized settings');
  }

  static void optimizeCache() {
    final imageCache = PaintingBinding.instance.imageCache;

    // Set memory limits
    imageCache.maximumSizeBytes = _maxCacheSize;
    imageCache.maximumSize = _maxCacheObjects;

    developer.log(
      '[ImageCacheOptimizer] Cache optimized - Size: ${_maxCacheSize / 1024 / 1024}MB, Objects: $_maxCacheObjects',
    );
  }

  static void clearExcessiveCache() {
    final imageCache = PaintingBinding.instance.imageCache;

    if (imageCache.currentSizeBytes > _maxCacheSize * 0.8) {
      imageCache.clear();
      developer.log(
        '[ImageCacheOptimizer] Cache cleared due to excessive memory usage',
      );
    }
  }

  static void logCacheStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    developer.log(
      '[ImageCacheOptimizer] Cache Stats - '
      'Objects: ${imageCache.currentSize}/${imageCache.maximumSize}, '
      'Size: ${(imageCache.currentSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB/'
      '${(imageCache.maximumSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB',
    );
  }
}

/// Performance monitoring for frame drops
class FramePerformanceMonitor {
  static int _frameDropCount = 0;
  static DateTime? _lastFrameTime;
  static const Duration _targetFrameTime = Duration(milliseconds: 16); // 60 FPS

  /// Mark the start of a frame for performance monitoring
  static void markFrameStart() {
    final now = DateTime.now();

    if (_lastFrameTime != null) {
      final frameDuration = now.difference(_lastFrameTime!);

      if (frameDuration > _targetFrameTime * 2) {
        _frameDropCount++;

        if (_frameDropCount % 10 == 0) {
          developer.log(
            '[FramePerformanceMonitor] Frame drops detected: $_frameDropCount, '
            'Last frame: ${frameDuration.inMilliseconds}ms',
          );

          // Trigger cache cleanup on excessive frame drops
          if (_frameDropCount > 50) {
            ImageCacheOptimizer.clearExcessiveCache();
            _frameDropCount = 0;
          }
        }
      }
    }

    _lastFrameTime = now;
  }

  static void monitorFrame() {
    markFrameStart();
  }

  static void reset() {
    _frameDropCount = 0;
    _lastFrameTime = null;
  }
}

/// Widget performance tracker
class WidgetPerformanceTracker extends StatefulWidget {
  final Widget child;
  final String widgetName;

  const WidgetPerformanceTracker({
    super.key,
    required this.child,
    required this.widgetName,
  });

  @override
  State<WidgetPerformanceTracker> createState() =>
      _WidgetPerformanceTrackerState();
}

class _WidgetPerformanceTrackerState extends State<WidgetPerformanceTracker> {
  int _buildCount = 0;
  DateTime? _lastBuildTime;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    _buildCount++;

    if (_lastBuildTime != null) {
      final timeSinceLastBuild = now.difference(_lastBuildTime!);

      // Log excessive rebuilds
      if (timeSinceLastBuild < const Duration(milliseconds: 100) &&
          _buildCount > 5) {
        developer.log(
          '[WidgetPerformanceTracker] Excessive rebuilds in ${widget.widgetName}: '
          '$_buildCount builds in short timespan',
        );
      }
    }

    _lastBuildTime = now;

    // Monitor frames
    FramePerformanceMonitor.monitorFrame();

    return widget.child;
  }
}
