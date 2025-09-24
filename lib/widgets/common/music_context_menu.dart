import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
// sizes not required here
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Enum to define the type of music content
enum MusicType { song, playlist, album }

/// Data model for context menu actions
class MusicContextAction {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  /// If provided, this notifier will be used to render a live favorite/toggle
  /// state inside the open context menu. When present the menu will not
  /// automatically dismiss after the action is invoked unless
  /// [closeOnTap] is set to true.
  final ValueNotifier<bool>? favoriteNotifier;

  /// Whether the menu should close after this action is tapped. Defaults to
  /// true for compatibility with existing actions. Favorite toggle actions
  /// created by the helper set this to false so the menu remains open.
  final bool closeOnTap;
  final bool isDestructive;

  const MusicContextAction({
    required this.title,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.isDestructive = false,
    this.favoriteNotifier,
    this.closeOnTap = true,
  });
}

/// Context menu data model
class MusicContextMenuData {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final MusicType type;
  final List<MusicContextAction> actions;

  const MusicContextMenuData({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.actions,
    this.imageUrl,
  });
}

/// Main context menu overlay widget
class MusicContextMenu extends StatefulWidget {
  final MusicContextMenuData data;
  final Offset position;
  final Size cardSize;
  final VoidCallback onDismiss;

  const MusicContextMenu({
    super.key,
    required this.data,
    required this.position,
    required this.cardSize,
    required this.onDismiss,
  });

  @override
  State<MusicContextMenu> createState() => _MusicContextMenuState();
}

