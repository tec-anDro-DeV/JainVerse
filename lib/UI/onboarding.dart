import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for SystemChrome
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/PhoneNumberInputScreen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  const OnboardingScreen({super.key, required this.onGetStarted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final random = Random();

  // Image set variables - to randomize which set is shown
  late int _selectedImageSet;
  late String _backgroundImage;

  // Animation controllers - initialize with default values
  AnimationController? _logoAnimationController;
  AnimationController? _textAnimationController;
  AnimationController? _buttonAnimationController;

  // Animations - initialize as nullable
  Animation<Offset>? _logoOffsetAnimation;
  Animation<double>? _textOpacityAnimation;
  Animation<double>? _buttonOpacityAnimation;

  @override
  void initState() {
    super.initState();

    // Set status bar icons to light for this screen
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Randomly select one of the four image sets
    _selectRandomImageSet();

    // Initialize animation controllers
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Define animations
    _logoOffsetAnimation =
        Tween<Offset>(begin: const Offset(0, -1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _logoAnimationController!,
            curve: Curves.easeOut,
          ),
        );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textAnimationController!, curve: Curves.easeIn),
    );

    _buttonOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonAnimationController!,
        curve: Curves.easeIn,
      ),
    );
    _startContentAnimations();
  }

  // New method to randomly select one of the three image sets
  void _selectRandomImageSet() {
    _selectedImageSet = random.nextInt(3) + 1; // Random number between 1-3
    _backgroundImage = 'assets/images/onboard_bg_$_selectedImageSet.png';
  }

  void _startContentAnimations() {
    // Start logo animation
    _logoAnimationController?.forward();

    // Start text animation with delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _textAnimationController?.forward();
      }
    });

    // Start button animation with longer delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _buttonAnimationController?.forward();
      }
    });
  }

  @override
  void dispose() {
    // Remove the status bar reset from dispose since we'll handle it in navigation
    // _timer?.cancel();
    _logoAnimationController?.dispose();
    _textAnimationController?.dispose();
    _buttonAnimationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Bottom layer: onboard_bg_X.png - Use errorBuilder to handle load failures
          Positioned.fill(
            child: Image.asset(
              _backgroundImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print("Error rendering background image: $error");
                return Container(color: const Color(0xFFF5C6B8));
              },
            ),
          ),

          // Content Column with animations
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingL,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top Spacing
                            SizedBox(height: screenHeight * 0.49),

                            // Logo with slide-down animation
                            SlideTransition(
                              position: _logoOffsetAnimation!,
                              child: FadeTransition(
                                opacity: _logoAnimationController!,
                                child: Image.asset(
                                  'assets/images/logo-transparent.png',
                                  width:
                                      MediaQuery.of(context).size.width *
                                      0.3, // Use width-based sizing
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),

                            // Flexible spacer
                            SizedBox(height: 12.w),

                            // Text with fade-in animation
                            FadeTransition(
                              opacity: _textOpacityAnimation!,
                              child: Column(
                                children: [
                                  // Welcome Text
                                  Text(
                                    'Welcome to',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: AppSizes.fontH1 + 6.sp,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Nunito-Regular',
                                      height: 1.2,
                                    ),
                                  ),

                                  // App Name Text
                                  Text(
                                    'JainVerse',
                                    style: TextStyle(
                                      color: appColors()
                                          .primaryColorApp, // Keeping the punchy orange
                                      fontSize: AppSizes.fontH1 + 10.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                      height: 1.2,
                                    ),
                                  ),

                                  // Spacing
                                  SizedBox(height: AppSizes.paddingM),

                                  // Description Text
                                  Text(
                                    'A divine space of stavan and bhakti, guiding your soul towards peace.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: AppSizes.fontSmall + 2.sp,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Spacing
                            SizedBox(height: screenHeight * 0.02),

                            // Get Started Button with fade-in animation
                            FadeTransition(
                              opacity: _buttonOpacityAnimation!,
                              child: SizedBox(
                                width: double.infinity,
                                height: AppSizes.inputHeight,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Reset to dark status bar icons before navigating
                                    SystemChrome.setSystemUIOverlayStyle(
                                      SystemUiOverlayStyle.light.copyWith(
                                        statusBarColor: const Color.fromARGB(
                                          255,
                                          255,
                                          255,
                                          255,
                                        ),
                                        statusBarIconBrightness:
                                            Brightness.dark,
                                      ),
                                    );
                                    // Direct navigation to Phone Number Input screen - Use pushReplacement to prevent back navigation
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PhoneNumberInputScreen(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        appColors().primaryColorApp,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.borderRadius,
                                      ),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontSize: AppSizes.fontLarge,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Bottom spacing
                            SizedBox(height: screenHeight * 0.06),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
