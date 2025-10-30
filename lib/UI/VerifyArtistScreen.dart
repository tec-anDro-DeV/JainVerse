import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/ArtistVerificationModel.dart';
import 'package:jainverse/services/artist_verification_service.dart';
import 'package:jainverse/services/file_upload_service.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/widgets/verification/document_picker_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

class VerifyArtistScreen extends StatefulWidget {
  const VerifyArtistScreen({super.key});

  @override
  State<VerifyArtistScreen> createState() => _VerifyArtistScreenState();
}

class _VerifyArtistScreenState extends State<VerifyArtistScreen> {
  // Services
  final ArtistVerificationService _verificationService =
      ArtistVerificationService();
  final FileUploadService _fileUploadService = FileUploadService();
  final SharedPref _sharePrefs = SharedPref();

  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  // State variables
  late ModelTheme _sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  String _token = '';
  bool _isLoading = false;

  // Document upload state
  File? _documentFile;
  String? _documentUrl;
  double? _documentUploadProgress;
  bool _isDocumentUploading = false;
  // Previously uploaded (server-side) URLs - shown in "Previously uploaded" section
  String? _previousDocumentUrl;

  // Certificate upload state
  File? _certificateFile;
  String? _certificateUrl;
  double? _certificateUploadProgress;
  bool _isCertificateUploading = false;
  // Previously uploaded (server-side) URLs - shown in "Previously uploaded" section
  String? _previousCertificateUrl;

  // Verification status
  VerificationStatusData? _verificationStatus;

