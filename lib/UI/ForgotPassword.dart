import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Presenter/ForGotPassPresenter.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/Login.dart';
import 'package:jainverse/utils/validators.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';
import 'package:jainverse/widgets/common/input_field.dart';

bool sendOtp = false;
String textEmail = '';

class ForgotPassword extends StatefulWidget {
  ForgotPassword(bool bool, String text, {super.key}) {
    sendOtp = bool;
    textEmail = text;
  }

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ForgotPassword> with SingleTickerProviderStateMixin {
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  TextEditingController passConfirmController = TextEditingController();
  TextEditingController otpController = TextEditingController();
  bool _isLoading = false;
  bool _autoValidate = false;

  // Map to track validation status for all fields
  final Map<String, String?> _validationErrors = {
    'email': null,
    'password': null,
    'confirmPassword': null,
    'otp': null,
  };

  // Animation controller for subtle UI animations
  late AnimationController _animationController;
  Animation<double> _fadeInAnimation = AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = AlwaysStoppedAnimation(Offset.zero);

  @override
  void initState() {
    super.initState();

    // Initialize email if coming from a screen that passed it
    if (textEmail.isNotEmpty) {
      emailController.text = textEmail;
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passController.dispose();
    passConfirmController.dispose();
    otpController.dispose();
    super.dispose();
  }

  // Validate email field
  String? _validateEmail() {
    return Validators.validateEmail(emailController.text.trim());
  }

  // Validate password field with strength requirements
  String? _validatePassword() {
    return Validators.validatePasswordStrength(passController.text);
  }

  // Validate confirm password field
  String? _validateConfirmPassword() {
    return Validators.validateConfirmPassword(
      passController.text,
      passConfirmController.text,
    );
  }

  // Validate OTP field
  String? _validateOTP() {
    if (otpController.text.isEmpty) {
      return 'OTP is required';
    } else if (otpController.text.length < 6) {
      return 'Please enter a valid 6-digit OTP';
    }
    return null;
  }

  // Validate all fields at once for password reset
  void _validateAllFields() {
    setState(() {
      _autoValidate = true;
      _validationErrors['email'] = _validateEmail();

      if (sendOtp) {
        _validationErrors['otp'] = _validateOTP();
        _validationErrors['password'] = _validatePassword();
        _validationErrors['confirmPassword'] = _validateConfirmPassword();
      }
    });
  }

  // Check if the form is valid based on current state
  bool _isFormValid() {
    if (!sendOtp) {
      // Only validate email for OTP request
      return _validationErrors['email'] == null;
    } else {
      // Validate all fields for password reset
      return _validationErrors['otp'] == null &&
          _validationErrors['password'] == null &&
          _validationErrors['confirmPassword'] == null;
    }
  }

  // Request OTP function
  void _requestOTP() {
    // Close keyboard first
    FocusScope.of(context).unfocus();

    // Validate email
    setState(() {
      _validationErrors['email'] = _validateEmail();
      _autoValidate = true;
    });

    if (_validationErrors['email'] != null) {
      Fluttertoast.showToast(
        msg: _validationErrors['email']!,
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: 14.0,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Call API to get OTP
    ForGotPassPresenter()
        .getOtp(context, emailController.text)
        .then((result) {
          if (result.contains("successfully")) {
            setState(() {
              sendOtp = true;
              textEmail = emailController.text;
              _isLoading = false;
            });

            Fluttertoast.showToast(
              msg: 'OTP has been sent on your email!!',
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
          } else {
            setState(() {
              _isLoading = false;
            });

            Fluttertoast.showToast(
              msg: result,
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
          }
        })
        .catchError((error) {
          setState(() {
            _isLoading = false;
          });

          Fluttertoast.showToast(
            msg: Resources.of(context).strings.tryAgain,
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 1,
            backgroundColor: appColors().black,
            textColor: appColors().colorBackground,
            fontSize: 14.0,
          );
        });
  }

  // Reset password function
  void _resetPassword() {
    // Close keyboard first
    FocusScope.of(context).unfocus();

    // Validate all fields
    _validateAllFields();

    if (!_isFormValid()) {
      // Show first validation error as toast
      String? firstError =
          _validationErrors['otp'] ??
          _validationErrors['password'] ??
          _validationErrors['confirmPassword'];

      if (firstError != null) {
        Fluttertoast.showToast(
          msg: firstError,
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1,
          backgroundColor: appColors().black,
          textColor: appColors().colorBackground,
          fontSize: 14.0,
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Call API to reset password
    ForGotPassPresenter()
        .getChangePass(
          context,
          textEmail,
          passController.text,
          passConfirmController.text,
          otpController.text,
        )
        .then((result) {
          if (result.contains("successfully")) {
            Fluttertoast.showToast(
              msg: result,
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Login()),
            );
          } else {
            setState(() {
              _isLoading = false;
            });

            Fluttertoast.showToast(
              msg: result,
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
          }
        })
        .catchError((error) {
          setState(() {
            _isLoading = false;
          });

          Fluttertoast.showToast(
            msg: Resources.of(context).strings.tryAgain,
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 1,
            backgroundColor: appColors().black,
            textColor: appColors().colorBackground,
            fontSize: 14.0,
          );
        });
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
                        "Forgot Password",
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
                                  !sendOtp
                                      ? 'Forgot Your Password?'
                                      : 'Reset Password',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: appColors().black,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(height: 12.w),
                                Text(
                                  !sendOtp
                                      ? 'Don\'t worry! Enter your registered email below and we\'ll send you an OTP to reset your password.'
                                      : 'Enter the OTP sent to $textEmail and create your new password.',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    color: Colors.black54,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                SizedBox(height: 28.w),

                                // Conditional UI based on state
                                if (!sendOtp) ...[
                                  // Email field state
                                  Text(
                                    'Email Address',
                                    style: TextStyle(
                                      color: const Color(0xFF555555),
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 8.w),
                                  InputField(
                                    controller: emailController,
                                    hintText:
                                        Resources.of(
                                          context,
                                        ).strings.enterUserEmailHere,
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icons.email_outlined,
                                  ),
                                  if (_autoValidate &&
                                      _validationErrors['email'] != null)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: 4.w,
                                        left: 4.w,
                                      ),
                                      child: Text(
                                        _validationErrors['email']!,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: AppSizes.fontSmall,
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 32.w),

                                  // Send OTP Button
                                  SizedBox(
                                    height: 56.w,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _requestOTP,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFEE5533,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                        ),
                                        elevation: 0,
                                        disabledBackgroundColor: const Color(
                                          0xFFEE5533,
                                        ).withOpacity(0.6),
                                      ),
                                      child: Text(
                                        Resources.of(context).strings.otp,
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  // OTP and Password reset state
                                  // OTP Field
                                  Text(
                                    'OTP',
                                    style: TextStyle(
                                      color: const Color(0xFF555555),
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 8.w),
                                  InputField(
                                    controller: otpController,
                                    hintText: 'Enter OTP here',
                                    keyboardType: TextInputType.number,
                                    prefixIcon: Icons.lock_outline,
                                    maxLength: 6,
                                  ),
                                  if (_autoValidate &&
                                      _validationErrors['otp'] != null)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: 4.w,
                                        left: 4.w,
                                      ),
                                      child: Text(
                                        _validationErrors['otp']!,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: AppSizes.fontSmall,
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 20.w),

                                  // New Password Field
                                  Text(
                                    'New Password',
                                    style: TextStyle(
                                      color: const Color(0xFF555555),
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 8.w),
                                  PasswordInputField(
                                    controller: passController,
                                    hintText:
                                        Resources.of(
                                          context,
                                        ).strings.enterPassHere,
                                  ),
                                  if (_autoValidate &&
                                      _validationErrors['password'] != null)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: 4.w,
                                        left: 4.w,
                                      ),
                                      child: Text(
                                        _validationErrors['password']!,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: AppSizes.fontSmall,
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 20.w),

                                  // Confirm Password Field
                                  Text(
                                    'Confirm New Password',
                                    style: TextStyle(
                                      color: const Color(0xFF555555),
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 8.w),
                                  PasswordInputField(
                                    controller: passConfirmController,
                                    hintText:
                                        Resources.of(
                                          context,
                                        ).strings.confirmPass,
                                  ),
                                  if (_autoValidate &&
                                      _validationErrors['confirmPassword'] !=
                                          null)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: 4.w,
                                        left: 4.w,
                                      ),
                                      child: Text(
                                        _validationErrors['confirmPassword']!,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: AppSizes.fontSmall,
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 32.w),

                                  // Reset Password Button
                                  SizedBox(
                                    height: 56.w,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _resetPassword,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFEE5533,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                        ),
                                        elevation: 0,
                                        disabledBackgroundColor: const Color(
                                          0xFFEE5533,
                                        ).withOpacity(0.6),
                                      ),
                                      child: Text(
                                        Resources.of(
                                          context,
                                        ).strings.resetMyPass,
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                // Back to Login Link
                                SizedBox(height: 24.w),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Remember your password?',
                                      style: TextStyle(
                                        color: appColors().black,
                                        fontSize: 14.sp,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder:
                                                (_, __, ___) => const Login(),
                                            transitionDuration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            transitionsBuilder: (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) {
                                              var begin = const Offset(
                                                1.0,
                                                0.0,
                                              );
                                              var end = Offset.zero;
                                              var curve = Curves.ease;
                                              var tween = Tween(
                                                begin: begin,
                                                end: end,
                                              ).chain(CurveTween(curve: curve));
                                              return SlideTransition(
                                                position: animation.drive(
                                                  tween,
                                                ),
                                                child: child,
                                              );
                                            },
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.only(left: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        Resources.of(context).strings.loginhere,
                                        style: TextStyle(
                                          color: const Color(0xFFEE5533),
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins',
                                        ),
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
                                          : 16.w,
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
}

class ResetSuccess extends StatelessWidget {
  const ResetSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: appColors().colorBackground,
        body: Container(
          child: Stack(
            children: [
              Image.asset('assets/images/SuccessfullysetBackground.jpg'),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(6, 0, 6, 230),
                  child: Text(
                    Resources.of(context).strings.resetMyPassSuccess,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: appColors().colorText,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
