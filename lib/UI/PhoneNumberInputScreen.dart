import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/OTPVerificationScreen.dart';
import 'package:jainverse/services/phone_auth_service.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';
import 'package:jainverse/widgets/common/input_field.dart';

class PhoneNumberInputScreen extends StatefulWidget {
  const PhoneNumberInputScreen({super.key});

  @override
  State<PhoneNumberInputScreen> createState() => _PhoneNumberInputScreenState();
}

class _PhoneNumberInputScreenState extends State<PhoneNumberInputScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final PhoneAuthService _authService = PhoneAuthService();
  bool _isLoading = false;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Validate phone number (basic validation)
  String? _validatePhone(String phone) {
    if (phone.isEmpty) {
      return 'Phone number is required';
    }

    // Remove any spaces or special characters
    final cleanedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Check minimum length (adjust based on your requirements)
    if (cleanedPhone.length < 10) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  /// Handle send OTP button press
  Future<void> _handleSendOTP() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Validate phone number
    final error = _validatePhone(_phoneController.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _authService.requestOTP(
        context,
        _phoneController.text.trim(),
      );

      if (success && mounted) {
        // Navigate to OTP verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              phoneNumber: _phoneController.text.trim(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                        "Login",
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
                                  Text.rich(
                                    TextSpan(
                                      text: 'Welcome to ',
                                      style: TextStyle(
                                        color: appColors().black,
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'JainVerse',
                                          style: TextStyle(
                                            color: appColors().primaryColorApp,
                                          ),
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 8.w),

                                  // Subtitle
                                  Text(
                                    'Enter your Phone Number to Continue',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFF777777),
                                      fontSize: 14.sp,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 40.w),

                                  // Phone number label
                                  Text(
                                    'Phone Number',
                                    style: TextStyle(
                                      color: const Color(0xFF555555),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 8.w),

                                  // Phone number input
                                  InputField(
                                    controller: _phoneController,
                                    hintText: 'Enter Your Phone Number',
                                    keyboardType: TextInputType.phone,
                                    prefixIcon: Icons.phone_outlined,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _handleSendOTP(),
                                    // Limit input to digits and maximum 10 characters
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                  ),
                                  SizedBox(height: 32.w),

                                  // Send OTP Button
                                  SizedBox(
                                    height: 56.w,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleSendOTP,
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
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Next',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize:
                                                        AppSizes.fontLarge,
                                                    fontWeight: FontWeight.w600,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                                SizedBox(width: 12.w),
                                                Icon(
                                                  Icons.arrow_forward_ios,
                                                  color: Colors.white,
                                                  size: 28.w,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: 24.w),

                                  // Info text
                                  Text(
                                    'We will send you a one-time password (OTP) to verify your phone number',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFF999999),
                                      fontSize: 12.sp,
                                      fontFamily: 'Poppins',
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
