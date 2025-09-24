import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/ThemeMain/sizes.dart';

/// An integrated lyrics overlay that animates from the bottom
/// and maintains the control panel's position
class IntegratedLyricsOverlay extends StatefulWidget {
  final MediaItem? mediaItem;
  final VoidCallback? onClose;
  final bool isVisible;
  final ColorScheme? colorScheme;

  const IntegratedLyricsOverlay({
    super.key,
    this.mediaItem,
    this.onClose,
    this.isVisible = false,
    this.colorScheme,
  });

  @override
  State<IntegratedLyricsOverlay> createState() =>
      _IntegratedLyricsOverlayState();
}

class _IntegratedLyricsOverlayState extends State<IntegratedLyricsOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _heightAnimation;
  late ScrollController _scrollController;

  // The maximum height the lyrics can expand to (60% of screen height - matching queue)
  double _maxLyricsHeight = 0;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scrollController = ScrollController();

    if (widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize max height based on screen size (40% for a more compact overlay)
    _maxLyricsHeight = MediaQuery.of(context).size.height * 0.4;

    // Create the animation here after we have the screen dimensions
    _heightAnimation = Tween<double>(begin: 0.0, end: _maxLyricsHeight).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(IntegratedLyricsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _showOverlay();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    _slideController.forward();
    // Auto-scroll to top when lyrics opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _hideOverlay() {
    _slideController.reverse();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30.r),
            topRight: Radius.circular(30.r),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              height: _heightAnimation.value,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30.r),
                  topRight: Radius.circular(30.r),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      widget.colorScheme != null
                          ? [
                            widget.colorScheme!.surface.withOpacity(0),
                            widget.colorScheme!.surface.withOpacity(0),
                          ]
                          : [
                            Colors.grey.shade700.withOpacity(0),
                            Colors.grey.shade800.withOpacity(0),
                          ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLyricsHeader(),
                  Expanded(child: _buildLyricsContent()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyricsHeader() {
    final textColor = widget.colorScheme?.onSurface ?? Colors.white;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Lyrics',
            style: TextStyle(
              color: textColor,
              fontSize: AppSizes.fontH2,
              fontWeight: FontWeight.w600,
            ),
          ),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: textColor, size: 16.w),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsContent() {
    final textColor = widget.colorScheme?.onSurface ?? Colors.white;
    final secondaryTextColor =
        widget.colorScheme != null
            ? widget.colorScheme!.onSurface.withOpacity(0.7)
            : Colors.white.withOpacity(0.7);

    // Get lyrics from mediaItem extras
    String? lyrics = widget.mediaItem?.extras?['lyrics']?.toString();

    // If no lyrics in extras, check other possible sources
    if (lyrics == null || lyrics.isEmpty) {
      lyrics = widget.mediaItem?.extras?['description']?.toString();
    }

    // Check if lyrics are available
    if (lyrics == null || lyrics.isEmpty) {
      return Center(
        child: Text(
          'No lyrics available',
          style: TextStyle(color: secondaryTextColor, fontSize: 18.sp),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.w),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.w),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            lyrics,
            style: TextStyle(
              fontSize: AppSizes.fontMedium,
              height: 1.8,
              color: textColor,
              fontWeight: FontWeight.normal,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
