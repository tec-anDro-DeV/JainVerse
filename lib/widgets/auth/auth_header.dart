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
    this.logoPath = 'assets/images/logo-transparent.png',
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
          // Logo with proper sizing — constrain height so it never exceeds the header
          // This prevents the logo from being cut off when the calculated width
          // would make the image taller than the available `height`.
          Builder(
            builder: (_) {
              // Reduce max height and nudge the logo upward so it won't sit
              // flush with the bottom of the header and appear clipped by the
              // content below (which often has rounded corners).
              final logoMaxHeight = height * 0.75; // stronger clamp
              final logoWidthPx = screenWidth * logoWidth;
              final logoBottomPadding = height * 0.06;

              final logoBox = SizedBox(
                height: logoMaxHeight,
                width: logoWidthPx,
                child: Image.asset(logoPath, fit: BoxFit.contain),
              );

              final positionedLogo = Align(
                alignment: const Alignment(0, -0.25),
                child: Padding(
                  padding: EdgeInsets.only(bottom: logoBottomPadding),
                  child: logoBox,
                ),
              );

              return heroTag != null
                  ? Hero(tag: heroTag!, child: positionedLogo)
                  : positionedLogo;
            },
          ),
        ],
      ),
    );
  }
}
