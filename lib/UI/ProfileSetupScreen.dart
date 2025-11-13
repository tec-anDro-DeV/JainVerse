import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/Model/CountryModel.dart';
import 'package:jainverse/Presenter/CountryPresenter.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/MainNavigation.dart';
import 'package:jainverse/services/phone_auth_service.dart';
import 'package:jainverse/utils/validators.dart';
import 'package:jainverse/widgets/auth/auth_header.dart';
import 'package:jainverse/widgets/common/country_dropdown_with_search.dart';
import 'package:jainverse/widgets/common/custom_date_picker.dart';
import 'package:jainverse/widgets/common/input_field.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String phoneNumber;

  const ProfileSetupScreen({super.key, required this.phoneNumber});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Services
  final PhoneAuthService _authService = PhoneAuthService();
  final CountryPresenter _countryPresenter = CountryPresenter();

  // State variables
  Country? _selectedCountry;
  DateTime? _selectedDate;
  int? _selectedGenderInt; // 0 = Male, 1 = Female
  bool _isLoading = false;
  List<Country> _countries = [];
  // Track when focus moved to a non-text widget so we can avoid
  // immediately returning focus to a text field after closing
  // a date picker / dropdown which briefly focused a non-text widget.
  DateTime? _lastNonTextFocusAt;

  // Animation controllers
  late AnimationController _animationController;
  Animation<double> _fadeInAnimation = const AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);

  // Focus nodes
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();

  // Field keys for scrolling to invalid fields
  final GlobalKey _firstNameKey = GlobalKey();
  final GlobalKey _lastNameKey = GlobalKey();

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Set the phone number (read-only)
    _phoneController.text = widget.phoneNumber;

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

    // Listen to focus changes so we can dismiss the keyboard when
    // focus moves to non-text widgets (like date pickers, dropdowns)
    FocusManager.instance.addListener(_handleFocusChange);

    // Load countries
    _loadCountries();
  }

  /// Hide the keyboard when focus changes to a non-text widget.
  ///
  /// We check the current primary focus's widget; if it's not an
  /// [EditableText] (the underlying widget for TextField), we hide
  /// the text input. This keeps the keyboard visible when moving
  /// between text fields but hides it when the user focuses a
  /// control that doesn't need typing.
  void _handleFocusChange() {
    try {
      final primary = FocusManager.instance.primaryFocus;
      // If there's no focus, ensure keyboard is hidden
      if (primary == null) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        _lastNonTextFocusAt = DateTime.now();
        return;
      }

      final widget = primary.context?.widget;
      // EditableText is the underlying widget for TextField/TextFormField
      if (widget is! EditableText) {
        // Focus moved to a non-text widget (like date picker controls)
        // Hide the keyboard and remember when this happened. Some
        // pickers briefly take focus and then return it to the field —
        // we'll prevent that quick return by clearing focus if it
        // happens within a short threshold.
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        _lastNonTextFocusAt = DateTime.now();
        return;
      }

      // If focus returned to an EditableText very shortly after being on
      // a non-text widget, it's likely from closing a picker — avoid
      // automatically re-showing the keyboard by unfocusing.
      if (_lastNonTextFocusAt != null) {
        final diff = DateTime.now().difference(_lastNonTextFocusAt!);
        if (diff.inMilliseconds < 700) {
          // Clear focus so the keyboard does not flash back.
          FocusManager.instance.primaryFocus?.unfocus();
          _lastNonTextFocusAt = null;
          SystemChannels.textInput.invokeMethod('TextInput.hide');
          return;
        }
        // If it's been longer than the threshold, allow normal behavior
        _lastNonTextFocusAt = null;
      }
    } catch (e) {
      // ignore any issues while trying to hide the keyboard
      // (for safety, do not crash the UI)
      // print('Focus change handler error: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  /// Load countries from API
  Future<void> _loadCountries() async {
    try {
      final loadedCountries = await _countryPresenter.getCountries(context);
      if (mounted) {
        setState(() {
          _countries = loadedCountries;
        });
      }
    } catch (e) {
      print('Error loading countries: $e');
    }
  }

  /// Validate and submit profile
  Future<void> _handleSubmitProfile() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Validate required fields: First name and last name are required
    if (_firstNameController.text.trim().isEmpty) {
      // Scroll to first name field
      _scrollToField(_firstNameKey);
      _showError('First name is required');
      return;
    }

    final firstNameError = Validators.validateName(
      _firstNameController.text.trim(),
      minLength: 2,
      maxLength: 30,
    );

    if (firstNameError != null) {
      _scrollToField(_firstNameKey);
      _showError(firstNameError);
      return;
    }

    // Last name required
    if (_lastNameController.text.trim().isEmpty) {
      _scrollToField(_lastNameKey);
      _showError('Last name is required');
      return;
    }

    final lastNameError = Validators.validateName(
      _lastNameController.text.trim(),
      minLength: 2,
      maxLength: 30,
    );

    if (lastNameError != null) {
      _scrollToField(_lastNameKey);
      _showError(lastNameError);
      return;
    }

    // Email removed from profile setup; skip email validation

    setState(() {
      _isLoading = true;
    });

    try {
      // Format the date if selected
      String? formattedDate;
      if (_selectedDate != null) {
        formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }

      // Use separate first and last name fields (both required)
      final fname = _firstNameController.text.trim();
      final lname = _lastNameController.text.trim();

      final success = await _authService.updateProfile(
        context,
        fname: fname,
        lname: lname,
        dob: formattedDate,
        countryId: _selectedCountry?.id,
        mobile: widget.phoneNumber,
        gender: _selectedGenderInt,
      );

      if (success && mounted) {
        // Navigate to main app
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainNavigationWrapper(initialIndex: 0),
          ),
          (Route<dynamic> route) => false,
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

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Scroll the form so the widget with [key] is visible
  void _scrollToField(GlobalKey key) {
    try {
      final currentContext = key.currentContext;
      if (currentContext != null) {
        Scrollable.ensureVisible(
          currentContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    } catch (e) {
      // ignore errors in scrolling
      print('Scroll error: $e');
    }
  }

  /// Build field label with optional indicator
  Widget _buildFieldLabel(String label, {required bool isRequired}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: const Color(0xFF555555),
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          fontFamily: 'Poppins',
        ),
        children: [
          TextSpan(text: label),
          if (isRequired)
            TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontSize: 14.sp),
            ),
          if (!isRequired)
            TextSpan(
              text: ' (Optional)',
              style: TextStyle(color: const Color(0xFF999999), fontSize: 12.sp),
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

    return Scaffold(
      backgroundColor: appColors().backgroundLogin,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 4.w,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Complete Your Profile",
                        style: TextStyle(
                          color: appColors().black,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
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
                            controller: _scrollController,
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
                                  // Info text
                                  Text(
                                    'Help us personalize your experience',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: const Color(0xFF777777),
                                      fontSize: 14.sp,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  SizedBox(height: 24.w),

                                  // First Name (required)
                                  _buildFieldLabel(
                                    'First Name',
                                    isRequired: true,
                                  ),
                                  SizedBox(height: 8.w),
                                  Container(
                                    key: _firstNameKey,
                                    child: InputField(
                                      controller: _firstNameController,
                                      hintText: 'Enter your first name',
                                      prefixIcon: Icons.person_outline,
                                      textInputAction: TextInputAction.next,
                                      focusNode: _firstNameFocus,
                                      onSubmitted: (_) => FocusScope.of(
                                        context,
                                      ).requestFocus(_lastNameFocus),
                                    ),
                                  ),
                                  SizedBox(height: 16.w),

                                  // Last Name (required)
                                  _buildFieldLabel(
                                    'Last Name',
                                    isRequired: true,
                                  ),
                                  SizedBox(height: 8.w),
                                  Container(
                                    key: _lastNameKey,
                                    child: InputField(
                                      controller: _lastNameController,
                                      hintText: 'Enter your last name',
                                      prefixIcon: Icons.person_outline,
                                      textInputAction: TextInputAction.next,
                                      focusNode: _lastNameFocus,
                                      onSubmitted: (_) =>
                                          FocusScope.of(context).unfocus(),
                                    ),
                                  ),
                                  SizedBox(height: 16.w),

                                  // Email field removed from setup screen

                                  // Phone (Read-only)
                                  _buildFieldLabel(
                                    'Phone Number',
                                    isRequired: true,
                                  ),
                                  SizedBox(height: 8.w),
                                  InputField(
                                    controller: _phoneController,
                                    hintText: 'Phone number',
                                    prefixIcon: Icons.phone_outlined,
                                    enabled: false,
                                  ),
                                  SizedBox(height: 16.w),

                                  // Date of Birth
                                  _buildFieldLabel(
                                    'Date of Birth',
                                    isRequired: false,
                                  ),
                                  SizedBox(height: 8.w),
                                  CustomDatePicker(
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                    onDateSelected: (date) {
                                      setState(() {
                                        _selectedDate = date;
                                      });
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
                                    hintText: 'Select your date of birth',
                                    minimumAge: 13,
                                  ),
                                  SizedBox(height: 16.w),

                                  // Gender
                                  _buildFieldLabel('Gender', isRequired: false),
                                  SizedBox(height: 8.w),
                                  GenderInputField(
                                    value: _selectedGenderInt,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedGenderInt = value;
                                      });
                                    },
                                  ),
                                  SizedBox(height: 16.w),

                                  // Country
                                  _buildFieldLabel(
                                    'Country',
                                    isRequired: false,
                                  ),
                                  SizedBox(height: 8.w),
                                  CountryDropdownWithSearch(
                                    countries: _countries,
                                    value: _selectedCountry,
                                    onChanged: (country) {
                                      setState(() {
                                        _selectedCountry = country;
                                      });
                                    },
                                    hintText: 'Select your country',
                                  ),
                                  SizedBox(height: 32.w),

                                  // Submit Button
                                  SizedBox(
                                    height: 56.w,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleSubmitProfile,
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
                                              'Complete Setup',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: AppSizes.fontMedium,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: 16.w),
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
