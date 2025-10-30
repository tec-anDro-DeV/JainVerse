import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/services/file_upload_service.dart';

enum DocumentPickerType { document, certificate }

class DocumentPickerWidget extends StatefulWidget {
  final String title;
  final String description;
  final DocumentPickerType type;
  final File? selectedFile;
  final String? uploadedUrl;
  final double? uploadProgress;
  final bool isUploading;
  final Function(File) onFileSelected;
  final VoidCallback? onRemoveFile;

  const DocumentPickerWidget({
    super.key,
    required this.title,
    required this.description,
    required this.type,
    this.selectedFile,
    this.uploadedUrl,
    this.uploadProgress,
    this.isUploading = false,
    required this.onFileSelected,
    this.onRemoveFile,
  });

  @override
  State<DocumentPickerWidget> createState() => _DocumentPickerWidgetState();
}

class _DocumentPickerWidgetState extends State<DocumentPickerWidget> {
  final ImagePicker _imagePicker = ImagePicker();
  final FileUploadService _fileUploadService = FileUploadService();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: appColors().colorBackEditText,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors().gray[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: appColors().colorTextHead,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  widget.description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: appColors().colorText,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),

          // File selection area
          if (widget.selectedFile == null && widget.uploadedUrl == null)
            _buildFileSelectionArea()
          else
            _buildSelectedFileArea(),

          // Upload progress
          if (widget.isUploading && widget.uploadProgress != null)
            _buildUploadProgress(),
        ],
      ),
    );
  }

  Widget _buildFileSelectionArea() {
    return Container(
      margin: EdgeInsets.all(12.w),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        border: Border.all(
          color: appColors().gray[300]!,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 48.w,
            color: appColors().gray[500],
          ),
          SizedBox(height: 8.w),
          Text(
            'Select ${widget.type == DocumentPickerType.document ? 'Document' : 'Certificate'}',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: appColors().colorTextHead,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 2.w),
          Text(
            'jpg, jpeg, png, webp, pdf, doc, txt',
            style: TextStyle(
              fontSize: 12.sp,
              color: appColors().gray[500],
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 16.w),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPickerButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: _pickFromCamera,
              ),
              _buildPickerButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: _pickFromGallery,
              ),
              _buildPickerButton(
                icon: Icons.folder_outlined,
                label: 'Files',
                onTap: _pickFromFiles,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFileArea() {
    final file = widget.selectedFile;
    final isUploaded = widget.uploadedUrl != null;
    // Determine if the file/url points to an image for preview
    bool isImageFile() {
      final path = file?.path ?? widget.uploadedUrl ?? '';
      final ext = path.toLowerCase().split('.').last;
      return ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
    }

    final showImagePreview = isImageFile();

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isUploaded
            ? appColors().primaryColorApp.withOpacity(0.1)
            : appColors().gray[100],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isUploaded
              ? appColors().primaryColorApp.withOpacity(0.3)
              : appColors().gray[300]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Image preview or file icon
          if (showImagePreview)
            GestureDetector(
              onTap: () {
                // Show full screen preview
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: InteractiveViewer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: file != null
                            ? Image.file(File(file.path))
                            : Image.network(widget.uploadedUrl ?? ''),
                      ),
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: file != null
                    ? Image.file(
                        File(file.path),
                        width: 72.w,
                        height: 72.w,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        widget.uploadedUrl ?? '',
                        width: 72.w,
                        height: 72.w,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 72.w,
                          height: 72.w,
                          color: appColors().gray[300],
                          child: Icon(Icons.broken_image, color: Colors.white),
                        ),
                      ),
              ),
            )
          else
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: isUploaded
                    ? appColors().primaryColorApp
                    : appColors().gray[400],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                _getFileIcon(file?.path ?? ''),
                color: Colors.white,
                size: 24.w,
              ),
            ),

          SizedBox(width: 12.w),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file?.path.split('/').last ?? 'Uploaded File',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: appColors().colorTextHead,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    if (file != null) ...[
                      Text(
                        _fileUploadService.getFileTypeDescription(file.path),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: appColors().gray[600],
                          fontFamily: 'Poppins',
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(color: appColors().gray[600]),
                      ),
                      FutureBuilder<int>(
                        future: file.length(),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.hasData
                                ? _fileUploadService.formatFileSize(
                                    snapshot.data!,
                                  )
                                : '...',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: appColors().gray[600],
                              fontFamily: 'Poppins',
                            ),
                          );
                        },
                      ),
                    ],
                    if (isUploaded)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: appColors().primaryColorApp,
                            size: 16.w,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Uploaded',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: appColors().primaryColorApp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Remove button
          if (widget.onRemoveFile != null && !widget.isUploading)
            IconButton(
              onPressed: widget.onRemoveFile,
              icon: Icon(Icons.close, color: appColors().gray[600], size: 20.w),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploading...',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: appColors().primaryColorApp,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                '${(widget.uploadProgress! * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: appColors().primaryColorApp,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          LinearProgressIndicator(
            value: widget.uploadProgress,
            backgroundColor: appColors().gray[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              appColors().primaryColorApp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: appColors().primaryColorApp.withOpacity(0.1),
              borderRadius: BorderRadius.circular(28.r),
              border: Border.all(
                color: appColors().primaryColorApp.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: appColors().primaryColorApp, size: 24.w),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: appColors().colorText,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (_fileUploadService.isAllowedFileType(file.path)) {
          widget.onFileSelected(file);
        } else {
          _showErrorSnackBar(
            'File type not allowed. Please select a valid document.',
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image from camera: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (_fileUploadService.isAllowedFileType(file.path)) {
          widget.onFileSelected(file);
        } else {
          _showErrorSnackBar(
            'File type not allowed. Please select a valid document.',
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image from gallery: $e');
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'pdf',
          'doc',
          'docx',
          'txt',
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        widget.onFileSelected(file);
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
