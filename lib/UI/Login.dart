import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/ModelAppInfo.dart';
import 'package:jainverse/Presenter/AppInfoPresenter.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/LoginDataPresenter.dart';
import 'package:jainverse/utils/ConnectionCheck.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/UI/ForgotPassword.dart';
import 'package:jainverse/UI/signup.dart';
import 'package:jainverse/UI/VerifyEmailScreen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';
import 'package:jainverse/widgets/auth/auth_tabbar.dart';
import 'package:jainverse/widgets/common/input_field.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'LanguageChoose.dart';
import 'MainNavigation.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/services/token_expiration_handler.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<Login> with SingleTickerProviderStateMixin {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  // Add focus node for password field
  final FocusNode _passwordFocusNode = FocusNode();
  SharedPref sharePrefs = SharedPref();

  bool hasLoad = false;
  String version = '';
  String buildNumber = '';
  late UserModel model;
  List<Data> list = [];
  String _selectedRole = 'Listener';
  bool _rememberMe = true; // default checked

  // Animation controller for subtle UI animations
  late AnimationController _animationController;
  // Initialize animations with default values to avoid LateInitializationError
  Animation<double> _fadeInAnimation = AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = AlwaysStoppedAnimation(Offset.zero);

  @override
  void initState() {
    super.initState();

    // Explicitly set status bar icon brightness to dark on Login screen
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

    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    });
    getValue();

    print("DEBUG: About to load remembered credentials in initState");
    loadRememberedCredentials();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _passwordFocusNode.dispose(); // Dispose the focus node
    super.dispose();
  }

  getValue() async {
    String data = await AppInfoPresenter().getInfo("");
    final Map<String, dynamic> parsed = json.decode(data.toString());
    ModelAppInfo mList = ModelAppInfo.fromJson(parsed);
    for (int i = 0; i < mList.data.length; i++) {
      if (mList.data[i].title.contains("Privacy")) {
        list.add(mList.data[i]);
      }
      if (mList.data[i].title.contains("Terms")) {
        list.add(mList.data[i]);
      }
    }
  }

  Future<void> loadRememberedCredentials() async {
    print("DEBUG: Loading remembered credentials...");
    // Try to read saved preference. If no saved credentials exist, keep the
    // checkbox checked by default (initial experience requirement). If saved
    // credentials exist, load them and check the box.
    bool rememberMe = await sharePrefs.getRememberMe();
    print("DEBUG: Remember me preference: $rememberMe");
    String email = await sharePrefs.getRememberedEmail();
    String password = await sharePrefs.getRememberedPassword();
    print("DEBUG: Remembered email: $email");
    print("DEBUG: Remembered password length: ${password.length}");

    if (rememberMe == true && (email.isNotEmpty || password.isNotEmpty)) {
      // Previously opted-in and we have stored credentials -> load them
      setState(() {
        _rememberMe = true;
        emailController.text = email;
        passwordController.text = password;
      });
      print("DEBUG: UI updated with remembered credentials");
    } else if (email.isNotEmpty || password.isNotEmpty) {
      // Credentials exist even if the boolean flag wasn't true -> load them
      setState(() {
        _rememberMe = true;
        emailController.text = email;
        passwordController.text = password;
      });
      print("DEBUG: Credentials found and loaded, checkbox set to true");
    } else {
      // No saved credentials -> keep checkbox checked by default but leave fields empty
      setState(() {
        _rememberMe = true;
        emailController.text = '';
        passwordController.text = '';
      });
      print(
        "DEBUG: No saved credentials, keeping Remember Me checked by default",
      );
    }
  }

  Future<void> login() async {
    try {
      // Map selected role to isArtist flag required by API: Listener -> 0, Artist -> 1
      int isArtistFlag = _selectedRole == 'Artist' ? 1 : 0;
      String res = await LoginDataPresenter().getUser(
        context,
        buildNumber,
        emailController.text,
        passwordController.text,
        isArtistFlag,
      );
      if (res.contains("1")) {
        print("DEBUG: Login successful, attempting to get user data");
        model = await sharePrefs.getUserData();
        print("DEBUG: User data retrieved successfully");

        // Save credentials if remember me is checked
        print("DEBUG: Remember me checked: $_rememberMe");
        if (_rememberMe) {
          print("DEBUG: Saving credentials to SharedPreferences");
          await sharePrefs.setRememberMe(true);
          await sharePrefs.setRememberedEmail(emailController.text);
          await sharePrefs.setRememberedPassword(passwordController.text);
          print("DEBUG: Credentials saved successfully");
        } else {
          print("DEBUG: Clearing remembered credentials");
          await sharePrefs.setRememberMe(false);
          await sharePrefs.setRememberedEmail('');
          await sharePrefs.setRememberedPassword('');
          print("DEBUG: Credentials cleared successfully");
        }

        // Check if language is selected
        if (model.selectedLanguage > 0) {
          // Reset token expiration handler so future 401s will trigger
          // the login-expired flow again for this new session.
          try {
            TokenExpirationHandler().reset();
          } catch (e) {
            // ignore
          }
          print("DEBUG: Language selected, navigating to main navigation");
          // Ensure navigation and mini player are visible after login (restore UI)
          try {
            MusicPlayerStateManager().showNavigationAndMiniPlayer();
          } catch (e) {
            print('Error restoring music UI state after login: $e');
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) {
                return const MainNavigationWrapper(initialIndex: 0);
              },
            ),
            (Route<dynamic> route) => false, // This removes all previous routes
          );
        } else {
          print(
            "DEBUG: No language selected, navigating to language selection",
          );
          // Also restore UI when navigating to language selection
          try {
            MusicPlayerStateManager().showNavigationAndMiniPlayer();
          } catch (e) {
            print('Error restoring music UI state after login: $e');
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) {
                return LanguageChoose('fromLogin');
              },
            ),
            (Route<dynamic> route) => false, // This removes all previous routes
          );
        }
      } else if (res.contains("2")) {
        print("DEBUG: Email verification required, navigating to OTP screen");
        hasLoad = false;
        setState(() {});

        // Navigate to email verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => VerifyEmailScreen(email: emailController.text),
          ),
        );
      } else {
        print("DEBUG: Login failed");
        // Fluttertoast.showToast(
        //   msg: "Try Again !",
        //   toastLength: Toast.LENGTH_SHORT,
        //   timeInSecForIosWeb: 2,
        //   backgroundColor: Colors.grey,
        //   textColor: appColors().colorBackground,
        //   fontSize: AppSizes.fontNormal,
        // );
        hasLoad = false;
        setState(() {});
      }
    } catch (e) {
      print("DEBUG: Exception in login method: $e");
      Fluttertoast.showToast(
        msg: "An error occurred. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 2,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: AppSizes.fontNormal,
      );
      hasLoad = false;
      setState(() {});
    }
  }

  void _handleLoginButton() {
    // Close keyboard first
    FocusScope.of(context).unfocus();

    // Artist login is now supported by the backend. We still keep the role
    // selection in UI but allow the login flow to proceed for both roles.

    // Regular login flow for Listener role
    ConnectionCheck().checkConnection();
    if (emailController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: Resources.of(context).strings.enterUserEmailContinue,
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: AppSizes.fontNormal,
      );
      return;
    }
    if (!RegExp(
      r'^.+@[a-zA-Z]+\.{1}[a-zA-Z]+(\.{0,1}[a-zA-Z]+)$',
    ).hasMatch(emailController.text)) {
      Fluttertoast.showToast(
        msg: Resources.of(context).strings.incorrectEmail,
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: AppSizes.fontNormal,
      );
      return;
    }
    if (passwordController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: Resources.of(context).strings.enterPassContinue,
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: AppSizes.fontNormal,
      );
      return;
    }
    if (passwordController.text.length < 6) {
      Fluttertoast.showToast(
        msg: Resources.of(context).strings.passwordLength,
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: AppSizes.fontNormal,
      );
      return;
    }
    hasLoad = true;
    setState(() {});
    login();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final safeAreaHeight = screenHeight - padding.top - padding.bottom;

    return Scaffold(
      backgroundColor: appColors().backgroundLogin,
      // Remove resizeToAvoidBottomInset to avoid the screen shifting
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
                        // onPressed:
                        //     () => Navigator.pushReplacement(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder:
                        //             (context) => OnboardingScreen(
                        //               onGetStarted: () {
                        //                 // This callback won't be used since we're navigating away
                        //               },
                        //             ),
                        //       ),
                        //     ),

                        // onPressed: () => Navigator.pop(context),
                        //Keep on Pressed to exit app as ther will be no screen previous
                        onPressed: () {
                          SystemNavigator.pop();
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
                      // Empty SizedBox for balanced spacing
                      SizedBox(width: 48.w),
                    ],
                  ),
                ),

                // Replace the header code with the new AuthHeader widget
                AuthHeader(height: safeAreaHeight * 0.12, heroTag: 'app_logo'),

                // Scrollable Login Form Container
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: GestureDetector(
                        onTap: () {
                          // Dismiss keyboard when tapping outside input fields
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
                          // Changed to a ScrollView that takes the full available space
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              // Move padding to here so it doesn't affect the background color
                              padding: EdgeInsets.only(
                                top: 24.w,
                                left: 24.w,
                                right: 24.w,
                                // Add additional padding at the bottom to ensure form is fully visible when keyboard is open
                                bottom:
                                    24.w +
                                    MediaQuery.of(context).viewInsets.bottom *
                                        0.5,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Role Selection Tabs
                                  AuthTabBar(
                                    selectedRole: _selectedRole,
                                    onRoleChanged: (role) {
                                      setState(() {
                                        _selectedRole = role;
                                      });
                                    },
                                  ),
                                  SizedBox(height: 28.w),

                                  // Email Section
                                  Text(
                                    'Email Address',
                                    style: TextStyle(
                                      color: const Color(0xFF555555),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 8.w),
                                  InputField(
                                    controller: emailController,
                                    hintText: 'Your Email Address',
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icons.email_outlined,
                                    textInputAction:
                                        TextInputAction.next, // Set next action
                                    onSubmitted:
                                        (_) =>
                                            FocusScope.of(context).requestFocus(
                                              _passwordFocusNode,
                                            ), // Move to password field
                                  ),
                                  SizedBox(height: 20.w),

                                  // Password Section
                                  Text(
                                    'Password',
                                    style: TextStyle(
                                      color: const Color(0xFF555555),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 8.w),
                                  PasswordInputField(
                                    controller: passwordController,
                                    hintText: 'Password',
                                    focusNode:
                                        _passwordFocusNode, // Assign focus node
                                    textInputAction:
                                        TextInputAction.done, // Set done action
                                    onSubmitted:
                                        (_) =>
                                            _handleLoginButton(), // Submit form on done
                                  ),

                                  // Row with Remember Me checkbox and Forgot Password link
                                  // Show for both Listener and Artist roles
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Remember Me checkbox
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Checkbox(
                                            value: _rememberMe,
                                            onChanged: (bool? value) {
                                              print(
                                                "DEBUG: Checkbox changed to: ${value ?? false}",
                                              );
                                              setState(() {
                                                _rememberMe = value ?? false;
                                              });
                                              print(
                                                "DEBUG: _rememberMe updated to: $_rememberMe",
                                              );
                                            },
                                            activeColor: const Color(
                                              0xFFEE5533,
                                            ),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          Text(
                                            'Remember me',
                                            style: TextStyle(
                                              color: const Color(0xFF555555),
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Forgot Password link
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder:
                                                  (_, __, ___) =>
                                                      ForgotPassword(false, ''),
                                              transitionDuration:
                                                  const Duration(
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
                                                ).chain(
                                                  CurveTween(curve: curve),
                                                );
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
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8.w,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            color: appColors().black,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 24.w),

                                  // Login Button - Updated text to reflect selected role
                                  SizedBox(
                                    height: 56.w,
                                    child: ElevatedButton(
                                      onPressed:
                                          hasLoad ? null : _handleLoginButton,
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
                                      child:
                                          hasLoad
                                              ? SizedBox(
                                                width: 24.w,
                                                height: 24.w,
                                                child: CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                  strokeWidth: 2.w,
                                                ),
                                              )
                                              : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    _selectedRole == 'Artist'
                                                        ? 'Login'
                                                        : Resources.of(
                                                          context,
                                                        ).strings.login,
                                                    style: TextStyle(
                                                      fontSize: 18.sp,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                    ),
                                  ),
                                  SizedBox(height: 32.w),

                                  // Create Account Link
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        Resources.of(
                                          context,
                                        ).strings.dontHaveAnAccount,
                                        style: TextStyle(
                                          color: appColors().black,
                                          fontSize: 14.sp,
                                          fontFamily: 'Poppins',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder:
                                                  (_, __, ___) =>
                                                      const signup(),
                                              transitionDuration:
                                                  const Duration(
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
                                                ).chain(
                                                  CurveTween(curve: curve),
                                                );
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
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          Resources.of(context).strings.signup,
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
                                  // Add extra space at the bottom to ensure content is visible when keyboard appears
                                  SizedBox(
                                    height:
                                        MediaQuery.of(
                                                  context,
                                                ).viewInsets.bottom >
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
                ),
              ],
            ),

            // Remove the loading overlay completely
          ],
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
