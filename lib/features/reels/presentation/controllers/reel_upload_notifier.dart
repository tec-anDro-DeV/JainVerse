import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:jainverse/features/reels/data/repository/reels_repository.dart';
import 'package:jainverse/features/reels/data/upload/reel_upload_service.dart';
import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/state/reel_upload_state.dart';

class ReelUploadNotifier extends Notifier<ReelUploadState> {
  late final ReelUploadService _uploadService;
  late final ReelsRepository _repository;
  final ImagePicker _picker = ImagePicker();

  @override
  ReelUploadState build() {
    _uploadService = ReelUploadService();
    _repository = ReelsRepository();
    return const ReelUploadState();
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Pick
  // ---------------------------------------------------------------------------

  Future<void> pickVideo() async {
    state = state.copyWith(status: UploadStatus.picking);
    try {
      final xFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 1),
      );
      if (xFile == null) {
        // User cancelled.
        state = state.copyWith(status: UploadStatus.idle);
        return;
      }
      final file = File(xFile.path);
      state = state.copyWith(
        status: UploadStatus.validating,
        pickedFile: file,
      );
      await _validate(file);
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Validate (size guard before compression)
  // ---------------------------------------------------------------------------

  Future<void> _validate(File file) async {
    const maxBytes = 100 * 1024 * 1024;
    final size = await file.length();
    if (size > maxBytes) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(0);
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'Video is too large ($mb MB). Maximum is 100 MB.',
      );
      return;
    }
    state = state.copyWith(status: UploadStatus.trimming, clearError: true);
  }

  // ---------------------------------------------------------------------------
  // Trim
  // ---------------------------------------------------------------------------

  /// Applies the chosen trim range and advances to the preview/metadata form.
  void applyTrim(Duration start, Duration end) {
    state = state.copyWith(
      status: UploadStatus.previewing,
      trimStart: start,
      trimEnd: end,
    );
  }

  /// Skips trim without changing start/end, advances to preview/metadata form.
  void skipTrim() {
    state = state.copyWith(status: UploadStatus.previewing);
  }

  // ---------------------------------------------------------------------------
  // Custom thumbnail
  // ---------------------------------------------------------------------------

  /// Opens the gallery image picker. Sets [customThumbnailFile] on success.
  Future<void> pickThumbnail() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;
    state = state.copyWith(customThumbnailFile: File(xFile.path));
  }

  /// Removes the custom thumbnail so the auto-generated frame is used instead.
  void clearCustomThumbnail() {
    state = state.copyWith(clearCustomThumbnail: true);
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Upload (Bunny CDN → backend metadata)
  // ---------------------------------------------------------------------------

  /// Starts the upload pipeline. Runs in the background so the user can
  /// navigate away from [ReelUploadScreen] while uploading.
  ///
  /// Phase A — Bunny CDN: compress + PUT video + PUT thumbnail.
  ///   On success the CDN URL and metadata are persisted in state immediately,
  ///   so a subsequent backend failure can be retried without re-uploading.
  ///
  /// Phase B — Backend: POST upload_short_video with full metadata.
  Future<void> startUpload({
    required String title,
    String? description,
  }) async {
    if (state.pickedFile == null) return;
    final file = state.pickedFile!;

    state = state.copyWith(
      status: UploadStatus.uploading,
      uploadProgress: 0.0,
      clearError: true,
    );

    try {
      final fileName = 'reel_${DateTime.now().millisecondsSinceEpoch}';

      // Phase A — upload to Bunny CDN (with optional trim).
      final trimStartSec = state.trimStart.inSeconds;
      final trimEnd = state.trimEnd;
      final trimDurationSec = (trimEnd != null && trimEnd > state.trimStart)
          ? (trimEnd - state.trimStart).inSeconds
          : null;

      final result = await _uploadService.uploadVideoComplete(
        file: file,
        fileName: fileName,
        trimStartSec: trimStartSec > 0 ? trimStartSec : null,
        trimDurationSec: trimDurationSec,
        customThumbnailFile: state.customThumbnailFile,
        onProgress: (sent, total) {
          if (total > 0) state = state.copyWith(uploadProgress: sent / total);
        },
      );

      // Persist CDN URLs + metadata in state BEFORE calling the backend.
      // If the backend call below fails, retry() will reuse these values
      // without re-uploading to Bunny.
      state = state.copyWith(
        publicUrl: result.videoUrl,
        thumbnailUrl: result.thumbnailUrl,
        duration: result.duration,
        videoSize: result.videoSize,
      );

      // Phase B — publish metadata to backend.
      await _publishToBackend(title: title, description: description);
    } catch (e) {
      if (kDebugMode) debugPrint('ReelUploadNotifier.startUpload error: $e');
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Calls the backend metadata endpoint using URLs already stored in state.
  ///
  /// Separated from [startUpload] so [retry] can invoke it directly when
  /// the Bunny upload already succeeded — no re-upload needed.
  Future<void> _publishToBackend({
    required String title,
    String? description,
  }) async {
    final videoUrl = state.publicUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      throw Exception('No CDN URL available — cannot publish');
    }

    // Signal the saving phase so the UI can show "Saving reel…" distinctly
    // from the Bunny upload progress.
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final reel = await _repository.uploadReel(
        videoUrl: videoUrl,
        thumbnailUrl: state.thumbnailUrl ?? '',
        title: title,
        description: description,
        duration: state.duration ?? '00:00',
        videoSize: state.videoSize ?? '0',
      );

      state = state.copyWith(
        status: UploadStatus.success,
        uploadProgress: 1.0,
        isSaving: false,
        savedReel: reel,
      );

      // Refresh the feed so the new reel appears immediately.
      ref.read(reelFeedProvider.notifier).loadInitial();
    } catch (e) {
      if (kDebugMode) debugPrint('ReelUploadNotifier._publishToBackend: $e');
      // publicUrl is already in state — retry() will call _publishToBackend
      // again without re-uploading to Bunny.
      state = state.copyWith(
        status: UploadStatus.error,
        isSaving: false,
        errorMessage:
            'Could not save reel. Tap Retry — no re-upload needed.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resets the notifier back to idle, clearing all transient state.
  void reset() => state = const ReelUploadState();

  /// Retry after an error.
  ///
  /// If [state.publicUrl] is already set, the Bunny upload succeeded and only
  /// the backend call needs to be re-attempted.
  /// Otherwise the full pipeline runs from the beginning.
  Future<void> retry({
    required String title,
    String? description,
  }) async {
    if (state.pickedFile == null) {
      reset();
      return;
    }

    state = state.copyWith(
      status: UploadStatus.uploading,
      clearError: true,
      uploadProgress: 0.0,
      compressProgress: 0.0,
    );

    if (state.publicUrl != null && state.publicUrl!.isNotEmpty) {
      // Bunny upload already succeeded — retry only the backend publish.
      await _publishToBackend(title: title, description: description);
    } else {
      // Full retry from compression onwards.
      await startUpload(title: title, description: description);
    }
  }

}
