import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/videoplayer/models/report_option.dart';
import 'package:jainverse/videoplayer/services/video_report_service.dart';

/// Multi-step modal for reporting a video
/// Step 1: Select report reason from radio buttons
/// Step 2: Add optional comment and submit
class VideoReportModal extends StatefulWidget {
  final int videoId;
  final String videoTitle;

  const VideoReportModal({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  State<VideoReportModal> createState() => _VideoReportModalState();
}

class _VideoReportModalState extends State<VideoReportModal> {
  final VideoReportService _reportService = VideoReportService();
  final TextEditingController _commentController = TextEditingController();

  // State variables
  int _currentStep = 0; // 0 = select reason, 1 = add comment
  List<ReportOption> _reportOptions = [];
  ReportOption? _selectedOption;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReportOptions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReportOptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final options = await _reportService.fetchReportOptions();
      if (mounted) {
        setState(() {
          _reportOptions = options;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load report options. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitReport() async {
    if (_selectedOption == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await _reportService.reportVideo(
        videoId: widget.videoId,
        reportId: _selectedOption!.id,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Video reported successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Failed to submit report. Please try again.';
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to submit report. Please try again.';
          _isSubmitting = false;
        });
      }
    }
  }

  void _goToNextStep() {
    if (_selectedOption != null) {
      setState(() {
        _currentStep = 1;
      });
    }
  }

  void _goToPreviousStep() {
    setState(() {
      _currentStep = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Row(
              children: [
                if (_currentStep == 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _isSubmitting ? null : _goToPreviousStep,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_currentStep == 1) SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    _currentStep == 0 ? 'Report Video' : 'Additional Comments',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null && _reportOptions.isEmpty
                ? _buildErrorState()
                : _currentStep == 0
                ? _buildStepOne()
                : _buildStepTwo(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: EdgeInsets.all(40.w),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48.w, color: Colors.red),
          SizedBox(height: 16.h),
          Text(
            _errorMessage ?? 'Something went wrong',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: _loadReportOptions,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepOne() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Subtitle
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          width: double.infinity,
          child: Text(
            'Select the reason for reporting this video:',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
          ),
        ),

        // Report options list
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            itemCount: _reportOptions.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1.h, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final option = _reportOptions[index];
              final isSelected = _selectedOption?.id == option.id;

              return RadioListTile<int>(
                value: option.id,
                groupValue: _selectedOption?.id,
                onChanged: (value) {
                  setState(() {
                    _selectedOption = option;
                  });
                },
                title: Text(
                  option.reportType,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                activeColor: Theme.of(context).primaryColor,
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
        ),

        // Next button
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedOption != null ? _goToNextStep : null,
              style: ButtonStyle(
                padding: MaterialStateProperty.all(
                  EdgeInsets.symmetric(vertical: 14.h),
                ),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                // Background: primary when enabled, grey when disabled
                backgroundColor: MaterialStateProperty.resolveWith<Color?>((
                  states,
                ) {
                  if (states.contains(MaterialState.disabled)) {
                    return Colors.grey.shade300;
                  }
                  return Theme.of(context).primaryColor;
                }),
                // Foreground/text: white when enabled, dark grey when disabled
                foregroundColor: MaterialStateProperty.resolveWith<Color?>((
                  states,
                ) {
                  if (states.contains(MaterialState.disabled)) {
                    return Colors.grey.shade700;
                  }
                  return Colors.white;
                }),
              ),
              child: Text(
                'Next',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selected reason display
        Container(
          margin: EdgeInsets.all(20.w),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.flag,
                size: 20.w,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _selectedOption?.reportType ?? '',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Comment input
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: TextField(
            controller: _commentController,
            maxLines: 5,
            maxLength: 500,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              hintText: 'Add additional details (optional)...',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14.sp,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.all(12.w),
            ),
          ),
        ),

        // Error message
        if (_errorMessage != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red, fontSize: 13.sp),
            ),
          ),

        // Submit button
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                backgroundColor: appColors().primaryColorApp,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      height: 20.h,
                      width: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Submit Report',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
