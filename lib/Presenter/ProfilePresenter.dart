import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

import 'AppSettingsPresenter.dart';

class ProfilePresenter {
  late final Dio _dio;

  ProfilePresenter() {
    _dio = Dio();
    // Configure timeout settings - INCREASED to fix timeout issue
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  SharedPref sharePrefs = SharedPref();

  Future<void> getProfileUpdate(
    BuildContext context,
    File? imageFile,
    String name,
    String pass,
    String mbl,
    String dob,
    int? gender,
    String countryId,
    String token,
    bool artist,
  ) async {
    // Create FormData that can handle both image and profile data
    Map<String, dynamic> formDataMap = {};

    // Add profile data if provided
    if (name.isNotEmpty) {
      formDataMap[AppConstant.name] = name;
    }
    if (mbl.isNotEmpty) {
      formDataMap[AppConstant.mobile] = mbl;
    }
    if (pass.isNotEmpty) {
      formDataMap[AppConstant.password] = pass;
    }
    // Add gender only when provided (0 or 1)
    if (gender != null) {
      formDataMap[AppConstant.gender] = gender;
    }
    if (dob.isNotEmpty && dob != 'Select Birthdate') {
      formDataMap[AppConstant.dob] = dob;
    }
    if (countryId.isNotEmpty && countryId != 'Select Country') {
      log('✅ Adding country_id to FormData: "$countryId"');
      formDataMap[AppConstant.country] = countryId;
    } else {
      log(
        '❌ NOT adding country_id. Value: "$countryId", isEmpty: ${countryId.isEmpty}, isSelectCountry: ${countryId == 'Select Country'}',
      );
    }

    // Add image if provided
    if (imageFile != null &&
        imageFile.path.isNotEmpty &&
        imageFile.existsSync()) {
      formDataMap[AppConstant.image] = await MultipartFile.fromFile(
        imageFile.path,
        filename: 'profile_image.jpg',
      );
    }

    FormData formData = FormData.fromMap(formDataMap);

    // Debug logging
    log('=====================================');
    log('🔥 PROFILE UPDATE REQUEST STARTED 🔥');
    log('=====================================');
    log('URL: ${AppConstant.BaseUrl + AppConstant.API_UPDATE_PROFILE}');
    log('Token: ${token.substring(0, 20)}...');

    // Log the actual FormData being sent to API
    log('📦 FORM DATA BEING SENT TO API:');
    log('-------------------------------------');

    // Debug the original parameters first
    log('📝 ORIGINAL PARAMETERS:');
    log('Name: "$name" (isEmpty: ${name.isEmpty})');
    log('Mobile: "$mbl" (isEmpty: ${mbl.isEmpty})');
    log('DOB: "$dob" (isEmpty: ${dob.isEmpty})');
    log('Gender: ${gender == null ? "<null>" : gender}');
    log('Country: "$countryId" (isEmpty: ${countryId.isEmpty})');
    log(
      'Password: "${pass.isNotEmpty ? "[SET]" : "[EMPTY]"}" (isEmpty: ${pass.isEmpty})',
    );

    // Debug the formDataMap before creating FormData
    log('📋 FORM DATA MAP CONTENTS:');
    if (formDataMap.isEmpty) {
      log('⚠️ WARNING: formDataMap is EMPTY!');
    } else {
      formDataMap.forEach((key, value) {
        if (value is MultipartFile) {
          log(
            'Map Entry: $key = MultipartFile(${value.filename}, ${value.length} bytes)',
          );
        } else {
          log('Map Entry: $key = "$value"');
        }
      });
    }

    for (var field in formData.fields) {
      log('Field: ${field.key} = ${field.value}');
    }

    for (var file in formData.files) {
      log(
        'File: ${file.key} = ${file.value.filename} (${file.value.length} bytes)',
      );
    }

    if (formData.fields.isEmpty && formData.files.isEmpty) {
      log('⚠️ WARNING: No data to send!');
    }
    log('-------------------------------------');

    if (imageFile != null && imageFile.path.isNotEmpty) {
      log('📸 ALSO UPDATING IMAGE:');
      log('Image path: ${imageFile.path}');
      log('File exists: ${imageFile.existsSync()}');
      if (imageFile.existsSync()) {
        log('File size: ${imageFile.lengthSync()} bytes');
      }
    } else {
      log('📸 NO IMAGE TO UPDATE');
    }
    log('=====================================');

    try {
      Response<String> response = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_UPDATE_PROFILE,
        data: formData,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
          validateStatus: (status) {
            // Accept all status codes to handle them manually
            return status! < 600;
          },
        ),
      );

      // If the response indicates token expiration, handle it and stop further processing.
      if (await TokenExpirationHandler().checkAndHandleResponse(response)) {
        // Token expiration handled (dialog + auto-logout). Exit early.
        return;
      }

      if (response.statusCode == 200) {
        log('✅ SUCCESS: Profile updated successfully');
        final Map parsed = json.decode(response.data.toString());
        log('Response data: $parsed');

        Fluttertoast.showToast(
          msg: parsed['msg'] ?? 'Profile updated successfully',
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1,
          backgroundColor: appColors().black,
          textColor: appColors().colorBackground,
          fontSize: 14.0,
        );
        sharePrefs.setUserData('$response');
        if (parsed['status'].toString().contains('true')) {
          String settingDetails = await AppSettingsPresenter().getAppSettings(
            token,
          );

          sharePrefs.setSettingsData(settingDetails);
        }
        // Don't throw exception on success - let the method complete normally
      } else {
        // Handle different status codes
        log('❌ ERROR: HTTP ${response.statusCode}');
        log('Error Response Data: ${response.data}');

        String errorMessage = "Failed to update profile";

        if (response.statusCode == 500) {
          errorMessage = "Server error occurred. Please try again later.";
          log('🔥 SERVER ERROR 500: This is likely a backend issue');
        } else if (response.statusCode == 401) {
          errorMessage = "Authentication failed. Please login again.";
          log('🔐 AUTH ERROR 401: Token may be invalid or expired');
        } else if (response.statusCode == 422) {
          errorMessage =
              "Invalid data provided. Please check your information.";
          log('📝 VALIDATION ERROR 422: Check your form data');
        } else if (response.statusCode == 404) {
          errorMessage = "Profile update service not found.";
          log('🔍 NOT FOUND 404: API endpoint may be wrong');
        }

        Fluttertoast.showToast(
          msg: errorMessage,
          toastLength: Toast.LENGTH_LONG,
          timeInSecForIosWeb: 2,
          backgroundColor: appColors().primaryColorApp,
          textColor: Colors.white,
          fontSize: 14.0,
        );

        // Throw exception so the UI knows the update failed
        throw Exception(errorMessage);
      }
    } on DioException catch (dioError) {
      log('💥 DIO EXCEPTION CAUGHT 💥');
      log('DioException Type: ${dioError.type}');
      log('DioException Message: ${dioError.message}');
      log('DioException Response Status: ${dioError.response?.statusCode}');
      log('DioException Response Data: ${dioError.response?.data}');
      log('=====================================');

      // If Dio returned a response that signals token expiration, handle and exit.
      if (await TokenExpirationHandler().checkAndHandleResponse(
        dioError.response,
      )) {
        return;
      }

      String errorMessage = "Network error occurred";

      if (dioError.type == DioExceptionType.connectionTimeout) {
        errorMessage =
            "Connection timeout. Please check your internet connection.";
      } else if (dioError.type == DioExceptionType.receiveTimeout) {
        errorMessage = "Server response timeout. Please try again.";
      } else if (dioError.type == DioExceptionType.sendTimeout) {
        errorMessage = "Request timeout. Please try again.";
      } else if (dioError.type == DioExceptionType.badResponse) {
        errorMessage =
            "Server error (${dioError.response?.statusCode}). Please try again later.";
      } else if (dioError.type == DioExceptionType.connectionError) {
        errorMessage = "No internet connection. Please check your network.";
      }

      Fluttertoast.showToast(
        msg: errorMessage,
        toastLength: Toast.LENGTH_LONG,
        timeInSecForIosWeb: 2,
        backgroundColor: appColors().primaryColorApp,
        textColor: Colors.white,
        fontSize: 14.0,
      );

      // Rethrow the exception so the UI knows the update failed
      throw Exception(errorMessage);
    } catch (error) {
      log('⚠️ GENERAL ERROR CAUGHT ⚠️');
      log('General Error: $error');
      log('Error Type: ${error.runtimeType}');
      log('=====================================');

      Fluttertoast.showToast(
        msg: "Unexpected error occurred. Please try again.",
        toastLength: Toast.LENGTH_LONG,
        timeInSecForIosWeb: 2,
        backgroundColor: appColors().primaryColorApp,
        textColor: Colors.white,
        fontSize: 14.0,
      );

      // Rethrow the exception so the UI knows the update failed
      throw Exception("Unexpected error occurred. Please try again.");
    }
  }
}
