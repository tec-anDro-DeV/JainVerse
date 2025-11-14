import 'dart:io'; // For platform detection
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/sharing_utils.dart'; // Import sharing utility
// For haptic feedback
import 'package:jainverse/widgets/common/smart_image_widget.dart'; // Import smart image widget
import 'package:jainverse/widgets/musicplayer/album_art.dart';

/// Modern visual area widget containing background image and album art
///
/// This widget focuses purely on visual presentation. Gesture handling
/// is now managed by the parent MusicPlayerView to ensure the entire
/// screen (including control panel) moves together during slide gestures.
///
/// The album art positioning is adjusted based on platform to account for
/// differences in control panel height (Android shows volume slider, iOS doesn't).
class ModernVisualArea extends StatelessWidget {
  final MediaItem? mediaItem;
  final VoidCallback onBackPressed;
  final VoidCallback?
  onAnimatedBackPressed; // New callback for animated dismiss
  final AudioPlayerHandler? audioHandler;

  const ModernVisualArea({
    super.key,
    this.mediaItem,
    required this.onBackPressed,
    this.onAnimatedBackPressed, // Optional animated back press
    this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate platform-specific offset for album art positioning
    // Android: Control panel includes volume slider (~40.w), so less upward offset needed
    // iOS: Control panel is shorter without volume slider, so more upward offset needed
    // This ensures balanced visual spacing on both platforms
    final double albumArtOffset = Platform.isAndroid ? -245.w : -200.w;

    return Stack(
      children: [
        // Blurred background image or black placeholder
        if (mediaItem?.artUri != null)
          _buildBlurredBackground()
        else
          Positioned.fill(
            child: Container(
              color: Colors
                  .black, // Changed from orange or any other color to black
            ),
          ),

        // Main Content (album art and app bar)
        Column(
          children: [
            // Transparent app bar with back button
            _buildAppBar(context),

            // Album art (centered with platform-specific offset)
            Expanded(
              child: Transform.translate(
                offset: Offset(0, albumArtOffset),
                child: ModernAlbumArt(
                  mediaItem: mediaItem,
                  audioHandler: audioHandler,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlurredBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: getSmartImageProvider(mediaItem!.artUri.toString()),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    return Container(
      // Increase height to include status bar area so icons are not obscured
      height: 56.w + topPadding,
      padding: EdgeInsets.fromLTRB(16.w, topPadding, 16.w, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap:
                onAnimatedBackPressed ??
                onBackPressed, // Use animated dismiss if available
            child: SizedBox(
              width: 50.w,
              height: 50.w,
              // decoration: BoxDecoration(
              //   color: Colors.black.withOpacity(0.3),
              //   borderRadius: BorderRadius.circular(20.w),
              // ),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 36.w,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _onSharePressed(context),
            child: SizedBox(
              width: 40.w,
              height: 40.w,
              // decoration: BoxDecoration(
              //   color: Colors.black.withOpacity(0.3),
              //   borderRadius: BorderRadius.circular(20.w),
              // ),
              child: Icon(Icons.share, color: Colors.white, size: 24.w),
            ),
          ),
        ],
      ),
    );
  }

  void _onSharePressed(BuildContext context) {
    if (mediaItem != null) {
      SharingUtils.shareFromMediaItemSafe(mediaItem, context: context);
    }
  }
}
