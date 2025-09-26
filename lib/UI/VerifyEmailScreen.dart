import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Presenter/VerifyEmailPresenter.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/MainNavigation.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<StatefulWidget> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  TextEditingController otpController = TextEditingController();

  // Individual OTP digit controllers for better UX
  late List<TextEditingController> _otpControllers;
  late List<FocusNode> _otpFocusNodes;

  // Form state
  bool _isLoading = false;
  bool _autoValidate = false;
  String? _otpError;

  // Animation controllers
  late AnimationController _animationController;
  Animation<double> _fadeInAnimation = AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = AlwaysStoppedAnimation(Offset.zero);

  // Timer for resend OTP
  Timer? _resendTimer;
  int _resendCountdown = 0;
  bool _canResend = true;

  // Focus node for OTP field
  final FocusNode _otpFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    // Note: User is in an "unverified" state at this point
    // They will only be considered "logged in" after successful OTP verification

    // Initialize OTP controllers and focus nodes
    _otpControllers = List.generate(6, (index) => TextEditingController());
    _otpFocusNodes = List.generate(6, (index) => FocusNode());

    // Add listeners to focus nodes for UI updates
    for (var focusNode in _otpFocusNodes) {
      focusNode.addListener(() {
        setState(() {}); // Rebuild to update border colors
      });
    }

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start the animation after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });

    // Start with a 30-second countdown for resend
    _startResendTimer();

    // Auto-focus first OTP box after animation
    Future.delayed(Duration(milliseconds: 1000), () {
      if (mounted) {
        _otpFocusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _animationController.dispose();
    otpController.dispose();
    _otpFocus.dispose();

    // Dispose individual OTP controllers and focus nodes
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  // Start the resend timer
  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendCountdown = 30;
    });

    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  // Validate OTP
  String? _validateOTP() {
    String otp = _getOTPFromControllers();
    if (otp.isEmpty) {
      return 'OTP is required';
    } else if (otp.length != 6) {
      return 'Please enter a valid 6-digit OTP';
    } else if (!RegExp(r'^[0-9]+$').hasMatch(otp)) {
      return 'OTP should contain only numbers';
    }
    return null;
  }

  // Get OTP string from individual controllers
  String _getOTPFromControllers() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  // Clear all OTP boxes
  void _clearOTPBoxes() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes[0].requestFocus();
  }

  // Handle OTP verification
  void _handleVerifyOTP() {
    // Close keyboard first
    FocusScope.of(context).unfocus();

    // Validate OTP
    setState(() {
      _otpError = _validateOTP();
      _autoValidate = true;
    });

    if (_otpError != null) {
      Fluttertoast.showToast(
        msg: _otpError!,
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: AppSizes.fontNormal,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Call verify OTP API
    VerifyEmailPresenter()
        .verifyOTP(context, widget.email, _getOTPFromControllers())
        .then((result) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            // Check if verification was successful
            if (result.login_token.isNotEmpty) {
              // Successful verification - user is now authenticated
              print("OTP verification successful, user is now logged in");

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) {
                    return const MainNavigationWrapper(initialIndex: 0);
                  },
                ),
                (Route<dynamic> route) => false,
              );
            } else {
              // Verification failed - user remains logged out
              print("OTP verification failed - user remains logged out");
              _clearOTPBoxes(); // Clear OTP boxes on failure
            }
          }
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            Fluttertoast.showToast(
              msg: "Verification failed. Please try again.",
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: AppSizes.fontNormal,
            );
          }
        });
  }

  // Handle resend OTP
  void _handleResendOTP() {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    VerifyEmailPresenter()
        .resendOTP(context, widget.email)
        .then((result) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            // Start the timer again
            _startResendTimer();

            // Success message already shown by presenter
            print("OTP resent successfully");
          }
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            Fluttertoast.showToast(
              msg: "Failed to resend OTP. Please try again.",
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: AppSizes.fontNormal,
            );
          }
        });
  }

  // Helper method to mask email for display
  String _getMaskedEmail() {
    if (widget.email.contains('@')) {
      final parts = widget.email.split('@');
      final localPart = parts[0];
      final domain = parts[1];

      if (localPart.length <= 2) {
        return '${localPart[0]}***@$domain';
      } else {
        return '${localPart.substring(0, 2)}***@$domain';
      }
    }
    return widget.email;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
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
                // App Bar replacement
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
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "Verify Email",
                        style: TextStyle(
                          color: appColors().black,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      // Empty SizedBox for balanced spacing
                      SizedBox(width: 48.w),
                    ],
                  ),
                ),

                // Header with logo
                AuthHeader(height: safeAreaHeight * 0.12, heroTag: 'app_logo'),

                // Content area
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
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
                              top: 24.w,
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
                                // Title and description
                                Text(
                                  'Verify Your Email',
                                  style: TextStyle(
                                    color: appColors().black,
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(height: 12.w),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: appColors().black.withOpacity(0.6),
                                      fontSize: 16.sp,
                                      fontFamily: 'Poppins',
                                    ),
                                    children: [
                                      TextSpan(
                                        text:
                                            'Enter the 6-digit code sent to\n',
                                      ),
                                      TextSpan(
                                        text: _getMaskedEmail(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: appColors().primaryColorApp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 40.w),

                                // OTP Input Field
                                Text(
                                  'Verification Code',
                                  style: TextStyle(
                                    color: appColors().black,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(height: 16.w),

                                // Individual OTP Boxes
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      6,
                                      (index) => _buildOTPBox(index),
                                    ),
                                  ),
                                ),

                                if (_autoValidate && _otpError != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 12.w),
                                    child: Text(
                                      _otpError!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 14.sp,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),

                                SizedBox(height: 32.w),

                                // Verify Button
                                SizedBox(
                                  height: 56.w,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _handleVerifyOTP,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          appColors().primaryColorApp,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                    child:
                                        _isLoading
                                            ? SizedBox(
                                              height: 24.w,
                                              width: 24.w,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                            : Text(
                                              'Verify',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18.sp,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                  ),
                                ),

                                SizedBox(height: 32.w),

                                // Resend OTP Section
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Didn't receive the code? ",
                                      style: TextStyle(
                                        color: appColors().black.withOpacity(
                                          0.6,
                                        ),
                                        fontSize: 16.sp,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    if (_canResend)
                                      GestureDetector(
                                        onTap:
                                            _isLoading
                                                ? null
                                                : _handleResendOTP,
                                        child: Text(
                                          'Resend',
                                          style: TextStyle(
                                            color: appColors().primaryColorApp,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Poppins',
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        'Resend in ${_resendCountdown}s',
                                        style: TextStyle(
                                          color: appColors().black.withOpacity(
                                            0.4,
                                          ),
                                          fontSize: 16.sp,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                  ],
                                ),

                                // Add extra space at the bottom when keyboard appears
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).viewInsets.bottom >
                                              0
                                          ? 200.w
                                          : 100.w,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Loading Overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                width: screenWidth,
                height: screenHeight,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 16.w,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(
                            appColors().primaryColorApp,
                          ),
                          strokeWidth: 4.0,
                        ),
                        SizedBox(height: 16.w),
                        Text(
                          Resources.of(context).strings.loadingPleaseWait,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build individual OTP input box
  Widget _buildOTPBox(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      width: 48.w,
      height: 56.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color:
              _otpFocusNodes[index].hasFocus
                  ? appColors().primaryColorApp
                  : _otpError != null && _autoValidate
                  ? Colors.red.withOpacity(0.8)
                  : appColors().black.withOpacity(0.08),
          width: _otpFocusNodes[index].hasFocus ? 2.0 : 1.5,
        ),
        boxShadow:
            _otpFocusNodes[index].hasFocus
                ? [
                  BoxShadow(
                    color: appColors().primaryColorApp.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ]
                : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (RawKeyEvent event) {
          // Handle backspace on empty field
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _otpControllers[index].text.isEmpty &&
              index > 0) {
            // Move to previous box and clear it
            _otpFocusNodes[index - 1].requestFocus();
            _otpControllers[index - 1].clear();

            // Update validation
            if (_autoValidate) {
              setState(() {
                _otpError = _validateOTP();
              });
            }
          }
        },
        child: TextFormField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          keyboardType: TextInputType.number,
          maxLength: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: appColors().black,
            fontFamily: 'Poppins',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          decoration: InputDecoration(
            border: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
            hintText: '•',
            hintStyle: TextStyle(
              color: appColors().black.withOpacity(0.2),
              fontSize: 32.sp,
              fontWeight: FontWeight.w300,
              fontFamily: 'Poppins',
            ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              // Move to next box
              if (index < 5) {
                _otpFocusNodes[index + 1].requestFocus();
              } else {
                // Last digit entered, trigger validation
                _otpFocusNodes[index].unfocus();
                if (_getOTPFromControllers().length == 6) {
                  _handleVerifyOTP();
                }
              }
            }

            // Update validation
            if (_autoValidate) {
              setState(() {
                _otpError = _validateOTP();
              });
            }
          },
          onTap: () {
            // Select all text when tapped for better UX
            _otpControllers[index].selection = TextSelection(
              baseOffset: 0,
              extentOffset: _otpControllers[index].text.length,
            );
          },
        ),
      ),
    );
  }
}

class Resources {
  Resources();

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
    return Resources();
  }
}
