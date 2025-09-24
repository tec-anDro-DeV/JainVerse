import 'package:flutter/material.dart';

class AuthHeader extends StatelessWidget {
  final double height;
  final String logoPath;
  final String backgroundImagePath;
  final String? heroTag;
  final double logoWidth;

  const AuthHeader({
    super.key,
    required this.height,
    this.logoPath = 'assets/images/Hear-God-Logo-Main.png',
    this.backgroundImagePath = 'assets/images/music-note-illustrator.png',
    this.heroTag,
    this.logoWidth = 0.7, // Default width is 70% of screen width
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: height,
      width: screenWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background image with proper sizing
          Positioned.fill(
            child: Image.asset(backgroundImagePath, fit: BoxFit.cover),
          ),
          // Logo with proper sizing
          heroTag != null
              ? Hero(
                tag: heroTag!,
                child: Image.asset(
                  logoPath,
                  width: screenWidth * logoWidth,
                  fit: BoxFit.contain,
                ),
              )
              : Image.asset(
                logoPath,
                width: screenWidth * logoWidth,
                fit: BoxFit.contain,
              ),
        ],
      ),
    );
  }
}
