import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/widgets/playlist/add_to_playlist_bottom_sheet.dart';

/// Enhanced responsive menu options widget that intelligently avoids UI conflicts
///
/// Key improvements made:
/// 1. More accurate calculation of bottom occupied space (mini player + navigation)
/// 2. Enhanced smart positioning that prefers overlay over bottom sheet
/// 3. Improved conflict detection with precise boundary calculations
/// 4. Better fallback positioning strategies when space is limited
/// 5. Tighter positioning with reduced margins for better screen utilization
/// 6. Enhanced overlay positioning with clamping to ensure visibility
/// 7. Dynamic maximum height constraints based on available screen space
/// 8. Improved shadow and visual presentation

/// A responsive menu options widget that adapts to screen space and UI elements
class MenuOption extends StatelessWidget {
  final String songId;
  final String title;
  final String artist;
  final String? songImage;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onDeleteFromLibrary;
  final VoidCallback? onRemoveFromRecent;
  final bool showDeleteFromLibrary;
  final bool showRemoveFromRecent;
  final bool allowDownload;
  final DataMusic? track;
  final List<MenuOptionItem>? customOptions;

  const MenuOption({
    super.key,
    required this.songId,
    required this.title,
    required this.artist,
    this.songImage,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onAddToPlaylist,
    this.onAddToQueue,
    this.onDownload,
    this.onShare,
    this.onDeleteFromLibrary,
    this.onRemoveFromRecent,
    this.showDeleteFromLibrary = false,
    this.showRemoveFromRecent = false,
    this.allowDownload = true,
    this.track,
    this.customOptions,
  });

