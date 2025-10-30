import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/widgets/common/app_header.dart';
import 'package:jainverse/models/channel_model.dart';
import 'package:jainverse/presenters/channel_presenter.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/UI/ChannelSettings.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/my_videos_service.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/videoplayer/widgets/video_card.dart';
import 'package:jainverse/videoplayer/widgets/video_card_skeleton.dart';
import 'package:jainverse/videoplayer/screens/common_video_player_screen.dart';

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

  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  // Edit mode state
  bool _isEditMode = false;
  bool _isUpdating = false;

  // Controllers for edit fields
  late TextEditingController _nameController;
  late TextEditingController _handleController;
  late TextEditingController _descriptionController;

  // Focus nodes
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _handleFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();

  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  File? _selectedBannerImage;

  // Form validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Store updated channel data
  late ChannelModel _currentChannel;

  // My Videos state
  final MyVideosService _myVideosService = MyVideosService();
  List<VideoItem> _myVideos = [];
  bool _isLoadingVideos = true;
  String? _videosError;

  // Helper getters for blocked/unblocked videos
  List<VideoItem> get _blockedVideos {
    return _myVideos.where((v) => (v.block ?? 0) == 1).toList();
  }

  List<VideoItem> get _unblockedVideos {
    return _myVideos.where((v) => (v.block ?? 0) != 1).toList();
  }

  @override
  void initState() {
    super.initState();

    // Initialize audio handler for mini player detection
    _audioHandler = const MyApp().called();

    // Initialize current channel
    _currentChannel = widget.channel;

    // Initialize text controllers
    _nameController = TextEditingController(text: widget.channel.name);
    _handleController = TextEditingController(text: widget.channel.handle);
    _descriptionController = TextEditingController(
      text: widget.channel.description,
    );

    // Initialize animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _slideController.forward();

    // Load my videos
    _loadMyVideos();
  }

  Future<void> _loadMyVideos() async {
    setState(() {
      _isLoadingVideos = true;
      _videosError = null;
    });

    try {
      final videos = await _myVideosService.getMyVideos();
      setState(() {
        _myVideos = videos;
        _isLoadingVideos = false;
      });
    } catch (e) {
      setState(() {
        _videosError = 'Failed to load videos: $e';
        _isLoadingVideos = false;
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    _handleController.dispose();
    _descriptionController.dispose();
    _nameFocus.dispose();
    _handleFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      if (_isEditMode) {
        // Cancel edit - reset controllers
        _nameController.text = _currentChannel.name;
        _handleController.text = _currentChannel.handle;
        _descriptionController.text = _currentChannel.description;
        _selectedImage = null;
        _selectedBannerImage = null;
      }
      _isEditMode = !_isEditMode;
    });
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 20.w, 24.w, 24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Profile Photo',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                      color: appColors().colorTextHead,
                    ),
                  ),
                  SizedBox(height: 8.w),
                  Text(
                    'Choose how you want to add your profile photo',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
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
                  // Removed local "Remove Photo" action - server-side removal requires API.
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  Future<void> _pickBannerImage() async {
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
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 20.w, 24.w, 24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Banner Image',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                      color: appColors().colorTextHead,
                    ),
                  ),
                  SizedBox(height: 8.w),
                  Text(
                    'Recommended size: 2560 x 1440 (16:9). Choose a photo to crop to 16:9.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
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
                            _bannerFromCamera();
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
                            _bannerFromGallery();
                          },
                        ),
                      ),
                    ],
                  ),
                  // Removed local "Remove Banner" action - server-side removal requires API.
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showErrorSnackbar('Error picking banner: $e');
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

  Future<void> _bannerFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final cropped = await _cropBannerImage(File(pickedFile.path));
        if (cropped != null) {
          setState(() => _selectedBannerImage = cropped);
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _bannerFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final cropped = await _cropBannerImage(File(pickedFile.path));
        if (cropped != null) {
          setState(() => _selectedBannerImage = cropped);
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

  Future<File?> _cropBannerImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Banner Image',
            toolbarColor: appColors().primaryColorApp,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Crop Banner', aspectRatioLockEnabled: true),
        ],
      );
      if (croppedFile != null) return File(croppedFile.path);
    } catch (e) {
      _showErrorSnackbar('Error cropping banner: $e');
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
        description: _descriptionController.text.trim(),
        image: _selectedImage,
        bannerImage: _selectedBannerImage,
      );

      setState(() => _isUpdating = false);

      if (response['status'] == true && response['data'] != null) {
        // After update, request fresh channel data from server to ensure all fields
        // (including generated image URLs, counts, timestamps) are up-to-date.
        _showSuccessSnackbar(response['msg'] ?? 'Channel updated successfully');
        await _refreshChannel();
        // Exit edit mode and clear local selections only after refresh succeeded
        setState(() {
          _isEditMode = false;
          _selectedImage = null;
          _selectedBannerImage = null;
        });
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

  /// Fetches latest channel data from server and updates local state/UI.
  Future<void> _refreshChannel() async {
    try {
      final presenter = ChannelPresenter();
      final resp = await presenter.getChannel();
      if (resp['status'] == true && resp['data'] != null) {
        final fresh = ChannelModel.fromJson(resp['data']);
        setState(() {
          _currentChannel = fresh;
          // Also sync controllers so if user re-enters edit mode they see latest values
          _nameController.text = fresh.name;
          _handleController.text = fresh.handle;
          _descriptionController.text = fresh.description;
        });
      } else {
        // If fetching fails, show a non-blocking error but keep current state
        _showErrorSnackbar(resp['msg'] ?? 'Failed to refresh channel');
      }
    } catch (e) {
      _showErrorSnackbar('Error refreshing channel: $e');
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(64.w),
        child: AppHeader(
          title: _isEditMode ? 'Edit Channel' : 'Your Channel',
          backgroundColor: Colors.transparent,
          showBackButton: true,
          showProfileIcon: false,
          onBackPressed: () => Navigator.of(context).pop(),
          trailingWidget: !_isEditMode
              ? IconButton(
                  icon: Icon(
                    Icons.settings,
                    size: 22.w,
                    color: appColors().colorTextHead,
                  ),
                  onPressed: () async {
                    // Open dedicated ChannelSettings screen and handle result
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChannelSettings(
                          channelId: _currentChannel.id,
                          channelName: _currentChannel.name,
                        ),
                      ),
                    );

                    // If settings returned true (deleted), propagate to previous route
                    if (result == true && mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                )
              : null,
          elevation: 0,
          titleStyle: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: appColors().colorTextHead,
          ),
        ),
      ),
      body: StreamBuilder<MediaItem?>(
        stream: _audioHandler?.mediaItem,
        builder: (context, snapshot) {
          // Calculate proper bottom padding accounting for mini player and navigation
          final hasMiniPlayer = snapshot.hasData;
          final bottomPadding = hasMiniPlayer
              ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 100.w
              : AppSizes.basePadding + AppSizes.miniPlayerPadding;

          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _slideController,
              child: SafeArea(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        // Banner image section with profile picture overlay
                        _buildBannerSection(),

                        // Content section with padding
                        Padding(
                          padding: EdgeInsets.only(
                            left: 24.w,
                            right: 24.w,
                            bottom: bottomPadding,
                          ),
                          child: Column(
                            children: [
                              // Action Buttons (only in non-edit mode)
                              if (!_isEditMode) _buildCustomizeButton(),

                              if (!_isEditMode) SizedBox(height: 24.w),

                              // Channel Info Card or Edit Form
                              if (_isEditMode)
                                _buildEditForm()
                              else
                                _buildInfoCard(),

                              // My Videos + Blocked Videos Sections (only in non-edit mode)
                              // Render unblocked (My Videos) first, then blocked videos below.
                              if (!_isEditMode) ...[
                                SizedBox(height: 32.w),
                                // My Videos (unblocked)
                                _buildMyVideosSection(),
                                // If there are blocked videos, add spacing then show them below
                                if (_blockedVideos.isNotEmpty)
                                  SizedBox(height: 24.w),
                                if (_blockedVideos.isNotEmpty)
                                  _buildBlockedVideosSection(),
                              ],

                              SizedBox(height: 24.w),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerSection() {
    // Wrap in SizedBox with height = banner height + avatar overflow
    // Banner is 200.w, avatar overflows by 60.w
    return SizedBox(
      height: 200.w + 80.w, // Extra space for avatar overflow and margin
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Banner Image
          Container(
            width: double.infinity,
            height: 200.w,
            decoration: BoxDecoration(color: Colors.grey[200]),
            child: _selectedBannerImage != null
                ? Image.file(
                    _selectedBannerImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  )
                : (_currentChannel.bannerImageUrl.isNotEmpty
                      ? Image.network(
                          _currentChannel.bannerImageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderBanner();
                          },
                        )
                      : _buildPlaceholderBanner()),
          ),

          // Edit banner button overlay (top-right in edit mode)
          if (_isEditMode)
            Positioned(
              top: 16.w,
              right: 16.w,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _pickBannerImage();
                  },
                  borderRadius: BorderRadius.circular(10.w),
                  child: Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10.w),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image, color: Colors.white, size: 16.w),
                        SizedBox(width: 6.w),
                        Text(
                          'Edit Banner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Profile Avatar positioned at 20% from left (80% in the banner)
          // Wrapped in Positioned with specific bounds to prevent hit-test conflicts
          Positioned(
            left: MediaQuery.of(context).size.width * 0.20 - 70.w,
            bottom: 20.w, // Changed from -60.w to 20.w to keep it inside bounds
            width: 140.w,
            height: 140.w,
            child: _buildAvatarSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            appColors().primaryColorApp.withOpacity(0.3),
            appColors().primaryColorApp.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 48.w, color: Colors.grey[400]),
            SizedBox(height: 8.w),
            Text(
              _isEditMode ? 'Tap "Edit Banner" to add' : 'No banner image',
              style: TextStyle(color: Colors.grey[500], fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Avatar Container - tappable in edit mode
        GestureDetector(
          onTap: _isEditMode
              ? () {
                  print('Avatar tapped!'); // Debug
                  _pickImage();
                }
              : null,
          child: Container(
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
                  child: _selectedImage != null
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
        ),

        // Edit button overlay in edit mode - positioned outside the circle
        if (_isEditMode)
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              elevation: 4,
              borderRadius: BorderRadius.circular(50.w),
              child: InkWell(
                onTap: () {
                  print('Profile edit button tapped!'); // Debug
                  _pickImage();
                },
                borderRadius: BorderRadius.circular(50.w),
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: appColors().primaryColorApp,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20.w,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard() {
    // Simplified info layout: plain background, rows separated by dividers.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8.w),
      child: Column(
        children: [
          _buildInfoListTile(
            icon: Icons.badge_outlined,
            label: 'Channel Name',
            value: _currentChannel.name,
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          _buildInfoListTile(
            icon: Icons.alternate_email,
            label: 'Channel Handle',
            value: '@${_currentChannel.handle}',
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          _buildInfoListTile(
            icon: Icons.description_outlined,
            label: 'Description',
            value: _currentChannel.description.isNotEmpty
                ? _currentChannel.description
                : 'No description yet',
            isPlaceholder: _currentChannel.description.isEmpty,
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          _buildInfoListTile(
            icon: Icons.calendar_today_outlined,
            label: 'Created On',
            value: _formatDate(_currentChannel.createdAt),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          _buildInfoListTile(
            icon: Icons.video_library_outlined,
            label: 'Total Videos',
            value: _currentChannel.totalVideos.toString(),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          _buildInfoListTile(
            icon: Icons.group_outlined,
            label: 'Subscribers',
            value: _currentChannel.totalSubscribers.toString(),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          _buildInfoListTile(
            icon: Icons.visibility_outlined,
            label: 'Total Views',
            value: _currentChannel.totalViews.toString(),
          ),
        ],
      ),
    );
  }

  // New helper: render a ListTile-like row for info without a card.
  Widget _buildInfoListTile({
    required IconData icon,
    required String label,
    required String value,
    bool isPlaceholder = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: appColors().primaryColorApp.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.w),
            ),
            child: Icon(icon, size: 20.w, color: appColors().primaryColorApp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: appColors().colorTextHead,
                  ),
                ),
                SizedBox(height: 4.w),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: isPlaceholder
                        ? Colors.grey[500]
                        : appColors().colorTextHead,
                  ),
                ),
              ],
            ),
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
            nextFocus: _descriptionFocus,
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
          SizedBox(height: 20.w),
          _buildModernTextField(
            controller: _descriptionController,
            focusNode: _descriptionFocus,
            label: 'Description (Optional)',
            hint: 'Tell viewers about your channel',
            icon: Icons.description_outlined,
            maxLength: 200,
            helperText: 'Maximum 200 characters',
            // Start with a few lines and allow the field to grow with content
            minLines: 3,
            maxLines: null,
            expands: false,
          ),
          SizedBox(height: 24.w),

          // Save Changes Button
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
              child: _isUpdating
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
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 12.w),

          // Cancel Button
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
                  fontWeight: FontWeight.w500,
                  color: appColors().primaryColorApp,
                ),
              ),
            ),
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
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
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
    // Allow multiline/autosizing configuration
    int? minLines,
    int? maxLines,
    bool? expands,
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
          minLines: minLines,
          maxLines: maxLines,
          expands: expands ?? false,
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
                  fontWeight: FontWeight.w500,
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

  /// Build the My Videos section
  Widget _buildMyVideosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 24.w,
                  color: appColors().primaryColorApp,
                ),
                SizedBox(width: 12.w),
                Text(
                  'My Videos',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: appColors().colorTextHead,
                  ),
                ),
              ],
            ),
            if (_unblockedVideos.isNotEmpty)
              Text(
                '${_unblockedVideos.length} ${_unblockedVideos.length == 1 ? 'video' : 'videos'}',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),

        SizedBox(height: 16.w),

        // Videos List or Loading/Error State - only for unblocked videos
        if (_isLoadingVideos)
          _buildLoadingVideos()
        else if (_videosError != null)
          _buildErrorState()
        else if (_unblockedVideos.isEmpty)
          _buildEmptyState()
        else
          _buildVideosList(),
      ],
    );
  }

  Widget _buildLoadingVideos() {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: 16.w),
          child: const VideoCardSkeleton(),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12.w),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48.w, color: Colors.red.shade400),
          SizedBox(height: 16.w),
          Text(
            'Failed to load videos',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8.w),
          Text(
            _videosError ?? 'Unknown error',
            style: TextStyle(fontSize: 13.sp, color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.w),
          ElevatedButton.icon(
            onPressed: _loadMyVideos,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      // Use the available horizontal space so the empty state appears centered
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.w),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64.w,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16.w),
          Text(
            'No videos yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8.w),
          Text(
            'Upload your first video to get started',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosList() {
    return Column(
      children: _unblockedVideos.map((video) {
        return Padding(
          padding: EdgeInsets.only(bottom: 16.w),
          child: VideoCard(
            item: video,
            onTap: () => _openVideoPlayer(video),
            showPopupMenu: true,
            onMenuAction: (action) => _handleVideoAction(action, video),
          ),
        );
      }).toList(),
    );
  }

  void _openVideoPlayer(VideoItem video) {
    // If video is blocked, show reason instead of opening player
    if ((video.block ?? 0) == 1) {
      _showBlockedReasonDialog(video);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommonVideoPlayerScreen(
          videoUrl: video.videoUrl,
          videoTitle: video.title,
          videoItem: video,
          restrictToChannel: true,
        ),
      ),
    );
  }

  void _showBlockedReasonDialog(VideoItem video) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.redAccent),
              SizedBox(width: 8.w),
              Text('Video Blocked'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(video.title, style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 12.w),
              Text(
                video.reason ?? 'No reason provided by the moderation team.',
                style: TextStyle(color: Colors.grey[800]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Blocked Videos section
  Widget _buildBlockedVideosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.block, size: 24.w, color: Colors.redAccent),
                SizedBox(width: 12.w),
                Text(
                  'Blocked Videos',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: appColors().colorTextHead,
                  ),
                ),
              ],
            ),
            if (_blockedVideos.isNotEmpty)
              Text(
                '${_blockedVideos.length} ${_blockedVideos.length == 1 ? 'video' : 'videos'}',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),

        SizedBox(height: 16.w),

        // Render blocked videos list
        _buildBlockedVideosList(),
      ],
    );
  }

  Widget _buildBlockedVideosList() {
    if (_isLoadingVideos) return _buildLoadingVideos();
    if (_videosError != null) return _buildErrorState();

    return Column(
      children: _blockedVideos.map((video) {
        return Padding(
          padding: EdgeInsets.only(bottom: 16.w),
          child: VideoCard(
            item: video,
            onTap: () => _openVideoPlayer(video),
            showPopupMenu: true,
            blockedReason: video.reason ?? 'Blocked by moderation',
            onMenuAction: (action) => _handleVideoAction(action, video),
          ),
        );
      }).toList(),
    );
  }

  void _handleVideoAction(String action, VideoItem video) {
    switch (action) {
      case 'watch_later':
        _showSuccessSnackbar('Added to Watch Later');
        break;
      case 'add_playlist':
        _showSuccessSnackbar('Added to Playlist');
        break;
      case 'share':
        _showSuccessSnackbar('Share functionality coming soon');
        break;
      case 'not_interested':
        _showSuccessSnackbar('Video hidden');
        break;
    }
  }
}
