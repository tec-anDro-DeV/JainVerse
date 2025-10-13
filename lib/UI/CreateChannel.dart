import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img_pkg;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/presenters/channel_presenter.dart';

class CreateChannel extends StatefulWidget {
  const CreateChannel({super.key});

  @override
  State<CreateChannel> createState() => _CreateChannelState();
}

class _CreateChannelState extends State<CreateChannel>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  bool _isCreating = false;
  final TextEditingController _handleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _nameValid = true;
  bool _handleValid = true;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _handleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _slideController.dispose();
    _nameFocus.dispose();
    _handleFocus.dispose();
    super.dispose();
  }

  Future<void> _imgFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (pickedFile == null) return;
      File file = File(pickedFile.path);
      final File? cropped = await _cropImage(file);
      if (cropped != null) {
        final File? finalFile = await _showFlipPreview(cropped);
        if (finalFile != null) setState(() => _selectedImage = finalFile);
      }
    } catch (e) {
      _showErrorSnackbar('Camera error: $e');
    }
  }

  Future<void> _openGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (pickedFile == null) return;
      File file = File(pickedFile.path);
      final File? cropped = await _cropImage(file);
      if (cropped != null) {
        final File? finalFile = await _showFlipPreview(cropped);
        if (finalFile != null) setState(() => _selectedImage = finalFile);
      }
    } catch (e) {
      _showErrorSnackbar('Gallery error: $e');
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Photo',
            toolbarColor: appColors().primaryColorApp,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Edit Photo', aspectRatioLockEnabled: true),
        ],
        compressQuality: 90,
      );
      if (croppedFile != null) return File(croppedFile.path);
    } catch (e) {
      // ignore
    }
    return null;
  }

  Future<File?> _showFlipPreview(File imageFile) async {
    try {
      final Uint8List originalBytes = await imageFile.readAsBytes();
      Uint8List previewBytes = originalBytes;
      bool isFlipped = false;
      bool isProcessing = false;

      final File? result = await showDialog<File?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx2, setStateDialog) {
              return AlertDialog(
                insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.w),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.w),
                      constraints: BoxConstraints(
                        maxHeight: 420.w,
                        maxWidth: MediaQuery.of(context).size.width * 0.9,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.w),
                            child: Image.memory(
                              previewBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                          if (isProcessing)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12.w),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              if (isProcessing) return;
                              setStateDialog(() => isProcessing = true);
                              try {
                                if (!isFlipped) {
                                  final List<int> flipped = await compute(
                                    _flipImageBytes,
                                    originalBytes,
                                  );
                                  previewBytes = Uint8List.fromList(flipped);
                                  isFlipped = true;
                                } else {
                                  previewBytes = originalBytes;
                                  isFlipped = false;
                                }
                                setStateDialog(() {});
                              } catch (_) {}
                              setStateDialog(() => isProcessing = false);
                            },
                            icon: Icon(Icons.flip, size: 20.w),
                            label: Text(isFlipped ? 'Unflip' : 'Flip'),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx2).pop(null),
                                child: const Text('Cancel'),
                              ),
                              SizedBox(width: 8.w),
                              ElevatedButton(
                                onPressed: () async {
                                  final tempDir = Directory.systemTemp;
                                  final f = await File(
                                    '${tempDir.path}/channel_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                  ).writeAsBytes(previewBytes);
                                  Navigator.of(ctx2).pop(f);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appColors().primaryColorApp,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.w),
                                  ),
                                ),
                                child: const Text('Use'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  static Future<List<int>> _flipImageBytes(Uint8List bytes) async {
    final img_pkg.Image? decoded = img_pkg.decodeImage(bytes);
    if (decoded == null) return bytes;
    final flipped = img_pkg.flipHorizontal(decoded);
    return img_pkg.encodeJpg(flipped, quality: 90);
  }

  Future<void> _createChannel() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isCreating = true);
    final presenter = ChannelPresenter();

    try {
      final result = await presenter.createChannel(
        name: _nameController.text,
        handle: _handleController.text,
        image: _selectedImage,
      );

      final int statusCode = result['statusCode'] as int? ?? 0;
      final bool status = result['status'] == true;
      final String msg = result['msg']?.toString() ?? '';
      final dynamic data = result['data'];

      if (statusCode == 200 && status) {
        _showSuccessSnackbar(
          msg.isNotEmpty ? msg : 'Channel created successfully!',
        );
        Navigator.of(context).pop(data);
        return;
      }

      final display =
          msg.isNotEmpty
              ? msg
              : (statusCode == 0
                  ? 'Network or parsing error'
                  : 'Failed to create channel: $statusCode');
      _showErrorSnackbar(display);
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    } finally {
      setState(() => _isCreating = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20.w),
            SizedBox(width: 12.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.w),
        ),
        margin: EdgeInsets.all(16.w),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20.w),
            SizedBox(width: 12.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.w),
        ),
        margin: EdgeInsets.all(16.w),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: 24.w,
              vertical: 24.w,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.w),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24.w, 20.w, 24.w, 24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Channel Photo',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: appColors().colorTextHead,
                      ),
                    ),
                    SizedBox(height: 8.w),
                    Text(
                      'Choose how you want to add your photo',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 20.w),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPhotoOption(
                            icon: Icons.camera_alt_rounded,
                            label: 'Camera',
                            gradient: LinearGradient(
                              colors: [
                                appColors().primaryColorApp,
                                appColors().primaryColorApp.withOpacity(0.7),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _imgFromCamera();
                            },
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: _buildPhotoOption(
                            icon: Icons.photo_library_rounded,
                            label: 'Gallery',
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple,
                                Colors.purple.withOpacity(0.7),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openGallery();
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_selectedImage != null) ...[
                      SizedBox(height: 16.w),
                      _buildPhotoOption(
                        icon: Icons.delete_rounded,
                        label: 'Remove Photo',
                        gradient: LinearGradient(
                          colors: [Colors.red[400]!, Colors.red[600]!],
                        ),
                        fullWidth: true,
                        onTap: () {
                          setState(() => _selectedImage = null);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showErrorSnackbar('Image pick error: $e');
    }
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.w),
        child: Container(
          height: 120.w,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20.w),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32.w, color: Colors.white),
              ),
              SizedBox(height: 12.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors().colorBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20.w),
          onPressed: () => Navigator.of(context).pop(),
          color: appColors().colorTextHead,
        ),
        centerTitle: true,
        title: Text(
          'Create Channel',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: appColors().colorTextHead,
          ),
        ),
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _slideController,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 20.w),

                  // Avatar with enhanced design
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 140.w,
                          height: 140.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                appColors().primaryColorApp.withOpacity(0.15),
                                appColors().primaryColorApp.withOpacity(0.05),
                              ],
                            ),
                          ),
                          child: Container(
                            margin: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: appColors().primaryColorApp
                                      .withOpacity(0.15),
                                  blurRadius: 24,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child:
                                  _selectedImage != null
                                      ? Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.cover,
                                      )
                                      : Icon(
                                        Icons.image_rounded,
                                        size: 50.w,
                                        color: appColors().primaryColorApp
                                            .withOpacity(0.6),
                                      ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8.w,
                          right: 8.w,
                          child: Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  appColors().primaryColorApp,
                                  appColors().primaryColorApp.withOpacity(0.8),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3.w,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: appColors().primaryColorApp
                                      .withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _selectedImage == null
                                  ? Icons.add_rounded
                                  : Icons.edit_rounded,
                              size: 20.w,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.w),
                  Text(
                    _selectedImage == null
                        ? 'Add Channel Photo'
                        : 'Looking good!',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: appColors().colorTextHead,
                    ),
                  ),
                  SizedBox(height: 6.w),
                  Text(
                    'Tap to ${_selectedImage == null ? 'add' : 'change'} your channel image',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 40.w),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModernTextField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          label: 'Channel Name',
                          hint: 'Morning Talks',
                          icon: Icons.tag_rounded,
                          nextFocus: _handleFocus,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              setState(() => _nameValid = false);
                              return 'Please enter a channel name';
                            }
                            setState(() => _nameValid = true);
                            return null;
                          },
                        ),
                        SizedBox(height: 28.w),
                        _buildModernTextField(
                          controller: _handleController,
                          focusNode: _handleFocus,
                          label: 'Handle',
                          hint: 'unique_handle',
                          icon: Icons.alternate_email_rounded,
                          maxLength: 30,
                          helperText: 'Use letters, numbers or underscore',
                          validator: (v) {
                            final value = v ?? '';
                            if (value.trim().isEmpty) {
                              setState(() => _handleValid = false);
                              return 'Please enter a handle';
                            }
                            final regex = RegExp(r'^[a-zA-Z0-9_]+$');
                            if (!regex.hasMatch(value.trim())) {
                              setState(() => _handleValid = false);
                              return 'Only letters, numbers and underscore';
                            }
                            setState(() => _handleValid = true);
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 48.w),

                  // Create Button with enhanced styling
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 58.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.w),
                      gradient:
                          (_isCreating || !_nameValid || !_handleValid)
                              ? LinearGradient(
                                colors: [Colors.grey[300]!, Colors.grey[400]!],
                              )
                              : LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  appColors().primaryColorApp,
                                  appColors().primaryColorApp.withOpacity(0.8),
                                ],
                              ),
                      boxShadow:
                          (_isCreating || !_nameValid || !_handleValid)
                              ? []
                              : [
                                BoxShadow(
                                  color: appColors().primaryColorApp
                                      .withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap:
                            (_isCreating || !_nameValid || !_handleValid)
                                ? null
                                : _createChannel,
                        borderRadius: BorderRadius.circular(20.w),
                        child: Center(
                          child:
                              _isCreating
                                  ? SizedBox(
                                    height: 26.w,
                                    width: 26.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.rocket_launch_rounded,
                                        color: Colors.white,
                                        size: 22.w,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'Create Channel',
                                        style: TextStyle(
                                          fontSize: 17.sp,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 32.w),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    FocusNode? nextFocus,
    String? Function(String?)? validator,
    int? maxLength,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 6.w, bottom: 10.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: appColors().primaryColorApp.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.w),
                ),
                child: Icon(
                  icon,
                  size: 16.w,
                  color: appColors().primaryColorApp,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: appColors().colorTextHead,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.w),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            maxLength: maxLength,
            validator: validator,
            onFieldSubmitted: (_) {
              if (nextFocus != null) {
                FocusScope.of(context).requestFocus(nextFocus);
              }
            },
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: appColors().colorTextHead,
            ),
            decoration: InputDecoration(
              hintText: hint,
              helperText: helperText,
              helperStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              counterText: '',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
                fontSize: 15.sp,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18.w),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18.w),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18.w),
                borderSide: BorderSide(
                  color: appColors().primaryColorApp,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18.w),
                borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18.w),
                borderSide: BorderSide(color: Colors.red[400]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: 18.w,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