  /// Smart positioning method that adapts based on screen space and UI elements
  static Future<void> show(
    BuildContext context, {
    required String songId,
    required String title,
    required String artist,
    String? songImage,
    bool isFavorite = false,
    VoidCallback? onFavoriteToggle,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onAddToQueue,
    VoidCallback? onDownload,
    VoidCallback? onShare,
    VoidCallback? onDeleteFromLibrary,
    VoidCallback? onRemoveFromRecent,
    bool showDeleteFromLibrary = false,
    bool showRemoveFromRecent = false,
    bool allowDownload = true,
    DataMusic? track,
    List<MenuOptionItem>? customOptions,
    // Optional positioning parameters
    Offset? preferredPosition,
    GlobalKey? anchorKey,
  }) async {
    final stateManager = MusicPlayerStateManager();
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    double estimatedMenuHeight = _calculateMenuHeight(
      showDeleteFromLibrary: showDeleteFromLibrary,
      showRemoveFromRecent: showRemoveFromRecent,
      allowDownload: allowDownload,
      hasCustomOptions: customOptions?.isNotEmpty ?? false,
      customOptionsCount: customOptions?.length ?? 0,
    );

    // More accurate calculation of bottom occupied space with enhanced buffering
    double bottomOccupiedSpace = 0;
    double miniPlayerSpace = 0;
    double navigationSpace = 0;

    if (!stateManager.shouldHideMiniPlayer) {
      // Mini player: height + margin + generous buffer to ensure no overlap
      miniPlayerSpace =
          90.w + 18.w + 25.w; // Increased buffer from 10.w to 25.w
      bottomOccupiedSpace += miniPlayerSpace;
    }

    if (!stateManager.shouldHideNavigation) {
      // Navigation: height + margins + safe area + generous buffer
      navigationSpace =
          75.w +
          25.w +
          bottomSafeArea +
          25.w; // Increased buffer from 10.w to 25.w
      bottomOccupiedSpace += navigationSpace;
    }

    // Add extra safety margin when both are present
    if (!stateManager.shouldHideMiniPlayer &&
        !stateManager.shouldHideNavigation) {
      bottomOccupiedSpace +=
          15.w; // Additional buffer when both UI elements are present
    }

    // Calculate available spaces with more precision and generous buffers
    double availableBottomSpace =
        screenSize.height - bottomOccupiedSpace - 80.w; // Increased from 60.w
    double availableTopSpace =
        screenSize.height - statusBarHeight - 100.w; // Increased from 80.w

    bool useBottomSheet = false;
    bool preferTopPosition = false;

    if (preferredPosition == null && anchorKey == null) {
      // Strongly prefer overlay positioning for better control and to avoid UI conflicts
      if (estimatedMenuHeight <= availableTopSpace * 0.8) {
        // Use only 80% of available space for safety
        preferTopPosition = true;
      } else if (estimatedMenuHeight <= availableBottomSpace * 0.7) {
        // Use only 70% of available space for safety
        // Still prefer overlay over bottom sheet for better positioning control
        preferTopPosition =
            false; // Will position in center, avoiding conflicts
      } else {
        // Only use bottom sheet as absolute last resort when space is extremely limited
        useBottomSheet =
            estimatedMenuHeight >
            screenSize.height * 0.6; // Only if menu is very large
      }
    }

    if (useBottomSheet && anchorKey == null) {
      return _showAsBottomSheet(
        context,
        songId: songId,
        title: title,
        artist: artist,
        songImage: songImage,
        isFavorite: isFavorite,
        onFavoriteToggle: onFavoriteToggle,
        onAddToPlaylist: onAddToPlaylist,
        onAddToQueue: onAddToQueue,
        onDownload: onDownload,
        onShare: onShare,
        onDeleteFromLibrary: onDeleteFromLibrary,
        onRemoveFromRecent: onRemoveFromRecent,
        showDeleteFromLibrary: showDeleteFromLibrary,
        showRemoveFromRecent: showRemoveFromRecent,
        allowDownload: allowDownload,
        track: track,
        customOptions: customOptions,
      );
    }

    Offset position;
    if (preferredPosition != null) {
      position = preferredPosition;
    } else if (anchorKey != null) {
      position = _calculateSmartMenuPosition(
        context,
        widgetKey: anchorKey,
        menuHeight: estimatedMenuHeight,
        menuWidth: 250.w,
        bottomOccupiedSpace: bottomOccupiedSpace,
        statusBarHeight: statusBarHeight,
        miniPlayerSpace: miniPlayerSpace,
        navigationSpace: navigationSpace,
      );
    } else if (preferTopPosition) {
      // Position at top center with adequate spacing
      position = Offset((screenSize.width - 250.w) / 2, statusBarHeight + 60.w);
    } else {
      // Position strategically to avoid UI conflicts, preferring upper screen areas
      double centerY = (screenSize.height - estimatedMenuHeight) / 2;
      double minY = statusBarHeight + 80.w; // Increased from 60.w
      double maxY =
          screenSize.height -
          estimatedMenuHeight -
          bottomOccupiedSpace -
          40.w; // Increased from 30.w

      // Bias towards upper positioning to avoid UI conflicts more effectively
      double biasedCenterY =
          minY +
          ((maxY - minY) * 0.3); // Position in upper 30% of available space

      // Use biased position if it fits, otherwise fallback to calculated center
      if (biasedCenterY + estimatedMenuHeight <= maxY) {
        centerY = biasedCenterY;
      }

      // Ensure the position doesn't conflict with UI elements
      if (centerY < minY) {
        centerY = minY;
      } else if (centerY > maxY) {
        centerY = maxY;
      }

      // Final safety check for UI conflicts
      if (centerY + estimatedMenuHeight >
          screenSize.height - bottomOccupiedSpace - 20.w) {
        centerY =
            screenSize.height -
            bottomOccupiedSpace -
            estimatedMenuHeight -
            35.w;
        if (centerY < minY) {
          centerY = minY;
        }
      }

      position = Offset((screenSize.width - 250.w) / 2, centerY);
    }

    position = _getScreenSafePosition(
      context,
      desiredPosition: position,
      menuSize: Size(250.w, estimatedMenuHeight),
      padding: EdgeInsets.all(8.w), // Reduced padding for tighter positioning
      bottomOccupiedSpace: bottomOccupiedSpace,
      statusBarHeight: statusBarHeight,
    );

    final overlayEntry = _showAsOverlay(
      context,
      songId: songId,
      title: title,
      artist: artist,
      songImage: songImage,
      isFavorite: isFavorite,
      onFavoriteToggle: onFavoriteToggle,
      onAddToPlaylist: onAddToPlaylist,
      onAddToQueue: onAddToQueue,
      onDownload: onDownload,
      onShare: onShare,
      onDeleteFromLibrary: onDeleteFromLibrary,
      onRemoveFromRecent: onRemoveFromRecent,
      showDeleteFromLibrary: showDeleteFromLibrary,
      showRemoveFromRecent: showRemoveFromRecent,
      allowDownload: allowDownload,
      track: track,
      position: position,
      width: 250.w,
      maxHeight: estimatedMenuHeight,
      customOptions: customOptions,
    );

    Future.delayed(const Duration(seconds: 10), () {
      try {
        overlayEntry?.remove();
      } catch (e) {
        // Overlay might already be removed
      }
    });
  }

