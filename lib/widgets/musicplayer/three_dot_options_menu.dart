import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/hooks/favorites_hook.dart';
import 'package:jainverse/widgets/playlist/add_to_playlist_bottom_sheet.dart';

/// Provides a clean, overlay-style menu with various music actions
class ThreeDotOptionsMenu extends StatefulWidget {
  final String songId;
  final String title;
  final String artist;
  final String? songImage; // Add song image parameter
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onPlayNext;
  final VoidCallback? onCreateStation;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onDeleteFromLibrary;
  final VoidCallback? onRemoveFromRecent;
  final bool showDeleteFromLibrary;
  final bool showRemoveFromRecent;
  final bool allowDownload;
  final DataMusic? track; // Add track data for enhanced download functionality

  const ThreeDotOptionsMenu({
    super.key,
    required this.songId,
    required this.title,
    required this.artist,
    this.songImage,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onAddToPlaylist,
    this.onPlayNext,
    this.onCreateStation,
    this.onAddToQueue,
    this.onDownload,
    this.onShare,
    this.onDeleteFromLibrary,
    this.onRemoveFromRecent,
    this.showDeleteFromLibrary = false,
    this.showRemoveFromRecent = false,
    this.allowDownload = true,
    this.track,
  });

  @override
  State<ThreeDotOptionsMenu> createState() => _ThreeDotOptionsMenuState();

