import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/state/reel_upload_state.dart';
import 'package:jainverse/features/reels/presentation/widgets/reel_trim_widget.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';

const _kPrimary = Color(0xFFF47B36);

/// Full upload flow: pick → preview → compress → upload → save.
///
/// The upload itself continues in the background via [reelUploadProvider]
/// even if this screen is popped.
class ReelUploadScreen extends ConsumerStatefulWidget {
  const ReelUploadScreen({super.key});

  @override
  ConsumerState<ReelUploadScreen> createState() => _ReelUploadScreenState();
}

class _ReelUploadScreenState extends ConsumerState<ReelUploadScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  VideoPlayerController? _previewController;
  VoidCallback? _trimLoopListener;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    MusicPlayerStateManager().hideMiniPlayerOnly('reel_upload');
    // Defer the reset until after the first frame to avoid Riverpod's
    // "modified provider during build" assertion. This clears any leftover
    // state from a previous visit so the user always lands on the pick-video
    // prompt. The guard keeps an in-progress background upload alive.
    Future(() {
      if (!mounted) return;
      final uploadState = ref.read(reelUploadProvider);
      if (!uploadState.isActive) {
        ref.read(reelUploadProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    MusicPlayerStateManager().showMiniPlayerForPage('reel_upload');
    _titleController.dispose();
    _descController.dispose();
    if (_trimLoopListener != null) {
      _previewController?.removeListener(_trimLoopListener!);
    }
    _previewController?.pause();
    _previewController?.dispose();
    super.dispose();
  }

  void _disposePreviewController() {
    if (_trimLoopListener != null) {
      _previewController?.removeListener(_trimLoopListener!);
      _trimLoopListener = null;
    }
    if (_previewController != null) {
      try {
        _previewController?.pause();
      } catch (_) {}
      try {
        _previewController?.dispose();
      } catch (_) {}
      _previewController = null;
      if (mounted) setState(() {});
    }
  }

  Future<void> _buildPreviewController(
    String path, {
    Duration trimStart = Duration.zero,
    Duration? trimEnd,
  }) async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      if (_trimLoopListener != null) {
        _previewController?.removeListener(_trimLoopListener!);
        _trimLoopListener = null;
      }
      await _previewController?.pause();
      await _previewController?.dispose();
      _previewController = null;
      if (mounted) setState(() {});
      final c = VideoPlayerController.file(File(path));
      await c.initialize();
      final hasTrim = trimEnd != null && trimEnd > trimStart;
      if (hasTrim) {
        // Loop within the trimmed range instead of the whole video.
        _trimLoopListener = () {
          if (c.value.position >= trimEnd) {
            c.seekTo(trimStart);
          }
        };
        c.addListener(_trimLoopListener!);
        await c.setLooping(false);
      } else {
        await c.setLooping(true);
      }
      await c.seekTo(trimStart);
      await c.play();
      if (mounted) setState(() => _previewController = c);
    } finally {
      _isInitializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(reelUploadProvider);

    ref.listen(reelUploadProvider, (prev, next) {
      if (next.status == UploadStatus.previewing &&
          prev?.status != UploadStatus.previewing &&
          next.pickedFile != null) {
        _buildPreviewController(
          next.pickedFile!.path,
          trimStart: next.trimStart,
          trimEnd: next.trimEnd,
        );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: !upload.isActive,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            // Ensure preview controller is disposed if the user navigates back
            // to avoid leaving platform decoders alive.
            _disposePreviewController();
          }
          if (!didPop && upload.isActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Upload in progress — please wait.'),
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            title: Text(
              'New Reel',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: Colors.grey.shade200),
            ),
          ),
          body: Padding(
            padding: EdgeInsets.only(bottom: 100.h), // nav bar height
            child: _buildBody(upload),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ReelUploadState upload) {
    return switch (upload.status) {
      UploadStatus.idle ||
      UploadStatus.picking => _buildPickPrompt(upload.errorMessage),
      UploadStatus.validating => _buildSpinner('Checking video…'),
      UploadStatus.trimming => ReelTrimWidget(
        file: upload.pickedFile!,
        isTrimRequired: upload.isTrimRequired,
        onApply: (s, e) =>
            ref.read(reelUploadProvider.notifier).applyTrim(s, e),
        onSkip: () => ref.read(reelUploadProvider.notifier).skipTrim(),
      ),
      UploadStatus.previewing => _buildPreview(upload),
      UploadStatus.compressing => _buildProgress(
        label: 'Compressing…',
        progress: upload.compressProgress,
      ),
      UploadStatus.uploading =>
        upload.isSaving
            ? _buildProgress(
                label: 'Saving reel…',
                progress: 1.0,
                sublabel: 'Almost done — finalising on server.',
              )
            : _buildProgress(
                label:
                    'Uploading… ${(upload.uploadProgress * 100).toStringAsFixed(0)}%',
                progress: upload.uploadProgress,
              ),
      UploadStatus.success => _buildSuccess(),
      UploadStatus.error => _buildError(upload.errorMessage),
    };
  }

  // ── Pick prompt ─────────────────────────────────────────────────────────────

  Widget _buildPickPrompt(String? errorMessage) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_rounded, color: Colors.grey.shade300, size: 80.w),
          SizedBox(height: 24.h),
          Text(
            'Share a short video',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '30 sec – 3 min · MP4, MOV',
            style: TextStyle(color: Colors.black45, fontSize: 13.sp),
          ),
          if (errorMessage != null) ...[
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade400,
                    size: 16.w,
                  ),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 32.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(reelUploadProvider.notifier).recordVideo(),
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Text('Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(reelUploadProvider.notifier).pickVideo(),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview + metadata form ──────────────────────────────────────────────────

  Widget _buildPreview(ReelUploadState upload) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            child:
                _previewController != null &&
                    _previewController!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _previewController!.value.size.width,
                      height: _previewController!.value.size.height,
                      child: VideoPlayer(_previewController!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: _kPrimary),
                  ),
          ),
        ),
        Container(
          color: Colors.grey.shade50,
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                style: TextStyle(color: Colors.black87, fontSize: 14.sp),
                decoration: _inputDecoration('Title *'),
                maxLength: 100,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _descController,
                style: TextStyle(color: Colors.black87, fontSize: 14.sp),
                decoration: _inputDecoration('Description (optional)'),
                maxLines: 2,
                maxLength: 300,
              ),
              SizedBox(height: 12.h),
              _buildThumbnailPicker(upload),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Dispose preview controller before resetting provider
                        // to avoid leaving native resources alive.
                        _disposePreviewController();
                        ref.read(reelUploadProvider.notifier).reset();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: const Text('Change Video'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _titleController.text.trim().isEmpty
                          ? null
                          : _startUpload,
                      icon: const Icon(Icons.upload_rounded),
                      label: const Text('Post Reel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startUpload() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    // Release the preview player's hardware decoder buffers before the native
    // transcoder starts. Both compete for Android's ImageReader surface buffer
    // pool; leaving the preview controller alive causes the transcoder to stall
    // indefinitely (State.Wait on both audio + video pipelines).
    _disposePreviewController();

    ref
        .read(reelUploadProvider.notifier)
        .startUpload(title: title, description: _descController.text.trim());
  }

  // ── Thumbnail picker ─────────────────────────────────────────────────────────

  Widget _buildThumbnailPicker(ReelUploadState upload) {
    final file = upload.customThumbnailFile;
    return Row(
      children: [
        GestureDetector(
          onTap: () => ref.read(reelUploadProvider.notifier).pickThumbnail(),
          child: Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: file != null ? _kPrimary : Colors.grey.shade300,
              ),
              color: Colors.grey.shade100,
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7.r),
                    child: Image.file(file, fit: BoxFit.cover),
                  )
                : Icon(
                    Icons.add_photo_alternate_rounded,
                    color: Colors.grey.shade400,
                    size: 24.w,
                  ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cover photo',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                file != null
                    ? 'Custom thumbnail selected'
                    : 'Auto-generated from video',
                style: TextStyle(fontSize: 11.sp, color: Colors.black45),
              ),
            ],
          ),
        ),
        if (file != null)
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18.w, color: Colors.black38),
            onPressed: () =>
                ref.read(reelUploadProvider.notifier).clearCustomThumbnail(),
          ),
      ],
    );
  }

  // ── Progress ────────────────────────────────────────────────────────────────

  Widget _buildProgress({
    required String label,
    required double progress,
    String? sublabel,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: progress > 0 && progress < 1.0 ? progress : null,
              color: _kPrimary,
              strokeWidth: 3.w,
            ),
            SizedBox(height: 24.h),
            Text(
              label,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              sublabel ??
                  'You can go back — upload continues in the background.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }

  // ── Success ─────────────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade500,
              size: 72.w,
            ),
            SizedBox(height: 20.h),
            Text(
              'Reel posted!',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Your reel is live on the feed.',
              style: TextStyle(color: Colors.black45, fontSize: 13.sp),
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: () {
                ref.read(reelUploadProvider.notifier).reset();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: const Text('Back to Reels'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────────

  Widget _buildError(String? message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red.shade400, size: 60.w),
            SizedBox(height: 16.h),
            Text(
              'Upload failed',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: 8.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13.sp),
              ),
            ],
            SizedBox(height: 28.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      ref.read(reelUploadProvider.notifier).reset(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black54,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: const Text('Start Over'),
                ),
                SizedBox(width: 12.w),
                ElevatedButton.icon(
                  onPressed: () => ref
                      .read(reelUploadProvider.notifier)
                      .retry(
                        title: _titleController.text.trim(),
                        description: _descController.text.trim(),
                      ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Spinner ──────────────────────────────────────────────────────────────────

  Widget _buildSpinner(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.w),
          SizedBox(height: 16.h),
          Text(
            label,
            style: TextStyle(color: Colors.black54, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.black38, fontSize: 14.sp),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: _kPrimary),
    ),
    counterStyle: TextStyle(color: Colors.black38, fontSize: 11.sp),
  );
}
