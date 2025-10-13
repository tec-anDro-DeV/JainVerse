import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/models/channel_model.dart';
import 'package:jainverse/presenters/channel_presenter.dart';
import 'package:jainverse/UI/ChannelSettings.dart';

class UserChannel extends StatefulWidget {
  final ChannelModel channel;

  const UserChannel({super.key, required this.channel});

  @override
  State<UserChannel> createState() => _UserChannelState();
}

class _UserChannelState extends State<UserChannel>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Edit mode state
  bool _isEditMode = false;
  bool _isUpdating = false;

  // Controllers for edit fields
  late TextEditingController _nameController;
  late TextEditingController _handleController;

  // Focus nodes
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _handleFocus = FocusNode();

  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  // Form validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Store updated channel data
  late ChannelModel _currentChannel;

  @override
  void initState() {
    super.initState();

    // Initialize current channel
    _currentChannel = widget.channel;

    // Initialize text controllers
    _nameController = TextEditingController(text: widget.channel.name);
    _handleController = TextEditingController(text: widget.channel.handle);

    // Initialize animation
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
    _slideController.dispose();
    _nameController.dispose();
    _handleController.dispose();
    _nameFocus.dispose();
    _handleFocus.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      if (_isEditMode) {
        // Cancel edit - reset controllers
        _nameController.text = _currentChannel.name;
        _handleController.text = _currentChannel.handle;
        _selectedImage = null;
      }
      _isEditMode = !_isEditMode;
    });
  }

  Future<void> _pickImage() async {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder:
            (context) => Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: appColors().colorBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose Photo',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: appColors().colorTextHead,
                    ),
                  ),
                  SizedBox(height: 20.w),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPhotoOption(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        gradient: LinearGradient(
                          colors: [Colors.blue, Colors.blue.shade700],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _imgFromCamera();
                        },
                      ),
                      _buildPhotoOption(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        gradient: LinearGradient(
                          colors: [Colors.purple, Colors.purple.shade700],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _openGallery();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20.w),
                ],
              ),
            ),
      );
    } catch (e) {
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  Future<void> _imgFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final cropped = await _cropImage(File(pickedFile.path));
        if (cropped != null) {
          setState(() => _selectedImage = cropped);
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _openGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final cropped = await _cropImage(File(pickedFile.path));
        if (cropped != null) {
          setState(() => _selectedImage = cropped);
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: appColors().primaryColorApp,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Image', aspectRatioLockEnabled: true),
        ],
      );
      if (croppedFile != null) return File(croppedFile.path);
    } catch (e) {
      _showErrorSnackbar('Error cropping image: $e');
    }
    return null;
  }

  Future<void> _updateChannel() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isUpdating = true);
    final presenter = ChannelPresenter();

    try {
      final response = await presenter.updateChannel(
        name: _nameController.text.trim(),
        handle: _handleController.text.trim(),
        image: _selectedImage,
      );

      setState(() => _isUpdating = false);

      if (response['status'] == true && response['data'] != null) {
        final updatedChannel = ChannelModel.fromJson(response['data']);
        setState(() {
          _currentChannel = updatedChannel;
          _isEditMode = false;
          _selectedImage = null;
        });
        _showSuccessSnackbar(response['msg'] ?? 'Channel updated successfully');
        // Update local state already applied above and exit edit mode.
        // Keep the UserChannel screen open (do not pop the route).
      } else {
        _showErrorSnackbar(response['msg'] ?? 'Failed to update channel');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      _showErrorSnackbar('Error: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.w),
        ),
        margin: EdgeInsets.all(16.w),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.w),
        ),
        margin: EdgeInsets.all(16.w),
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
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: Icon(
                Icons.settings_outlined,
                color: appColors().colorTextHead,
                size: 22.w,
              ),
              onPressed: () async {
                // Open dedicated ChannelSettings screen
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ChannelSettings(
                          channelId: _currentChannel.id,
                          channelName: _currentChannel.name,
                        ),
                  ),
                );

                // If settings returned true (deleted), propagate to AccountPage
                if (result == true) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
        ],
        centerTitle: true,
        title: Text(
          _isEditMode ? 'Edit Channel' : 'Your Channel',
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
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    SizedBox(height: 20.w),

                    // Avatar with edit overlay in edit mode
                    _buildAvatarSection(),

                    SizedBox(height: 24.w),

                    // Channel Info Card or Edit Form
                    if (_isEditMode) _buildEditForm() else _buildInfoCard(),

                    SizedBox(height: 24.w),

                    // Action Buttons
                    if (_isEditMode)
                      _buildEditModeButtons()
                    else
                      _buildCustomizeButton(),

                    SizedBox(height: 32.w),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 140.w,
          height: 140.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                appColors().primaryColorApp,
                appColors().primaryColorApp.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: appColors().primaryColorApp.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: ClipOval(
                child:
                    _selectedImage != null
                        ? Image.file(_selectedImage!, fit: BoxFit.cover)
                        : (_currentChannel.imageUrl.isNotEmpty
                            ? Image.network(
                              _currentChannel.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderAvatar();
                              },
                            )
                            : _buildPlaceholderAvatar()),
              ),
            ),
          ),
        ),

        // Edit button overlay in edit mode
        if (_isEditMode)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: appColors().primaryColorApp,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.camera_alt, color: Colors.white, size: 20.w),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
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
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'Channel Name',
            value: _currentChannel.name,
          ),
          SizedBox(height: 20.w),
          _buildInfoRow(
            icon: Icons.alternate_email,
            label: 'Channel Handle',
            value: '@${_currentChannel.handle}',
          ),
          SizedBox(height: 20.w),
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Created On',
            value: _formatDate(_currentChannel.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Container(
      width: double.infinity,
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
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernTextField(
            controller: _nameController,
            focusNode: _nameFocus,
            label: 'Channel Name',
            hint: 'Enter channel name',
            icon: Icons.badge_outlined,
            nextFocus: _handleFocus,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a channel name';
              }
              if (value.trim().length < 3) {
                return 'Name must be at least 3 characters';
              }
              return null;
            },
          ),
          SizedBox(height: 20.w),
          _buildModernTextField(
            controller: _handleController,
            focusNode: _handleFocus,
            label: 'Channel Handle',
            hint: 'Enter channel handle',
            icon: Icons.alternate_email,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a channel handle';
              }
              if (value.trim().length < 3) {
                return 'Handle must be at least 3 characters';
              }
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                return 'Handle can only contain letters, numbers, and underscores';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: appColors().primaryColorApp,
          padding: EdgeInsets.symmetric(vertical: 16.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.w),
          ),
          elevation: 2,
        ),
        onPressed: _toggleEditMode,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_outlined, size: 20.w, color: Colors.white),
            SizedBox(width: 8.w),
            Text(
              'Customize Channel',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditModeButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appColors().primaryColorApp,
              padding: EdgeInsets.symmetric(vertical: 16.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.w),
              ),
              elevation: 2,
            ),
            onPressed: _isUpdating ? null : _updateChannel,
            child:
                _isUpdating
                    ? SizedBox(
                      height: 20.w,
                      width: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
          ),
        ),
        SizedBox(height: 12.w),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: appColors().primaryColorApp),
              padding: EdgeInsets.symmetric(vertical: 16.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.w),
              ),
            ),
            onPressed: _isUpdating ? null : _toggleEditMode,
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: appColors().primaryColorApp,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: appColors().primaryColorApp.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.person,
          size: 60.w,
          color: appColors().primaryColorApp,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: appColors().primaryColorApp.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.w),
          ),
          child: Icon(icon, size: 20.w, color: appColors().primaryColorApp),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.w),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: appColors().colorTextHead,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: appColors().colorTextHead,
          ),
        ),
        SizedBox(height: 8.w),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          validator: validator,
          maxLength: maxLength,
          style: TextStyle(fontSize: 16.sp, color: appColors().colorTextHead),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15.sp),
            prefixIcon: Icon(
              icon,
              color: appColors().primaryColorApp,
              size: 22.w,
            ),
            filled: true,
            fillColor: appColors().primaryColorApp.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: BorderSide(
                color: appColors().primaryColorApp,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.w),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            counterText: '',
            helperText: helperText,
            helperStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
          ),
          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            } else {
              FocusScope.of(context).unfocus();
            }
          },
        ),
      ],
    );
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
        borderRadius: BorderRadius.circular(16.w),
        child: Container(
          width: fullWidth ? double.infinity : 140.w,
          padding: EdgeInsets.symmetric(vertical: 20.w),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32.w),
              SizedBox(height: 8.w),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
