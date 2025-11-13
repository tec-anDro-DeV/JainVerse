import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../ThemeMain/appColors.dart';
import '../../ThemeMain/sizes.dart';

class CircleLoader extends StatefulWidget {
  final double size;
  final Color? backgroundColor;
  final bool showBackground;
  final bool showLogo;

  const CircleLoader({
    super.key,
    this.size = 200.0,
    this.backgroundColor,
    this.showBackground = false,
    this.showLogo = true,
  });

  @override
  State<CircleLoader> createState() => _CircleLoaderState();
}

class _CircleLoaderState extends State<CircleLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleOneAnimation;
  late Animation<double> _circleTwoAnimation;
  late Animation<double> _circleThreeAnimation;
  late Animation<double> _circleFourAnimation;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _circleOneAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _circleTwoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );

    _circleThreeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );

    _circleFourAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );

    _logoAnimation = Tween<double>(begin: 0.65, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outerCircleSize = widget.size.w;
    final secondCircleSize = (widget.size * 0.75).w;
    final thirdCircleSize = (widget.size * 0.5).w;
    final innerCircleSize = (widget.size * 0.35).w;
    final logoContainerSize = (widget.size * 0.4).w;

    return Container(
      width: widget.showBackground ? double.infinity : null,
      height: widget.showBackground ? double.infinity : null,
      color: widget.showBackground
          ? (widget.backgroundColor ?? Colors.white.withOpacity(0.8))
          : null,
      child: Center(
        child: SizedBox(
          width: outerCircleSize,
          height: outerCircleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outermost circle - Light grey
              AnimatedBuilder(
                animation: _circleOneAnimation,
                builder: (context, _) {
                  return Container(
                    width: outerCircleSize * _circleOneAnimation.value,
                    height: outerCircleSize * _circleOneAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appColors().primaryColorApp.withOpacity(0.2),
                    ),
                  );
                },
              ),
              // Second circle - Medium grey
              AnimatedBuilder(
                animation: _circleTwoAnimation,
                builder: (context, _) {
                  return Container(
                    width: secondCircleSize * _circleTwoAnimation.value,
                    height: secondCircleSize * _circleTwoAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appColors().primaryColorApp.withOpacity(0.4),
                    ),
                  );
                },
              ),
              // Third circle - Dark grey
              AnimatedBuilder(
                animation: _circleThreeAnimation,
                builder: (context, _) {
                  return Container(
                    width: thirdCircleSize * _circleThreeAnimation.value,
                    height: thirdCircleSize * _circleThreeAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appColors().primaryColorApp.withOpacity(0.6),
                    ),
                  );
                },
              ),
              // Fourth circle - Full white (contains logo)
              AnimatedBuilder(
                animation: _circleFourAnimation,
                builder: (context, _) {
                  return Container(
                    width: innerCircleSize * _circleFourAnimation.value,
                    height: innerCircleSize * _circleFourAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: AppSizes.loaderBlurRadius,
                          offset: Offset(0, AppSizes.loaderShadowOffset),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Logo in the center
              if (widget.showLogo)
                AnimatedBuilder(
                  animation: _logoAnimation,
                  builder: (context, _) {
                    return Transform.scale(
                      scale: _logoAnimation.value,
                      child: SizedBox(
                        width: logoContainerSize,
                        height: logoContainerSize,
                        child: Padding(
                          padding: EdgeInsets.all(logoContainerSize * 0.1),
                          child: Image.asset(
                            'assets/images/logo-transparent.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full screen loader overlay
class LoaderOverlay extends StatelessWidget {
  final String? message;
  final double loaderSize;

  const LoaderOverlay({super.key, this.message, this.loaderSize = 120.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleLoader(size: loaderSize),
            if (message != null) ...[
              SizedBox(height: AppSizes.paddingS),
              Text(
                message!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppSizes.fontNormal,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Helper method to show loader as dialog
class LoaderUtils {
  static void showLoader(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LoaderOverlay(message: message);
      },
    );
  }

  static void hideLoader(BuildContext context) {
    Navigator.of(context).pop();
  }
}
