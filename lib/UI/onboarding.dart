import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for SystemChrome
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/Login.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  const OnboardingScreen({super.key, required this.onGetStarted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // List<MusicNote> musicNotes = [];
  final random = Random();
  // Timer? _timer;
  // bool _notesStarted = false;

  // Image set variables - to randomize which set is shown
  late int _selectedImageSet;
  late String _backgroundImage;
  // late String _foregroundImage;

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
    _logoOffsetAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _logoAnimationController!, curve: Curves.easeOut),
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

    // Start animations immediately since images are already preloaded
    // _initNotes();
    _startContentAnimations();

    // Start the timer for notes animation
    // _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
    //   if (mounted && _notesStarted) {
    //     setState(() {
    //       for (var note in musicNotes) {
    //         note.move();
    //       }
    //     });
    //   }
    // });
  }

  // New method to randomly select one of the five image sets
  void _selectRandomImageSet() {
    _selectedImageSet = random.nextInt(5) + 1; // Random number between 1-5
    _backgroundImage = 'assets/images/onboard_bg_$_selectedImageSet.png';
    // _foregroundImage = 'assets/images/onboard_$_selectedImageSet.png';

    print('Selected image set $_selectedImageSet: $_backgroundImage');
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

  // void _initNotes() {
  //   try {
  //     musicNotes.clear();
  //     for (int i = 0; i < 60; i++) {
  //       musicNotes.add(
  //         MusicNote(
  //           x: random.nextDouble() * 400,
  //           y: random.nextDouble() * 800,
  //           size: (random.nextDouble() * 14 + 10) * 2, // 20 to 48
  //           angle: random.nextDouble() * pi * 2,
  //           speed: (random.nextDouble() * 1 + 0.5) * 3, // 1.5 to 4.5
  //         ),
  //       );
  //     }
  //     setState(() {
  //       _notesStarted = true;
  //     });
  //   } catch (e) {
  //     print("Error initializing notes: $e");
  //     // If there's an error, still mark as started to avoid crashes
  //     setState(() {
  //       _notesStarted = true;
  //     });
  //   }
  // }

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

          // Middle layer: Animated music notes
          // if (_notesStarted)
          //   ...musicNotes.map(
          //     (note) => Positioned(
          //       left: note.x,
          //       top: note.y,
          //       child: Transform.rotate(
          //         angle: note.angle,
          //         child: Icon(
          //           Icons.music_note,
          //           color: const Color.fromARGB(111, 255, 255, 255),
          //           size: note.size,
          //         ),
          //       ),
          //     ),
          //   ),

          // Top layer: onboard_X.png - Use errorBuilder to handle load failures
          // Positioned.fill(
          //   child: Image.asset(
          //     _foregroundImage,
          //     fit: BoxFit.cover,
          //     errorBuilder: (context, error, stackTrace) {
          //       print("Error rendering front background image: $error");
          //       return const SizedBox.shrink();
          //     },
          //   ),
          // ),

          // Transparent black overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha((0.3 * 255).toInt()),
            ),
          ),
          // Content Column with animations
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              child: Column(
                children: [
                  // Top Spacing
                  SizedBox(height: screenHeight * 0.05),

                  // Logo with slide-down animation
                  SlideTransition(
                    position: _logoOffsetAnimation!,
                    child: FadeTransition(
                      opacity: _logoAnimationController!,
                      child: Image.asset(
                        'assets/images/logo-transparent.png',
                        // width:
                        //     MediaQuery.of(context).size.width *
                        //     0.7, // Use width-based sizing
                        // fit: BoxFit.fill,
                      ),
                    ),
                  ),

                  // Flexible spacer
                  const Spacer(),

                  // Text with fade-in animation
                  FadeTransition(
                    opacity: _textOpacityAnimation!,
                    child: Column(
                      children: [
                        // Welcome Text
                        Text(
                          'Welcome to',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppSizes.fontH1 + 10.sp,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Nunito-Regular',
                            height: 1.2,
                          ),
                        ),

                        // App Name Text
                        Text(
                          'JainVerse',
                          style: TextStyle(
                            color:
                                appColors()
                                    .primaryColorApp, // Keeping the punchy orange
                            fontSize: AppSizes.fontH1 + 10.sp,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            height: 1.2,
                          ),
                        ),

                        // Spacing
                        SizedBox(height: AppSizes.paddingL),

                        // Description Text
                        Text(
                          'A divine space of stavan and bhakti, guiding your soul towards peace.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppSizes.fontSmall + 2.sp,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Spacing
                  SizedBox(height: screenHeight * 0.05),

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
                              statusBarIconBrightness: Brightness.dark,
                            ),
                          );
                          // Direct navigation to Login screen - Use pushReplacement to prevent back navigation
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Login(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appColors().primaryColorApp,
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
        ],
      ),
    );
  }
}

// MusicNote class
// class MusicNote {
//   double x;
//   double y;
//   double size;
//   double angle;
//   double speed;

//   MusicNote({
//     required this.x,
//     required this.y,
//     required this.size,
//     required this.angle,
//     required this.speed,
//   });

//   void move() {
//     x += cos(angle) * speed;
//     y += sin(angle) * speed;

//     if (x < -50) x = 450;
//     if (x > 450) x = -50;
//     if (y < -50) y = 850;
//     if (y > 850) y = -50;
//   }
// }
