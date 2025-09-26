import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for TextInputFormatter
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/Model/CountryModel.dart';
import 'package:jainverse/Model/ModelAppInfo.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/AppInfoPresenter.dart';
import 'package:jainverse/Presenter/CountryPresenter.dart';
import 'package:jainverse/Presenter/SignupPresenter.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/VerifyEmailScreen.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/validators.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';
import 'package:jainverse/widgets/auth/privacy_policy_view.dart';
import 'package:jainverse/widgets/common/country_dropdown_with_search.dart';
import 'package:jainverse/widgets/common/custom_date_picker.dart';
import 'package:jainverse/widgets/common/input_field.dart';

class signup extends StatefulWidget {
  const signup({super.key});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<signup> with SingleTickerProviderStateMixin {
  // Controllers
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  // Removed artistNameController (artist registration not supported)
  TextEditingController phoneController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  // Form state
  final _formKey = GlobalKey<FormState>();
  bool _autoValidate = false;

  // Animation controllers
  late AnimationController _animationController;
  Animation<double> _fadeInAnimation = AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = AlwaysStoppedAnimation(Offset.zero);

  // Form state variables
  final String _selectedRole = 'Listener';
  String? _selectedGender; // Changed from 'Male' to null
  Country? _selectedCountry; // Changed to Country object
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _termsAccepted = false;

  // Lists needed for the UI
  List<String> genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
  List<Country> countries = []; // Dynamic country list
  SharedPref sharePrefs = SharedPref();
  List<Data> list = [];
  CountryPresenter countryPresenter =
      CountryPresenter(); // Add country presenter

  // Debounce timer for delayed validation
  Timer? _debounceTimer;
  // Map to track validation status for all fields
  final Map<String, String?> _validationErrors = {
    'firstName': null,
    'lastName': null,
    'phone': null,
    'email': null,
    'password': null,
    'confirmPassword': null,
    'birthdate': null,
  };
  // Flag to indicate if form can be submitted
  bool _formValid = false;

  // Add scroll controller to manage scrolling
  final ScrollController _scrollController = ScrollController();

  // Add field keys to locate each field for scrolling
  final _firstNameFieldKey = GlobalKey();
  final _lastNameFieldKey = GlobalKey();
  // Removed _artistNameFieldKey (artist registration not supported)
  final _phoneFieldKey = GlobalKey();
  final _emailFieldKey = GlobalKey();
  final _genderFieldKey = GlobalKey();
  final _countryFieldKey = GlobalKey();
  final _passwordFieldKey = GlobalKey();
  final _confirmPasswordFieldKey = GlobalKey();

  // Add FocusNodes for all input fields
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  // Removed _artistNameFocus (artist registration not supported)
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  @override
  void initState() {
    super.initState();

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

    // Load countries from API
    _loadCountries();

    // Add listeners to text controllers for delayed validation
    firstNameController.addListener(_validateFirstName);
    lastNameController.addListener(_validateLastName);
    // Removed artistNameController listener (artist registration not supported)
    phoneController.addListener(_validatePhone);
    emailController.addListener(_validateEmail);
    passwordController.addListener(_validatePassword);
    confirmPasswordController.addListener(_validateConfirmPassword);

    // Add listeners to focus nodes to scroll to active field
    _firstNameFocus.addListener(() {
      if (_firstNameFocus.hasFocus) _scrollToField(_firstNameFieldKey);
    });
    _lastNameFocus.addListener(() {
      if (_lastNameFocus.hasFocus) _scrollToField(_lastNameFieldKey);
    });
    // Removed artistNameFocus listener (artist registration not supported)
    _phoneFocus.addListener(() {
      if (_phoneFocus.hasFocus) _scrollToField(_phoneFieldKey);
    });
    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) _scrollToField(_emailFieldKey);
    });
    _passwordFocus.addListener(() {
      if (_passwordFocus.hasFocus) _scrollToField(_passwordFieldKey);
    });
    _confirmPasswordFocus.addListener(() {
      if (_confirmPasswordFocus.hasFocus) {
        _scrollToField(_confirmPasswordFieldKey);
      }
    });

    getValue();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();

    // Remove all listeners from controllers
    firstNameController.removeListener(_validateFirstName);
    lastNameController.removeListener(_validateLastName);
    phoneController.removeListener(_validatePhone);
    emailController.removeListener(_validateEmail);
    passwordController.removeListener(_validatePassword);
    confirmPasswordController.removeListener(_validateConfirmPassword);

    // Dispose focus nodes
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();

    _animationController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    // Removed _artistNameFocus and artistNameController dispose (artist registration not supported)
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

  // Load countries from API
  Future<void> _loadCountries() async {
    try {
      final loadedCountries = await countryPresenter.getCountries(context);
      setState(() {
        countries = loadedCountries;
      });
    } catch (e) {
      print('Error loading countries: $e');
      // Fallback to empty list - the CountryPresenter handles fallback internally
    }
  }

  // Debounce function to delay validation
  void _debounce(Function() callback) {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(Duration(milliseconds: 500), callback);
  }

  // Individual field validation methods
  void _validateFirstName() {
    _debounce(() {
      if (mounted) {
        setState(() {
          _validationErrors['firstName'] = Validators.validateName(
            firstNameController.text.trim(),
            minLength: 2,
            maxLength: 30,
          );
          _updateFormValidity();
        });
      }
    });
  }

  void _validateLastName() {
    _debounce(() {
      if (mounted) {
        setState(() {
          _validationErrors['lastName'] = Validators.validateName(
            lastNameController.text.trim(),
            minLength: 2,
            maxLength: 30,
          );
          _updateFormValidity();
        });
      }
    });
  }

  // Removed _validateArtistName (artist registration not supported)

  void _validatePhone() {
    _debounce(() {
      if (mounted) {
        setState(() {
          // Check if phone is empty before validating (since it's optional)
          if (phoneController.text.trim().isEmpty) {
            _validationErrors['phone'] = null;
          } else {
            _validationErrors['phone'] = Validators.validatePhone(
              phoneController.text.trim(),
            );
          }
          _updateFormValidity();
        });
      }
    });
  }

  void _validateEmail() {
    _debounce(() {
      if (mounted) {
        setState(() {
          _validationErrors['email'] = Validators.validateEmail(
            emailController.text.trim(),
          );
          _updateFormValidity();
        });
      }
    });
  }

  void _validatePassword() {
    _debounce(() {
      if (mounted) {
        setState(() {
          _validationErrors['password'] = Validators.validatePasswordStrength(
            passwordController.text,
          );
          // Also validate confirm password as it depends on password
          _validationErrors['confirmPassword'] =
              Validators.validateConfirmPassword(
                passwordController.text,
                confirmPasswordController.text,
              );
          _updateFormValidity();
        });
      }
    });
  }

  void _validateConfirmPassword() {
    _debounce(() {
      if (mounted) {
        setState(() {
          _validationErrors['confirmPassword'] =
              Validators.validateConfirmPassword(
                passwordController.text,
                confirmPasswordController.text,
              );
          _updateFormValidity();
        });
      }
    });
  }

  // Validate all fields at once
  void _validateAllFields() {
    setState(() {
      _validationErrors['firstName'] = Validators.validateName(
        firstNameController.text.trim(),
        minLength: 2,
        maxLength: 30,
      );

      _validationErrors['lastName'] = Validators.validateName(
        lastNameController.text.trim(),
        minLength: 2,
        maxLength: 30,
      );

      // Artist name validation removed (artist registration not supported)

      // Special handling for phone (optional field)
      if (phoneController.text.trim().isEmpty) {
        _validationErrors['phone'] = null;
      } else {
        _validationErrors['phone'] = Validators.validatePhone(
          phoneController.text.trim(),
        );
      }

      _validationErrors['email'] = Validators.validateEmail(
        emailController.text.trim(),
      );

      _validationErrors['password'] = Validators.validatePasswordStrength(
        passwordController.text,
      );

      _validationErrors['confirmPassword'] = Validators.validateConfirmPassword(
        passwordController.text,
        confirmPasswordController.text,
      );

      _updateFormValidity();
    });
  }

  // Update overall form validity
  void _updateFormValidity() {
    bool isValid = true;

    // Check required fields
    if (_validationErrors['firstName'] != null ||
        _validationErrors['lastName'] != null ||
        _validationErrors['email'] != null ||
        _validationErrors['password'] != null ||
        _validationErrors['confirmPassword'] != null) {
      isValid = false;
    }

    // Artist name validation removed (artist registration not supported)

    // Phone is optional, so only check if it has an error when filled
    if (_validationErrors['phone'] != null &&
        phoneController.text.trim().isNotEmpty) {
      isValid = false;
    }

    setState(() {
      _formValid = isValid;
    });
  }

  // Modified handler to properly validate and scroll to errors
  void _handleSignup() {
    // Close keyboard first
    FocusScope.of(context).unfocus();

    // Validate all fields first
    _validateAllFields();

    // Set autoValidate to true so errors become visible
    setState(() {
      _autoValidate = true;
    });

    // Artist registration logic removed (only Listener allowed)

    // Validate form data
    if (!_termsAccepted) {
      Fluttertoast.showToast(
        msg: "Accept all terms and conditions.",
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: AppSizes.fontNormal,
      );
      return;
    }

    // If there are validation errors, scroll to the first error
    if (!_formValid) {
      _scrollToFirstError();

      // Show general error message
      Fluttertoast.showToast(
        msg: "Please fix the errors in the form",
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: AppSizes.fontNormal,
      );
      return;
    }

    // At this point, form is valid, proceed with registration
    setState(() {
      _isLoading = true;
    });

    // Proceed with registration
    _registerUser(
      firstNameController.text.trim(),
      lastNameController.text.trim(),
      emailController.text,
      passwordController.text,
      phoneController.text,
    );
  }

  // New method to scroll to the first field with an error
  void _scrollToFirstError() {
    // Define a list of field keys and their corresponding error keys
    final fieldErrors = [
      {'key': _firstNameFieldKey, 'error': 'firstName'},
      {'key': _lastNameFieldKey, 'error': 'lastName'},
      {'key': _phoneFieldKey, 'error': 'phone'},
      {'key': _emailFieldKey, 'error': 'email'},
      {'key': _passwordFieldKey, 'error': 'password'},
      {'key': _confirmPasswordFieldKey, 'error': 'confirmPassword'},
    ];

    // Find the first field with an error
    for (var field in fieldErrors) {
      if (_validationErrors[field['error']] != null) {
        // Get the field's render box
        if ((field['key'] as GlobalKey).currentContext != null) {
          final RenderBox renderBox =
              (field['key'] as GlobalKey).currentContext!.findRenderObject()
                  as RenderBox;

          // Get the field position
          final position = renderBox.localToGlobal(Offset.zero);

          // Scroll to the field position with some padding
          _scrollController.animateTo(
            position.dy - 100, // Account for app bar and some padding
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );

          // Break after finding the first error
          break;
        }
      }
    }
  }

  void _registerUser(
    String firstName,
    String lastName,
    String email,
    String password,
    String phone,
  ) async {
    try {
      // Debug information
      print("========== REGISTRATION FLOW STARTED ==========");
      print("First Name: $firstName");
      print("Last Name: $lastName");
      print("Email: $email");
      print("Phone: $phone");
      print("Role Selected: $_selectedRole");
      print("Gender Selected: $_selectedGender");

      // Format the date as yyyy-MM-dd for API
      String? formattedDate;
      if (_selectedDate != null) {
        formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        print("Date of Birth: $formattedDate");
      } else {
        print("Date of Birth: Not provided");
      }

      // Send the actual country name directly (no conversion to ID)
      print("Country Selected: ${_selectedCountry ?? 'None'}");

      print("Calling API for registration...");

      // Use async/await instead of FutureBuilder to avoid setState during build
      final UserModel result = await SignupPresenter().getRegister(
        context,
        firstName,
        lastName,
        email,
        password,
        phone,
        gender: _selectedGender,
        dob: formattedDate,
        countryId:
            _selectedCountry?.id.toString(), // Send the country ID as string
      );

      // If we reach here, registration was successful
      // Check if registration response indicates OTP was sent
      print(
        "Registration result - status: ${result.status}, msg: '${result.msg}', login_token: '${result.login_token}'",
      );

      if (result.status == true &&
          result.msg.isNotEmpty &&
          result.msg.toLowerCase().contains("otp has been successfully sent")) {
        // Clear any existing authentication data since user needs to verify OTP first
        sharePrefs.removeValues();

        // Navigate to verify email screen instead of language choose
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => VerifyEmailScreen(email: emailController.text),
          ),
        );
      } else {
        // Handle case where neither condition is met
        print(
          "Unexpected registration response - status: ${result.status}, msg: '${result.msg}'",
        );
        Fluttertoast.showToast(
          msg:
              "Registration completed but unable to proceed. Please try logging in.",
          toastLength: Toast.LENGTH_LONG,
          timeInSecForIosWeb: 2,
          backgroundColor: appColors().black,
          textColor: appColors().colorBackground,
          fontSize: AppSizes.fontNormal,
        );
      }
    } catch (e) {
      // Log the error but don't show toast (presenter already handles this)
      print("Registration error: $e");
      // No need to show toast here as the presenter already handles error messages
    } finally {
      // Update loading state when complete
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Method to handle field focus and scroll to it
  void _scrollToField(GlobalKey fieldKey) {
    Future.delayed(Duration(milliseconds: 300), () {
      if (fieldKey.currentContext != null) {
        final RenderBox renderBox =
            fieldKey.currentContext!.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);

        // Get available height considering keyboard
        final availableHeight =
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).viewInsets.bottom -
            100; // Extra padding

        // Only scroll if field is below the visible area
        if (position.dy > availableHeight) {
          _scrollController.animateTo(
            _scrollController.offset + (position.dy - availableHeight) + 100,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  // Helper method to move focus to next field
  void _fieldFocusChange(FocusNode currentFocus, FocusNode nextFocus) {
    currentFocus.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  // Helper method to build consistent field labels
  Widget _buildFieldLabel(String label, bool isRequired) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: const Color(0xFF555555),
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
          if (isRequired)
            TextSpan(
              text: '*',
              style: TextStyle(
                color: appColors().primaryColorApp,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final safeAreaHeight = screenHeight - padding.top - padding.bottom;

    // Check if keyboard is visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

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
                    vertical: 4.w, // Changed from .w to .w
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
                        "Create an Account",
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

                // Content area with fixed bottom section
                Expanded(
                  child: Stack(
                    children: [
                      // Main container with rounded top
                      SizedBox(
                        height: double.infinity,
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
                                child: Column(
                                  children: [
                                    // Removed AuthTabBar (only Listener role supported)
                                    SizedBox(height: 20.w),
                                    // Scrollable content area starting below the tab bar
                                    Expanded(
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        physics: const BouncingScrollPhysics(),
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            left: 24.w,
                                            right: 24.w,
                                            bottom:
                                                isKeyboardVisible
                                                    ? keyboardHeight +
                                                        120
                                                            .w // Changed from .w to .w
                                                    : 40.w, // Changed from .w to .w
                                          ),
                                          child: Form(
                                            key: _formKey,
                                            autovalidateMode:
                                                _autoValidate
                                                    ? AutovalidateMode.always
                                                    : AutovalidateMode.disabled,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                // First Name Field
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                        bottom: 8.w,
                                                      ),
                                                      child: _buildFieldLabel(
                                                        'First Name',
                                                        true,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      key: _firstNameFieldKey,
                                                      height:
                                                          AppSizes.inputHeight,
                                                      child: InputField(
                                                        controller:
                                                            firstNameController,
                                                        hintText:
                                                            'Enter your first name',
                                                        prefixIcon:
                                                            Icons
                                                                .person_outline,
                                                        focusNode:
                                                            _firstNameFocus,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        inputFormatters: [
                                                          CapitalizeFirstLetterFormatter(),
                                                        ],
                                                        onEditingComplete:
                                                            () => _fieldFocusChange(
                                                              _firstNameFocus,
                                                              _lastNameFocus,
                                                            ),
                                                      ),
                                                    ),
                                                    if (_autoValidate &&
                                                        _validationErrors['firstName'] !=
                                                            null)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 4.w,
                                                              left: 4.w,
                                                            ),
                                                        child: Text(
                                                          _validationErrors['firstName']!,
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize:
                                                                AppSizes
                                                                    .fontSmall,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: AppSizes.paddingM,
                                                ),

                                                // Last Name Field
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                        bottom: 8.w,
                                                      ),
                                                      child: _buildFieldLabel(
                                                        'Last Name',
                                                        true,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      key: _lastNameFieldKey,
                                                      height:
                                                          AppSizes.inputHeight,
                                                      child: InputField(
                                                        controller:
                                                            lastNameController,
                                                        hintText:
                                                            'Enter Your last name',
                                                        prefixIcon:
                                                            Icons
                                                                .person_outline,
                                                        focusNode:
                                                            _lastNameFocus,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        inputFormatters: [
                                                          CapitalizeFirstLetterFormatter(),
                                                        ],
                                                        onEditingComplete:
                                                            () =>
                                                                _fieldFocusChange(
                                                                  _lastNameFocus,
                                                                  _phoneFocus,
                                                                ),
                                                      ),
                                                    ),
                                                    if (_autoValidate &&
                                                        _validationErrors['lastName'] !=
                                                            null)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 4.w,
                                                              left: 4.w,
                                                            ),
                                                        child: Text(
                                                          _validationErrors['lastName']!,
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize:
                                                                AppSizes
                                                                    .fontSmall,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: AppSizes.paddingM,
                                                ),

                                                // Artist Name Field removed (only Listener role supported)

                                                // Phone Number Field
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                        bottom: 8.w,
                                                      ),
                                                      child: _buildFieldLabel(
                                                        'Phone Number',
                                                        false,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      key: _phoneFieldKey,
                                                      height:
                                                          AppSizes.inputHeight,
                                                      child: InputField(
                                                        controller:
                                                            phoneController,
                                                        hintText:
                                                            'Enter your phone number',
                                                        prefixIcon:
                                                            Icons
                                                                .phone_outlined,
                                                        keyboardType:
                                                            TextInputType.phone,
                                                        focusNode: _phoneFocus,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        onEditingComplete:
                                                            () =>
                                                                _fieldFocusChange(
                                                                  _phoneFocus,
                                                                  _emailFocus,
                                                                ),
                                                      ),
                                                    ),
                                                    if (_autoValidate &&
                                                        _validationErrors['phone'] !=
                                                            null)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 4.w,
                                                              left: 4.w,
                                                            ),
                                                        child: Text(
                                                          _validationErrors['phone']!,
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize:
                                                                AppSizes
                                                                    .fontSmall,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: AppSizes.paddingM,
                                                ),

                                                // Email Address Field
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                        bottom: 8.w,
                                                      ),
                                                      child: _buildFieldLabel(
                                                        'Email Address',
                                                        true,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      key: _emailFieldKey,
                                                      height:
                                                          AppSizes.inputHeight,
                                                      child: InputField(
                                                        controller:
                                                            emailController,
                                                        hintText:
                                                            'Enter your email address',
                                                        prefixIcon:
                                                            Icons
                                                                .email_outlined,
                                                        keyboardType:
                                                            TextInputType
                                                                .emailAddress,
                                                        focusNode: _emailFocus,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        onEditingComplete:
                                                            () =>
                                                                _fieldFocusChange(
                                                                  _emailFocus,
                                                                  _passwordFocus,
                                                                ),
                                                      ),
                                                    ),
                                                    if (_autoValidate &&
                                                        _validationErrors['email'] !=
                                                            null)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 4.w,
                                                              left: 4.w,
                                                            ),
                                                        child: Text(
                                                          _validationErrors['email']!,
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize:
                                                                AppSizes
                                                                    .fontSmall,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: AppSizes.paddingM,
                                                ),

                                                // Gender Dropdown Field
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                        bottom: 8.w,
                                                      ),
                                                      child: _buildFieldLabel(
                                                        'Gender',
                                                        false,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      key: _genderFieldKey,
                                                      height:
                                                          AppSizes.inputHeight,
                                                      child: GenderInputField(
                                                        value: _selectedGender,
                                                        onChanged: (value) {
                                                          if (mounted) {
                                                            setState(() {
                                                              _selectedGender =
                                                                  value;
                                                            });
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: AppSizes.paddingM,
                                                ),

                                                // Birthdate Field
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                        bottom: 8.w,
                                                      ),
                                                      child: _buildFieldLabel(
                                                        'Birthdate',
                                                        false,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          AppSizes.inputHeight,
                                                      child: DatePickerField(
                                                        selectedDate:
                                                            _selectedDate,
                                                        onDateSelected: (date) {
                                                          print(
                                                            "Date callback in signup.dart: $date",
                                                          ); // Debug print
                                                          if (mounted) {
                                                            setState(() {
                                                              _selectedDate =
                                                                  date;
                                                              print(
                                                                "_selectedDate updated to: $_selectedDate",
                                                              ); // Debug print
                                                            });
                                                          }
                                                        },
                                                        hintText:
                                                            'Select your birthdate',
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: AppSizes.paddingM,
                                                ),

                                                // Country Dropdown Field
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                        bottom: 8.w,
                                                      ),
                                                      child: _buildFieldLabel(
                                                        'Country',
                                                        false,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      key: _countryFieldKey,
                                                      height:
                                                          AppSizes.inputHeight,
                                                      child: CountryDropdownWithSearch(
                                                        value: _selectedCountry,
                                                        countries:
                                                            countries, // Pass the loaded countries
                                                        onChanged: (
                                                          Country? value,
                                                        ) {
                                                          setState(() {
                                                            _selectedCountry =
                                                                value;
                                                          });
                                                        },
                                                        hintText:
                                                            'Select your country',
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: AppSizes.paddingM,
                                                ),

                                                // Password Field
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                        bottom: 8.w,
                                                      ),
                                                      child: _buildFieldLabel(
                                                        'Password',
                                                        true,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      key: _passwordFieldKey,
                                                      height:
                                                          AppSizes.inputHeight,
                                                      child: PasswordInputField(
                                                        controller:
                                                            passwordController,
                                                        hintText:
                                                            'Create a password',
                                                        focusNode:
                                                            _passwordFocus,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        onEditingComplete:
                                                            () => _fieldFocusChange(
                                                              _passwordFocus,
                                                              _confirmPasswordFocus,
                                                            ),
                                                      ),
                                                    ),
                                                    if (_autoValidate &&
                                                        _validationErrors['password'] !=
                                                            null)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 4.w,
                                                              left: 4.w,
                                                            ),
                                                        child: Text(
                                                          _validationErrors['password']!,
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize:
                                                                AppSizes
                                                                    .fontSmall,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: AppSizes.paddingM,
                                                ),

                                                // Confirm Password Field
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                        left: 4.w,
                                                        bottom: 8.w,
                                                      ),
                                                      child: _buildFieldLabel(
                                                        'Confirm Password',
                                                        true,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      key:
                                                          _confirmPasswordFieldKey,
                                                      height:
                                                          AppSizes.inputHeight,
                                                      child: PasswordInputField(
                                                        controller:
                                                            confirmPasswordController,
                                                        hintText:
                                                            'Confirm your password',
                                                        focusNode:
                                                            _confirmPasswordFocus,
                                                        textInputAction:
                                                            TextInputAction
                                                                .done,
                                                        onSubmitted:
                                                            (_) =>
                                                                _confirmPasswordFocus
                                                                    .unfocus(),
                                                      ),
                                                    ),
                                                    if (_autoValidate &&
                                                        _validationErrors['confirmPassword'] !=
                                                            null)
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 4.w,
                                                              left: 4.w,
                                                            ),
                                                        child: Text(
                                                          _validationErrors['confirmPassword']!,
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize:
                                                                AppSizes
                                                                    .fontSmall,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: AppSizes.paddingM,
                                                ),

                                                // Terms and Conditions Checkbox
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 24.w,
                                                      height:
                                                          24.w, // Changed from .w to .w
                                                      child: Checkbox(
                                                        value: _termsAccepted,
                                                        activeColor:
                                                            appColors()
                                                                .primaryColorApp,
                                                        onChanged: (value) {
                                                          setState(() {
                                                            _termsAccepted =
                                                                value!;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Expanded(
                                                      child: RichText(
                                                        text: TextSpan(
                                                          style: TextStyle(
                                                            fontSize:
                                                                AppSizes
                                                                    .fontNormal,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            fontFamily:
                                                                'Poppins',
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                          children: [
                                                            TextSpan(
                                                              text:
                                                                  'I Accept all the ',
                                                            ),
                                                            WidgetSpan(
                                                              child: GestureDetector(
                                                                onTap: () {
                                                                  // Show Terms of Service for both user types
                                                                  if (list
                                                                      .isNotEmpty) {
                                                                    // Find the Terms document - usually index 0
                                                                    int
                                                                    termsIndex = list.indexWhere(
                                                                      (
                                                                        element,
                                                                      ) => element
                                                                          .title
                                                                          .contains(
                                                                            "Terms",
                                                                          ),
                                                                    );
                                                                    if (termsIndex >=
                                                                        0) {
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                          builder:
                                                                              (
                                                                                context,
                                                                              ) => PrivacyPolicyView(
                                                                                title:
                                                                                    list[termsIndex].title,
                                                                                htmlContent:
                                                                                    list[termsIndex].detail,
                                                                              ),
                                                                        ),
                                                                      );
                                                                    }
                                                                  }
                                                                },
                                                                child: Text(
                                                                  'Terms of Use',
                                                                  style: TextStyle(
                                                                    color:
                                                                        appColors()
                                                                            .primaryColorApp,
                                                                    fontSize:
                                                                        AppSizes
                                                                            .fontNormal,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text: ' and ',
                                                            ),
                                                            WidgetSpan(
                                                              child: GestureDetector(
                                                                onTap: () {
                                                                  // Show Privacy Policy for both user types
                                                                  if (list
                                                                      .isNotEmpty) {
                                                                    // Find the Privacy document - usually index 1
                                                                    int
                                                                    privacyIndex = list.indexWhere(
                                                                      (
                                                                        element,
                                                                      ) => element
                                                                          .title
                                                                          .contains(
                                                                            "Privacy",
                                                                          ),
                                                                    );
                                                                    if (privacyIndex >=
                                                                        0) {
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                          builder:
                                                                              (
                                                                                context,
                                                                              ) => PrivacyPolicyView(
                                                                                title:
                                                                                    list[privacyIndex].title,
                                                                                htmlContent:
                                                                                    list[privacyIndex].detail,
                                                                              ),
                                                                        ),
                                                                      );
                                                                    }
                                                                  }
                                                                },
                                                                child: Text(
                                                                  'Privacy Policy',
                                                                  style: TextStyle(
                                                                    color:
                                                                        appColors()
                                                                            .primaryColorApp,
                                                                    fontSize:
                                                                        AppSizes
                                                                            .fontNormal,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(
                                                  height: 16.w,
                                                ), // Changed from .w to .w
                                                // Create Account Button
                                                SizedBox(
                                                  height:
                                                      56.w, // Changed from .w to .w
                                                  child: ElevatedButton(
                                                    onPressed:
                                                        _isLoading
                                                            ? null
                                                            : _handleSignup,
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          appColors()
                                                              .primaryColorApp,
                                                      foregroundColor:
                                                          Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16.r,
                                                            ),
                                                      ),
                                                      elevation: 0,
                                                      disabledBackgroundColor:
                                                          appColors()
                                                              .primaryColorApp
                                                              .withOpacity(0.6),
                                                    ),
                                                    child:
                                                        _isLoading
                                                            ? SizedBox(
                                                              width: 24.w,
                                                              height:
                                                                  24.w, // Changed from .w to .w
                                                              child: CircularProgressIndicator(
                                                                valueColor:
                                                                    AlwaysStoppedAnimation<
                                                                      Color
                                                                    >(
                                                                      Colors
                                                                          .white,
                                                                    ),
                                                                strokeWidth:
                                                                    2.w,
                                                              ),
                                                            )
                                                            : Text(
                                                              _selectedRole ==
                                                                      'Artist'
                                                                  ? 'Create Artist Account'
                                                                  : 'Create Account',
                                                              style: TextStyle(
                                                                fontSize: 18.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontFamily:
                                                                    'Poppins',
                                                              ),
                                                            ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: 16.w,
                                                ), // Changed from .w to .w
                                                // Login Link
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      Resources.of(context)
                                                          .strings
                                                          .alreadyhaveanaccount,
                                                      style: TextStyle(
                                                        color:
                                                            appColors().black,
                                                        fontSize: 14.sp,
                                                        fontFamily: 'Poppins',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                      },
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 4,
                                                            ),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                      child: Text(
                                                        Resources.of(
                                                          context,
                                                        ).strings.loginhere,
                                                        style: TextStyle(
                                                          color:
                                                              appColors()
                                                                  .primaryColorApp,
                                                          fontSize: 14.sp,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontFamily: 'Poppins',
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
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
                    ],
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

  // Replace the existing DatePickerField with better debugging
  Widget DatePickerField({
    DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
    required String hintText,
  }) {
    print(
      "DatePickerField built with selectedDate: $selectedDate",
    ); // Debug print
    return CustomDatePicker(
      initialDate: selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      onDateSelected: (DateTime date) {
        print(
          "Date selected in DatePickerField callback: $date",
        ); // Debug print
        onDateSelected(date);
      },
      dateFormat: 'MMMM d, yyyy',
      primaryColor: appColors().primaryColorApp,
      backgroundColor: Colors.white,
      title: 'Select Birthdate',
      showTitle: true,
      confirmText: 'SELECT',
      cancelText: 'CANCEL',
      elevation: 0,
      borderRadius: BorderRadius.circular(16.r),
      hintText: hintText,
      minimumAge: 13,
    );
  }
}

class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Capitalize the first letter and keep the rest as is
    String formattedText =
        newValue.text[0].toUpperCase() + newValue.text.substring(1);

    return TextEditingValue(text: formattedText, selection: newValue.selection);
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
