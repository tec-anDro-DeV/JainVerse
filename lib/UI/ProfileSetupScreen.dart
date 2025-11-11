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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
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

  // Animation controllers
  late AnimationController _animationController;
  Animation<double> _fadeInAnimation = const AlwaysStoppedAnimation(1.0);
  Animation<Offset> _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);

  // Focus nodes
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  // Field keys for scrolling to invalid fields
  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _emailKey = GlobalKey();

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

    // Load countries
    _loadCountries();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
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

    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      // Scroll to name field
      _scrollToField(_nameKey);
      _showError('Name is required');
      return;
    }

    final nameError = Validators.validateName(
      _nameController.text.trim(),
      minLength: 2,
      maxLength: 30,
    );

    if (nameError != null) {
      _scrollToField(_nameKey);
      _showError(nameError);
      return;
    }

    // Name is a single field now (was first+last)

    // Validate email if provided
    if (_emailController.text.trim().isNotEmpty) {
      final emailError = Validators.validateEmail(_emailController.text.trim());
      if (emailError != null) {
        _scrollToField(_emailKey);
        _showError(emailError);
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Format the date if selected
      String? formattedDate;
      if (_selectedDate != null) {
        formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      }

      // Split name into fname and lname (first word -> fname, rest -> lname)
      final fullName = _nameController.text.trim();
      String? fname;
      String? lname;
      if (fullName.isNotEmpty) {
        final parts = fullName.split(RegExp(r"\s+"));
        if (parts.isNotEmpty) {
          fname = parts.first;
          if (parts.length > 1) {
            lname = parts.sublist(1).join(' ');
          }
        }
      }

      final success = await _authService.updateProfile(
        context,
        fname: fname,
        lname: (lname != null && lname.isNotEmpty) ? lname : null,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
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

                                  // Name (single field)
                                  _buildFieldLabel('Name', isRequired: true),
                                  SizedBox(height: 8.w),
                                  Container(
                                    key: _nameKey,
                                    child: InputField(
                                      controller: _nameController,
                                      hintText: 'Enter your full name',
                                      prefixIcon: Icons.person_outline,
                                      textInputAction: TextInputAction.next,
                                      focusNode: _nameFocus,
                                      onSubmitted: (_) => FocusScope.of(
                                        context,
                                      ).requestFocus(_emailFocus),
                                    ),
                                  ),
                                  SizedBox(height: 16.w),

                                  // Email
                                  _buildFieldLabel('Email', isRequired: false),
                                  SizedBox(height: 8.w),
                                  Container(
                                    key: _emailKey,
                                    child: InputField(
                                      controller: _emailController,
                                      hintText: 'Enter your email',
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: Icons.email_outlined,
                                      textInputAction: TextInputAction.next,
                                      focusNode: _emailFocus,
                                      onSubmitted: (_) =>
                                          FocusScope.of(context).unfocus(),
                                    ),
                                  ),
                                  SizedBox(height: 16.w),

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
