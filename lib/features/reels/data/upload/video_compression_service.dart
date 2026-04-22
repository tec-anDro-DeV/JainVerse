import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

/// Smart, quality-preserving video compressor backed by [VideoCompress].
///
/// ## Strategy
/// 1. Probe the source with [VideoCompress.getMediaInfo] to read resolution,
///    duration, and derived bitrate.
/// 2. **Skip** if the video is already within acceptable quality bounds:
///
///    | Resolution        | Bitrate threshold |
///    |-------------------|-------------------|
///    | ≤ 720p (≤1280 px) | ≤ 4 Mbps          |
///    | ≤ 1080p (≤1920 px)| ≤ 8 Mbps          |
///    | file size > 50 MB | always compress   |
///
///    When skipped, [compress] returns [file] unchanged — **zero re-encoding**.
///
/// 3. Otherwise compress with [VideoQuality.HighestQuality]:
///    - iOS  : `AVAssetExportPreset1920x1080` → H.264, max 1080p, ~8–10 Mbps
///    - Android: transcoder highest quality setting (~8 Mbps at 1080p)
///
/// This fixes the previous [VideoQuality.MediumQuality] default which mapped
/// to `AVAssetExportPreset1280x720` (~1–2 Mbps) — the root cause of blurry,
/// pixelated output.
class VideoCompressionService {
  // Bitrate skip thresholds (kbps) — at-or-below → no compression needed
  static const double _max720pKbps  = 4000; // 4 Mbps
  static const double _max1080pKbps = 8000; // 8 Mbps

  // File size above which we always compress regardless of bitrate
  static const double _maxSkipSizeMb = 50.0;

  // Timeout for the underlying VideoCompress transcoder
  static const Duration _compressTimeout = Duration(minutes: 8);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Probes [file], decides whether compression is needed, and returns:
  /// - [file] unchanged when compression is **skipped** (no temp file created).
  /// - A new temp file with the compressed output otherwise.
  ///
  /// The caller is responsible for deleting the returned file if it differs
  /// from [file] (i.e. when `result.path != file.path`).
  Future<File> compress(File file) async {
    final fileSizeBytes = await file.length();
    final fileSizeMb    = fileSizeBytes / (1024 * 1024);

    // Probe resolution + duration to derive bitrate.
    final info         = await VideoCompress.getMediaInfo(file.path);
    final width        = info.width  ?? 0;
    final height       = info.height ?? 0;
    final longEdge     = max(width, height);
    final durationSec  = ((info.duration ?? 0) / 1000.0);

    // Derive bitrate from file size + duration (more reliable than container tag).
    final double? bitrateKbps = durationSec > 0
        ? (fileSizeBytes * 8.0) / (durationSec * 1000.0)
        : null;

    _log('Input : ${width}x$height | '
        '${bitrateKbps != null ? '${bitrateKbps.toStringAsFixed(0)} kbps' : '? kbps'} | '
        '${fileSizeMb.toStringAsFixed(1)} MB | ${durationSec.toStringAsFixed(1)} s');

    if (_shouldSkip(longEdge: longEdge, bitrateKbps: bitrateKbps, fileSizeMb: fileSizeMb)) {
      _log('→ SKIP compression — already within quality targets');
      return file;
    }

    _log('→ COMPRESS (HighestQuality)');
    return _runCompress(file, fileSizeBytes);
  }

  // ---------------------------------------------------------------------------
  // Skip decision
  // ---------------------------------------------------------------------------

  bool _shouldSkip({
    required int    longEdge,
    required double? bitrateKbps,
    required double  fileSizeMb,
  }) {
    // Unknown bitrate → compress conservatively to be safe
    if (bitrateKbps == null) {
      _log('  skip-check: bitrate unknown → compress');
      return false;
    }

    // File too large → must compress regardless of bitrate
    if (fileSizeMb > _maxSkipSizeMb) {
      _log('  skip-check: ${fileSizeMb.toStringAsFixed(1)} MB > $_maxSkipSizeMb MB → compress');
      return false;
    }

    // Choose threshold based on current source resolution
    final threshold = longEdge > 1280 ? _max1080pKbps : _max720pKbps;
    final ok        = bitrateKbps <= threshold;

    _log('  skip-check: ${bitrateKbps.toStringAsFixed(0)} kbps '
        '${ok ? '≤' : '>'} ${threshold.toInt()} kbps '
        '(${longEdge}px long edge) → ${ok ? 'skip' : 'compress'}');
    return ok;
  }

  // ---------------------------------------------------------------------------
  // Compression
  // ---------------------------------------------------------------------------

  Future<File> _runCompress(File file, int inputSizeBytes) async {
    // HighestQuality on iOS  → AVAssetExportPreset1920x1080 (~8–10 Mbps, max 1080p)
    // HighestQuality on Android → transcoder max quality (~8 Mbps at 1080p)
    //
    // This replaces the old MediumQuality (AVAssetExportPreset1280x720, ~1–2 Mbps)
    // which was the root cause of blur and pixelation.
    final result = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.HighestQuality,
      deleteOrigin: false,
      includeAudio: true,
      frameRate: 30,
    ).timeout(_compressTimeout, onTimeout: () {
      VideoCompress.cancelCompression();
      throw TimeoutException(
        'VideoCompress timeout after ${_compressTimeout.inMinutes} min '
        '(State.Wait deadlock guard)',
      );
    });

    if (result == null || result.file == null) {
      throw Exception('VideoCompress returned null result');
    }

    final outFile        = result.file!;
    final outSizeBytes   = await outFile.length();
    final saved          = inputSizeBytes > 0
        ? ((1.0 - outSizeBytes / inputSizeBytes) * 100).clamp(0.0, 100.0)
        : 0.0;

    _log('Output: ${_fmt(outSizeBytes)} (was ${_fmt(inputSizeBytes)}, '
        '${saved.toStringAsFixed(0)}% saved)');
    return outFile;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _fmt(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('VideoCompressionService: $msg');
  }
}
