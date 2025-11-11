import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/utils/SharedPref.dart';

class PhoneAuthService {
  static const String baseUrl = 'https://musicvideo.techcronus.com/api/v2';
  final SharedPref _sharedPref = SharedPref();

  /// Request OTP for phone number
  /// Returns true if OTP was sent successfully
  Future<bool> requestOTP(BuildContext context, String mobile) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/request_mobile_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile': mobile}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == true) {
          _showToast(
            context,
            data['msg'] ?? 'OTP sent successfully',
            isError: false,
          );
          return true;
        } else {
          _showToast(
            context,
            data['msg'] ?? 'Failed to send OTP',
            isError: true,
          );
          return false;
        }
      } else {
        _showToast(context, 'Server error. Please try again.', isError: true);
        return false;
      }
    } catch (e) {
      print('Request OTP Error: $e');
      _showToast(
        context,
        'Network error. Please check your connection.',
        isError: true,
      );
      return false;
    }
  }

  /// Verify OTP and return authentication result
  /// Returns a map with keys: success, token, profileComplete, userData
  Future<Map<String, dynamic>> verifyOTP(
    BuildContext context,
    String mobile,
    String otp,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile': mobile, 'otp': otp}),
      );

      print('Verify OTP Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == true) {
          // Extract login_token
          final String? loginToken = data['login_token'];
          final bool profileComplete = data['profile_complete'] ?? false;

          if (loginToken != null && loginToken.isNotEmpty) {
            // Store the token securely
            await _sharedPref.setToken(loginToken);

            // Persist the full user response so getUserData() returns current user model
            try {
              await _sharedPref.setUserData(jsonEncode(data));

              // Also persist settings and theme if the API returned them
              try {
                // Common keys where settings might be present
                dynamic settingsCandidate;
                if (data.containsKey('settings')) {
                  settingsCandidate = data['settings'];
                } else if (data.containsKey('setting')) {
                  settingsCandidate = data['setting'];
                } else if (data.containsKey('data') &&
                    data['data'] is Map &&
                    data['data'].containsKey('settings')) {
                  settingsCandidate = data['data']['settings'];
                }

                if (settingsCandidate != null) {
                  // Ensure we persist a JSON string
                  final String settingsJson = settingsCandidate is String
                      ? settingsCandidate
                      : jsonEncode(settingsCandidate);
                  await _sharedPref.setSettingsData(settingsJson);
                  print('Saved settings from verifyOTP to SharedPref');
                }

                // Persist theme if present
                if (data.containsKey('theme')) {
                  final themeCandidate = data['theme'];
                  final String themeJson = themeCandidate is String
                      ? themeCandidate
                      : jsonEncode(themeCandidate);
                  await _sharedPref.setThemeData(themeJson);
                  print('Saved theme from verifyOTP to SharedPref');
                }
              } catch (e) {
                print('Error saving settings/theme after verifyOTP: $e');
              }
            } catch (e) {
              print('Error saving user data after verifyOTP: $e');
            }

            _showToast(
              context,
              data['msg'] ?? 'OTP verified successfully',
              isError: false,
            );

            return {
              'success': true,
              'token': loginToken,
              'profileComplete': profileComplete,
              'userData': data,
            };
          } else {
            _showToast(
              context,
              'Authentication failed. No token received.',
              isError: true,
            );
            return {'success': false};
          }
        } else {
          _showToast(context, data['msg'] ?? 'Invalid OTP', isError: true);
          return {'success': false};
        }
      } else {
        _showToast(context, 'Server error. Please try again.', isError: true);
        return {'success': false};
      }
    } catch (e) {
      print('Verify OTP Error: $e');
      _showToast(
        context,
        'Network error. Please check your connection.',
        isError: true,
      );
      return {'success': false};
    }
  }

  /// Update user profile
  /// Returns true if profile was updated successfully
  Future<bool> updateProfile(
    BuildContext context, {
    String? name,
    String? fname,
    String? lname,
    String? email,
    String? dob,
    String? country,
    int? countryId,
    String? mobile,
    int? gender,
  }) async {
    try {
      // Get the stored token
      final String token = await _sharedPref.getToken();

      if (token.isEmpty) {
        _showToast(
          context,
          'Authentication required. Please login again.',
          isError: true,
        );
        return false;
      }

      final Map<String, dynamic> body = {};

      // Prefer explicit fname/lname if provided, otherwise send 'name' for backward compatibility
      if (fname != null && fname.isNotEmpty) {
        body['fname'] = fname;
      }
      if (lname != null && lname.isNotEmpty) {
        body['lname'] = lname;
      }
      if ((fname == null || fname.isEmpty) &&
          (lname == null || lname.isEmpty)) {
        // fallback to generic name if provided
        if (name != null && name.isNotEmpty) body['name'] = name;
      }

      // Add optional fields if provided
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (dob != null && dob.isNotEmpty) body['dob'] = dob;
      // prefer country_id if available, otherwise send country name
      if (countryId != null) {
        body['country_id'] = countryId;
      } else if (country != null && country.isNotEmpty) {
        body['country'] = country;
      }
      if (mobile != null && mobile.isNotEmpty) body['mobile'] = mobile;
      if (gender != null) body['gender'] = gender;

      final response = await http.post(
        Uri.parse('$baseUrl/updateProfile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('Update Profile Response: ${response.statusCode}');
      print('Update Profile Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == true) {
          // Store updated user data
          await _sharedPref.setUserData(jsonEncode(data));

          _showToast(
            context,
            data['msg'] ?? 'Profile updated successfully',
            isError: false,
          );
          return true;
        } else {
          _showToast(
            context,
            data['msg'] ?? 'Failed to update profile',
            isError: true,
          );
          return false;
        }
      } else {
        _showToast(context, 'Server error. Please try again.', isError: true);
        return false;
      }
    } catch (e) {
      print('Update Profile Error: $e');
      _showToast(
        context,
        'Network error. Please check your connection.',
        isError: true,
      );
      return false;
    }
  }

  /// Helper method to show toast messages
  void _showToast(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      timeInSecForIosWeb: 2,
      backgroundColor: isError ? Colors.red : appColors().black,
      textColor: Colors.white,
      fontSize: AppSizes.fontNormal,
    );
  }
}
