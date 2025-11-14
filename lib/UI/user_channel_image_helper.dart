import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/image_compressor.dart';
import 'package:jainverse/utils/image_optimizer.dart';
import 'package:jainverse/utils/crash_prevention_helper.dart';

/// Helper utilities used by the `UserChannel` screen for converting,
/// warning about, and cropping images. This moves bulky inline code out
/// of the screen file to keep it smaller and easier to read.
class UserChannelImageHelper {
  /// Converts an [XFile] or content:// URI into a local file suitable
  /// for native crop libraries. Returns null on failure.
  static Future<File?> xFileToLocalFile(XFile xfile, {String? prefix}) async {
    try {
      final rawPath = xfile.path;
      if (rawPath.startsWith('content://')) {
        final bytes = await xfile.readAsBytes();
        final tmp = await getTemporaryDirectory();
        final out = File(
          '${tmp.path}/${prefix ?? 'img'}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await out.writeAsBytes(bytes);
        return out;
      }

      final f = File(rawPath);
      if (await f.exists()) return f;

      try {
        final bytes = await xfile.readAsBytes();
        final tmp = await getTemporaryDirectory();
        final out = File(
          '${tmp.path}/${prefix ?? 'img'}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await out.writeAsBytes(bytes);
        return out;
      } catch (e) {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Warns the user if the selected image file size is large (>10MB).
  /// Returns true when the user wants to proceed.
  static Future<bool> checkImageSizeAndWarn(
    BuildContext context,
    File file,
  ) async {
    try {
      final size = await file.length();
      final sizeMB = size / (1024 * 1024);

      if (sizeMB > 10) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Large Image Detected'),
            content: Text(
              'This image is ${sizeMB.toStringAsFixed(1)} MB. '
              'Large images may cause issues. We recommend using smaller images.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        );

        return proceed == true;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  /// Crop a profile square image and return an optimized/compressed File.
  static Future<File?> cropProfileImage(
    BuildContext context,
    File imageFile,
  ) async {
    try {
      File source = imageFile;
      try {
        final pre = await ImageOptimizer.optimizeProfileForCropping(source);
        if (pre != null) source = pre;
      } catch (_) {}

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: source.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 1080,
        maxHeight: 1080,
        compressQuality: 85,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: appColors().primaryColorApp,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Image', aspectRatioLockEnabled: true),
        ],
      );

      if (croppedFile != null) {
        final file = File(croppedFile.path);

        try {
          final optimized = await ImageOptimizer.optimizeProfileImage(file);
          if (optimized != null) {
            CrashPreventionHelper.cleanupImageCache();
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
            await Future.delayed(const Duration(milliseconds: 200));
            return optimized;
          }
        } catch (_) {}

        final compressed = await ImageCompressor.compressImage(file);
        final resultFile = compressed ?? file;

        try {
          CrashPreventionHelper.cleanupImageCache();
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 200));

        return resultFile;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cropping image: $e'),
        ), // lightweight fallback
      );
    }
    return null;
  }

  /// Crop a banner (16:9) image and return an optimized/compressed File.
  static Future<File?> cropBannerImage(
    BuildContext context,
    File imageFile,
  ) async {
    try {
      File source = imageFile;
      try {
        final pre = await ImageOptimizer.optimizeBannerForCropping(source);
        if (pre != null) source = pre;
      } catch (_) {}

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: source.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        maxWidth: 1920,
        maxHeight: 1080,
        compressQuality: 85,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Banner Image',
            toolbarColor: appColors().primaryColorApp,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Banner', aspectRatioLockEnabled: true),
        ],
      );

      if (croppedFile != null) {
        final file = File(croppedFile.path);

        try {
          final optimized = await ImageOptimizer.optimizeBannerImage(file);
          if (optimized != null) {
            CrashPreventionHelper.cleanupImageCache();
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
            await Future.delayed(const Duration(milliseconds: 200));
            return optimized;
          }
        } catch (_) {}

        final compressed = await ImageCompressor.compressBannerImage(file);
        final resultFile = compressed ?? file;

        try {
          CrashPreventionHelper.cleanupImageCache();
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 200));

        return resultFile;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cropping banner: $e')));
    }
    return null;
  }
}
