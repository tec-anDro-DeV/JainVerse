import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/services/media_overlay_manager.dart';
import 'package:jainverse/widgets/common/app_header.dart';
import 'package:jainverse/widgets/user_channel/banner_section.dart';
import 'package:jainverse/widgets/user_channel/info_card.dart';
import 'package:jainverse/widgets/user_channel/edit_form.dart';
import 'package:jainverse/models/channel_model.dart';
// Channel network/caching handled by ChannelService
import 'package:jainverse/services/channel_service.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/UI/ChannelSettings.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/my_videos_service.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
// moved: MyVideosSection and video card widgets now used from `user_channel_videos.dart`
import 'package:jainverse/videoplayer/screens/video_player_view.dart';
import 'package:jainverse/utils/crash_prevention_helper.dart';
import 'package:jainverse/UI/user_channel_image_helper.dart';
import 'package:jainverse/UI/user_channel_videos.dart';

class UserChannel extends StatefulWidget {
  final ChannelModel channel;

  const UserChannel({super.key, required this.channel});

  @override
  State<UserChannel> createState() => _UserChannelState();
}

class _UserChannelState extends State<UserChannel>
    with TickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
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

  /// Converts an [XFile] (or a path that might be a content:// URI) into a
  /// local temporary File with a file:// path that native crop libraries can
  /// safely open. Returns null on failure.

  // Form validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Store updated channel data
  late ChannelModel _currentChannel;
  // Channel loading / caching state
  bool _isLoadingChannel = true;
  bool _usedCache = false;

  // Note: channel fetching and caching delegated to `ChannelService`

  // My Videos state
  final MyVideosService _myVideosService = MyVideosService();
  List<VideoItem> _myVideos = [];
  bool _isLoadingVideos = true;
  String? _videosError;

  // Track last-known mini player visibility to avoid redundant overlay updates
  bool? _lastHasMiniPlayer;

  // Helper getters for blocked/unblocked videos
  // (blocked/unblocked lists are handled inside the videos widget)

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

    // Begin loading fresh channel data (will use cache then revalidate)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChannelOnOpen());

    // Observe app lifecycle to revalidate when app resumes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final ModalRoute? route = ModalRoute.of(context);
      if (route != null) routeObserver.subscribe(this, route);
    } catch (e) {}
  }

  @override
  void didPopNext() {
    // Returned to this route -> revalidate channel (coalesced)
    _loadChannelOnOpen();
  }

  @override
  void didPush() {
    // Screen pushed -> ensure we fetch
    _loadChannelOnOpen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadChannelOnOpen();
    }
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
    // This dispose block performs the heavy cleanup and runs after the
    // lightweight unsubscribe above.
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _slideController.dispose();
    _nameController.dispose();
    _handleController.dispose();
    _descriptionController.dispose();
    _nameFocus.dispose();
    _handleFocus.dispose();
    _descriptionFocus.dispose();
    // Clean up temporary image files if any (non-blocking)
    if (_selectedImage != null) {
      _selectedImage!.delete().then((_) {}).catchError((_) {});
    }
    if (_selectedBannerImage != null) {
      _selectedBannerImage!.delete().then((_) {}).catchError((_) {});
    }

    super.dispose();
  }

  void _toggleEditMode() {
    // Close keyboard when toggling edit mode
    try {
      FocusScope.of(context).unfocus();
    } catch (_) {}

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
      // free Flutter image caches and pause audio to reduce native/GPU memory
      CrashPreventionHelper.cleanupImageCache();
      try {
        await _audioHandler?.pause();
      } catch (_) {}

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
      // free Flutter image caches and pause audio to reduce native/GPU memory
      CrashPreventionHelper.cleanupImageCache();
      try {
        await _audioHandler?.pause();
      } catch (_) {}

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
        imageQuality: 70,
        // limit capture to safe profile size to avoid large ARGB_8888 buffers
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        final local = await UserChannelImageHelper.xFileToLocalFile(
          pickedFile,
          prefix: 'profile',
        );
        if (local == null) {
          _showErrorSnackbar('Failed to access captured image');
          return;
        }
        // Warn user if the picked image is very large and allow cancel
        if (!await UserChannelImageHelper.checkImageSizeAndWarn(context, local))
          return;
        final cropped = await UserChannelImageHelper.cropProfileImage(
          context,
          local,
        );
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
        imageQuality: 70,
        // downscale large gallery images before handing them to UCrop
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        final local = await UserChannelImageHelper.xFileToLocalFile(
          pickedFile,
          prefix: 'profile',
        );
        if (local == null) {
          _showErrorSnackbar('Failed to access selected image');
          return;
        }
        // Warn user about very large images (may blow native cropper memory)
        if (!await UserChannelImageHelper.checkImageSizeAndWarn(context, local))
          return;
        final cropped = await UserChannelImageHelper.cropProfileImage(
          context,
          local,
        );
        if (cropped != null) setState(() => _selectedImage = cropped);
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _bannerFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        // limit banner capture to a reasonable size
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        final local = await UserChannelImageHelper.xFileToLocalFile(
          pickedFile,
          prefix: 'banner',
        );
        if (local == null) {
          _showErrorSnackbar('Failed to access captured banner image');
          return;
        }
        // Warn user about very large banner images
        if (!await UserChannelImageHelper.checkImageSizeAndWarn(context, local))
          return;
        final cropped = await UserChannelImageHelper.cropBannerImage(
          context,
          local,
        );
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
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        final local = await UserChannelImageHelper.xFileToLocalFile(
          pickedFile,
          prefix: 'banner',
        );
        if (local == null) {
          _showErrorSnackbar('Failed to access selected banner image');
          return;
        }
        // Warn user about very large banner images
        if (!await UserChannelImageHelper.checkImageSizeAndWarn(context, local))
          return;
        final cropped = await UserChannelImageHelper.cropBannerImage(
          context,
          local,
        );
        if (cropped != null) {
          setState(() => _selectedBannerImage = cropped);
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _updateChannel() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isUpdating = true);

    try {
      final response = await ChannelService.instance.updateChannel(
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
      final fresh = await ChannelService.instance.fetchChannelAndCache(
        widget.channel.id,
      );
      if (!mounted) return;
      setState(() {
        _currentChannel = fresh;
        // Also sync controllers so if user re-enters edit mode they see latest values
        _nameController.text = fresh.name;
        _handleController.text = fresh.handle;
        _descriptionController.text = fresh.description;
      });
    } catch (e) {
      _showErrorSnackbar('Error refreshing channel: $e');
    }
  }

  /// Loads channel on screen open. Shows cached value immediately when available
  /// and revalidates from network. `force` forces a network fetch.
  Future<void> _loadChannelOnOpen({bool force = false}) async {
    final int cacheKey = widget.channel.id;

    if (!force) {
      final cached = ChannelService.instance.getCachedIfFresh(cacheKey);
      if (cached != null) {
        setState(() {
          _currentChannel = cached;
          _isLoadingChannel = false;
          _usedCache = true;
        });

        // Revalidate in background and update UI when it completes
        ChannelService.instance
            .fetchChannelAndCache(cacheKey)
            .then((fresh) {
              if (!mounted) return;
              setState(() {
                _currentChannel = fresh;
                _isLoadingChannel = false;
                _usedCache = false;
              });
            })
            .catchError((_) {});

        return;
      }
    }

    // No usable cache -> fetch now (show skeleton for channel parts)
    setState(() {
      _isLoadingChannel = true;
      _usedCache = false;
    });

    try {
      final fresh = await ChannelService.instance.fetchChannelAndCache(
        cacheKey,
      );
      if (!mounted) return;
      setState(() {
        _currentChannel = fresh;
        _isLoadingChannel = false;
        _usedCache = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingChannel = false;
      });
      _showErrorSnackbar('Failed to load channel: $e');
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

          // Schedule overlay updates after build to avoid ValueNotifier changes
          // during the build phase which can cause FlutterError.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_lastHasMiniPlayer == hasMiniPlayer) return;
            _lastHasMiniPlayer = hasMiniPlayer;
            if (hasMiniPlayer) {
              MediaOverlayManager.instance.showMiniPlayer(
                type: MediaOverlayType.audioMini,
              );
            } else {
              MediaOverlayManager.instance.hideMiniPlayer();
            }
          });

          final bottomPadding = hasMiniPlayer
              ? AppPadding.bottom(context, extra: 100.w)
              : AppPadding.bottom(context);

          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _slideController,
              child: SafeArea(
                child: Form(
                  key: _formKey,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      // Dismiss keyboard when tapping outside input fields
                      try {
                        FocusScope.of(context).unfocus();
                      } catch (_) {}
                    },
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          await _loadChannelOnOpen(force: true),
                      color: appColors().primaryColorApp,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            // Banner image section with profile picture overlay
                            _buildBannerOrPlaceholder(),
                            // Show a non-blocking cached/stale indicator when using cache
                            if (_usedCache)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: 8.w,
                                  left: 24.w,
                                  right: 24.w,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 6.w,
                                          horizontal: 12.w,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8.w,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.history,
                                              size: 16.w,
                                              color: Colors.orange.shade700,
                                            ),
                                            SizedBox(width: 8.w),
                                            Expanded(
                                              child: Text(
                                                'Showing recent cached data — refreshing…',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  color: Colors.orange.shade800,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints.tight(
                                                Size(28.w, 28.w),
                                              ),
                                              icon: Icon(
                                                Icons.refresh,
                                                size: 18.w,
                                                color:
                                                    appColors().primaryColorApp,
                                              ),
                                              onPressed: () =>
                                                  _loadChannelOnOpen(
                                                    force: true,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

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
                                  else if (_isLoadingChannel && !_usedCache)
                                    _buildChannelSkeleton()
                                  else
                                    _buildInfoCard(),

                                  // My Videos + Blocked Videos Sections (only in non-edit mode)
                                  // Moved into a separate widget for clarity and file size.
                                  if (!_isEditMode) ...[
                                    SizedBox(height: 32.w),
                                    UserChannelVideosSection(
                                      videos: _myVideos,
                                      isLoading: _isLoadingVideos,
                                      error: _videosError,
                                      onRetry: _loadMyVideos,
                                      onTap: _openVideoPlayer,
                                      onMenuAction: (action, video) =>
                                          _handleVideoAction(action, video),
                                    ),
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
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerSection() {
    return BannerSection(
      isEditMode: _isEditMode,
      selectedBannerImage: _selectedBannerImage,
      bannerImageUrl: _currentChannel.bannerImageUrl,
      onPickBanner: _pickBannerImage,
      avatarIsEditMode: _isEditMode,
      avatarSelectedImage: _selectedImage,
      avatarImageUrl: _currentChannel.imageUrl,
      onPickImage: _pickImage,
    );
  }

  Widget _buildBannerOrPlaceholder() {
    if (_isLoadingChannel && !_usedCache) {
      return SizedBox(
        width: double.infinity,
        height: 180.w,
        child: Center(
          child: CircularProgressIndicator(color: appColors().primaryColorApp),
        ),
      );
    }
    return _buildBannerSection();
  }

  Widget _buildChannelSkeleton() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6.w),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 18.w, width: 200.w, color: Colors.grey[300]),
          SizedBox(height: 12.w),
          Container(height: 14.w, width: 120.w, color: Colors.grey[300]),
          SizedBox(height: 12.w),
          Container(
            height: 64.w,
            width: double.infinity,
            color: Colors.grey[200],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final items = {
      'Channel Name': _currentChannel.name,
      'Channel Handle': '@${_currentChannel.handle}',
      'Description': _currentChannel.description.isNotEmpty
          ? _currentChannel.description
          : 'No description yet',
      'Created On': _formatDate(_currentChannel.createdAt),
      'Total Videos': _currentChannel.totalVideos.toString(),
      'Subscribers': _currentChannel.totalSubscribers.toString(),
      'Total Views': _currentChannel.totalViews.toString(),
    };

    final icons = {
      'Channel Name': Icons.badge_outlined,
      'Channel Handle': Icons.alternate_email,
      'Description': Icons.description_outlined,
      'Created On': Icons.calendar_today_outlined,
      'Total Videos': Icons.video_library_outlined,
      'Subscribers': Icons.group_outlined,
      'Total Views': Icons.visibility_outlined,
    };

    return InfoCard(items: items, icons: icons);
  }

  Widget _buildEditForm() {
    // Create field widgets using existing _buildModernTextField helper to keep logic
    final nameField = _buildModernTextField(
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
    );

    final handleField = _buildModernTextField(
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
        if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value.trim())) {
          return 'Handle can only contain letters, numbers, underscores, and dashes';
        }
        return null;
      },
    );

    final descriptionField = _buildModernTextField(
      controller: _descriptionController,
      focusNode: _descriptionFocus,
      label: 'Description (Optional)',
      hint: 'Tell viewers about your channel',
      icon: Icons.description_outlined,
      maxLength: 200,
      helperText: 'Maximum 200 characters',
      minLines: 3,
      maxLines: null,
      expands: false,
    );

    return EditForm(
      nameField: nameField,
      handleField: handleField,
      descriptionField: descriptionField,
      isUpdating: _isUpdating,
      onSave: _updateChannel,
      onCancel: _toggleEditMode,
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
    // Decide effective line configuration:
    // - If a minLines is provided (e.g. description), allow multiline by
    //   leaving maxLines null so the field can grow. For other fields,
    //   enforce single-line by setting maxLines = 1.
    final bool _expands = expands ?? false;
    final int? _minLines = minLines;
    final int? _maxLines = (minLines != null) ? null : (maxLines ?? 1);

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
          minLines: _minLines,
          maxLines: _maxLines,
          expands: _expands,
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

  // Videos section moved to `UserChannelVideosSection` in separate file.

  void _openVideoPlayer(VideoItem video) {
    // If video is blocked, show reason instead of opening player
    if ((video.block ?? 0) == 1) {
      _showBlockedReasonDialog(video);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerView(
          videoUrl: video.videoUrl,
          videoId: video.id.toString(),
          title: video.title,
          thumbnailUrl: video.thumbnailUrl,
          channelId: video.channelId,
          channelAvatarUrl: video.channelImageUrl,
          videoItem: video,
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
