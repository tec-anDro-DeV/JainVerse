import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/state/reel_upload_state.dart';

/// Full upload flow: pick → preview → compress → upload.
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
  bool _isInitializing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _previewController?.pause();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _buildPreviewController(String path) async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      await _previewController?.pause();
      await _previewController?.dispose();
      _previewController = null;
      if (mounted) setState(() {});
      final c = VideoPlayerController.file(File(path));
      await c.initialize();
      await c.setLooping(true);
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
        _buildPreviewController(next.pickedFile!.path);
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
          if (!didPop && upload.isActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Upload in progress — please wait.'),
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text('New Reel', style: TextStyle(fontSize: 16.sp)),
            elevation: 0,
          ),
          body: _buildBody(upload),
        ),
      ),
    );
  }

  Widget _buildBody(ReelUploadState upload) {
    return switch (upload.status) {
      UploadStatus.idle || UploadStatus.picking => _buildPickPrompt(),
      UploadStatus.validating => _buildSpinner('Checking video…'),
      UploadStatus.previewing => _buildPreview(upload),
      UploadStatus.compressing => _buildProgress(
          label: 'Compressing…',
          progress: upload.compressProgress,
        ),
      UploadStatus.uploading => _buildProgress(
          label:
              'Uploading… ${(upload.uploadProgress * 100).toStringAsFixed(0)}%',
          progress: upload.uploadProgress,
        ),
      UploadStatus.success => _buildSuccess(),
      UploadStatus.error => _buildError(upload.errorMessage),
    };
  }

  // ── Pick prompt ────────────────────────────────────────────────────────────

  Widget _buildPickPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_rounded, color: Colors.white38, size: 80.w),
          SizedBox(height: 24.h),
          Text(
            'Share a short video',
            style: TextStyle(color: Colors.white, fontSize: 18.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Up to 60 seconds · MP4, MOV',
            style: TextStyle(color: Colors.white54, fontSize: 13.sp),
          ),
          SizedBox(height: 32.h),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(reelUploadProvider.notifier).pickVideo(),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Pick from Gallery'),
            style: ElevatedButton.styleFrom(
              padding:
                  EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview + metadata form ────────────────────────────────────────────────

  Widget _buildPreview(ReelUploadState upload) {
    return Column(
      children: [
        Expanded(
          child: _previewController != null &&
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
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
        ),
        Container(
          color: Colors.grey[900],
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: _inputDecoration('Title *'),
                maxLength: 100,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _descController,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: _inputDecoration('Description (optional)'),
                maxLines: 2,
                maxLength: 300,
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          ref.read(reelUploadProvider.notifier).reset(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
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
    ref.read(reelUploadProvider.notifier).startUpload(
          title: title,
          description: _descController.text.trim(),
        );
  }

  // ── Progress ───────────────────────────────────────────────────────────────

  Widget _buildProgress({required String label, required double progress}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              color: Colors.white,
              strokeWidth: 3.w,
            ),
            SizedBox(height: 24.h),
            Text(label,
                style: TextStyle(color: Colors.white, fontSize: 15.sp)),
            SizedBox(height: 8.h),
            Text(
              'You can go back — upload continues in the background.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }

  // ── Success ────────────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 72.w),
            SizedBox(height: 20.h),
            Text(
              'Reel posted!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: () {
                ref.read(reelUploadProvider.notifier).reset();
                Navigator.of(context).pop();
              },
              child: const Text('Back to Reels'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(String? message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red, size: 60.w),
            SizedBox(height: 16.h),
            Text(
              'Upload failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: 8.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13.sp),
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
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Start Over'),
                ),
                SizedBox(width: 12.w),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(reelUploadProvider.notifier).retry(
                            title: _titleController.text.trim(),
                            description: _descController.text.trim(),
                          ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Spinner ────────────────────────────────────────────────────────────────

  Widget _buildSpinner(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2.w),
          SizedBox(height: 16.h),
          Text(label,
              style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
        counterStyle: TextStyle(color: Colors.white38, fontSize: 11.sp),
      );
}
