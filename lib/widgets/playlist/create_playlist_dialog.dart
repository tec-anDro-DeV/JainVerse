import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/widgets/playlist/playlist_service.dart';

/// Enhanced dialog for creating a new playlist
/// Features improved UI/UX with better keyboard handling and modern design
class CreatePlaylistDialog extends StatefulWidget {
  final String? songId;
  final VoidCallback? onPlaylistCreated;
  final Function(String playlistName)? onPlaylistCreatedWithName;

  const CreatePlaylistDialog({
    super.key,
    this.songId,
    this.onPlaylistCreated,
    this.onPlaylistCreatedWithName,
  });

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();

  /// Static method to show the dialog with enhanced UX
  static Future<bool?> show(
    BuildContext context, {
    String? songId,
    VoidCallback? onPlaylistCreated,
    Function(String playlistName)? onPlaylistCreatedWithName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.75),
      useSafeArea: true,
      builder:
          (context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(false),
            child: Container(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {}, // Prevent closing when tapping inside
                child: CreatePlaylistDialog(
                  songId: songId,
                  onPlaylistCreated: onPlaylistCreated,
                  onPlaylistCreatedWithName: onPlaylistCreatedWithName,
                ),
              ),
            ),
          ),
    );
  }
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final PlaylistService _playlistService = PlaylistService();

  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize enhanced animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Start animation
    _animationController.forward();

    // Focus listener for UI updates
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    // Auto-focus text field after animation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _createPlaylist() async {
    final playlistName = _nameController.text.trim();

    if (playlistName.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a playlist name';
      });
      _focusNode.requestFocus();
      HapticFeedback.lightImpact();
      return;
    }

    if (playlistName.length < 2) {
      setState(() {
        _errorMessage = 'Playlist name must be at least 2 characters';
      });
      HapticFeedback.lightImpact();
      return;
    }

    if (playlistName.length > 50) {
      setState(() {
        _errorMessage = 'Playlist name is too long (max 50 characters)';
      });
      HapticFeedback.lightImpact();
      return;
    }

    // Check for special characters that might cause issues
    if (playlistName.contains(RegExp(r'[<>:"/\\|?*]'))) {
      setState(() {
        _errorMessage = 'Playlist name contains invalid characters';
      });
      HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Enhanced haptic feedback
    HapticFeedback.mediumImpact();

    bool success = false;

    try {
      if (widget.songId != null && widget.songId!.isNotEmpty) {
        // Create playlist and add song
        success = await _playlistService.createPlaylistAndAddSong(
          playlistName,
          widget.songId!,
        );
      } else {
        // Just create playlist
        success = await _playlistService.createPlaylist(playlistName);
      }

      if (success) {
        // Success haptic feedback
        HapticFeedback.heavyImpact();

        // Call callbacks
        widget.onPlaylistCreated?.call();
        widget.onPlaylistCreatedWithName?.call(playlistName);

        // Close dialog with success result
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to create playlist. Please try again.';
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24.w),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 440.w,
                      minHeight: 380.w,
                    ),
                    decoration: BoxDecoration(
                      color: appColors().colorBackEditText,
                      borderRadius: BorderRadius.circular(28.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30.w,
                          offset: const Offset(0, 15),
                          spreadRadius: 3.w,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        _buildContent(),
                        _buildActions(),
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(32.w, 32.w, 32.w, 24.w),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: appColors().primaryColorApp.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              Icons.playlist_add_rounded,
              color: appColors().primaryColorApp,
              size: 30.sp,
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Playlist',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: appColors().colorTextHead,
                    fontFamily: 'Poppins',
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4.w),
                Text(
                  'Name your new music collection',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: appColors().colorText.withOpacity(0.7),
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: Icon(
              Icons.close_rounded,
              color: appColors().colorText.withOpacity(0.6),
              size: 24.sp,
            ),
            style: IconButton.styleFrom(
              backgroundColor: appColors().colorHint.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Playlist Name',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: appColors().colorTextHead,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 12.w),
          Container(
            decoration: BoxDecoration(
              color: appColors().colorBackground.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color:
                    _focusNode.hasFocus
                        ? appColors().primaryColorApp.withOpacity(0.4)
                        : appColors().colorHint.withOpacity(0.2),
                width: _focusNode.hasFocus ? 2 : 1.5,
              ),
              boxShadow:
                  _focusNode.hasFocus
                      ? [
                        BoxShadow(
                          color: appColors().primaryColorApp.withOpacity(0.1),
                          blurRadius: 8.w,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: TextField(
              controller: _nameController,
              focusNode: _focusNode,
              maxLength: 50,
              style: TextStyle(
                fontSize: 16.sp,
                color: appColors().colorTextHead,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Enter playlist name...',
                hintStyle: TextStyle(
                  fontSize: 16.sp,
                  color: appColors().colorText.withOpacity(0.5),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 18.w,
                ),
                counterStyle: TextStyle(
                  fontSize: 12.sp,
                  color: appColors().colorText.withOpacity(0.6),
                  fontFamily: 'Poppins',
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _createPlaylist(),
              onChanged: (value) {
                setState(() {
                  if (_errorMessage != null) {
                    _errorMessage = null;
                  }
                });
              },
            ),
          ),
          if (_errorMessage != null) ...[
            SizedBox(height: 12.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
              decoration: BoxDecoration(
                color: appColors().primaryColorApp.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: appColors().primaryColorApp.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: appColors().primaryColorApp,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: appColors().primaryColorApp,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.fromLTRB(32.w, 32.w, 32.w, 32.w),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed:
                  _isLoading ? null : () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                backgroundColor: appColors().colorHint.withOpacity(0.1),
                padding: EdgeInsets.symmetric(vertical: 16.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: appColors().colorText.withOpacity(0.8),
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: ElevatedButton(
              onPressed:
                  _isLoading || _nameController.text.trim().isEmpty
                      ? null
                      : _createPlaylist,
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors().primaryColorApp,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: _isLoading ? 0 : 4,
                shadowColor: appColors().primaryColorApp.withOpacity(0.3),
              ),
              child:
                  _isLoading
                      ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        ),
                      )
                      : Text(
                        'Create',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
