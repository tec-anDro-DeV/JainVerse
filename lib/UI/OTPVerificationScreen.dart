import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/ProfileSetupScreen.dart';
import 'package:jainverse/UI/MainNavigation.dart';
import 'package:jainverse/services/phone_auth_service.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OTPVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  // Separate focus nodes used by the ancestor Focus widgets to listen for key events
  final List<FocusNode> _otpKeyNodes = List.generate(6, (_) => FocusNode());
  final PhoneAuthService _authService = PhoneAuthService();

  bool _isLoading = false;
  bool _canResend = false;
  int _resendCooldown = 30;
  Timer? _cooldownTimer;

  // Animation controllers
  late AnimationController _animationController;
  Animation<double> _fadeInAnimation = const AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);

  @override
  void initState() {
    super.initState();

    // Set status bar icons to dark
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          ),
        );

    // Start the animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });

    // Start resend cooldown
    _startResendCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _animationController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    for (var node in _otpKeyNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Return a masked phone display showing only the last 3 digits
  String _maskedLastThree(String phone) {
    try {
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length <= 3) return digits;
      final last3 = digits.substring(digits.length - 3);
      return '*******$last3';
    } catch (e) {
      return phone;
    }
  }

  /// Start the resend cooldown timer
  void _startResendCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 30;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  /// Get the complete OTP from all controllers
  String _getOTP() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  /// Handle OTP verification
  Future<void> _handleVerifyOTP() async {
    final otp = _getOTP();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter complete OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.verifyOTP(
        context,
        widget.phoneNumber,
        otp,
      );

      if (result['success'] == true && mounted) {
        final bool profileComplete = result['profileComplete'] ?? false;

        // Reset token expiration handler
        try {
          TokenExpirationHandler().reset();
        } catch (e) {
          print('Error resetting token handler: $e');
        }

        // Show mini player if needed
        try {
          MusicPlayerStateManager().showNavigationAndMiniPlayer();
        } catch (e) {
          print('Error showing mini player: $e');
        }

        if (profileComplete) {
          // Profile is complete, navigate to main app
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  const MainNavigationWrapper(initialIndex: 0),
            ),
            (Route<dynamic> route) => false,
          );
        } else {
          // Profile is incomplete, navigate to profile setup
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) =>
                  ProfileSetupScreen(phoneNumber: widget.phoneNumber),
            ),
            (Route<dynamic> route) => false,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handle resend OTP
  Future<void> _handleResendOTP() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.requestOTP(
        context,
        widget.phoneNumber,
      );

      if (success && mounted) {
        // Clear existing OTP
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();

        // Restart cooldown
        _startResendCooldown();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Build OTP input field
  Widget _buildOTPField(int index) {
    return SizedBox(
      width: 56.w,
      height: 68.w,
      child: Focus(
        focusNode: _otpKeyNodes[index],
        onKey: (node, event) {
          // Handle backspace key specifically to manage deleting previous box
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            final currentText = _otpControllers[index].text;
            if (currentText.isNotEmpty) {
              // If current box has value, just clear it and keep focus
              _otpControllers[index].clear();
              return KeyEventResult.handled;
            } else if (index > 0) {
              // If current is empty, move to previous, clear it and focus it
              _otpControllers[index - 1].clear();
              _otpFocusNodes[index - 1].requestFocus();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          maxLength: 1,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: appColors().primaryColorApp,
                width: 2,
              ),
            ),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            if (value.isNotEmpty) {
              // Move to next field
              if (index < 5) {
                FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
              } else {
                // Last field, dismiss keyboard
                FocusScope.of(context).unfocus();
                // Auto-verify if all fields are filled
                if (_getOTP().length == 6) {
                  _handleVerifyOTP();
                }
              }
            }
            // Do not handle empty->previous here; onKey handles backspace logic to avoid double-clearing
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final safeAreaHeight = screenHeight - padding.top - padding.bottom;

    return Scaffold(
      backgroundColor: appColors().backgroundLogin,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header with back button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 4.w,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          size: 24.w,
                          color: appColors().black,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      Text(
                        "Verify OTP",
                        style: TextStyle(
                          color: appColors().black,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(width: 48.w),
                    ],
                  ),
                ),

                // Logo
                AuthHeader(height: safeAreaHeight * 0.12, heroTag: 'app_logo'),

                // Main content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32.r),
                              topRight: Radius.circular(32.r),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 0,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: 32.w,
                                left: 24.w,
                                right: 24.w,
                                bottom:
                                    24.w +
                                    MediaQuery.of(context).viewInsets.bottom *
                                        0.5,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Title
                                  Text(
                                    'Enter Verification Code',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: appColors().black,
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 8.w),

                                  // Subtitle with phone number
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: const Color(0xFF777777),
                                        fontSize: 14.sp,
                                        fontFamily: 'Poppins',
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'We sent a code to ',
                                        ),
                                        TextSpan(
                                          text: _maskedLastThree(
                                            widget.phoneNumber,
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: appColors().primaryColorApp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 40.w),

                                  // OTP input fields
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: List.generate(
                                      6,
                                      (index) => _buildOTPField(index),
                                    ),
                                  ),
                                  SizedBox(height: 32.w),

                                  // Verify Button
                                  SizedBox(
                                    height: 56.w,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleVerifyOTP,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            appColors().primaryColorApp,
                                        disabledBackgroundColor: appColors()
                                            .primaryColorApp
                                            .withOpacity(0.6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.borderRadius,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              height: 24.w,
                                              width: 24.w,
                                              child:
                                                  const CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                            )
                                          : Text(
                                              'Verify OTP',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: AppSizes.fontLarge,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: 24.w),

                                  // Resend OTP
                                  Center(
                                    child: _canResend
                                        ? TextButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _handleResendOTP,
                                            child: Text(
                                              'Resend OTP',
                                              style: TextStyle(
                                                color:
                                                    appColors().primaryColorApp,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          )
                                        : Text(
                                            'Resend OTP in $_resendCooldown seconds',
                                            style: TextStyle(
                                              color: const Color(0xFF999999),
                                              fontSize: 14.sp,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
