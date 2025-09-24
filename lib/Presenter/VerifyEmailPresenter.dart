import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/presenters/base_presenter.dart';

class VerifyEmailPresenter extends BasePresenter {
  SharedPref sharePrefs = SharedPref();

  VerifyEmailPresenter() : super();

  Future<UserModel> verifyOTP(
    BuildContext context,
    String email,
    String otp,
  ) async {
    var formData = FormData.fromMap({"email": email, "otp": otp});

    // Debug: Print all form data being sent
    print("========== VERIFY OTP REQUEST DATA ==========");
    print("Email: $email");
    print("OTP: $otp");
    print("FormData fields:");
    for (var field in formData.fields) {
      print("  ${field.key}: ${field.value}");
    }
    print("============================================");

    try {
      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_VERIFY_OTP,
        data: formData,
        options: Options(),
        context: context,
      );

      print("verify_otp response: ${response.data}");

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());

        // Show message from backend
        if (parsed.containsKey('msg')) {
          Fluttertoast.showToast(
            msg: parsed['msg'],
            toastLength: Toast.LENGTH_SHORT,
            timeInSecForIosWeb: 1,
            backgroundColor: appColors().black,
            textColor: appColors().colorBackground,
            fontSize: 14.0,
          );
        }

        if (parsed['status'].toString().contains('true')) {
          // Save user data and token on successful verification
          // Only save if we have a valid login_token
          if (parsed.containsKey('login_token') &&
              parsed['login_token'] != null &&
              parsed['login_token'].toString().isNotEmpty) {
            sharePrefs.setUserData(response.data.toString());
            sharePrefs.setToken(parsed['login_token']);
            print("User successfully authenticated after OTP verification");
          } else {
            print(
              "Warning: OTP verification successful but no login_token received",
            );
          }
          return UserModel.fromJson(parsed);
        }

        return UserModel.fromJson(parsed);
      } else {
        print("verify_otp response error: ${response.data}");

        // Try to extract message from response
        try {
          final Map parsed = json.decode(response.data.toString());
          if (parsed.containsKey('msg')) {
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
          }
          return UserModel.fromJson(parsed);
        } catch (e) {
          print("Error parsing response: $e");
          return UserModel.fromJson({});
        }
      }
    } catch (e) {
      print("verify_otp error: $e");

      // Try to extract error response from DioError
      if (e is DioException && e.response != null && e.response!.data != null) {
        try {
          final Map parsed = json.decode(e.response!.data.toString());
          if (parsed.containsKey('msg')) {
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
            return UserModel.fromJson(parsed);
          }
        } catch (parseError) {
          print("Error parsing DioError response: $parseError");
        }
      }

      // Return empty model without showing toast if no message could be extracted
      return UserModel.fromJson({});
    }
  }

  Future<String> resendOTP(BuildContext context, String email) async {
    var formData = FormData.fromMap({"email": email});

    // Debug: Print all form data being sent
    print("========== RESEND OTP REQUEST DATA ==========");
    print("Email: $email");
    print("FormData fields:");
    for (var field in formData.fields) {
      print("  ${field.key}: ${field.value}");
    }
    print("===========================================");

    try {
      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_RESEND_OTP,
        data: formData,
        options: Options(),
        context: context,
      );

      print("resend_otp response: ${response.data}");

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());

        if (parsed['status'].toString().contains('true')) {
          // Show success message
          if (parsed.containsKey('msg')) {
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
          }
          return parsed['msg'] ?? 'OTP has been successfully sent to email.';
        } else {
          // Show error message
          if (parsed.containsKey('msg')) {
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
          }
          return parsed['msg'] ?? 'Failed to resend OTP';
        }
      } else {
        print("resend_otp response error: ${response.data}");

        // Try to extract message from response
        try {
          final Map parsed = json.decode(response.data.toString());
          if (parsed.containsKey('msg')) {
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
            return parsed['msg'];
          }
        } catch (e) {
          print("Error parsing response: $e");
        }
        return 'Failed to resend OTP';
      }
    } catch (e) {
      print("resend_otp error: $e");

      // Try to extract error response from DioError
      if (e is DioException && e.response != null && e.response!.data != null) {
        try {
          final Map parsed = json.decode(e.response!.data.toString());
          if (parsed.containsKey('msg')) {
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
            return parsed['msg'];
          }
        } catch (parseError) {
          print("Error parsing DioError response: $parseError");
        }
      }

      return 'Failed to resend OTP';
    }
  }
}
