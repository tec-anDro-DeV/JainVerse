import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart'; // Import StringsLocalization directly
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/Login.dart'
    as login_page; // Import with prefix to avoid ambiguity
import 'package:jainverse/services/app_router_manager.dart';
import 'package:jainverse/services/offline_mode_service.dart';
import 'package:jainverse/utils/SharedPref.dart';

import 'onboarding.dart';
// Import with prefix to avoid ambiguity

// Define a local Resources class to handle string localization
class Resources {
  final BuildContext _context;

  Resources(this._context);

  StringsLocalization get strings {
    switch ('en') {
      case 'ar':
        return ArabicStrings();
      case 'fn':
        return FranchStrings();
      default:
        return EnglishStrings();
    }
  }

  static Resources of(BuildContext context) {
    return Resources(context);
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _circleOneAnimation;
  late Animation<double> _circleTwoAnimation;
  late Animation<double> _circleThreeAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _textOpacityAnimation;

  List<MusicNote> musicNotes = [];
  final random = Random();
  SharedPref sharePrefs = SharedPref();
  bool loginPresent = false;

  // Services for offline mode management
  final OfflineModeService _offlineModeService = OfflineModeService();
  final AppRouterManager _appRouterManager = AppRouterManager();

  // Updated variables to track all image sets
  final Map<String, bool> _imagesLoaded = {};
  bool _navigationInitiated = false;
  bool _preloadingStarted = false;
  bool _animationCompleted = false;

  // Reduce max wait time to ensure faster fallback
  final int _maxWaitTime =
      4; // Reduced from 7 to 4 seconds for faster navigation

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 20; i++) {
      musicNotes.add(
        MusicNote(
          x: random.nextDouble() * 400,
          y: random.nextDouble() * 800,
          size: random.nextDouble() * 25 + 10,
          angle: random.nextDouble() * pi * 2,
          speed: random.nextDouble() * 2 + 2,
        ),
      );
    }

    _controller = AnimationController(
      duration: const Duration(
        milliseconds: 3000,
      ), // Reduced from 4000 to 3000ms
      vsync: this,
    );

