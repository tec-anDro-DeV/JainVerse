import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';

enum UploadStatus {
  idle,
  picking,
  validating,
  trimming,
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

  /// Unique file name used for the uploaded video on Bunny and backend metadata.
  final String? videoFileName;

  /// Unique file name used for the uploaded thumbnail on Bunny and backend metadata.
  final String? thumbnailFileName;

  /// True while the backend POST (save reel metadata) is in-flight.
  /// Distinct from [UploadStatus.uploading] which covers the Bunny CDN phase.
  final bool isSaving;

  /// The [ReelItem] returned by the backend on successful publish.
  /// Populated only when [status] is [UploadStatus.success].
  final ReelItem? savedReel;

  final String? errorMessage;

  /// Trim start point chosen on the trim screen. [Duration.zero] = no start offset.
  final Duration trimStart;

  /// Trim end point. Null means use the full video length from [trimStart].
  final Duration? trimEnd;

  /// User-picked cover photo. Null = auto-generate thumbnail from the video frame.
  final File? customThumbnailFile;

  /// Actual duration of the picked video, set after validation.
  final Duration? videoDuration;

  /// True when [videoDuration] > 3 minutes — trim is mandatory in this case.
  final bool isTrimRequired;

  /// True when the user explicitly tapped "Skip Trim".
  final bool isTrimSkipped;

  const ReelUploadState({
    this.status = UploadStatus.idle,
    this.pickedFile,
    this.uploadProgress = 0.0,
    this.compressProgress = 0.0,
    this.publicUrl,
    this.thumbnailUrl,
    this.duration,
    this.videoSize,
    this.videoFileName,
    this.thumbnailFileName,
    this.isSaving = false,
    this.savedReel,
    this.errorMessage,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.customThumbnailFile,
    this.videoDuration,
    this.isTrimRequired = false,
    this.isTrimSkipped = false,
  });

  /// True while any background work is running — prevents back navigation.
  bool get isActive =>
      status == UploadStatus.compressing ||
      status == UploadStatus.uploading ||
      isSaving;

  ReelUploadState copyWith({
    UploadStatus? status,
    File? pickedFile,
    double? uploadProgress,
    double? compressProgress,
    String? publicUrl,
    String? thumbnailUrl,
    String? duration,
    String? videoSize,
    String? videoFileName,
    String? thumbnailFileName,
    bool? isSaving,
    ReelItem? savedReel,
    String? errorMessage,
    bool clearError = false,
    bool clearFile = false,
    Duration? trimStart,
    Duration? trimEnd,
    bool clearTrimEnd = false,
    File? customThumbnailFile,
    bool clearCustomThumbnail = false,
    Duration? videoDuration,
    bool? isTrimRequired,
    bool? isTrimSkipped,
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
      videoFileName: videoFileName ?? this.videoFileName,
      thumbnailFileName: thumbnailFileName ?? this.thumbnailFileName,
      isSaving: isSaving ?? this.isSaving,
      savedReel: savedReel ?? this.savedReel,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      trimStart: trimStart ?? this.trimStart,
      trimEnd: clearTrimEnd ? null : (trimEnd ?? this.trimEnd),
      customThumbnailFile: clearCustomThumbnail
          ? null
          : (customThumbnailFile ?? this.customThumbnailFile),
      videoDuration: videoDuration ?? this.videoDuration,
      isTrimRequired: isTrimRequired ?? this.isTrimRequired,
      isTrimSkipped: isTrimSkipped ?? this.isTrimSkipped,
    );
  }
}
