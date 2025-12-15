import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image/image.dart' as img_pkg;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:jainverse/Model/CountryModel.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/CountryPresenter.dart';
import 'package:jainverse/Presenter/ProfilePresenter.dart';
import 'package:jainverse/Presenter/Logout.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/validators.dart';
import 'package:jainverse/widgets/common/app_header.dart';
import 'package:jainverse/widgets/common/country_dropdown_with_search.dart';
import 'package:jainverse/widgets/common/custom_date_picker.dart';
import 'package:jainverse/widgets/common/input_field.dart';
import 'package:jainverse/widgets/common/loader.dart';
import 'Login.dart';

class ProfileEdit extends StatefulWidget {
  const ProfileEdit({super.key});

  @override
  myState createState() {
    return myState();
  }
}

// Background isolate helper: accepts raw image bytes and returns flipped bytes
// This runs in an isolate via `compute` to avoid jank on the UI thread.
Future<List<int>> _flipImageBytes(Uint8List bytes) async {
  final img_pkg.Image? decoded = img_pkg.decodeImage(bytes);
  if (decoded == null) return bytes;
  final flipped = img_pkg.flipHorizontal(decoded);
  return img_pkg.encodeJpg(flipped, quality: 90);
}

class myState extends State<ProfileEdit> {
  TextEditingController passwordController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  // Replaced single name controller with separate first/last name controllers
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController birthdateController = TextEditingController();

  final picker = ImagePicker();
  bool has = false, presentImage = true;
  File? _tempSelectedImage; // Store temporarily selected image
  bool _imageChanged = false; // Track if image was changed
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  int? gender; // 0 = Male, 1 = Female, null = not selected
  Country? selectedCountry; // Changed to Country object
  String dateOfBirth = '';
  String imagePresent = '';
  String token = '';
  bool isOpen = false;
  bool _isLoading = false; // Add loading state

  // Add country-related variables
  List<Country> countries = []; // Dynamic country list
  CountryPresenter countryPresenter = CountryPresenter();
  int? _preferredCountryId;
  String? _preferredCountryLegacyValue;
  bool _handledInactiveAccount = false;

  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  // Form validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  // Separate keys for first and last name fields
  final GlobalKey _firstNameFieldKey = GlobalKey();
  final GlobalKey _lastNameFieldKey = GlobalKey();
  final GlobalKey _phoneFieldKey = GlobalKey();
  String? firstNameError;
  String? lastNameError;
  String? phoneError;
  late FocusNode firstNameFocusNode;
  late FocusNode lastNameFocusNode;
  late FocusNode phoneFocusNode;
  late ScrollController _scrollController;

  Future<dynamic> value() async {
    model = await sharePrefs.getUserData();
    token = await sharePrefs.getToken();
    await _applyUserPayload(_userDataToPayload(model.data));
    // Refresh profile from server when possible
    await _fetchProfileFromApi(token);

    setState(() {});
    return model;
  }

  @override
  void initState() {
    // Initialize scroll controller
    _scrollController = ScrollController();

    // Initialize focus nodes
    firstNameFocusNode = FocusNode();
    lastNameFocusNode = FocusNode();
    phoneFocusNode = FocusNode();

    // Initialize audio handler
    _audioHandler = const MyApp().called();

    // Load countries from API
    _loadCountries();

    // Add focus listeners for validation
    firstNameFocusNode.addListener(() {
      if (!firstNameFocusNode.hasFocus) {
        _validateFirstName();
      }
    });

    lastNameFocusNode.addListener(() {
      if (!lastNameFocusNode.hasFocus) {
        _validateLastName();
      }
    });

    phoneFocusNode.addListener(() {
      if (!phoneFocusNode.hasFocus) {
        _validatePhone();
      }
    });

    value();

    super.initState();
  }

