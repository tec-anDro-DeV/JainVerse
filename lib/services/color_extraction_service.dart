import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/widgets/common/smart_image_widget.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Service for extracting dominant colors from album artwork
class ColorExtractionService {
  static const Duration _animationDuration = Duration(milliseconds: 1500);

  /// Extracts colors from the given image URL and creates a color scheme
  static Future<ColorScheme?> extractColorsFromAlbumArt(String imageUrl) async {
    try {
      final colors = await _getColorsFromImage(getSmartImageProvider(imageUrl));

      if (colors.isNotEmpty) {
        return ColorScheme.fromSeed(
          seedColor: colors.first,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        );
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
      final quantizerResult = await _extractColorsFromImageProvider(provider);
      final Map<int, int> colorToCount = quantizerResult.colorToCount.map(
        (key, value) => MapEntry<int, int>(_getArgbFromAbgr(key), value),
      );

      // Score colors for color scheme suitability
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

      return <dynamic>{
        ...filteredResults,
        ...scoredResults,
      }.toList().map((argb) => Color(argb)).toList();
    } catch (e) {
      debugPrint('Error getting colors from image: $e');
      return [appColors().primaryColorApp];
    }
  }

  /// Extracts colors from image provider using quantizer
  static Future<QuantizerResult> _extractColorsFromImageProvider(
    ImageProvider provider,
  ) async {
    final imageStream = provider.resolve(const ImageConfiguration());
    final completer = Completer<ui.Image>();

    // CRITICAL FIX: Prevent multiple completions of the same completer
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          // Remove listener first to prevent multiple calls
          imageStream.removeListener(listener);
          completer.complete(info.image);
        }
      },
      onError: (exception, stackTrace) {
        if (!completer.isCompleted) {
          imageStream.removeListener(listener);
          completer.completeError(exception, stackTrace);
        }
      },
    );

    imageStream.addListener(listener);

    final image = await completer.future;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (bytes == null) {
      throw Exception('Failed to get image bytes');
    }

    final pixels = bytes.buffer.asUint32List();
    return QuantizerCelebi().quantize(pixels, 128);
  }

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