  /// Static method to show the menu as a bottom sheet
  /// Uses root navigator to ensure it appears above navigation bars and mini player
  static Future<void> showAsBottomSheet(
    BuildContext context, {
    required String songId,
    required String title,
    required String artist,
    String? songImage,
    bool isFavorite = false,
    VoidCallback? onFavoriteToggle,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onPlayNext,
    VoidCallback? onCreateStation,
    VoidCallback? onAddToQueue,
    VoidCallback? onDownload,
    VoidCallback? onShare,
    VoidCallback? onDeleteFromLibrary,
    VoidCallback? onRemoveFromRecent,
    bool showDeleteFromLibrary = false,
    bool showRemoveFromRecent = false,
    bool allowDownload = true,
    DataMusic? track, // Add track parameter for enhanced download functionality
  }) {
    // Use the root navigator context to ensure the bottom sheet appears above all navigation elements
    final NavigatorState rootNavigator = Navigator.of(
      context,
      rootNavigator: true,
    );
    final BuildContext rootContext = rootNavigator.context;

    return showModalBottomSheet(
      context: rootContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Container(
              margin: EdgeInsets.all(16.w),
              child: ThreeDotOptionsMenu(
                songId: songId,
                title: title,
                artist: artist,
                songImage: songImage,
                isFavorite: isFavorite,
                onFavoriteToggle: onFavoriteToggle,
                onAddToPlaylist: onAddToPlaylist,
                onPlayNext: onPlayNext,
                onCreateStation: onCreateStation,
                onAddToQueue: onAddToQueue,
                onDownload: onDownload,
                onShare: onShare,
                onDeleteFromLibrary: onDeleteFromLibrary,
                onRemoveFromRecent: onRemoveFromRecent,
                showDeleteFromLibrary: showDeleteFromLibrary,
                showRemoveFromRecent: showRemoveFromRecent,
                allowDownload: allowDownload,
                track: track,
              ),
            ),
          ),
    );
  }

  /// Static method to show the menu as a positioned dialog (for contextual positioning)
  static Future<void> showAsDialog(
    BuildContext context, {
    required GlobalKey buttonKey,
    required String songId,
    required String title,
    required String artist,
    String? songImage,
    bool isFavorite = false,
    VoidCallback? onFavoriteToggle,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onPlayNext,
    VoidCallback? onCreateStation,
    VoidCallback? onAddToQueue,
    VoidCallback? onDownload,
    VoidCallback? onShare,
    VoidCallback? onDeleteFromLibrary,
    VoidCallback? onRemoveFromRecent,
    bool showDeleteFromLibrary = false,
    bool showRemoveFromRecent = false,
    bool allowDownload = true,
    DataMusic? track, // Add track parameter
  }) {
    // Safe context check
    if (buttonKey.currentContext?.mounted != true) {
      // Fallback to bottom sheet if context is not available
      return showAsBottomSheet(
        context,
        songId: songId,
        title: title,
        artist: artist,
        songImage: songImage,
        isFavorite: isFavorite,
        onFavoriteToggle: onFavoriteToggle,
        onAddToPlaylist: onAddToPlaylist,
        onPlayNext: onPlayNext,
        onCreateStation: onCreateStation,
        onAddToQueue: onAddToQueue,
        onDownload: onDownload,
        onShare: onShare,
        onDeleteFromLibrary: onDeleteFromLibrary,
        onRemoveFromRecent: onRemoveFromRecent,
        showDeleteFromLibrary: showDeleteFromLibrary,
        showRemoveFromRecent: showRemoveFromRecent,
        allowDownload: allowDownload,
        track: track,
      );
    }

    final RenderBox? renderBox =
        buttonKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      // Fallback to bottom sheet
      return showAsBottomSheet(
        context,
        songId: songId,
        title: title,
        artist: artist,
        songImage: songImage,
        isFavorite: isFavorite,
        onFavoriteToggle: onFavoriteToggle,
        onAddToPlaylist: onAddToPlaylist,
        onPlayNext: onPlayNext,
        onCreateStation: onCreateStation,
        onAddToQueue: onAddToQueue,
        onDownload: onDownload,
        onShare: onShare,
        onDeleteFromLibrary: onDeleteFromLibrary,
        onRemoveFromRecent: onRemoveFromRecent,
        showDeleteFromLibrary: showDeleteFromLibrary,
        showRemoveFromRecent: showRemoveFromRecent,
        allowDownload: allowDownload,
      );
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    // Calculate optimal position - moved 10% higher up
    double left = position.dx - 150.w + size.width;
    double top =
        position.dy - 410.w; // Moved up from 360.w to 340.w (10% increase)

    // Ensure the dialog stays within screen bounds
    if (left < 16.w) left = 16.w;
    if (left + 250.w > screenSize.width - 16.w) {
      left = screenSize.width - 250.w - 16.w;
    }

    // If there's not enough space above, show below instead
    if (top < 50.w) {
      // Reduced threshold from 100.w to 50.w
      top = position.dy + size.height + 8.w;
    }

    // Final check to ensure it doesn't go off bottom of screen
    if (top + 320.w > screenSize.height - 100.w) {
      top = screenSize.height - 420.w; // Position near bottom with some margin
    }

    return showDialog(
      context: context,
      barrierColor: Colors.transparent, // Make barrier completely transparent
      builder:
          (context) => Stack(
            children: [
              // Positioned menu - removed the overlay GestureDetector
              Positioned(
                left: left,
                top: top,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 250.w,
                    constraints: BoxConstraints(
                      maxHeight: screenSize.height * 0.6,
                    ),
                    child: ThreeDotOptionsMenu(
                      songId: songId,
                      title: title,
                      artist: artist,
                      songImage: songImage,
                      isFavorite: isFavorite,
                      onFavoriteToggle: onFavoriteToggle,
                      onAddToPlaylist: onAddToPlaylist,
                      onPlayNext: onPlayNext,
                      onCreateStation: onCreateStation,
                      onAddToQueue: onAddToQueue,
                      onDownload: onDownload,
                      onShare: onShare,
                      onDeleteFromLibrary: onDeleteFromLibrary,
                      onRemoveFromRecent: onRemoveFromRecent,
                      showDeleteFromLibrary: showDeleteFromLibrary,
                      showRemoveFromRecent: showRemoveFromRecent,
                      allowDownload: allowDownload,
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

class _ThreeDotOptionsMenuState extends State<ThreeDotOptionsMenu>
    with TickerProviderStateMixin {
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;

  // Enhanced download tracking
  final DownloadController _downloadController = DownloadController();
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();

    // Debug: Log initial state
    print(
      '🔥 ThreeDotOptionsMenu: initState - songId: ${widget.songId}, isFavorite: ${widget.isFavorite}',
    );

    // Initialize heart animation controller
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Scale animation for the heart (grows and shrinks)
    _heartScaleAnimation = Tween<double>(begin: 0.3, end: 3.0).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: const Interval(0.0, 0.99, curve: Curves.easeOut),
      ),
    );

    // Opacity animation for fade effect
    _heartOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _heartAnimationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Initialize download status
    _initializeDownloadStatus();
  }

  /// Initialize and check current download status
  Future<void> _initializeDownloadStatus() async {
    try {
      final isDownloaded = _downloadController.isTrackDownloaded(widget.songId);
      final isDownloading = _downloadController.isDownloading(widget.songId);
      final progress = _downloadController.getDownloadProgress(widget.songId);

      if (mounted) {
        setState(() {
          _isDownloaded = isDownloaded;
          _isDownloading = isDownloading;
          _downloadProgress = progress;
        });
      }
    } catch (e) {
      print('Error initializing download status: $e');
    }
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ThreeDotOptionsMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Log when the widget's isFavorite parameter changes
    if (oldWidget.isFavorite != widget.isFavorite) {
      print(
        '🔥 ThreeDotOptionsMenu: didUpdateWidget - oldWidget.isFavorite: ${oldWidget.isFavorite}, widget.isFavorite: ${widget.isFavorite}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: (appColors().gray[900] ?? Colors.black).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16.w),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Menu options - removed header
            _buildMenuOptions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOptions(BuildContext context) {
    final options = <Widget>[];

    // Play Next
    if (widget.onPlayNext != null) {
      options.add(
        _buildMenuOption(
          icon: Icons.skip_next_outlined,
          title: 'Play Next',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            widget.onPlayNext?.call();
          },
        ),
      );
    }

    // Add to Playlist
    if (options.isNotEmpty) options.add(_buildDivider());
    options.add(
      _buildMenuOption(
        icon: Icons.playlist_add_outlined,
        title: 'Add to Playlist',
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
          if (widget.onAddToPlaylist != null) {
            widget.onAddToPlaylist?.call();
          } else {
            // Use the new modern playlist bottom sheet with force refresh
            final rootContext =
                Navigator.of(context, rootNavigator: true).context;
            AddToPlaylistBottomSheet.show(
              rootContext,
              songId: widget.songId,
              songTitle: widget.title,
              artistName: widget.artist,
              songImage: widget.songImage,
              forceRefresh:
                  true, // Force refresh when opened from three-dot menu
            );
          }
        },
      ),
    );

    // Create Station
    if (widget.onCreateStation != null) {
      if (options.isNotEmpty) options.add(_buildDivider());
      options.add(
        _buildMenuOption(
          icon: Icons.radio_outlined,
          title: 'Create Station',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            widget.onCreateStation?.call();
          },
        ),
      );
    }

    // Favorite
    if (options.isNotEmpty) options.add(_buildDivider());
    options.add(_buildFavoriteMenuOption());

    // Download
    if (widget.allowDownload) {
      if (options.isNotEmpty) options.add(_buildDivider());
      options.add(_buildEnhancedDownloadOption());
    }

    // Share
    if (widget.onShare != null) {
      if (options.isNotEmpty) options.add(_buildDivider());
      options.add(
        _buildMenuOption(
          icon: Icons.share_outlined,
          title: 'Share Song',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            widget.onShare?.call();
          },
        ),
      );
    }

    // Delete from Library
    if (widget.showDeleteFromLibrary && widget.onDeleteFromLibrary != null) {
      options.add(_buildDivider());
      options.add(
        _buildMenuOption(
          icon: Icons.delete_outline,
          title: 'Delete from Library',
          iconColor: appColors().primaryColorApp.withOpacity(0.8),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            widget.onDeleteFromLibrary?.call();
          },
        ),
      );
    }

    // Remove from Recent
    if (widget.showRemoveFromRecent && widget.onRemoveFromRecent != null) {
      options.add(_buildDivider());
      options.add(
        _buildMenuOption(
          icon: Icons.history_outlined,
          title: 'Remove from Recent',
          iconColor: appColors().primaryColorApp.withOpacity(0.8),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            widget.onRemoveFromRecent?.call();
          },
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.w),
      child: Column(mainAxisSize: MainAxisSize.min, children: options),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.w),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 16.w),
                child: Icon(
                  icon,
                  color: iconColor ?? Colors.white.withOpacity(0.8),
                  size: 22.w,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1.5.w,
      // margin: EdgeInsets.symmetric(horizontal: 1.w),
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildFavoriteMenuOption() {
    return FavoritesSelector<bool>(
      selector: (provider) {
        final result = provider.isFavorite(widget.songId);
        print(
          '🔥 ThreeDotMenu: FavoritesSelector called for songId: ${widget.songId}, result: $result',
        );
        return result;
      },
      builder: (context, isGloballyFavorite, child) {
        print(
          '🔥 ThreeDotMenu: FavoritesSelector builder called - songId: ${widget.songId}, isFavorite: $isGloballyFavorite',
        );

        // Use global provider status if available, fallback to widget status
        final isFavorite = isGloballyFavorite;

        return Stack(
          children: [
            // Main favorite menu option
            _buildMenuOption(
              icon: isFavorite ? Icons.favorite : Icons.favorite_border,
              title: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              iconColor:
                  isFavorite
                      ? appColors().primaryColorApp
                      : Colors.white.withOpacity(0.8),
              onTap: () {
                print(
                  '🔥 ThreeDotMenu: Favorite toggle tapped for songId: ${widget.songId}',
                );
                HapticFeedback.lightImpact();
                // Close menu immediately for better UX
                Navigator.pop(context);
                // Call the favorite toggle callback
                widget.onFavoriteToggle?.call();
              },
            ),

            // Animated heart overlay (only visible during animation)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _heartAnimationController,
                builder: (context, child) {
                  if (!_heartAnimationController.isAnimating &&
                      _heartAnimationController.value == 0) {
                    return const SizedBox.shrink();
                  }

                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 20.w),
                      child: Transform.scale(
                        scale: _heartScaleAnimation.value,
                        child: Opacity(
                          opacity: _heartOpacityAnimation.value,
                          child: Icon(
                            Icons.favorite,
                            color: appColors().primaryColorApp,
                            size: 22.w,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnhancedDownloadOption() {
    // Determine the current state and appropriate action
    IconData icon;
    String title;
    VoidCallback? onTap;
    Color? iconColor;

    if (_isDownloading) {
      icon = Icons.downloading;
      title = 'Downloading... ${(_downloadProgress * 100).toInt()}%';
      onTap = null; // Disable during download
      iconColor = Colors.orange;
    } else if (_isDownloaded) {
      icon = Icons.download_done;
      title = 'Remove Download';
      iconColor = Colors.green;
      onTap = () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        _handleRemoveDownload();
      };
    } else {
      icon = Icons.download_outlined;
      title = 'Download';
      iconColor = Colors.white.withOpacity(0.8);
      onTap = () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        _handleDownload();
      };
    }

    return Stack(
      children: [
        // Main download option
        _buildMenuOption(
          icon: icon,
          title: title,
          iconColor: iconColor,
          onTap: onTap ?? () {}, // Provide empty callback for disabled state
        ),

        // Progress indicator for downloads
        if (_isDownloading)
          Positioned(
            right: 20.w,
            top: 0,
            bottom: 0,
            child: Center(
              child: SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  value: _downloadProgress,
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  backgroundColor: Colors.orange.withOpacity(0.3),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Handle download action with enhanced functionality
  Future<void> _handleDownload() async {
    if (widget.track == null) {
      // Fallback to legacy download callback
      widget.onDownload?.call();
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isDownloading = true;
          _downloadProgress = 0.0;
        });
      }

      // Use DownloadController to add to downloads and trigger sync
      final trackId = widget.track!.id.toString();
      final success = await _downloadController.addToDownloads(trackId);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloaded = success;
          _downloadProgress = success ? 1.0 : 0.0;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download completed: ${widget.title}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: ${widget.title}'),
              backgroundColor: appColors().primaryColorApp,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: appColors().primaryColorApp,
          ),
        );
      }
    }
  }

  /// Handle remove download action
  Future<void> _handleRemoveDownload() async {
    try {
      await _downloadController.removeFromDownloads(widget.songId);

      if (mounted) {
        setState(() {
          _isDownloaded = false;
          _isDownloading = false;
          _downloadProgress = 0.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download removed: ${widget.title}'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove download: $e'),
            backgroundColor: appColors().primaryColorApp,
          ),
        );
      }
    }
  }
}

/// Simple three-dot button widget that can be used anywhere
class ThreeDotMenuButton extends StatefulWidget {
  final String songId;
  final String title;
  final String artist;
  final String? songImage;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onPlayNext;
  final VoidCallback? onCreateStation;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onDeleteFromLibrary;
  final VoidCallback? onRemoveFromRecent;
  final bool showDeleteFromLibrary;
  final bool showRemoveFromRecent;
  final bool allowDownload;
  final bool useBottomSheet;
  final Color? iconColor;
  final double? iconSize;

  const ThreeDotMenuButton({
    super.key,
    required this.songId,
    required this.title,
    required this.artist,
    this.songImage,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onAddToPlaylist,
    this.onPlayNext,
    this.onCreateStation,
    this.onAddToQueue,
    this.onDownload,
    this.onShare,
    this.onDeleteFromLibrary,
    this.onRemoveFromRecent,
    this.showDeleteFromLibrary = false,
    this.showRemoveFromRecent = false,
    this.allowDownload = true,
    this.useBottomSheet = false,
    this.iconColor,
    this.iconSize,
  });

  @override
  State<ThreeDotMenuButton> createState() => _ThreeDotMenuButtonState();
}

class _ThreeDotMenuButtonState extends State<ThreeDotMenuButton> {
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: _buttonKey,
        borderRadius: BorderRadius.circular(20.w),
        onTap: _showMenu,
        child: Container(
          padding: EdgeInsets.all(8.w),
          child: Icon(
            Icons.more_vert,
            color: widget.iconColor ?? appColors().gray[600],
            size: widget.iconSize ?? 20.w,
          ),
        ),
      ),
    );
  }

  void _showMenu() {
    HapticFeedback.lightImpact();

    // Debug: Log the current favorite status when menu is opened
    print('🔥 ThreeDotMenuButton: Opening menu for songId: ${widget.songId}');
    print('🔥 ThreeDotMenuButton: Current isFavorite: ${widget.isFavorite}');

    if (widget.useBottomSheet) {
      ThreeDotOptionsMenu.showAsBottomSheet(
        context,
        songId: widget.songId,
        title: widget.title,
        artist: widget.artist,
        songImage: widget.songImage,
        isFavorite: widget.isFavorite,
        onFavoriteToggle: widget.onFavoriteToggle,
        onAddToPlaylist: widget.onAddToPlaylist,
        onPlayNext: widget.onPlayNext,
        onCreateStation: widget.onCreateStation,
        onAddToQueue: widget.onAddToQueue,
        onDownload: widget.onDownload,
        onShare: widget.onShare,
        onDeleteFromLibrary: widget.onDeleteFromLibrary,
        onRemoveFromRecent: widget.onRemoveFromRecent,
        showDeleteFromLibrary: widget.showDeleteFromLibrary,
        showRemoveFromRecent: widget.showRemoveFromRecent,
        allowDownload: widget.allowDownload,
      );
    } else {
      ThreeDotOptionsMenu.showAsDialog(
        context,
        buttonKey: _buttonKey,
        songId: widget.songId,
        title: widget.title,
        artist: widget.artist,
        songImage: widget.songImage,
        isFavorite: widget.isFavorite,
        onFavoriteToggle: widget.onFavoriteToggle,
        onAddToPlaylist: widget.onAddToPlaylist,
        onPlayNext: widget.onPlayNext,
        onCreateStation: widget.onCreateStation,
        onAddToQueue: widget.onAddToQueue,
        onDownload: widget.onDownload,
        onShare: widget.onShare,
        onDeleteFromLibrary: widget.onDeleteFromLibrary,
        onRemoveFromRecent: widget.onRemoveFromRecent,
        showDeleteFromLibrary: widget.showDeleteFromLibrary,
        showRemoveFromRecent: widget.showRemoveFromRecent,
        allowDownload: widget.allowDownload,
      );
    }
  }
}