  /// Public method for direct overlay positioning (for backwards compatibility)
  static OverlayEntry? showAsOverlay(
    BuildContext context, {
    required String songId,
    required String title,
    required String artist,
    String? songImage,
    bool isFavorite = false,
    VoidCallback? onFavoriteToggle,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onAddToQueue,
    VoidCallback? onDownload,
    VoidCallback? onShare,
    VoidCallback? onDeleteFromLibrary,
    VoidCallback? onRemoveFromRecent,
    bool showDeleteFromLibrary = false,
    bool showRemoveFromRecent = false,
    bool allowDownload = true,
    DataMusic? track,
    required Offset position,
    required double width,
    required double maxHeight,
    List<MenuOptionItem>? customOptions,
  }) {
    return _showAsOverlay(
      context,
      songId: songId,
      title: title,
      artist: artist,
      songImage: songImage,
      isFavorite: isFavorite,
      onFavoriteToggle: onFavoriteToggle,
      onAddToPlaylist: onAddToPlaylist,
      onAddToQueue: onAddToQueue,
      onDownload: onDownload,
      onShare: onShare,
      onDeleteFromLibrary: onDeleteFromLibrary,
      onRemoveFromRecent: onRemoveFromRecent,
      showDeleteFromLibrary: showDeleteFromLibrary,
      showRemoveFromRecent: showRemoveFromRecent,
      allowDownload: allowDownload,
      track: track,
      position: position,
      width: width,
      maxHeight: maxHeight,
      customOptions: customOptions,
    );
  }

