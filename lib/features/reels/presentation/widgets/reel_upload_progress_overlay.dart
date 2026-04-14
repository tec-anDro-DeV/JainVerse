import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/state/reel_upload_state.dart';

/// Floating badge that shows background upload progress.
/// Rendered inside the [ReelsScreen] Stack — visible even after the user
/// dismisses [ReelUploadScreen].
class ReelUploadProgressOverlay extends ConsumerWidget {
  const ReelUploadProgressOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(reelUploadProvider);

    if (!upload.isActive &&
        upload.status != UploadStatus.success &&
        upload.status != UploadStatus.error) {
      return const SizedBox.shrink();
    }

    return _Badge(upload: upload);
  }
}

class _Badge extends StatelessWidget {
  final ReelUploadState upload;
  const _Badge({required this.upload});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (upload.status) {
      UploadStatus.compressing => (
          Icons.compress_rounded,
          'Compressing…',
          Colors.orange,
        ),
      UploadStatus.uploading => (
          Icons.cloud_upload_rounded,
          '${(upload.uploadProgress * 100).toStringAsFixed(0)}%',
          Colors.blue,
        ),
      UploadStatus.success => (
          Icons.check_circle_rounded,
          'Uploaded!',
          Colors.green,
        ),
      UploadStatus.error => (
          Icons.error_rounded,
          'Failed',
          Colors.red,
        ),
      _ => (Icons.hourglass_top_rounded, '…', Colors.grey),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          upload.status == UploadStatus.uploading
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                    value: upload.uploadProgress,
                    strokeWidth: 2.w,
                    color: color,
                  ),
                )
              : Icon(icon, color: color, size: 18.w),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
