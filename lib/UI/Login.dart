import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/ModelAppInfo.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/AppInfoPresenter.dart';
import 'package:jainverse/Presenter/LoginDataPresenter.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/ForgotPassword.dart';
import 'package:jainverse/UI/VerifyEmailScreen.dart';
import 'package:jainverse/UI/signup.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/ConnectionCheck.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';
import 'package:jainverse/widgets/common/input_field.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'MainNavigation.dart';

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
  // Only listener role is required
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
      // Only listener role is supported
      int isArtistFlag = 0;
      String res = await LoginDataPresenter().getUser(
        context,
        buildNumber,
        emailController.text,
        passwordController.text,
        isArtistFlag,
      );
      if (res.contains("1")) {
        model = await sharePrefs.getUserData();
        if (_rememberMe) {
          await sharePrefs.setRememberMe(true);
          await sharePrefs.setRememberedEmail(emailController.text);
          await sharePrefs.setRememberedPassword(passwordController.text);
        } else {
          await sharePrefs.setRememberMe(false);
          await sharePrefs.setRememberedEmail('');
          await sharePrefs.setRememberedPassword('');
        }
        try {
          TokenExpirationHandler().reset();
        } catch (e) {
          e.toString();
        }
        try {
          MusicPlayerStateManager().showNavigationAndMiniPlayer();
        } catch (e) {
          e.toString();
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) {
              return const MainNavigationWrapper(initialIndex: 0);
            },
          ),
          (Route<dynamic> route) => false,
        );
      } else if (res.contains("2")) {
        hasLoad = false;
        setState(() {});
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => VerifyEmailScreen(email: emailController.text),
          ),
        );
      } else {
        hasLoad = false;
        setState(() {});
      }
    } catch (e) {
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
    FocusScope.of(context).unfocus();
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
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
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
                      SizedBox(width: 48.w),
                    ],
                  ),
                ),
                AuthHeader(height: safeAreaHeight * 0.12, heroTag: 'app_logo'),
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
                                    textInputAction: TextInputAction.next,
                                    onSubmitted:
                                        (_) => FocusScope.of(
                                          context,
                                        ).requestFocus(_passwordFocusNode),
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
                                    focusNode: _passwordFocusNode,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _handleLoginButton(),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Checkbox(
                                            value: _rememberMe,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                _rememberMe = value ?? false;
                                              });
                                            },
                                            activeColor:
                                                appColors().primaryColorApp,
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
                                  SizedBox(
                                    height: 56.w,
                                    child: ElevatedButton(
                                      onPressed:
                                          hasLoad ? null : _handleLoginButton,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            appColors().primaryColorApp,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                        ),
                                        elevation: 0,
                                        disabledBackgroundColor: appColors()
                                            .primaryColorApp
                                            .withOpacity(0.6),
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
                                                    Resources.of(
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
                                            color: appColors().primaryColorApp,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
