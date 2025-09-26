import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelPlayList.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/widgets/playlist/create_playlist_dialog.dart';
import 'package:jainverse/widgets/playlist/playlist_service.dart';

class AddToPlaylistBottomSheet extends StatefulWidget {
  final String songId;
  final String songTitle;
  final String artistName;
  final String? songImage; // Add song image parameter
  final VoidCallback? onPlaylistAdded;
  final bool forceRefresh; // Add force refresh parameter
  final bool
  showCreateOnly; // When true, the sheet will immediately open the Create Playlist dialog
  final VoidCallback? onClose;

  const AddToPlaylistBottomSheet({
    super.key,
    required this.songId,
    required this.songTitle,
    required this.artistName,
    this.songImage,
    this.onPlaylistAdded,
    this.forceRefresh = false,
    this.showCreateOnly = false,
    this.onClose,
  });

  @override
  State<AddToPlaylistBottomSheet> createState() =>
      _AddToPlaylistBottomSheetState();

  /// Static method to show the bottom sheet with enhanced UX
  /// Uses root navigator and a modal route to ensure it appears above all UI elements including navigation bars and mini player
  static Future<void> show(
    BuildContext context, {
    required String songId,
    required String songTitle,
    required String artistName,
    String? songImage,
    VoidCallback? onPlaylistAdded,
    bool forceRefresh = false,
    bool showCreateOnly = false,
  }) {
    final BuildContext rootContext =
        Navigator.of(context, rootNavigator: true).context;

    return showGeneralDialog<void>(
      context: rootContext,
      barrierDismissible: true,
      barrierLabel: 'AddToPlaylist',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          top: false,
          bottom: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AddToPlaylistBottomSheet(
              songId: songId,
              songTitle: songTitle,
              artistName: artistName,
              songImage: songImage,
              onPlaylistAdded: onPlaylistAdded,
              forceRefresh: forceRefresh,
              showCreateOnly: showCreateOnly,
              onClose: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, a1, a2, widget) {
        final curved = CurvedAnimation(parent: a1, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: a1,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: widget,
          ),
        );
      },
    );
  }
}

