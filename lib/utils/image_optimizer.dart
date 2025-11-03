import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

// Worker functions run in a background isolate via compute(). They accept a
// serializable message (Map) and return Uint8List encoded JPEG bytes.
Future<Uint8List?> _processForCropping(Map<String, dynamic> msg) async {
  try {
    final bytes = msg['bytes'] as Uint8List;
    final maxWidth = msg['maxWidth'] as int;
    final maxHeight = msg['maxHeight'] as int;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    int targetWidth = decoded.width;
    int targetHeight = decoded.height;

    if (targetWidth > maxWidth || targetHeight > maxHeight) {
      final widthRatio = maxWidth / targetWidth;
      final heightRatio = maxHeight / targetHeight;
      final scale = widthRatio < heightRatio ? widthRatio : heightRatio;

      targetWidth = (targetWidth * scale).round();
      targetHeight = (targetHeight * scale).round();
    }

    img.Image processed = decoded;
    if (targetWidth != decoded.width || targetHeight != decoded.height) {
      processed = img.copyResize(
        decoded,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    final jpg = img.encodeJpg(processed, quality: 90);
    return Uint8List.fromList(jpg);
  } catch (e) {
    if (kDebugMode) print('ImageOptimizer._processForCropping error: $e');
    return null;
  }
}

Future<Uint8List?> _processForFinalOptimize(Map<String, dynamic> msg) async {
  try {
    final bytes = msg['bytes'] as Uint8List;
    final maxWidth = msg['maxWidth'] as int;
    final maxHeight = msg['maxHeight'] as int;
    final quality = msg['quality'] as int;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    int newW = decoded.width;
    int newH = decoded.height;

    if (newW > maxWidth || newH > maxHeight) {
      final ratio = newW / newH;
      if (newW > newH) {
        newW = maxWidth;
        newH = (newW / ratio).round();
      } else {
        newH = maxHeight;
        newW = (newH * ratio).round();
      }
    }

    img.Image processed = decoded;
    if (processed.width != newW || processed.height != newH) {
      processed = img.copyResize(
        processed,
        width: newW,
        height: newH,
        interpolation: img.Interpolation.linear,
      );
    }

    final jpg = img.encodeJpg(processed, quality: quality);
    return Uint8List.fromList(jpg);
  } catch (e) {
    if (kDebugMode) print('ImageOptimizer._processForFinalOptimize error: $e');
    return null;
  }
}

class ImageOptimizer {
  /// Aggressively downscale images BEFORE passing to native cropper
  /// to prevent OOM crashes in UCrop's native bitmap allocation
  static Future<File?> optimizeForCropping(
    File imageFile, {
    required int maxWidth,
    required int maxHeight,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // Offload heavy decode/resize/encode work to a background isolate
      final result = await compute<Map<String, dynamic>, Uint8List?>(
        (msg) => _processForCropping(msg),
        {'bytes': bytes, 'maxWidth': maxWidth, 'maxHeight': maxHeight},
      );

      if (result == null) {
        if (kDebugMode) print('ImageOptimizer: processing returned null');
        return null;
      }

      final tmp = await getTemporaryDirectory();
      final out = File(
        '${tmp.path}/precrop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(result);

      if (kDebugMode) {
        final sizeKB = result.length / 1024;
        print('ImageOptimizer: Output size: ${sizeKB.toStringAsFixed(1)} KB');
      }

      return out;
    } catch (e) {
      if (kDebugMode) print('ImageOptimizer.optimizeForCropping error: $e');
      return null;
    }
  }

  /// Optimize final cropped image for upload/display
  static Future<File?> optimizeFinalImage(
    File imageFile, {
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      final result = await compute<Map<String, dynamic>, Uint8List?>(
        (msg) => _processForFinalOptimize(msg),
        {
          'bytes': bytes,
          'maxWidth': maxWidth,
          'maxHeight': maxHeight,
          'quality': quality,
        },
      );

      if (result == null) return null;

      final tmp = await getTemporaryDirectory();
      final out = File(
        '${tmp.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(result);
      return out;
    } catch (e) {
      if (kDebugMode) print('ImageOptimizer.optimizeFinalImage error: $e');
      return null;
    }
  }

  /// Profile images: very safe limits for native cropper
  static Future<File?> optimizeProfileForCropping(File imageFile) async {
    return optimizeForCropping(
      imageFile,
      maxWidth: 800, // Safe size for 1:1 crop on low-memory devices
      maxHeight: 800,
    );
  }

  /// Banner images: moderate limits to prevent OOM
  static Future<File?> optimizeBannerForCropping(File imageFile) async {
    // Use reduced limits to be extra-safe before handing to native cropper.
    // 1280x720 is a friendly 16:9 size that significantly reduces native memory
    // allocation compared to very large images while still preserving sufficient
    // resolution for cropped banners.
    return optimizeForCropping(
      imageFile,
      maxWidth: 1280, // Reduced to 1280x720 to reduce OOM risk pre-crop
      maxHeight: 720,
    );
  }

  /// Final optimization for profile after cropping
  static Future<File?> optimizeProfileImage(File imageFile) async {
    return optimizeFinalImage(
      imageFile,
      maxWidth: 800,
      maxHeight: 800,
      quality: 90,
    );
  }

  /// Final optimization for banner after cropping
  static Future<File?> optimizeBannerImage(File imageFile) async {
    return optimizeFinalImage(
      imageFile,
      maxWidth: 1920,
      maxHeight: 1080,
      quality: 85,
    );
  }
}