  Future<void> _applyUserPayload(Map<String, dynamic>? payload) async {
    if (payload == null || payload.isEmpty) return;

    final dynamic statusRaw = payload['status'];
    if (statusRaw != null && statusRaw.toString() == '0') {
      await _handleInactiveAccount();
      return;
    }

    final bool canReplaceImage = !_imageChanged && !has;
    final String? resolvedImage = _resolveProfileImageUrl(payload);
    if (canReplaceImage) {
      if (resolvedImage != null && resolvedImage.isNotEmpty) {
        imagePresent = resolvedImage;
        presentImage = false;
      } else {
        imagePresent = '';
        presentImage = true;
      }
    } else if (resolvedImage != null && resolvedImage.isNotEmpty) {
      imagePresent = resolvedImage;
    }

    final String? combinedName = payload['name']?.toString();
    if (combinedName != null && combinedName.trim().isNotEmpty) {
      final parts = combinedName.trim().split(RegExp(r"\s+"));
      firstNameController.text = parts.isNotEmpty ? parts.first : '';
      lastNameController.text = parts.length > 1
          ? parts.sublist(1).join(' ')
          : '';
    } else {
      firstNameController.text = (payload['fname']?.toString() ?? '').trim();
      lastNameController.text = (payload['lname']?.toString() ?? '').trim();
    }

    mobileController.text = payload['mobile']?.toString() ?? '';
    phoneError = null;

    gender = _parseGenderValue(payload['gender']);

    final String? dobRaw = payload['dob']?.toString();
    if (dobRaw != null && dobRaw.trim().isNotEmpty) {
      try {
        final DateTime dobDate = DateTime.parse(dobRaw.trim());
        final DateFormat formatter = DateFormat('yyyy-MM-dd');
        final String formatted = formatter.format(dobDate);
        birthdateController.text = formatted;
        dateOfBirth = formatted;
      } catch (e) {
        if (kDebugMode) print('Error parsing dob: $e');
        birthdateController.text = 'Select Birthdate';
        dateOfBirth = 'Select Birthdate';
      }
    } else {
      birthdateController.text = 'Select Birthdate';
      dateOfBirth = 'Select Birthdate';
    }

    _preferredCountryId = _extractCountryId(payload);
    _preferredCountryLegacyValue = _extractCountryLegacyValue(payload);
    _applyCountrySelection();

    if (mounted) setState(() {});
  }

  Map<String, dynamic> _userDataToPayload(UserData data) {
    return {
      'id': data.id,
      'name': data.name,
      'fname': data.fname,
      'lname': data.lname,
      'mobile': data.mobile,
      'gender': data.gender,
      'dob': data.dob,
      'image': data.image,
      'artist_verify_status': data.artist_verify_status,
      'status': 1,
    };
  }

  String? _resolveProfileImageUrl(Map<String, dynamic> payload) {
    final dynamic url = payload['image_url'];
    if (url is String && url.isNotEmpty) return url;

    final dynamic image = payload['image'];
    if (image is String && image.isNotEmpty) {
      return image.startsWith('http') ? image : AppConstant.ImageUrl + image;
    }
    return null;
  }