  @override
  void initState() {
    super.initState();
    _audioHandler = const MyApp().called();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      _token = await _sharePrefs.getToken();
      _sharedPreThemeData = await _sharePrefs.getThemeData();

      // Load verification status
      await _loadVerificationStatus();
    } catch (e) {
      _showErrorMessage('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final response = await _verificationService.getVerificationStatus(
        token: _token,
        context: context,
      );

      if (response.status && response.data != null) {
        setState(() {
          _verificationStatus = response.data;

          // Keep server-side previously uploaded URLs separate from the
          // current upload fields. This prevents the upload widgets from
          // being pre-populated with previous uploads when the user wants
          // to submit new files (e.g., on Rejected status).
          _previousDocumentUrl = _verificationStatus?.documentUrl;
          _previousCertificateUrl = _verificationStatus?.certificateUrl;
        });
      }
    } catch (e) {
      print('Error loading verification status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: (_sharedPreThemeData.themeImageBack.isEmpty)
                  ? AssetImage(AppSettings.imageBackground)
                  : AssetImage(_sharedPreThemeData.themeImageBack),
              fit: BoxFit.fill,
            ),
          ),
          child: StreamBuilder<MediaItem?>(
            stream: _audioHandler?.mediaItem,
            builder: (context, snapshot) {
              final bottomPadding = snapshot.hasData
                  ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 40.w
                  : AppSizes.basePadding + 40.w;

              return Column(
                children: [
                  // Header
                  _buildHeader(),

                  // Content
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            padding: EdgeInsets.only(
                              left: 16.w,
                              right: 16.w,
                              bottom: bottomPadding,
                            ),
                            children: [
                              // Status card: only show if the user has previously
                              // requested verification (pending/verified/rejected).
                              if (_verificationStatus != null &&
                                  (_verificationStatus!.isPending ||
                                      _verificationStatus!.isVerified ||
                                      _verificationStatus!.isRejected))
                                _buildStatusCard(),

                              SizedBox(height: 12.w),

                              // Instructions: hide when status is Pending
                              if (!(_verificationStatus?.isPending ??
                                  false)) ...[
                                _buildInstructions(),
                                SizedBox(height: 12.w),
                              ],

                              // Previously uploaded documents (when available).
                              if ((_previousDocumentUrl != null &&
                                      _previousDocumentUrl!.isNotEmpty) ||
                                  (_previousCertificateUrl != null &&
                                      _previousCertificateUrl!.isNotEmpty)) ...[
                                _buildPreviousUploadsSection(),
                                SizedBox(height: 12.w),
                              ],

                              // If status is Pending, do NOT show upload options.
                              // If status is Rejected or there is no status, allow uploads.
                              if (!(_verificationStatus?.isPending ??
                                  false)) ...[
                                // Document picker
                                DocumentPickerWidget(
                                  title: 'Government/Legal Document',
                                  description:
                                      'Upload your government ID, license, or any legal document for identity verification.',
                                  type: DocumentPickerType.document,
                                  selectedFile: _documentFile,
                                  uploadedUrl: _documentUrl,
                                  uploadProgress: _documentUploadProgress,
                                  isUploading: _isDocumentUploading,
                                  onFileSelected: _onDocumentSelected,
                                  onRemoveFile: () =>
                                      _removeFile(isDocument: true),
                                ),

                                SizedBox(height: 2.w),

                                // Certificate picker
                                DocumentPickerWidget(
                                  title: 'License/Ownership Certificate',
                                  description:
                                      'Upload your music license, copyright certificate, or ownership proof documents.',
                                  type: DocumentPickerType.certificate,
                                  selectedFile: _certificateFile,
                                  uploadedUrl: _certificateUrl,
                                  uploadProgress: _certificateUploadProgress,
                                  isUploading: _isCertificateUploading,
                                  onFileSelected: _onCertificateSelected,
                                  onRemoveFile: () =>
                                      _removeFile(isDocument: false),
                                ),

                                SizedBox(height: 16.w),
                              ],

                              SizedBox(height: 16.w),

                              // Submit button
                              _buildSubmitButton(),

                              SizedBox(height: 20.w),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back,
              color: appColors().colorText,
              size: 24.w,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Request as Artist',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 22.sp,
                color: appColors().colorText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _verificationStatus!;
    Color statusColor;
    IconData statusIcon;

    switch (status.verifyStatus) {
      case 'P':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'A':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'R':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'N':
        statusColor = Colors.blueGrey;
        statusIcon = Icons.cloud_upload_outlined;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: appColors().colorBackEditText,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification Status',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: appColors().colorTextHead,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height: 4.w),
                Text(
                  status.statusDisplayText,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (status.isRejected && status.rejectionReason != null) ...[
                  SizedBox(height: 8.w),
                  Text(
                    'Reason: ${status.rejectionReason}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: appColors().colorText,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
                if (status.isNotUploaded) ...[
                  SizedBox(height: 8.w),
                  Text(
                    'You haven\'t uploaded any verification documents yet. Please submit the required files below to begin the review.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: appColors().colorText,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
                if (status.isVerified) ...[
                  SizedBox(height: 8.w),
                  Text(
                    'Congratulations! Your artist profile has been verified successfully.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: appColors().primaryColorApp,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: appColors().primaryColorApp.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: appColors().primaryColorApp.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: appColors().primaryColorApp,
                size: 20.w,
              ),
              SizedBox(width: 8.w),
              Text(
                'Verification Requirements',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: appColors().primaryColorApp,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          SizedBox(height: 5.w),
          Text(
            '• Upload clear, high-quality images or documents\n'
            '• Ensure all text is readable and not blurred\n'
            '• Accepted formats: JPG, PNG, WEBP, PDF, DOC, TXT\n'
            '• Maximum file size: 2MB per file\n'
            '• Both documents are required for verification',
            style: TextStyle(
              fontSize: 13.sp,
              color: appColors().colorText,
              fontFamily: 'Poppins',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousUploadsSection() {
    final docUrl = _previousDocumentUrl;
    final certUrl = _previousCertificateUrl;

    if ((docUrl == null || docUrl.isEmpty) &&
        (certUrl == null || certUrl.isEmpty)) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: appColors().colorBackEditText,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: appColors().gray[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Previously uploaded documents',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: appColors().colorTextHead,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 12.w),
          if (docUrl != null && docUrl.isNotEmpty) ...[
            _buildUploadedFileTile(
              label: 'Government/Legal Document',
              url: docUrl,
            ),
            SizedBox(height: 8.w),
          ],
          if (certUrl != null && certUrl.isNotEmpty) ...[
            _buildUploadedFileTile(
              label: 'License/Ownership Certificate',
              url: certUrl,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadedFileTile({required String label, required String url}) {
    final isImage = _isImageUrl(url);

    return Row(
      children: [
        if (isImage)
          GestureDetector(
            onTap: () => _showImagePreview(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.network(
                url,
                width: 64.w,
                height: 64.w,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: 64.w,
                  height: 64.w,
                  color: appColors().gray[300],
                  child: Icon(Icons.broken_image, color: Colors.white),
                ),
              ),
            ),
          )
        else
          _buildExtensionIcon(url),

        SizedBox(width: 12.w),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: appColors().colorTextHead,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 6.w),
              Text(
                // Don't show the raw link; display a friendly filename instead.
                Uri.tryParse(url)?.pathSegments.last ?? 'Uploaded file',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: appColors().colorText,
                  fontFamily: 'Poppins',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        SizedBox(width: 8.w),

        Column(
          children: [
            IconButton(
              onPressed: () => _openUrl(url),
              icon: Icon(Icons.open_in_new, color: appColors().primaryColorApp),
              tooltip: 'Open',
            ),
          ],
        ),
      ],
    );
  }

  bool _isImageUrl(String url) {
    final ext = url.toLowerCase().split('?').first.split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
  }

  Widget _buildExtensionIcon(String url) {
    final ext = url.toLowerCase().split('?').first.split('.').last;

    // Use app primary color as background for all extension icons per request
    final Color bgColor = appColors().primaryColorApp;
    IconData icon = Icons.insert_drive_file;

    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        break;
      case 'txt':
        icon = Icons.text_snippet;
        break;
      case 'xls':
      case 'xlsx':
      case 'csv':
        icon = Icons.grid_on;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    // For unknown types show a badge with extension letters if icon is generic
    if (icon == Icons.insert_drive_file) {
      final label = ext.length <= 4
          ? ext.toUpperCase()
          : ext.substring(0, 4).toUpperCase();
      return Container(
        width: 64.w,
        height: 64.w,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
      );
    }

    return Container(
      width: 64.w,
      height: 64.w,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(icon, color: Colors.white, size: 28.w),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        _showErrorMessage('Invalid URL');
        return;
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorMessage('Cannot open URL');
      }
    } catch (e) {
      _showErrorMessage('Error opening URL: $e');
    }
  }

  void _showImagePreview(String url) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: EdgeInsets.all(16.w),
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Container(
                  color: appColors().gray[300],
                  child: Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    final status = _verificationStatus;
    final canSubmit = _documentUrl != null && _certificateUrl != null;
    final isUploading = _isDocumentUploading || _isCertificateUploading;
    final isAlreadyVerified = status?.isVerified ?? false;
    final isUnderReview = status?.isPending ?? false;

    final isButtonEnabled =
        canSubmit &&
        !isUploading &&
        !_isLoading &&
        !isAlreadyVerified &&
        !isUnderReview;

    return SizedBox(
      width: double.infinity,
      height: 56.w,
      child: ElevatedButton(
        onPressed: isButtonEnabled ? _submitVerification : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: appColors().primaryColorApp,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 0,
          disabledBackgroundColor: appColors().gray[400],
        ),
        child: _isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.w,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                isAlreadyVerified
                    ? 'Already Verified'
                    : isUnderReview
                    ? 'Under Review'
                    : canSubmit
                    ? 'Submit Verification'
                    : 'Upload Both Documents',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
      ),
    );
  }

  void _onDocumentSelected(File file) {
    setState(() {
      _documentFile = file;
      _documentUrl = null;
    });
    _uploadFile(file, isDocument: true);
  }

  void _onCertificateSelected(File file) {
    setState(() {
      _certificateFile = file;
      _certificateUrl = null;
    });
    _uploadFile(file, isDocument: false);
  }

  Future<void> _uploadFile(File file, {required bool isDocument}) async {
    try {
      setState(() {
        if (isDocument) {
          _isDocumentUploading = true;
          _documentUploadProgress = 0.0;
        } else {
          _isCertificateUploading = true;
          _certificateUploadProgress = 0.0;
        }
      });

      final filename =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final contentType = _fileUploadService.getMimeType(filename);

      final publicUrl = await _fileUploadService.uploadFileComplete(
        file: file,
        filename: filename,
        contentType: contentType,
        token: _token,
        maxRetries: 5, // More retries for better reliability on mobile networks
        onProgress: (received, total) {
          final progress = received / total;
          setState(() {
            if (isDocument) {
              _documentUploadProgress = progress;
            } else {
              _certificateUploadProgress = progress;
            }
          });
        },
      );

      setState(() {
        if (isDocument) {
          _documentUrl = publicUrl;
          _isDocumentUploading = false;
        } else {
          _certificateUrl = publicUrl;
          _isCertificateUploading = false;
        }
      });

      _showSuccessMessage(
        '${isDocument ? 'Document' : 'Certificate'} uploaded successfully!',
      );
    } catch (e) {
      setState(() {
        if (isDocument) {
          _isDocumentUploading = false;
          _documentFile = null;
        } else {
          _isCertificateUploading = false;
          _certificateFile = null;
        }
      });
      _showErrorMessage('Upload failed: $e');
    }
  }

  void _removeFile({required bool isDocument}) {
    setState(() {
      if (isDocument) {
        _documentFile = null;
        _documentUrl = null;
        _documentUploadProgress = null;
      } else {
        _certificateFile = null;
        _certificateUrl = null;
        _certificateUploadProgress = null;
      }
    });
  }

  Future<void> _submitVerification() async {
    if (_documentUrl == null || _certificateUrl == null) {
      _showErrorMessage('Please upload both documents before submitting.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _verificationService.submitVerificationRequest(
        documentUrl: _documentUrl!,
        certificateUrl: _certificateUrl!,
        token: _token,
        context: context,
      );

      if (response.status) {
        _showSuccessMessage('Verification request submitted successfully!');

        // Refresh verification status
        await _loadVerificationStatus();

        await _showVerificationReviewDialog();
      } else {
        _showErrorMessage(response.message);
      }
    } catch (e) {
      _showErrorMessage('Submission failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      timeInSecForIosWeb: 1,
      backgroundColor: appColors().primaryColorApp,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  void _showErrorMessage(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      timeInSecForIosWeb: 2,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  Future<void> _showVerificationReviewDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          contentPadding: EdgeInsets.fromLTRB(24.w, 24.w, 24.w, 16.w),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: appColors().primaryColorApp.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(10.w),
                    child: Icon(
                      Icons.info_outline,
                      color: appColors().primaryColorApp,
                      size: 24.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification in Progress',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            color: appColors().colorTextHead,
                          ),
                        ),
                        SizedBox(height: 8.w),
                        Text(
                          'Thanks for submitting your documents. Our team will review your information, which may take 5-10 working days. You\'ll receive an update once the review is complete.',
                          style: TextStyle(
                            fontSize: 14.sp,
                            height: 1.4,
                            color: appColors().colorText,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(
                'Close',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: appColors().primaryColorApp,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