  /// Show as traditional bottom sheet
  /// Uses root navigator to ensure it appears above navigation bars and mini player
  static Future<void> _showAsBottomSheet(
    BuildContext context, {
    required String songId,
    required String title,
    required String artist,
    String? songImage,
    bool isFavorite = false,
    VoidCallback? onFavoriteToggle,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onAddToQueue,
    VoidCallback? onDownload,
    VoidCallback? onShare,
    VoidCallback? onDeleteFromLibrary,
    VoidCallback? onRemoveFromRecent,
    bool showDeleteFromLibrary = false,
    bool showRemoveFromRecent = false,
    bool allowDownload = true,
    DataMusic? track,
    List<MenuOptionItem>? customOptions,
  }) {
    // Use the root navigator context to ensure the bottom sheet appears above all navigation elements
    final NavigatorState rootNavigator = Navigator.of(
      context,
      rootNavigator: true,
    );
    final BuildContext rootContext = rootNavigator.context ?? context;

    return showModalBottomSheet(
      context: rootContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Container(
              margin: EdgeInsets.all(16.w),
              child: MenuOption(
                songId: songId,
                title: title,
                artist: artist,
                songImage: songImage,
                isFavorite: isFavorite,
                onFavoriteToggle: () {
                  Navigator.pop(context);
                  onFavoriteToggle?.call();
                },
                onAddToPlaylist: () {
                  Navigator.pop(context);
                  onAddToPlaylist?.call();
                },
                onAddToQueue: () {
                  Navigator.pop(context);
                  onAddToQueue?.call();
                },
                onDownload: () {
                  Navigator.pop(context);
                  onDownload?.call();
                },
                onShare: () {
                  Navigator.pop(context);
                  onShare?.call();
                },
                onDeleteFromLibrary: () {
                  Navigator.pop(context);
                  onDeleteFromLibrary?.call();
                },
                onRemoveFromRecent: () {
                  Navigator.pop(context);
                  onRemoveFromRecent?.call();
                },
                showDeleteFromLibrary: showDeleteFromLibrary,
                showRemoveFromRecent: showRemoveFromRecent,
                allowDownload: allowDownload,
                track: track,
                customOptions: customOptions,
              ),
            ),
          ),
    );
  }

  /// Show as overlay with smart positioning
  static OverlayEntry? _showAsOverlay(
    BuildContext context, {
    required String songId,
    required String title,
    required String artist,
    String? songImage,
    bool isFavorite = false,
    VoidCallback? onFavoriteToggle,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onAddToQueue,
    VoidCallback? onDownload,
    VoidCallback? onShare,
    VoidCallback? onDeleteFromLibrary,
    VoidCallback? onRemoveFromRecent,
    bool showDeleteFromLibrary = false,
    bool showRemoveFromRecent = false,
    bool allowDownload = true,
    DataMusic? track,
    required Offset position,
    required double width,
    required double maxHeight,
    List<MenuOptionItem>? customOptions,
  }) {
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => ResponsiveMenuOverlay(
            onDismiss: () => overlayEntry.remove(),
            position: position,
            child: MenuOption(
              songId: songId,
              title: title,
              artist: artist,
              songImage: songImage,
              isFavorite: isFavorite,
              onFavoriteToggle: () {
                overlayEntry.remove();
                onFavoriteToggle?.call();
              },
              onAddToPlaylist: () {
                overlayEntry.remove();
                onAddToPlaylist?.call();
              },
              onAddToQueue: () {
                overlayEntry.remove();
                onAddToQueue?.call();
              },
              onDownload: () {
                overlayEntry.remove();
                onDownload?.call();
              },
              onShare: () {
                overlayEntry.remove();
                onShare?.call();
              },
              onDeleteFromLibrary: () {
                overlayEntry.remove();
                onDeleteFromLibrary?.call();
              },
              onRemoveFromRecent: () {
                overlayEntry.remove();
                onRemoveFromRecent?.call();
              },
              showDeleteFromLibrary: showDeleteFromLibrary,
              showRemoveFromRecent: showRemoveFromRecent,
              allowDownload: allowDownload,
              track: track,
              customOptions: customOptions,
            ),
          ),
    );

    Overlay.of(context).insert(overlayEntry);
    return overlayEntry;
  }

  /// Calculate estimated menu height based on visible options
  static double _calculateMenuHeight({
    required bool showDeleteFromLibrary,
    required bool showRemoveFromRecent,
    required bool allowDownload,
    required bool hasCustomOptions,
    required int customOptionsCount,
  }) {
    double height = 16.w; // Base padding

    // Base options (always shown)
    int baseOptionsCount = 3; // Add to Playlist, Share, Favorite

    // Optional options
    if (allowDownload) baseOptionsCount++;
    if (showDeleteFromLibrary) baseOptionsCount++;
    if (showRemoveFromRecent) baseOptionsCount++;
    if (hasCustomOptions) baseOptionsCount += customOptionsCount;

    // Each option height (including divider)
    double optionHeight =
        44.w; // 12.w padding top + 12.w padding bottom + ~20.w content

    // Calculate total height
    height += (baseOptionsCount * optionHeight);
    height += ((baseOptionsCount - 1) * 1.5.w); // Dividers

    return height;
  }

  /// Smart menu positioning that adapts to available space and avoids UI elements
  static Offset _calculateSmartMenuPosition(
    BuildContext context, {
    required GlobalKey widgetKey,
    required double menuHeight,
    required double menuWidth,
    required double bottomOccupiedSpace,
    required double statusBarHeight,
    required double miniPlayerSpace,
    required double navigationSpace,
  }) {
    final RenderBox? renderBox =
        widgetKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) return Offset.zero;

    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    double x, y;

    // Position horizontally - prefer left side of button first, then right side
    x = buttonPosition.dx - menuWidth - 8.w; // Increased gap for better spacing
    if (x < 12.w) {
      // If menu would go off left edge, position to the right of button
      x = buttonPosition.dx + buttonSize.width + 8.w; // Increased gap
      if (x + menuWidth > screenSize.width - 12.w) {
        // If it still doesn't fit on right, position it with edge margin
        x = screenSize.width - menuWidth - 12.w;

        // If button is too close to the right edge, center the menu horizontally
        if (buttonPosition.dx > screenSize.width - 120.w) {
          x = (screenSize.width - menuWidth) / 2;
        }
      }
    }

    // Enhanced vertical positioning logic with aggressive conflict avoidance
    // Try to align menu center with button center first
    y = buttonPosition.dy + (buttonSize.height / 2) - (menuHeight / 2);

    // Calculate safe boundaries more precisely with generous buffers
    double topSafeZone =
        statusBarHeight + 20.w; // Status bar + increased buffer
    double bottomSafeZone =
        screenSize.height -
        bottomOccupiedSpace -
        20.w; // UI elements + increased buffer

    // Check if the menu would conflict with bottom UI elements with more aggressive detection
    double menuBottom = y + menuHeight;
    double conflictZoneStart =
        screenSize.height -
        bottomOccupiedSpace +
        15.w; // Start checking earlier

    // Primary conflict detection - if any part of menu would be in the occupied zone
    if (menuBottom > conflictZoneStart) {
      // Menu would overlap with mini player or navigation
      // Position it well above the conflict zone with generous spacing
      y = conflictZoneStart - menuHeight - 35.w; // Increased from 30.w to 35.w

      // If positioning above conflict zone makes it too high, try above the button
      if (y < topSafeZone) {
        double aboveButtonY = buttonPosition.dy - menuHeight - 16.w;
        if (aboveButtonY >= topSafeZone) {
          y = aboveButtonY;
        } else {
          // Position in upper safe area with maximum available space
          y = topSafeZone;
        }
      }
    }

    // Secondary check: ensure menu doesn't go above the safe area
    if (y < topSafeZone) {
      y = topSafeZone;
    }

    // Final comprehensive check: if the menu still might overlap, force it higher
    if (y + menuHeight > bottomSafeZone) {
      // Try positioning above the button with more spacing
      double aboveButtonY =
          buttonPosition.dy - menuHeight - 20.w; // Increased spacing
      if (aboveButtonY >= topSafeZone) {
        y = aboveButtonY;
      } else {
        // As absolute last resort, position in the safest available space
        double availableHeight = bottomSafeZone - topSafeZone;
        if (menuHeight <= availableHeight) {
          // Center in available space, but prefer upper positioning
          y =
              topSafeZone +
              min(
                20.w,
                (availableHeight - menuHeight) * 0.3,
              ); // Prefer upper third
        } else {
          // Menu is too tall, position at top and constrain height
          y = topSafeZone;
        }
      }
    }

    return Offset(x, y);
  }

  /// Get screen-safe position ensuring menu stays within bounds
  static Offset _getScreenSafePosition(
    BuildContext context, {
    required Offset desiredPosition,
    required Size menuSize,
    EdgeInsets padding = const EdgeInsets.all(8), // Reduced from 16
    double bottomOccupiedSpace = 0,
    double statusBarHeight = 0,
  }) {
    final screenSize = MediaQuery.of(context).size;

    double x = desiredPosition.dx;
    double y = desiredPosition.dy;

    // Ensure horizontal bounds with tighter margins
    if (x < padding.left) {
      x = padding.left;
    } else if (x + menuSize.width > screenSize.width - padding.right) {
      x = screenSize.width - menuSize.width - padding.right;
    }

    // Ensure vertical bounds with precise consideration for occupied spaces
    double minY = statusBarHeight + padding.top;
    double maxY =
        screenSize.height -
        menuSize.height -
        bottomOccupiedSpace -
        padding.bottom;

    // Enhanced conflict detection and avoidance with more aggressive buffering
    double conflictZoneStart = screenSize.height - bottomOccupiedSpace;
    double menuBottom = y + menuSize.height;

    if (menuBottom > conflictZoneStart - 25.w) {
      // Increased buffer from 20.w to 25.w
      // Reposition well above the conflict zone with generous spacing
      y =
          conflictZoneStart -
          menuSize.height -
          30.w; // Increased buffer from 25.w to 30.w
    }

    if (y < minY) {
      y = minY;
    } else if (y > maxY) {
      y = maxY;
      // If repositioning still doesn't work, ensure it's at least visible and not overlapping
      if (y < minY) {
        y = minY;
      }

      // Final check: if menu would still overlap UI elements, force it to top safe area
      if (y + menuSize.height > conflictZoneStart - 20.w) {
        // Increased buffer from 15.w to 20.w
        y = min(
          minY,
          conflictZoneStart - menuSize.height - 35.w,
        ); // Increased from 30.w to 35.w
      }
    }

    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final stateManager = MusicPlayerStateManager();
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Calculate maximum height based on available space
    double bottomOccupiedSpace = 0;
    if (!stateManager.shouldHideMiniPlayer) {
      bottomOccupiedSpace += 90.w + 18.w + 10.w;
    }
    if (!stateManager.shouldHideNavigation) {
      bottomOccupiedSpace += 75.w + 25.w + bottomSafeArea + 10.w;
    }

    double maxAllowedHeight =
        screenSize.height - statusBarHeight - bottomOccupiedSpace - 80.w;

    return Container(
      width: 250.w,
      constraints: BoxConstraints(
        maxHeight: maxAllowedHeight,
        minHeight: 100.w, // Minimum height for usability
      ),
      decoration: BoxDecoration(
        color: appColors().gray[600],
        borderRadius: BorderRadius.circular(16.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4), // Slightly stronger shadow
            blurRadius: 12.w, // Increased blur radius
            spreadRadius: 2.w, // Added spread radius
            offset: Offset(0, 6.w), // Increased offset
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildMenuOptions(context)],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOptions(BuildContext context) {
    final options = <Widget>[];

    // Add custom options first if provided
    if (customOptions != null && customOptions!.isNotEmpty) {
      for (final customOption in customOptions!) {
        options.add(_buildMenuOptionFromItem(customOption));
        if (customOption != customOptions!.last) {
          options.add(_buildDivider());
        }
      }
      if (options.isNotEmpty) options.add(_buildDivider());
    }

    // Enhanced Download/Remove Download
    if (allowDownload) {
      if (options.isNotEmpty) options.add(_buildDivider());
      options.add(_buildDownloadOption());
    }

    // Add to Playlist
    if (options.isNotEmpty) options.add(_buildDivider());
    options.add(
      _buildMenuOption(
        icon: Icons.playlist_add_outlined,
        title: 'Add to Playlist',
        onTap: () {
          HapticFeedback.lightImpact();
          if (onAddToPlaylist != null) {
            onAddToPlaylist?.call();
          } else {
            // Default add to playlist behavior - use the static show method
            // which handles root navigator context properly
            final rootContext =
                Navigator.of(context, rootNavigator: true).context;
            AddToPlaylistBottomSheet.show(
              rootContext,
              songId: songId,
              songTitle: title,
              artistName: artist,
              songImage: songImage,
            );
          }
        },
      ),
    );

    // Share
    if (onShare != null) {
      options.add(_buildDivider());
      options.add(
        _buildMenuOption(
          icon: Icons.share_outlined,
          title: 'Share Song',
          onTap: () {
            HapticFeedback.lightImpact();
            onShare?.call();
          },
        ),
      );
    }

    // Favorite option
    options.add(_buildDivider());
    options.add(_buildFavoriteMenuOption());

    // Delete from Library
    if (showDeleteFromLibrary && onDeleteFromLibrary != null) {
      options.add(_buildDivider());
      options.add(
        _buildMenuOption(
          icon: Icons.delete_outline,
          title: 'Delete from Library',
          onTap: () {
            HapticFeedback.lightImpact();
            onDeleteFromLibrary?.call();
          },
          iconColor: appColors().primaryColorApp.withOpacity(0.8),
        ),
      );
    }

    // Remove from Recent
    if (showRemoveFromRecent && onRemoveFromRecent != null) {
      options.add(_buildDivider());
      options.add(
        _buildMenuOption(
          icon: Icons.history,
          title: 'Remove from Recent',
          onTap: () {
            HapticFeedback.lightImpact();
            onRemoveFromRecent?.call();
          },
          iconColor: Colors.orange.withOpacity(0.8),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: options);
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
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? Colors.white.withOpacity(0.8),
                size: 20.w,
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOptionFromItem(MenuOptionItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          item.onTap?.call();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: item.iconColor ?? Colors.white.withOpacity(0.8),
                size: 20.w,
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: item.textColor ?? Colors.white.withOpacity(0.9),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (item.trailing != null) ...[
                SizedBox(width: 8.w),
                item.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 1.5.w, color: Colors.white.withOpacity(0.1));
  }

  Widget _buildFavoriteMenuOption() {
    return _buildMenuOption(
      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
      title: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
      onTap: () {
        HapticFeedback.lightImpact();
        onFavoriteToggle?.call();
      },
      iconColor:
          isFavorite
              ? appColors().primaryColorApp.withOpacity(0.8)
              : Colors.white.withOpacity(0.8),
    );
  }

  Widget _buildDownloadOption() {
    return _buildMenuOption(
      icon: Icons.download_outlined,
      title: 'Download',
      onTap: () {
        HapticFeedback.lightImpact();
        onDownload?.call();
      },
      iconColor: Colors.white.withOpacity(0.8),
    );
  }
}

/// Responsive overlay widget that provides smart positioning and animations
class ResponsiveMenuOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final Offset? position;
  final Alignment alignment;

  const ResponsiveMenuOverlay({
    super.key,
    required this.child,
    required this.onDismiss,
    this.position,
    this.alignment = Alignment.center,
  });

  @override
  State<ResponsiveMenuOverlay> createState() => _ResponsiveMenuOverlayState();
}

class _ResponsiveMenuOverlayState extends State<ResponsiveMenuOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            color: Colors.black.withOpacity(0.0 * _fadeAnimation.value),
            child: Stack(
              children: [
                if (widget.position != null)
                  Positioned(
                    left: widget.position!.dx.clamp(
                      8.w,
                      MediaQuery.of(context).size.width - 258.w,
                    ), // 250.w + 8.w margin
                    top: widget.position!.dy.clamp(
                      MediaQuery.of(context).padding.top + 8.w,
                      MediaQuery.of(context).size.height -
                          200.w, // Minimum space for menu
                    ),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            margin:
                                EdgeInsets
                                    .zero, // Remove margin for tighter positioning
                            child: GestureDetector(
                              onTap: () {}, // Prevent tap from propagating
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: widget.alignment,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            margin: EdgeInsets.all(
                              8.w,
                            ), // Keep this one as is for center alignment
                            child: GestureDetector(
                              onTap: () {}, // Prevent tap from propagating
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Data class for custom menu option items
class MenuOptionItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;

  const MenuOptionItem({
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.textColor,
    this.trailing,
  });
}