    _circleOneAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.12,
          curve: Curves.easeOut,
        ), // Adjusted interval
      ),
    );

    _circleTwoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.22, curve: Curves.easeOut),
      ),
    );

    _circleThreeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.32, curve: Curves.easeOut),
      ),
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.3,
          0.45,
          curve: Curves.easeOut,
        ), // Adjusted timing
      ),
    );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.6,
          0.7,
          curve: Curves.easeIn,
        ), // Shows text earlier
      ),
    );

    _controller.forward();

    // Add a listener to the animation controller to check navigation ONLY when animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animationCompleted = true;
        });
        print("Animation completed, checking for navigation");
        _checkAndNavigate();
      }
    });

    // Add a listener to allow early navigation when animation reaches 80%
    _controller.addListener(() {
      if (_controller.value >= 0.8 && !_navigationInitiated) {
        _checkAndNavigate();
      }
    });

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          for (var note in musicNotes) {
            note.move();
          }
        });
      }
    });

    // Add a fallback timer to ensure we don't get stuck in splash screen
    Timer(Duration(seconds: _maxWaitTime), () {
      if (!_navigationInitiated && mounted) {
        print("Fallback timer triggered: Forcing navigation");
        _forceNavigation();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start preloading onboarding images in didChangeDependencies
    if (!_preloadingStarted) {
      _preloadingStarted = true;
      _preloadOnboardingImages();
    }
  }

  void _preloadOnboardingImages() {
    print("Starting to preload all onboarding image sets");

    // List of all image paths to preload
    final List<String> imagePaths = [
      'assets/images/onboard_bg_1.png',
      // 'assets/images/onboard_1.png',
      'assets/images/onboard_bg_2.png',
      // 'assets/images/onboard_2.png',
      'assets/images/onboard_bg_3.png',
      // 'assets/images/onboard_3.png',
      'assets/images/onboard_bg_4.png',
      // 'assets/images/onboard_4.png',
      'assets/images/onboard_bg_5.png',
      // 'assets/images/onboard_5.png',
    ];

    // Initialize all images as not loaded
    for (String path in imagePaths) {
      _imagesLoaded[path] = false;
    }

    // Set timers for each image
    for (String path in imagePaths) {
      // Use a safety timer for each image in case the loading callback gets lost
      Timer(const Duration(seconds: 2), () {
        if (!_imagesLoaded[path]! && mounted) {
          print("Timer expired for $path - marking as loaded anyway");
          setState(() {
            _imagesLoaded[path] = true;
          });
          _checkAndNavigate();
        }
      });

      // Try to preload using multiple approaches
      try {
        // Method 1: Using precacheImage
        precacheImage(AssetImage(path), context)
            .then((_) {
              if (mounted) {
                setState(() {
                  _imagesLoaded[path] = true;
                  print("Image $path loaded successfully via precacheImage");
                });
                _checkAndNavigate();
              }
            })
            .catchError((error) {
              print("Error loading image $path: $error");
              // Try method 2 if method 1 fails
              _loadImageUsingImageProvider(path)
                  .then((_) {
                    if (mounted) {
                      setState(() {
                        _imagesLoaded[path] = true;
                        print("Image $path loaded via ImageProvider");
                      });
                      _checkAndNavigate();
                    }
                  })
                  .catchError((e) {
                    // Even if both methods fail, don't block navigation
                    if (mounted) {
                      setState(() {
                        _imagesLoaded[path] = true;
                        print("Marking $path as loaded despite errors");
                      });
                      _checkAndNavigate();
                    }
                  });
            });
      } catch (e) {
        print("Unexpected error in preloading $path: $e");
        // If there's any unexpected error, mark as loaded
        if (mounted) {
          setState(() {
            _imagesLoaded[path] = true;
          });
          _checkAndNavigate();
        }
      }
    }
  }

  // Alternative method to load image
  Future<void> _loadImageUsingImageProvider(String assetPath) {
    final completer = Completer<void>();
    final imageProvider = AssetImage(assetPath);
    final config = ImageConfiguration();

    final imageStream = imageProvider.resolve(config);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, syncCall) {
        if (!completer.isCompleted) {
          imageStream.removeListener(listener);
          completer.complete();
        }
      },
      onError: (exception, stackTrace) {
        if (!completer.isCompleted) {
          imageStream.removeListener(listener);
          completer.completeError(exception);
        }
      },
    );

    imageStream.addListener(listener);

    return completer.future
        .timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            if (!completer.isCompleted) {
              imageStream.removeListener(listener);
            }
            return;
          },
        )
        .whenComplete(() => imageStream.removeListener(listener));
  }

  Future<void> _checkAndNavigate() async {
    // Prioritize animation completion and allow navigation even if some images aren't loaded
    // Only navigate if:
    // 1. Animation has completed
    // 2. We haven't already navigated
    // 3. Component is still mounted
    // 4. Images are loaded OR sufficient time has passed

    bool allImagesLoaded = !_imagesLoaded.values.contains(false);
    bool sufficientTimeElapsed =
        _controller.value >=
        0.8; // Allow navigation when animation is 80% complete

    print(
      "Navigation check - Animation completed: $_animationCompleted, "
      "All images loaded: $allImagesLoaded, "
      "Sufficient time elapsed: $sufficientTimeElapsed, "
      "Not initiated: ${!_navigationInitiated}",
    );

    if (_animationCompleted &&
        (allImagesLoaded || sufficientTimeElapsed) &&
        !_navigationInitiated &&
        mounted) {
      print("Navigation triggered - Animation completed and conditions met");
      _navigateToNextScreen();
    }
  }

  // Force navigation regardless of loading state
  Future<void> _forceNavigation() async {
    if (!_navigationInitiated && mounted) {
      print("Force navigating to next screen");
      _navigateToNextScreen();
    }
  }

  // Extract navigation logic to a separate method
  Future<void> _navigateToNextScreen() async {
    _navigationInitiated = true;

    try {
      loginPresent = await sharePrefs.check();

      // Update user login status in offline mode service
      await _offlineModeService.setUserLoggedIn(loginPresent);

      // Use the app router manager for smart navigation
      _appRouterManager.navigateFromSplash();
    } catch (e) {
      print("Error during navigation: $e");
      // Fallback to onboarding if anything fails
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (BuildContext context) => OnboardingScreen(
                onGetStarted: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder:
                          (BuildContext context) => const login_page.Login(),
                    ),
                  );
                },
              ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5C6B8),
      body: SafeArea(
        // Apply SafeArea with maintainBottomViewPadding to avoid animation issues
        maintainBottomViewPadding: true,
        child: Stack(
          children: [
            ...musicNotes.map(
              (note) => Positioned(
                left: note.x,
                top: note.y,
                child: Transform.rotate(
                  angle: note.angle,
                  child: Icon(
                    Icons.music_note,
                    color: const Color.fromRGBO(232, 70, 37, 0.35),
                    size: note.size,
                  ),
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: AppSizes.splashOuterCircle,
                    height: AppSizes.splashOuterCircle,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _circleOneAnimation,
                          builder: (context, _) {
                            return Container(
                              width:
                                  AppSizes.splashOuterCircle *
                                  _circleOneAnimation.value,
                              height:
                                  AppSizes.splashOuterCircle *
                                  _circleOneAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color.fromRGBO(232, 70, 37, 0.30),
                              ),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: _circleTwoAnimation,
                          builder: (context, _) {
                            return Container(
                              width:
                                  AppSizes.splashMiddleCircle *
                                  _circleTwoAnimation.value,
                              height:
                                  AppSizes.splashMiddleCircle *
                                  _circleTwoAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color.fromRGBO(232, 70, 37, 0.45),
                              ),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: _circleThreeAnimation,
                          builder: (context, _) {
                            return Container(
                              width:
                                  AppSizes.splashInnerCircle *
                                  _circleThreeAnimation.value,
                              height:
                                  AppSizes.splashInnerCircle *
                                  _circleThreeAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color.fromRGBO(232, 70, 37, 0.65),
                              ),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: _logoAnimation,
                          builder: (context, _) {
                            return Transform.scale(
                              scale: _logoAnimation.value,
                              child: Container(
                                width: AppSizes.splashLogoContainer,
                                height: AppSizes.splashLogoContainer,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.splashLogoRadius,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    AppSizes.splashLogoPadding,
                                  ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MusicNote {
  double x;
  double y;
  double size;
  double angle;
  double speed;

  MusicNote({
    required this.x,
    required this.y,
    required this.size,
    required this.angle,
    required this.speed,
  });

  void move() {
    x += cos(angle) * speed;
    y += sin(angle) * speed;

    if (x < -50) x = 450;
    if (x > 450) x = -50;
    if (y < -50) y = 850;
    if (y > 850) y = -50;
  }
}
