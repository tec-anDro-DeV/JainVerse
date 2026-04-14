import 'dart:io';
import 'package:flutter/foundation.dart';

enum UploadStatus {
  idle,
  picking,
  validating,
  previewing,
  compressing,
  uploading,
  success,
  error,
}

@immutable
class ReelUploadState {
  final UploadStatus status;
  final File? pickedFile;

  /// Upload progress 0.0–1.0. Valid during [UploadStatus.uploading].
  final double uploadProgress;

  /// Compression progress 0.0–1.0. Valid during [UploadStatus.compressing].
  final double compressProgress;

  /// Public CDN URL for the video — set immediately after a successful Bunny
  /// upload. Persisted through the [UploadStatus.error] state so that a retry
  /// can call the backend publish endpoint without re-uploading to Bunny.
  final String? publicUrl;

  /// CDN URL for the generated thumbnail. Empty string if thumbnail upload
  /// failed (non-fatal).
  final String? thumbnailUrl;

  /// Video duration formatted as "MM:SS".
  final String? duration;

  /// Compressed video size in MB, e.g. "12.4".
  final String? videoSize;

  final String? errorMessage;

  const ReelUploadState({
    this.status = UploadStatus.idle,
    this.pickedFile,
    this.uploadProgress = 0.0,
    this.compressProgress = 0.0,
    this.publicUrl,
    this.thumbnailUrl,
    this.duration,
    this.videoSize,
    this.errorMessage,
  });

  bool get isActive =>
      status == UploadStatus.compressing || status == UploadStatus.uploading;

  ReelUploadState copyWith({
    UploadStatus? status,
    File? pickedFile,
    double? uploadProgress,
    double? compressProgress,
    String? publicUrl,
    String? thumbnailUrl,
    String? duration,
    String? videoSize,
    String? errorMessage,
    bool clearError = false,
    bool clearFile = false,
  }) {
    return ReelUploadState(
      status: status ?? this.status,
      pickedFile: clearFile ? null : (pickedFile ?? this.pickedFile),
      uploadProgress: uploadProgress ?? this.uploadProgress,
      compressProgress: compressProgress ?? this.compressProgress,
      publicUrl: publicUrl ?? this.publicUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      videoSize: videoSize ?? this.videoSize,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
