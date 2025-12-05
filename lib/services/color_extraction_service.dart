import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/widgets/common/smart_image_widget.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Service for extracting dominant colors from album artwork
class ColorExtractionService {
  static const Duration _animationDuration = Duration(milliseconds: 1500);
  // Simple in-memory cache for color schemes by image URL to avoid
  // re-processing the same artwork repeatedly.
  static final Map<String, ColorScheme> _schemeCache = <String, ColorScheme>{};

  /// Extracts colors from the given image URL and creates a color scheme
  static Future<ColorScheme?> extractColorsFromAlbumArt(String imageUrl) async {
    try {
      if (imageUrl.isNotEmpty && _schemeCache.containsKey(imageUrl)) {
        return _schemeCache[imageUrl];
      }
      // Use a low-resolution resize during color extraction to reduce
      // decode + quantization cost. The ResizeImage instructs the engine
      // to decode at smaller dimensions where possible.
      final provider = getSmartImageProvider(imageUrl);
      final lowResProvider = ResizeImage(provider, width: 64, height: 64);

      final colors = await _getColorsFromImage(lowResProvider);

      if (colors.isNotEmpty) {
        final scheme = ColorScheme.fromSeed(
          seedColor: colors.first,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        );
        if (imageUrl.isNotEmpty) {
          _schemeCache[imageUrl] = scheme;
        }
        return scheme;
      }
    } catch (e) {
      debugPrint('Error extracting colors: $e');
      // Return fallback color scheme
      return ColorScheme.fromSeed(
        seedColor: appColors().primaryColorApp,
        brightness: Brightness.dark,
      );
    }
    return null;
  }

  /// Extracts dominant colors from image provider
  static Future<List<Color>> _getColorsFromImage(ImageProvider provider) async {
    try {
      // Load image and obtain raw RGBA bytes (this part must run on UI
      // isolate because decoding uses Flutter engine APIs). We then send
      // the raw bytes to a background isolate to perform the CPU heavy
      // quantization so it doesn't block the main thread.
      final imageStream = provider.resolve(const ImageConfiguration());
      final completer = Completer<ui.Image>();

      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!completer.isCompleted) {
            imageStream.removeListener(listener);
            completer.complete(info.image);
          }
        },
        onError: (e, st) {
          if (!completer.isCompleted) {
            imageStream.removeListener(listener);
            completer.completeError(e, st);
          }
        },
      );

      imageStream.addListener(listener);
      final image = await completer.future;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) throw Exception('Failed to get image bytes');

      // Offload heavy quantization to a background isolate. We pass the
      // underlying byte buffer (as Uint8List) to the isolate which will
      // convert it to a Uint32List and run the quantizer there.
      final rgba = bytes.buffer.asUint8List();

      final List<int> argbList = await compute(_extractColorsFromBytes, rgba);

      // Convert int ARGB values to Flutter Colors
      return argbList.map((argb) => Color(argb)).toList();
    } catch (e) {
      debugPrint('Error getting colors from image: $e');
      return [appColors().primaryColorApp];
    }
  }

  /// Top-level isolate entrypoint used by [compute]. Accepts raw RGBA bytes
  /// and returns a list of ARGB integers sorted/scored for palette suitability.
  // NOTE: moved to top-level below as [_extractColorsFromBytes] because
  // `compute` requires a top-level or static function to spawn an isolate.

  /// Converts ABGR to ARGB color format
  static int _getArgbFromAbgr(int abgr) {
    final a = (abgr >> 24) & 0xFF;
    final b = (abgr >> 16) & 0xFF;
    final g = (abgr >> 8) & 0xFF;
    final r = abgr & 0xFF;
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// Animation duration for color transitions
  static Duration get animationDuration => _animationDuration;
}

/// Top-level isolate entrypoint used by [compute]. Accepts raw RGBA bytes
/// and returns a list of ARGB integers sorted/scored for palette suitability.
Future<List<int>> _extractColorsFromBytes(Uint8List rgba) async {
  try {
    // Convert the byte buffer into a 32-bit view. The original code used
    // rawRgba -> asUint32List which yields ABGR/other platform ordering. We'll
    // reuse the same conversion and then map to ARGB as before.
    final pixels = rgba.buffer.asUint32List();

    final QuantizerResult quant = await QuantizerCelebi().quantize(
      pixels,
      128,
    ); // await async call

    final Map<int, int> colorToCount = quant.colorToCount.map((key, value) {
      final argb = ColorExtractionService._getArgbFromAbgr(key);
      return MapEntry<int, int>(argb, value);
    });

    final List<int> filteredResults = Score.score(
      colorToCount,
      desired: 1,
      filter: true,
    );
    final List<int> scoredResults = Score.score(
      colorToCount,
      desired: 4,
      filter: false,
    );

    final Set<int> combined = {...filteredResults, ...scoredResults};
    return combined.toList();
  } catch (e) {
    // On any error, return a fallback seed color
    return [appColors().primaryColorApp.value];
  }
}