  int? _parseGenderValue(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      return (raw == 0 || raw == 1) ? raw : null;
    }
    final String trimmed = raw.toString().trim();
    if (trimmed.isEmpty) return null;
    final int? numeric = int.tryParse(trimmed);
    if (numeric != null) {
      return (numeric == 0 || numeric == 1) ? numeric : null;
    }
    final String lowered = trimmed.toLowerCase();
    if (lowered == 'male') return 0;
    if (lowered == 'female') return 1;
    return null;
  }

  int? _extractCountryId(Map<String, dynamic> payload) {
    final dynamic numeric = payload['country_id_numeric'];
    final int? parsedNumeric = _tryParseInt(numeric);
    if (parsedNumeric != null) return parsedNumeric;

    final dynamic fallback = payload['country_id'];
    return _tryParseInt(fallback);
  }

  String? _extractCountryLegacyValue(Map<String, dynamic> payload) {
    final dynamic value = payload['country_id'];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.toLowerCase() == 'select country') return null;
      if (_tryParseInt(trimmed) != null) return null;
      return trimmed;
    }
    return null;
  }

  int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    final String parsed = value.toString().trim();
    if (parsed.isEmpty) return null;
    return int.tryParse(parsed);
  }

  void _applyCountrySelection() {
    if (countries.isEmpty) return;

    Country? resolved;
    if (_preferredCountryId != null) {
      resolved = countryPresenter.findCountryById(
        countries,
        _preferredCountryId!,
      );
    }

    if (resolved == null &&
        _preferredCountryLegacyValue != null &&
        _preferredCountryLegacyValue!.isNotEmpty) {
      resolved = countryPresenter.findCountryByOldValue(
        countries,
        _preferredCountryLegacyValue!,
      );
    }

    if (resolved != null && resolved != selectedCountry) {
      if (!mounted) return;
      setState(() {
        selectedCountry = resolved;
      });
    }
  }

  Future<void> _handleInactiveAccount() async {
    if (_handledInactiveAccount) return;
    _handledInactiveAccount = true;

    await sharePrefs.removeValues();
    has = false;
    _tempSelectedImage = null;
    _imageChanged = false;

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (BuildContext context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );

    try {
      await Logout().logout(context, token);
    } catch (_) {}
  }

  // Load countries from API and handle backward compatibility
  Future<void> _loadCountries() async {
    try {
      final loadedCountries = await countryPresenter.getCountries(context);
      setState(() {
        countries = loadedCountries;
      });

      _applyCountrySelection();
    } catch (e) {
      print('Error loading countries: $e');
    }
  }

  /// Fetch profile data from server and merge into local fields used by the
  /// profile edit screen. This keeps the edit form in sync with server data.
  Future<void> _fetchProfileFromApi(String token) async {
    if (token.isEmpty) return;
    try {
      final uri = Uri.parse('${AppConstant.BaseUrl}my_profile');
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 200) {
        final Map<String, dynamic> jsonResp = json.decode(resp.body);
        final dynamic data = jsonResp['data'] ?? jsonResp;
        Map<String, dynamic>? userPayload;
        if (data is Map<String, dynamic>) {
          final dynamic possibleUser = data['user'];
          if (possibleUser is Map<String, dynamic>) {
            userPayload = possibleUser;
          } else {
            userPayload = data;
          }
        }

        if (userPayload != null) {
          await _applyUserPayload(userPayload);
        }
      } else {
        if (kDebugMode) print('my_profile returned ${resp.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to fetch profile: $e');
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Dispose controllers and focus nodes
    _scrollController.dispose();
    firstNameFocusNode.dispose();
    lastNameFocusNode.dispose();
    phoneFocusNode.dispose();

    super.dispose();
  }

  void showPickDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            // reduced corner radius for the image source dialog
            borderRadius: BorderRadius.circular(8.w),
          ),
          child: Container(
            padding: EdgeInsets.all(AppSizes.paddingM),
            height: 200.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: AppSizes.fontMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSizes.paddingM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      'Camera',
                      Icons.camera_alt,
                      () => _imgFromCamera(ctx),
                    ),
                    _buildImageSourceOption(
                      'Gallery',
                      Icons.photo_library,
                      () => _openGallery(ctx),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
              color: appColors().gray[100],
              borderRadius: BorderRadius.circular(15.w),
            ),
            child: Icon(icon, size: 30.w, color: Colors.grey[700]),
          ),
          SizedBox(height: 8.w),
          Text(title, style: TextStyle(fontSize: AppSizes.fontSmall)),
        ],
      ),
    );
  }

  _imgFromCamera(BuildContext dialogContext) async {
    // Close the dialog first to avoid presenting native pickers/croppers on top
    try {
      Navigator.of(dialogContext).pop();
    } catch (_) {
      // ignore if already popped
    }

    // Small delay to ensure dialog is dismissed before launching native UI
    await Future.delayed(Duration(milliseconds: 200));

    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (pickedFile == null) return;

      final File file = File(pickedFile.path);

      // Launch native cropper and require a 1:1 square crop
      final File? cropped = await _cropImage(file);

      // FIX: Wait for FlutterSurfaceView to stabilize after UCrop closes
      await Future.delayed(const Duration(milliseconds: 500));

      if (cropped != null) {
        // Show preview with Flip option before applying
        final File? finalFile = await _showFlipPreview(cropped);
        if (finalFile != null) {
          _tempSelectedImage = finalFile;
          _imageChanged = true;
          has = true;
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      log('Error picking/cropping image from camera: $e');
    }
  }

  _openGallery(BuildContext dialogContext) async {
    // Close the dialog first to avoid presenting native pickers/croppers on top
    try {
      Navigator.of(dialogContext).pop();
    } catch (_) {
      // ignore if already popped
    }

    // Small delay to ensure dialog is dismissed before launching native UI
    await Future.delayed(Duration(milliseconds: 200));

    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile == null) return;

      final File file = File(pickedFile.path);

      // Launch native cropper and require a 1:1 square crop
      final File? cropped = await _cropImage(file);

      // FIX: Wait for FlutterSurfaceView to stabilize after UCrop closes
      await Future.delayed(const Duration(milliseconds: 500));

      if (cropped != null) {
        // Show preview with Flip option before applying
        final File? finalFile = await _showFlipPreview(cropped);
        if (finalFile != null) {
          _tempSelectedImage = finalFile;
          _imageChanged = true;
          has = true;
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      log('Error picking/cropping image from gallery: $e');
    }
  }

  // Crop image to a square (1:1) using the native UI provided by image_cropper
  Future<File?> _cropImage(File imageFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Photo',
            toolbarColor: appColors().primaryColorApp,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Edit Photo', aspectRatioLockEnabled: true),
        ],
        compressQuality: 100,
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
    } catch (e) {
      // If cropping fails, log and return the original file as a fallback
      log('Image cropping failed: $e');
    }
    return null;
  }

  // Show a preview dialog with a Flip toggle so user can flip horizontally before confirming
  Future<File?> _showFlipPreview(File imageFile) async {
    try {
      final Uint8List originalBytes = await imageFile.readAsBytes();
      Uint8List previewBytes = originalBytes;
      bool isFlipped = false;
      bool isProcessing = false;

      final File? result = await showDialog<File?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx2, setStateDialog) {
              return AlertDialog(
                insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  // reduced corner radius for the flip preview dialog
                  borderRadius: BorderRadius.circular(8.w),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image preview area with a subtle rounded border
                    Container(
                      padding: EdgeInsets.all(12.w),
                      constraints: BoxConstraints(
                        maxHeight: 420.w,
                        maxWidth: MediaQuery.of(context).size.width * 0.9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        // reduced corner radius for preview container
                        borderRadius: BorderRadius.circular(8.w),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.memory(previewBytes, fit: BoxFit.contain),
                          if (isProcessing)
                            Container(
                              color: Colors.black.withOpacity(0.35),
                              child: Center(
                                child: SizedBox(
                                  width: 48.w,
                                  height: 48.w,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.w),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Row(
                        children: [
                          // Flip / Unflip button with icon (primary color)
                          OutlinedButton.icon(
                            onPressed: () async {
                              if (isProcessing) return;
                              setStateDialog(() {
                                isProcessing = true;
                              });
                              try {
                                if (!isFlipped) {
                                  final List<int> flipped = await compute(
                                    _flipImageBytes,
                                    originalBytes,
                                  );
                                  previewBytes = Uint8List.fromList(flipped);
                                  setStateDialog(() {
                                    isFlipped = true;
                                  });
                                } else {
                                  previewBytes = originalBytes;
                                  setStateDialog(() {
                                    isFlipped = false;
                                  });
                                }
                              } catch (e) {
                                log('Flip failed: $e');
                              } finally {
                                setStateDialog(() {
                                  isProcessing = false;
                                });
                              }
                            },
                            icon: Icon(
                              isFlipped ? Icons.repeat : Icons.flip,
                              size: 18.w,
                              color: appColors().primaryColorApp,
                            ),
                            label: Text(
                              isFlipped ? 'Unflip' : 'Flip',
                              style: TextStyle(
                                color: appColors().primaryColorApp,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: appColors().primaryColorApp,
                                width: 1,
                              ),
                              foregroundColor: appColors().primaryColorApp,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.w,
                              ),
                            ),
                          ),
                          // Horizontal spacing between Flip button and the rest
                          SizedBox(width: 12.w),
                          Spacer(),
                          TextButton(
                            onPressed: isProcessing
                                ? null
                                : () => Navigator.of(ctx2).pop(null),
                            style: TextButton.styleFrom(
                              foregroundColor: appColors().primaryColorApp,
                            ),
                            child: Text('Cancel'),
                          ),
                          SizedBox(width: 8.w),
                          ElevatedButton(
                            onPressed: isProcessing
                                ? null
                                : () async {
                                    if (!listEquals(
                                      previewBytes,
                                      originalBytes,
                                    )) {
                                      await imageFile.writeAsBytes(
                                        previewBytes,
                                      );
                                    }
                                    Navigator.of(ctx2).pop(imageFile);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appColors().primaryColorApp,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.w,
                              ),
                              child: Text(
                                'Confirm',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Add vertical spacing below the action row so buttons don't sit flush to dialog bottom
                    SizedBox(height: 12.w),
                  ],
                ),
              );
            },
          );
        },
      );

      return result;
    } catch (e) {
      log('Error in flip preview: $e');
      return imageFile;
    }
  }

  // Helper method to get profile image child widget (icon when no image)
  Widget? _getProfileImageChild() {
    if (has && _tempSelectedImage != null) {
      return null; // Image is shown, no child needed
    } else if (!presentImage && imagePresent.isNotEmpty) {
      return null; // Network image is shown, no child needed
    }
    // Show person icon as placeholder
    return Icon(Icons.person, size: 60.w, color: appColors().primaryColorApp);
  }

  // Helper method to get profile image decoration (used for the circular avatar)
  DecorationImage? _getProfileImage() {
    if (has && _tempSelectedImage != null) {
      // Show selected image from camera/gallery
      return DecorationImage(
        image: FileImage(_tempSelectedImage!),
        fit: BoxFit.cover,
      );
    } else if (!presentImage && imagePresent.isNotEmpty) {
      // Show network image from server
      return DecorationImage(
        image: NetworkImage(imagePresent),
        fit: BoxFit.cover,
      );
    }
    return null; // No image, show placeholder
  }

  // Validation methods
  void _validateFirstName() {
    final value = firstNameController.text.trim();
    String? error;
    if (value.isEmpty) {
      error = 'Please enter first name';
    } else {
      // Fall back to shared validator for other rules (length, chars)
      error = Validators.validateName(value, fieldName: 'First Name');
    }
    if (firstNameError != error) {
      setState(() {
        firstNameError = error;
      });
    }
  }

  void _validateLastName() {
    final value = lastNameController.text.trim();
    String? error;
    if (value.isEmpty) {
      error = 'Please enter last name';
    } else {
      // Use shared validator for other constraints
      error = Validators.validateName(value, fieldName: 'Last Name');
    }
    if (lastNameError != error) {
      setState(() {
        lastNameError = error;
      });
    }
  }

  void _validatePhone() {
    final error = Validators.validatePhone(mobileController.text);
    if (phoneError != error) {
      setState(() {
        phoneError = error;
      });
    }
  }

  bool _validateForm() {
    // Validate both first and last names. Phone is non-editable.
    _validateFirstName();
    _validateLastName();

    // Ensure both fields are present (cannot be blank)
    if (firstNameController.text.trim().isEmpty) {
      _validateFirstName();
      _scrollToField(_firstNameFieldKey, firstNameFocusNode);
      return false;
    }

    if (lastNameController.text.trim().isEmpty) {
      _validateLastName();
      _scrollToField(_lastNameFieldKey, lastNameFocusNode);
      return false;
    }

    if (firstNameError != null) {
      _scrollToField(_firstNameFieldKey, firstNameFocusNode);
      return false;
    }

    if (lastNameError != null) {
      _scrollToField(_lastNameFieldKey, lastNameFocusNode);
      return false;
    }

    return true;
  }

  void _scrollToField(GlobalKey fieldKey, FocusNode focusNode) {
    // Focus on the field with error
    focusNode.requestFocus();

    // Scroll to the field using ensureVisible for accurate positioning
    Future.delayed(Duration(milliseconds: 100), () {
      if (fieldKey.currentContext != null) {
        Scrollable.ensureVisible(
          fieldKey.currentContext!,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1, // Show field near top of view
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If keyboard is visible, close the keyboard instead of popping
        // the route. This prevents keyboards that send a back/dismiss
        // event (some Android keyboards) from closing the screen.
        if (MediaQuery.of(context).viewInsets.bottom > 0) {
          FocusScope.of(context).unfocus();
          return false; // don't pop
        }

        // Otherwise, allow pop only when not loading
        return !_isLoading;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Column(
              children: [
                AppHeader(
                  title: 'Profile',
                  showBackButton:
                      !_isLoading, // Disable back button during loading
                  showProfileIcon: false,
                  onBackPressed: () => Navigator.of(context).pop(),
                ),
                // Add vertical spacing to maintain layout
                SizedBox(height: 8.0),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      // Dismiss keyboard when tapping outside input fields
                      FocusScope.of(context).unfocus();
                    },
                    child: StreamBuilder<MediaItem?>(
                      stream: _audioHandler?.mediaItem,
                      builder: (context, snapshot) {
                        // Calculate proper bottom padding accounting for mini player and navigation
                        final bottomPadding = AppPadding.bottom(
                          context,
                          extra: 100.w,
                        );
                        return SingleChildScrollView(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            AppSizes.paddingM,
                            0,
                            AppSizes.paddingM,
                            bottomPadding,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Profile Image Section
                                Center(
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 120.w,
                                        height: 120.w,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: appColors().primaryColorApp
                                              .withOpacity(0.3),
                                          image: _getProfileImage(),
                                        ),
                                        child: _getProfileImageChild(),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () => showPickDialog(context),
                                          child: Container(
                                            padding: EdgeInsets.all(8.w),
                                            decoration: BoxDecoration(
                                              color:
                                                  appColors().primaryColorApp,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 16.w,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12.w),
                                Text(
                                  'Change Photo',
                                  style: TextStyle(
                                    color: appColors().primaryColorApp,
                                    fontSize: AppSizes.fontNormal,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 30.w),

                                // Form Fields
                                // First Name Section
                                Column(
                                  key: _firstNameFieldKey,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 4.w,
                                        bottom: 8.w,
                                      ),
                                      child: Text(
                                        'First Name',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontNormal,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: firstNameError != null
                                          ? 90.w
                                          : AppSizes.inputHeight,
                                      child: InputField(
                                        controller: firstNameController,
                                        hintText: 'Enter first name',
                                        prefixIcon: Icons.person_outline,
                                        errorText: firstNameError,
                                        focusNode: firstNameFocusNode,
                                        onChanged: (value) =>
                                            _validateFirstName(),
                                      ),
                                    ),
                                    if (firstNameError != null)
                                      SizedBox(height: 8.w),
                                  ],
                                ),

                                SizedBox(height: AppSizes.paddingM / 2),

                                // Last Name Section
                                Column(
                                  key: _lastNameFieldKey,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 4.w,
                                        bottom: 8.w,
                                      ),
                                      child: Text(
                                        'Last Name',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontNormal,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: lastNameError != null
                                          ? 90.w
                                          : AppSizes.inputHeight,
                                      child: InputField(
                                        controller: lastNameController,
                                        hintText: 'Enter last name',
                                        prefixIcon: Icons.person_outline,
                                        errorText: lastNameError,
                                        focusNode: lastNameFocusNode,
                                        onChanged: (value) =>
                                            _validateLastName(),
                                      ),
                                    ),
                                    if (lastNameError != null)
                                      SizedBox(height: 8.w),
                                  ],
                                ),

                                SizedBox(height: AppSizes.paddingM),

                                // Phone Number Section
                                Column(
                                  key: _phoneFieldKey,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 4.w,
                                        bottom: 8.w,
                                      ),
                                      child: Text(
                                        'Phone Number',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontNormal,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: phoneError != null
                                          ? 90.w
                                          : AppSizes.inputHeight,
                                      child: InputField(
                                        controller: mobileController,
                                        hintText: 'Phone number',
                                        prefixIcon: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                        maxLength: 20,
                                        errorText: null,
                                        focusNode: phoneFocusNode,
                                        enabled: false,
                                      ),
                                    ),
                                    // Add some space after error text
                                    if (phoneError != null)
                                      SizedBox(height: 8.w),
                                  ],
                                ),

                                SizedBox(height: AppSizes.paddingM),

                                // Email field removed from profile edit

                                // Gender Section
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 4.w,
                                        bottom: 8.w,
                                      ),
                                      child: Text(
                                        'Gender',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontNormal,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: AppSizes.inputHeight,
                                      child: GenderInputField(
                                        value: gender,
                                        onChanged: (int? newValue) {
                                          setState(() {
                                            gender = newValue;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: AppSizes.paddingM),

                                // Custom Date Picker for Birthdate
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 4.w,
                                        bottom: 8.w,
                                      ),
                                      child: Text(
                                        'Birthdate',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontNormal,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: AppSizes.inputHeight,
                                      child: CustomDatePicker(
                                        key: ValueKey(
                                          dateOfBirth,
                                        ), // Force rebuild when dateOfBirth changes
                                        initialDate: () {
                                          print(
                                            'dateOfBirth value: "$dateOfBirth"',
                                          );
                                          if (dateOfBirth.isNotEmpty &&
                                              dateOfBirth !=
                                                  'Select Birthdate') {
                                            final parsedDate =
                                                DateTime.tryParse(dateOfBirth);
                                            print(
                                              'Parsed date for CustomDatePicker: $parsedDate',
                                            );
                                            return parsedDate;
                                          }
                                          print(
                                            'No valid date, returning null',
                                          );
                                          return null;
                                        }(),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime.now(),
                                        onDateSelected: (date) {
                                          final formatter = DateFormat(
                                            'yyyy-MM-dd',
                                          );
                                          final formattedDate = formatter
                                              .format(date);

                                          log(
                                            '📅 Date picker callback triggered',
                                          );
                                          log('📅 Selected date: $date');
                                          log(
                                            '📅 Formatted date: $formattedDate',
                                          );
                                          log(
                                            '📅 Previous dateOfBirth: "$dateOfBirth"',
                                          );

                                          birthdateController.text =
                                              formattedDate;
                                          dateOfBirth = formattedDate;

                                          setState(() {
                                            dateOfBirth = formattedDate;
                                          });

                                          log(
                                            '📅 Updated dateOfBirth: "$dateOfBirth"',
                                          );
                                        },
                                        dateFormat: 'MMMM d, yyyy',
                                        primaryColor:
                                            appColors().primaryColorApp,
                                        backgroundColor: Colors.white,
                                        title: 'Select Birthdate',
                                        showTitle: true,
                                        confirmText: 'SELECT',
                                        cancelText: 'CANCEL',
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        hintText: 'Select your birthdate',
                                        minimumAge:
                                            13, // Only allow users 13 years and older
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: AppSizes.paddingM),

                                // Country Section
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 4.w,
                                        bottom: 8.w,
                                      ),
                                      child: Text(
                                        'Country',
                                        style: TextStyle(
                                          fontSize: AppSizes.fontNormal,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: AppSizes.inputHeight,
                                      child: CountryDropdownWithSearch(
                                        value: selectedCountry,
                                        countries:
                                            countries, // Pass the loaded countries
                                        onChanged: (Country? newValue) {
                                          setState(() {
                                            selectedCountry = newValue;
                                          });
                                        },
                                        hintText: 'Select your country',
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 30.w),

                                // Save Button
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: AppSizes.inputHeight,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              // Close keyboard first
                                              FocusScope.of(context).unfocus();

                                              // Validate form before proceeding
                                              if (!_validateForm()) {
                                                return; // _validateForm() already handles scrolling to error field
                                              }

                                              // Debug the selectedCountry value before sending
                                              log(
                                                '🏳️ DEBUG: selectedCountry value = "$selectedCountry"',
                                              );
                                              log(
                                                '🏳️ DEBUG: selectedCountry isEmpty = ${selectedCountry == null}',
                                              );
                                              log(
                                                '🏳️ DEBUG: selectedCountry == "Select Country" = ${selectedCountry?.nicename == "Select Country"}',
                                              );

                                              // Debug date values
                                              log(
                                                '📅 DEBUG: dateOfBirth value = "$dateOfBirth"',
                                              );
                                              log(
                                                '📅 DEBUG: birthdateController.text = "${birthdateController.text}"',
                                              );

                                              // Show loading state with loader widget
                                              setState(() {
                                                _isLoading = true;
                                              });

                                              try {
                                                // Make a single API call with both profile data and image
                                                await ProfilePresenter().getProfileUpdate(
                                                  context,
                                                  _imageChanged
                                                      ? _tempSelectedImage
                                                      : null,
                                                  // Combine first and last name for API
                                                  '${firstNameController.text} ${lastNameController.text}'
                                                      .trim(),
                                                  passwordController.text,
                                                  mobileController.text,
                                                  dateOfBirth,
                                                  gender,
                                                  selectedCountry?.id
                                                          .toString() ??
                                                      '', // Send country ID as string
                                                  token,
                                                  false,
                                                );

                                                // Reset image change tracking after successful save
                                                _imageChanged = false;
                                                _tempSelectedImage = null;

                                                // Small delay to show success message
                                                await Future.delayed(
                                                  Duration(milliseconds: 500),
                                                );

                                                // Hide loading state before navigation
                                                if (mounted) {
                                                  setState(() {
                                                    _isLoading = false;
                                                  });

                                                  // Navigate back to AccountPage after successful update
                                                  // Return `true` so calling page can refresh immediately.
                                                  Navigator.pop(context, true);
                                                }
                                              } catch (e) {
                                                // Hide loading state on error
                                                if (mounted) {
                                                  setState(() {
                                                    _isLoading = false;
                                                  });
                                                }

                                                // Handle any errors that might occur during the update
                                                log(
                                                  '❌ Error updating profile: $e',
                                                );
                                                // The ProfilePresenter already handles showing error toasts,
                                                // so we don't need to show additional error messages here
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            appColors().primaryColorApp,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.borderRadius,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 20.w,
                                                  height: 20.w,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                ),
                                                SizedBox(width: 12.w),
                                                Text(
                                                  'Updating...',
                                                  style: TextStyle(
                                                    fontSize:
                                                        AppSizes.fontMedium,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              'Save',
                                              style: TextStyle(
                                                fontSize: AppSizes.fontMedium,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ], // <-- Added missing closing bracket for Column children
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            // Loader overlay positioned as second child of Stack
            if (_isLoading) LoaderOverlay(message: 'Updating profile...'),
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
