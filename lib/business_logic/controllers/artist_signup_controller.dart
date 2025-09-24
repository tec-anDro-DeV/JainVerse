import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:jainverse/data/repositories/artist_repository.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:intl/intl.dart';

enum ArtistSignUpState { initial, loading, loaded, error, success }

class ArtistSignUpController extends ChangeNotifier {
  final ArtistRepository _artistRepository;
  final SharedPref _sharedPref;

  ArtistSignUpController({
    ArtistRepository? artistRepository,
    SharedPref? sharedPref,
  }) : _artistRepository = artistRepository ?? ArtistRepositoryImpl(),
       _sharedPref = sharedPref ?? SharedPref();

  // State management
  ArtistSignUpState _state = ArtistSignUpState.initial;
  ArtistSignUpState get state => _state;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // User data
  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  ModelSettings? _settings;
  ModelSettings? get settings => _settings;

  String _token = '';
  String get token => _token;

  // Form data
  String _gender = 'Select';
  String get gender => _gender;

  String _dateOfBirth = '';
  String get dateOfBirth => _dateOfBirth;

  String _imagePresent = '';
  String get imagePresent => _imagePresent;

  bool _hasCustomImage = false;
  bool get hasCustomImage => _hasCustomImage;

  File? _selectedImage;
  File? get selectedImage => _selectedImage;

  bool _agreedToTerms = true;
  bool get agreedToTerms => _agreedToTerms;

  // Initialization
  Future<void> initialize() async {
    _setState(ArtistSignUpState.loading);

    try {
      // Get user data and token
      _userModel = await _sharedPref.getUserData();
      _token = await _sharedPref.getToken();

      // Set initial date of birth
      final DateTime dob = DateTime.now();
      final DateFormat formatter = DateFormat('yyyy-MM-dd');
      _dateOfBirth = formatter.format(dob);

      // Load settings and populate form
      await _loadSettings();

      // Set gender from user model
      if (_userModel?.data.gender.toString().contains('0') == true) {
        _gender = 'Male';
      } else {
        _gender = 'Female';
      }

      _setState(ArtistSignUpState.loaded);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(ArtistSignUpState.error);
    }
  }

  Future<void> _loadSettings() async {
    try {
      String? settingsJson = await _sharedPref.getSettings();
      if (settingsJson != null) {
        final parsed = Map<String, dynamic>.from(
          Map<String, dynamic>.from(await compute(_parseJson, settingsJson)),
        );
        _settings = ModelSettings.fromJson(parsed);

        if (_settings?.data.image.isNotEmpty == true) {
          _imagePresent =
              _settings!.data.image; // You might need to add base URL
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  static Map<String, dynamic> _parseJson(String jsonString) {
    return Map<String, dynamic>.from(
      Map<String, dynamic>.from(
        // Parse JSON in isolate
        {},
      ),
    );
  }

  // Form actions
  void setGender(String newGender) {
    _gender = newGender;
    notifyListeners();
  }

  void setDateOfBirth(String newDate) {
    _dateOfBirth = newDate;
    notifyListeners();
  }

  void setSelectedImage(File? image) {
    _selectedImage = image;
    _hasCustomImage = image != null;
    notifyListeners();
  }

  void setAgreedToTerms(bool agreed) {
    _agreedToTerms = agreed;
    notifyListeners();
  }

  // Image picker actions
  Future<void> pickImageFromCamera() async {
    // This will be handled by the UI layer and passed to setSelectedImage
    // The UI layer handles ImagePicker to avoid platform-specific code in business logic
  }

  Future<void> pickImageFromGallery() async {
    // This will be handled by the UI layer and passed to setSelectedImage
    // The UI layer handles ImagePicker to avoid platform-specific code in business logic
  }

  // Submit artist request
  Future<void> submitArtistRequest({
    required String firstName,
    required String lastName,
    required String mobile,
  }) async {
    if (!_agreedToTerms) {
      _errorMessage = 'Please agree to the terms and conditions';
      _setState(ArtistSignUpState.error);
      return;
    }

    _setState(ArtistSignUpState.loading);

    try {
      final result = await _artistRepository.submitArtistRequest(
        firstName: firstName,
        lastName: lastName,
        mobile: mobile,
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        token: _token,
        profileImage: _selectedImage,
      );

      if (result['success'] == true) {
        _setState(ArtistSignUpState.success);
      } else {
        _errorMessage = result['error'] ?? 'Failed to submit artist request';
        _setState(ArtistSignUpState.error);
      }
    } catch (e) {
      _errorMessage = e.toString();
      _setState(ArtistSignUpState.error);
    }
  }

  // Update profile (for image updates)
  Future<void> updateProfileImage() async {
    if (_selectedImage == null) return;

    _setState(ArtistSignUpState.loading);

    try {
      final result = await _artistRepository.updateProfile(
        token: _token,
        profileImage: _selectedImage,
      );

      if (result['success'] == true) {
        // Image updated successfully
        notifyListeners();
      } else {
        _errorMessage = result['error'] ?? 'Failed to update profile image';
        _setState(ArtistSignUpState.error);
      }
    } catch (e) {
      _errorMessage = e.toString();
      _setState(ArtistSignUpState.error);
    }
  }

  void _setState(ArtistSignUpState newState) {
    _state = newState;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    if (_state == ArtistSignUpState.error) {
      _setState(ArtistSignUpState.loaded);
    }
  }
}
