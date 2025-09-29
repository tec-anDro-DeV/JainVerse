import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/services/color_extraction_service.dart';

/// Service to handle theme and color management for the music player
class MusicPlayerThemeService extends ChangeNotifier {
  // Animation controller for background
  AnimationController? _backgroundAnimationController;
  Animation<double>? _backgroundAnimation;

  // Color scheme state
  ColorScheme? _currentColorScheme;
  ColorScheme? _nextColorScheme;

  // Current media item
  MediaItem? _currentMediaItem;

  // Loading state
  bool _isLoadingColors = false;

  // Disposal state
  bool _isDisposed = false;

  // Getters
  ColorScheme? get currentColorScheme => _currentColorScheme;
  Animation<double>? get backgroundAnimation => _backgroundAnimation;
  bool get isLoadingColors => _isLoadingColors;
  MediaItem? get currentMediaItem => _currentMediaItem;
  bool get isDisposed => _isDisposed;

  /// Safe notifyListeners that checks disposal state
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Initialize the animation controller
  void initializeAnimations(TickerProvider vsync) {
    if (_isDisposed) return;

    // Dispose existing controller if any
    _backgroundAnimationController?.dispose();

    _backgroundAnimationController = AnimationController(
      duration: ColorExtractionService.animationDuration,
      vsync: vsync,
    );

    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backgroundAnimationController!,
        curve: Curves.easeInOut,
      ),
    );
  }

  /// Extract colors from album art and animate to new colors
  Future<void> extractColorsFromAlbumArt(MediaItem mediaItem) async {
    if (_isDisposed || _isLoadingColors || mediaItem.artUri == null) return;

    _isLoadingColors = true;
    _safeNotifyListeners();

    try {
      final newColorScheme =
          await ColorExtractionService.extractColorsFromAlbumArt(
            mediaItem.artUri.toString(),
          );

      if (!_isDisposed && newColorScheme != null) {
        _nextColorScheme = newColorScheme;
        _safeNotifyListeners();
        await _animateToNewColors();
      }
    } catch (e) {
      debugPrint('Error extracting colors: $e');
    } finally {
      if (!_isDisposed) {
        _isLoadingColors = false;
        _safeNotifyListeners();
      }
    }
  }

  /// Animate to new color scheme
  Future<void> _animateToNewColors() async {
    if (_isDisposed) return;

    _currentColorScheme = _nextColorScheme;
    _safeNotifyListeners();

    if (!_isDisposed) {
      _backgroundAnimationController?.reset();
      _backgroundAnimationController?.forward();
    }
  }

  /// Update current media item and extract colors if changed
  void updateMediaItem(MediaItem? mediaItem) {
    if (_isDisposed || mediaItem == null || mediaItem == _currentMediaItem) {
      return;
    }

    _currentMediaItem = mediaItem;
    extractColorsFromAlbumArt(mediaItem);
  }

  /// Build background decoration based on current color scheme
  BoxDecoration buildBackgroundDecoration() {
    // Return fallback decoration if disposed
    if (_isDisposed) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey, Colors.black],
        ),
      );
    }

    if (_currentColorScheme == null) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [appColors().primaryColorApp, Colors.black],
        ),
      );
    }

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(
            _currentColorScheme!.primary,
            _currentColorScheme!.primaryContainer,
            0.3,
          )!.withOpacity(0.8),
          Color.lerp(_currentColorScheme!.surface, appColors().black, 0.7)!,
        ],
      ),
    );
  }

  /// Dispose of resources
  @override
  void dispose() {
    _isDisposed = true;
    _backgroundAnimationController?.dispose();
    _backgroundAnimationController = null;
    _backgroundAnimation = null;
    super.dispose();
  }
}
