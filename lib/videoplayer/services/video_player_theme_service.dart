import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Service for dynamically generating themes from video thumbnails
/// Similar to MusicPlayerThemeService but for video players
class VideoPlayerThemeService {
  static final VideoPlayerThemeService _instance =
      VideoPlayerThemeService._internal();
  factory VideoPlayerThemeService() => _instance;
  VideoPlayerThemeService._internal();

  // Cache for generated themes
  final Map<String, VideoPlayerTheme> _themeCache = {};

  /// Generate theme from video thumbnail
  Future<VideoPlayerTheme> generateThemeFromThumbnail({
    required String thumbnailUrl,
    required BuildContext context,
  }) async {
    // Check cache first
    if (_themeCache.containsKey(thumbnailUrl)) {
      return _themeCache[thumbnailUrl]!;
    }

    try {
      // Get image provider
      final imageProvider = NetworkImage(thumbnailUrl);

      // Generate color scheme using Flutter's built-in method (available in Flutter 3.9+)
      final ColorScheme colorScheme = await ColorScheme.fromImageProvider(
        provider: imageProvider,
        brightness: Brightness.dark,
      );

      // Extract colors from scheme
      final primaryColor = colorScheme.primary;
      final secondaryColor = colorScheme.secondary;
      final backgroundColor = colorScheme.surface;
      final textColor = colorScheme.onSurface;
      final accentColor = colorScheme.tertiary;

      // Create theme
      // Blend colors with black to produce a darker, less-saturated background
      final darkBackground =
          Color.lerp(backgroundColor, Colors.black, 0.45) ?? backgroundColor;
      final darkPrimary =
          Color.lerp(primaryColor, Colors.black, 0.35) ?? primaryColor;

      final theme = VideoPlayerTheme(
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        backgroundColor: darkBackground,
        textColor: textColor,
        accentColor: accentColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkBackground, darkPrimary.withOpacity(0.8)],
        ),
      );

      // Cache theme
      _themeCache[thumbnailUrl] = theme;

      return theme;
    } catch (e) {
      debugPrint('Error generating theme: $e');
      return VideoPlayerTheme.defaultTheme();
    }
  }

  /// Clear theme cache
  void clearCache() {
    _themeCache.clear();
  }

  /// Remove specific thumbnail from cache
  void removeCached(String thumbnailUrl) {
    _themeCache.remove(thumbnailUrl);
  }
}

/// Theme data for video player
class VideoPlayerTheme {
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color textColor;
  final Color accentColor;
  final Gradient gradient;

  const VideoPlayerTheme({
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.accentColor,
    required this.gradient,
  });

  /// Default theme (used when theme generation fails)
  factory VideoPlayerTheme.defaultTheme() {
    return VideoPlayerTheme(
      primaryColor: Colors.blue,
      secondaryColor: Colors.blueGrey,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      accentColor: Colors.blueAccent,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.black, Colors.blue.shade900.withOpacity(0.75)],
      ),
    );
  }

  /// Get contrasting text color for a background
  Color getContrastingTextColor() {
    final brightness = backgroundColor.computeLuminance();
    return brightness > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Get semi-transparent overlay color
  Color getOverlayColor({double opacity = 0.7}) {
    return backgroundColor.withOpacity(opacity);
  }

  VideoPlayerTheme copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? backgroundColor,
    Color? textColor,
    Color? accentColor,
    Gradient? gradient,
  }) {
    return VideoPlayerTheme(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      accentColor: accentColor ?? this.accentColor,
      gradient: gradient ?? this.gradient,
    );
  }
}