class _AddToPlaylistBottomSheetState extends State<AddToPlaylistBottomSheet>
    with TickerProviderStateMixin {
  final PlaylistService _playlistService = PlaylistService();

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Future<ModelPlayList>? _playlistsFuture;
  bool _isRefreshing = false;
  String? _addingToPlaylistId;

  @override
  void initState() {
    super.initState();

    // Initialize enhanced animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Load playlists with force refresh if specified
    if (widget.forceRefresh) {
      _refreshPlaylists();
    } else {
      _loadPlaylists();
    }
    _animationController.forward();

    // If the caller requested create-only mode, open the Create Playlist
    // dialog right after the sheet animates in. We schedule it on the
    // next frame to avoid calling context during build.
    if (widget.showCreateOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // give a small delay to let the sheet finish animating
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        await _createNewPlaylist();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadPlaylists() {
    setState(() {
      _playlistsFuture = _playlistService.getPlaylists();
    });
  }

  void _refreshPlaylists() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      // Set the future to null to trigger loading state immediately
      _playlistsFuture = null;
    });

    HapticFeedback.lightImpact();

    try {
      // Start the fresh data fetch and immediately assign it to _playlistsFuture
      final refreshedFuture = _playlistService.getPlaylists(forceRefresh: true);
      setState(() {
        _playlistsFuture = refreshedFuture;
      });

      // Wait for the data to load
      await refreshedFuture;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _addToPlaylist(DataCat playlist) async {
    HapticFeedback.mediumImpact();

    setState(() {
      _addingToPlaylistId = playlist.id.toString();
    });

    final success = await _playlistService.addSongToPlaylist(
      widget.songId,
      playlist.id.toString(),
      playlist.playlist_name,
    );

    if (mounted) {
      setState(() {
        _addingToPlaylistId = null;
      });

      if (success) {
        // Force immediate refresh with fresh data
        setState(() {
          _playlistsFuture = _playlistService.getPlaylists(forceRefresh: true);
        });

        widget.onPlaylistAdded?.call();

        // Enhanced user feedback with haptic
        HapticFeedback.heavyImpact();

        // Smooth delay before closing
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          if (widget.onClose != null) {
            widget.onClose!.call();
          } else {
            Navigator.of(context).pop();
          }
        }
      }
    }
  }

  Future<void> _createNewPlaylist() async {
    HapticFeedback.lightImpact();

    // Use root navigator context to ensure dialog appears above all navigation elements
    final BuildContext rootContext =
        Navigator.of(context, rootNavigator: true).context;

    final result = await CreatePlaylistDialog.show(
      rootContext,
      songId: widget.songId,
      onPlaylistCreated: () {
        _refreshPlaylists();
        widget.onPlaylistAdded?.call();
      },
    );

    if (result == true && mounted) {
      if (widget.onClose != null) {
        widget.onClose!.call();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return WillPopScope(
          onWillPop: () async {
            // Handle back button properly - close the bottom sheet
            if (widget.onClose != null) {
              widget.onClose!.call();
            } else {
              Navigator.of(context).pop();
            }
            return false; // Prevent default behavior
          },
          child: Material(
            type: MaterialType.transparency,
            elevation: 999, // Maximum elevation to ensure highest z-index
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: DraggableScrollableSheet(
                  initialChildSize: 0.8,
                  minChildSize: 0.6,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32.r),
                        topRight: Radius.circular(32.r),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32.r),
                              topRight: Radius.circular(32.r),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.grey.shade900.withOpacity(0.85),
                                Colors.black.withOpacity(0.90),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.45),
                                blurRadius: 30.w,
                                offset: const Offset(0, -10),
                                spreadRadius: 3.w,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildDragHandle(),
                              _buildHeader(),
                              _buildSongInfo(),
                              Expanded(
                                child: _buildPlaylistsList(scrollController),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: EdgeInsets.only(top: 10.w),
      width: 40.w,
      height: 4.w,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10.r),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 16.w, 24.w, 12.w),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add to Playlist',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 4.w),
                    Text(
                      'Choose where to save your music',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white.withOpacity(0.7),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  if (widget.onClose != null) {
                    widget.onClose!.call();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 20.sp,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSongInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 28.w),
      child: Row(
        children: [
          // Song Image or Default Icon
          Container(
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              color: appColors().primaryColorApp.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8.w,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child:
                widget.songImage != null && widget.songImage!.isNotEmpty
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.network(
                        '${AppConstant.ImageUrl}images/audio/thumb/${widget.songImage}',
                        width: 54.w,
                        height: 54.w,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            decoration: BoxDecoration(
                              color: appColors().primaryColorApp.withOpacity(
                                0.15,
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation(
                                    appColors().primaryColorApp,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultSongIcon();
                        },
                      ),
                    )
                    : _buildDefaultSongIcon(),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.songTitle,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.w),
                Text(
                  widget.artistName,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.7),
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultSongIcon() {
    return Container(
      decoration: BoxDecoration(
        color: appColors().primaryColorApp.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: appColors().primaryColorApp,
        size: 24.sp,
      ),
    );
  }

  Widget _buildPlaylistsList(ScrollController scrollController) {
    return FutureBuilder<ModelPlayList>(
      future: _playlistsFuture,
      builder: (context, snapshot) {
        // Show loading state when future is null or connection is waiting
        if (_playlistsFuture == null ||
            snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (!snapshot.hasData || snapshot.data!.data.isEmpty) {
          return _buildEmptyState();
        }

        final playlists = snapshot.data!.data;

        return Column(
          children: [
            // Fixed header section
            Container(
              padding: EdgeInsets.fromLTRB(24.w, 18.w, 24.w, 0.w),
              child: Column(
                children: [
                  _buildCreateNewTile(),
                  SizedBox(height: 16.w),
                  Row(
                    children: [
                      Text(
                        'Your Playlists (${playlists.length})',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.w),
                ],
              ),
            ),
            // Scrollable playlists section
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refreshPlaylists(),
                color: appColors().primaryColorApp,
                backgroundColor: appColors().colorBackEditText,
                strokeWidth: 2.5,
                child: ListView.builder(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24.w, 0.w, 24.w, 24.w),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    return _buildPlaylistTile(playlists[index]);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 40.w,
          height: 40.w,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(appColors().primaryColorApp),
          ),
        ),
        SizedBox(height: 24.w),
        Text(
          _isRefreshing
              ? 'Refreshing playlists...'
              : 'Loading your playlists...',
          style: TextStyle(
            fontSize: 16.sp,
            color: appColors().colorText.withOpacity(0.7),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_isRefreshing) ...[
          SizedBox(height: 8.w),
          Text(
            'Getting the latest data',
            style: TextStyle(
              fontSize: 14.sp,
              color: appColors().colorText.withOpacity(0.5),
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: appColors().primaryColorApp.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Icon(
            Icons.error_outline_rounded,
            color: appColors().primaryColorApp,
            size: 48.sp,
          ),
        ),
        SizedBox(height: 24.w),
        Text(
          'Unable to load playlists',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: appColors().colorTextHead,
            fontFamily: 'Poppins',
          ),
        ),
        SizedBox(height: 8.w),
        Text(
          'Please check your connection and try again',
          style: TextStyle(
            fontSize: 14.sp,
            color: appColors().colorText.withOpacity(0.7),
            fontFamily: 'Poppins',
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24.w),
        ElevatedButton.icon(
          onPressed: _refreshPlaylists,
          icon: Icon(Icons.refresh_rounded, size: 20.sp),
          label: Text(
            'Try Again',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: appColors().primaryColorApp,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 48.w),
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: appColors().primaryColorApp.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Icon(
              Icons.playlist_add_outlined,
              color: appColors().primaryColorApp,
              size: 56.sp,
            ),
          ),
          SizedBox(height: 24.w),
          Text(
            'No playlists yet',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 12.w),
          Text(
            'Create your first playlist to organize\nyour favorite songs',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'Poppins',
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28.w),
          _buildCreateNewTile(),
        ],
      ),
    );
  }

  Widget _buildCreateNewTile() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _createNewPlaylist,
          borderRadius: BorderRadius.circular(20.r),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  appColors().primaryColorApp.withOpacity(0.2),
                  appColors().primaryColorApp.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: appColors().primaryColorApp.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: appColors().primaryColorApp.withOpacity(0.15),
                  blurRadius: 8.w,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: appColors().primaryColorApp,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: appColors().primaryColorApp.withOpacity(0.3),
                        blurRadius: 8.w,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Playlist',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: appColors().primaryColorApp,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: appColors().primaryColorApp,
                  size: 16.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(DataCat playlist) {
    final songCount = playlist.song_list.length;
    final isLoading = _addingToPlaylistId == playlist.id.toString();

    return Container(
      margin: EdgeInsets.only(bottom: 10.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () => _addToPlaylist(playlist),
          borderRadius: BorderRadius.circular(20.r),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color:
                  isLoading
                      ? appColors().primaryColorApp.withOpacity(0.15)
                      : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color:
                    isLoading
                        ? appColors().primaryColorApp.withOpacity(0.4)
                        : Colors.white.withOpacity(0.2),
                width: isLoading ? 2 : 1.5,
              ),
              boxShadow:
                  isLoading
                      ? [
                        BoxShadow(
                          color: appColors().primaryColorApp.withOpacity(0.2),
                          blurRadius: 12.w,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8.w,
                          offset: const Offset(0, 2),
                        ),
                      ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 54.w,
                  height: 54.w,
                  child:
                      songCount > 0
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child:
                                songCount > 0 &&
                                        playlist
                                            .song_list
                                            .first
                                            .image
                                            .isNotEmpty
                                    ? Image.network(
                                      '${AppConstant.ImageUrl}images/audio/thumb/${playlist.song_list.first.image}',
                                      width: 54.w,
                                      height: 54.w,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (
                                        context,
                                        child,
                                        loadingProgress,
                                      ) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          width: 54.w,
                                          height: 54.w,
                                          decoration: BoxDecoration(
                                            color: appColors().primaryColorApp
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12.r,
                                            ),
                                          ),
                                          child: Center(
                                            child: SizedBox(
                                              width: 20.w,
                                              height: 20.w,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      appColors()
                                                          .primaryColorApp,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return _buildDefaultPlaylistIcon();
                                      },
                                    )
                                    : _buildDefaultPlaylistIcon(),
                          )
                          : _buildDefaultPlaylistIcon(),
                ),
                SizedBox(width: 20.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.playlist_name,
                        style: TextStyle(
                          fontSize: AppSizes.fontMedium - 1,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.w),
                      Row(
                        children: [
                          Icon(
                            songCount == 0
                                ? Icons.playlist_add_outlined
                                : Icons.library_music_outlined,
                            size: 24.sp,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            songCount == 0
                                ? 'Empty playlist'
                                : '$songCount song${songCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: AppSizes.fontSmall - 1,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color:
                        isLoading
                            ? appColors().primaryColorApp.withOpacity(0.2)
                            : appColors().primaryColorApp.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child:
                      isLoading
                          ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation(
                                appColors().primaryColorApp,
                              ),
                            ),
                          )
                          : Icon(
                            Icons.add_rounded,
                            color: appColors().primaryColorApp,
                            size: 24.sp,
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultPlaylistIcon() {
    return Container(
      decoration: BoxDecoration(
        color: appColors().primaryColorApp.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Icon(
        Icons.queue_music_rounded,
        color: appColors().primaryColorApp,
        size: 28.sp,
      ),
    );
  }
}