class _MusicContextMenuState extends State<MusicContextMenu>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    // Smooth fade in with no delay
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    // Gentle scale animation starting closer to final size
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    // Subtle slide up animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Background overlay with Gaussian blur
          GestureDetector(
            onTap: _dismiss,
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Apply blur effect
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                ],
              ),
            ),
          ),
          // Context menu
          _buildContextMenu(),
        ],
      ),
    );
  }

  Widget _buildContextMenu() {
    final screenSize = MediaQuery.of(context).size;
    final menuWidth = 340.w;
    final previewHeight = 340.w;
    final actionItemHeight = 50.w;
    final menuHeight =
        previewHeight + (widget.data.actions.length * actionItemHeight) + 16.w;

    // Center the menu in the middle of the screen
    double left = (screenSize.width - menuWidth) / 2.5;
    double top = (screenSize.height - menuHeight) / 3;

    return Positioned(
      left: left,
      top: top,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24.w,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: _buildMenuContent(menuWidth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuContent(double menuWidth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Song info/image card
        Container(
          width: menuWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.13),
                blurRadius: 24.w,
                offset: const Offset(0, 12),
                spreadRadius: 0,
              ),
            ],
          ),
          child: _buildPreviewCard(),
        ),
        SizedBox(height: 12.w), // Gap between the two cards
        // Actions card with full-width tap detection
        SizedBox(
          width: menuWidth,
          child: Stack(
            children: [
              // Transparent GestureDetector for blank space
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _dismiss,
                  child: Container(),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 240.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.w),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 18.w,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: _buildActionsList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      child: Column(
        children: [
          // Large image with exact design proportions and overflow handling
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.w),
              topRight: Radius.circular(20.w),
            ),
            child: Container(
              width: 340.w, // Larger to match the design
              height: 340.w,
              decoration: BoxDecoration(color: Colors.grey[340]),
              child:
                  widget.data.imageUrl != null &&
                          widget.data.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: widget.data.imageUrl!,
                        fit: BoxFit.cover,
                        width: 340.w,
                        height: 340.w,
                        placeholder:
                            (context, url) => Container(
                              width: 340.w,
                              height: 340.w,
                              color: Colors.grey[300],
                              child: Center(
                                child: SizedBox(
                                  width: 28.w,
                                  height: 28.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation(
                                      appColors().primaryColorApp,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Image.asset(
                              'assets/images/song_placeholder.png',
                              fit: BoxFit.cover,
                              width: 340.w,
                              height: 340.w,
                            ),
                        fadeInDuration: const Duration(milliseconds: 250),
                      )
                      : Image.asset(
                        'assets/images/song_placeholder.png',
                        fit: BoxFit.cover,
                        width: 340.w,
                        height: 340.w,
                      ),
            ),
          ),
          // SizedBox(height: 16.w), // Perfect spacing between image and text
          // Text content - left aligned like in the image
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16.w,
                right: 8.w,
                top: 8.w,
                bottom: 8.w,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Left aligned
                children: [
                  Text(
                    widget.data.title,
                    style: TextStyle(
                      fontSize: 18.sp, // Larger font for title
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: appColors().black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.w),
                  if (widget.data.subtitle.isNotEmpty)
                    Text(
                      widget.data.subtitle,
                      style: TextStyle(
                        fontSize: 14.sp, // Smaller subtitle
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Poppins',
                        color: appColors().gray[500],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Divider removed in new design

  Widget _buildActionsList() {
    return Container(
      decoration: BoxDecoration(
        color: appColors().gray[50], // Very light background for actions
        borderRadius: BorderRadius.all(Radius.circular(20.w)),
      ),
      child: Column(
        children:
            widget.data.actions
                .map((action) => _buildActionItem(action))
                .toList(),
      ),
    );
  }

  Widget _buildActionItem(MusicContextAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();

          // Execute the provided action callback. If this action represents
          // a favorite toggle (has a favoriteNotifier) we don't automatically
          // dismiss the menu so the UI can update live. The notifier is
          // expected to be updated by the provided onTap (or by the helper
          // wrapper which toggles it before calling the app logic).
          try {
            action.onTap();
          } catch (_) {
            // ignore errors from user callbacks to avoid breaking the menu
          }

          if (action.closeOnTap) {
            _dismiss();
          }
        },
        borderRadius:
            widget.data.actions.last == action
                ? BorderRadius.only(
                  bottomLeft: Radius.circular(20.w),
                  bottomRight: Radius.circular(20.w),
                )
                : BorderRadius.zero,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 16.w,
          ), // More padding
          decoration: BoxDecoration(
            border:
                widget.data.actions.last != action
                    ? Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 0.5,
                      ),
                    )
                    : null,
          ),
          child: Row(
            children: [
              // If this action has a favoriteNotifier we render its title and
              // icon from the notifier so that toggling favorites updates the
              // menu UI live without closing it. Otherwise render static
              // title/icon from the action.
              if (action.favoriteNotifier != null)
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: action.favoriteNotifier!,
                    builder: (context, isFav, _) {
                      final title =
                          isFav ? 'Undo Favorite' : 'Add to Favorites';
                      final icon =
                          isFav
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart;
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Poppins',
                                color:
                                    action.isDestructive
                                        ? Colors.red
                                        : Colors.black87,
                              ),
                            ),
                          ),
                          Icon(
                            icon,
                            size: 20.w,
                            color: action.iconColor ?? Colors.red,
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: Text(
                    action.title,
                    style: TextStyle(
                      fontSize: 16.sp, // Consistent font size
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                      color: action.isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
              // Icon on the right side like in the design for non-favorite
              // actions. Favorite actions render their own icon inside the
              // ValueListenableBuilder above.
              if (action.favoriteNotifier == null)
                Icon(
                  action.icon,
                  size: 20.w,
                  color:
                      action.isDestructive
                          ? Colors.red
                          : (action.iconColor ??
                              Colors.red), // Red icons like in design
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _dismiss() {
    // Faster reverse animation for more responsive feel
    _animationController
        .animateBack(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInQuart,
        )
        .then((_) {
          widget.onDismiss();
        });
  }
}

/// Helper class to show context menu
class MusicContextMenuHelper {
  static OverlayEntry? _overlayEntry;

  /// Show context menu for a music item
  static void show({
    required BuildContext context,
    required MusicContextMenuData data,
    required Offset position,
    required Size cardSize,
  }) {
    // Trigger haptic feedback
    HapticFeedback.mediumImpact();

    // Remove existing overlay if any
    hide();

    // Warm image cache asynchronously to reduce perceived load time.
    // We don't await this fully to avoid blocking UI; it will help when
    // the network is fast or image already cached.
    if (data.imageUrl != null && data.imageUrl!.isNotEmpty) {
      try {
        final provider = CachedNetworkImageProvider(data.imageUrl!);
        // precacheImage returns a Future; fire-and-forget with small delay cap
        precacheImage(provider, context).catchError((e) {
          // ignore errors - fallback to placeholder will be used
        });
      } catch (e) {
        // ignore
      }
    }

    _overlayEntry = OverlayEntry(
      builder:
          (context) => MusicContextMenu(
            data: data,
            position: position,
            cardSize: cardSize,
            onDismiss: hide,
          ),
    );

    // Insert into the root overlay to ensure menu appears above all UI layers
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  /// Hide context menu
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Create default actions for different music types
  static List<MusicContextAction> getDefaultActions({
    required MusicType type,
    VoidCallback? onPlay,
    VoidCallback? onPlayNext,
    VoidCallback? onAddToQueue,
    VoidCallback? onDownload,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onShare,
    VoidCallback? onFavorite,
    VoidCallback? onRemove,
    bool isFavorite = false, // Add favorite status parameter
  }) {
    List<MusicContextAction> actions = [];

    switch (type) {
      case MusicType.song:
        if (onPlay != null) {
          actions.add(
            MusicContextAction(
              title: 'Play',
              icon: CupertinoIcons.play_arrow,
              onTap: onPlay,
              iconColor: appColors().primaryColorApp,
            ),
          );
        }
        if (onPlayNext != null) {
          actions.add(
            MusicContextAction(
              title: 'Play Next',
              icon: CupertinoIcons.list_bullet_below_rectangle,
              onTap: onPlayNext,
              iconColor: appColors().primaryColorApp,
            ),
          );
        }
        if (onAddToQueue != null) {
          actions.add(
            MusicContextAction(
              title: 'Add to Queue',
              icon: CupertinoIcons.list_bullet_indent,
              onTap: onAddToQueue,
            ),
          );
        }
        if (onFavorite != null) {
          // Use a ValueNotifier to allow the menu UI to update live when the
          // favorite state toggles without closing the menu. We wrap the
          // original onFavorite callback so callers still receive the event.
          final favNotifier = ValueNotifier<bool>(isFavorite);

          actions.add(
            MusicContextAction(
              title: isFavorite ? 'Undo Favorite' : 'Add to Favorites',
              icon:
                  isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              onTap: () {
                // Toggle the notifier first so UI updates immediately.
                favNotifier.value = !favNotifier.value;
                try {
                  onFavorite();
                } catch (_) {
                  // swallow errors from callback
                }
              },
              iconColor: Colors.red,
              favoriteNotifier: favNotifier,
              closeOnTap: false, // keep the menu open for live toggle
            ),
          );
        }
        if (onDownload != null) {
          actions.add(
            MusicContextAction(
              title: 'Download',
              icon: CupertinoIcons.cloud_download,
              onTap: onDownload,
            ),
          );
        }
        if (onAddToPlaylist != null) {
          actions.add(
            MusicContextAction(
              title: 'Add to Playlist',
              icon: CupertinoIcons.add_circled,
              onTap: onAddToPlaylist,
            ),
          );
        }
        if (onShare != null) {
          actions.add(
            MusicContextAction(
              title: 'Share',
              icon: CupertinoIcons.share,
              onTap: onShare,
            ),
          );
        }
        if (onRemove != null) {
          actions.add(
            MusicContextAction(
              title: 'Remove',
              icon: CupertinoIcons.trash,
              onTap: onRemove,
              isDestructive: true,
            ),
          );
        }
        break;

      case MusicType.playlist:
        if (onShare != null) {
          actions.add(
            MusicContextAction(
              title: 'Share Playlist',
              icon: CupertinoIcons.share,
              onTap: onShare,
            ),
          );
        }
        break;

      case MusicType.album:
        if (onShare != null) {
          actions.add(
            MusicContextAction(
              title: 'Share Album',
              icon: CupertinoIcons.share,
              onTap: onShare,
            ),
          );
        }
        break;
    }

    // print('DEBUG: Created ${actions.length} actions for $type');
    // for (var action in actions) {
    //   print('DEBUG: - ${action.title}');
    // }

    return actions;
  }
}
