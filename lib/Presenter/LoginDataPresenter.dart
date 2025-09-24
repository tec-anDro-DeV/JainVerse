import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/presenters/base_presenter.dart';

class LoginDataPresenter extends BasePresenter {
  SharedPref sharePrefs = SharedPref();

  LoginDataPresenter() : super();

  // New context-aware method that uses BasePresenter.post and handles token expiration
  Future<String> getUser(
    BuildContext context,
    String buildNumber,
    String email,
    String pass,
    int isArtist,
  ) async {
    print("DEBUG: Login process started for email: $email");
    var formData = FormData.fromMap({
      AppConstant.email: email,
      AppConstant.password: pass,
      'is_artist': isArtist.toString(),
    });

    try {
      print(
        "DEBUG: Sending login request to ${AppConstant.BaseUrl + AppConstant.API_LOGIN}",
      );

      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_LOGIN,
        data: formData,
        // No auth header for login
        context: context,
      );

      print(
        "DEBUG: Received response with status code: ${response.statusCode}",
      );

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());

        if (parsed['status'].toString().contains('true')) {
          sharePrefs.setUserData(response.data.toString());
          sharePrefs.setToken('' + parsed['login_token']);
          sharePrefs.setThemeData(
            jsonEncode(
              ModelTheme(
                '',
                '',
                'Default theme',
                '0xFFb5bada',
                'assets/images/default_screen.jpg',
                'free',
              ),
            ),
          );
          return "1";
        } else {
          // Check if error is specifically for email not verified
          if (parsed.containsKey('error') &&
              parsed['error'] == 'email_not_verified') {
            // Show the message but don't return error code "0"
            // Return special code "2" to indicate email verification needed
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
            return "2"; // Special code for email verification required
          } else {
            // Regular error - show toast and return error
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
            return "0";
          }
        }
      } else {
        return "0";
      }
    } catch (error) {
      print("DEBUG: Exception occurred during login: $error");
      if (error is DioException) {
        print("DEBUG: DioError details: ${error.message}");
        print("DEBUG: Response data: ${error.response?.data}");
      }
      return "0";
    }
  }

  // Legacy method kept for backward compatibility - uses raw dio
  Future<String> getUserLegacy(
    String buildNumber,
    String email,
    String pass,
    int isArtist,
  ) async {
    print("DEBUG: Login process started for email: $email (legacy)");
    var formData = FormData.fromMap({
      AppConstant.email: email,
      AppConstant.password: pass,
      'is_artist': isArtist.toString(),
    });

    try {
      Response<String> response = await dio.post(
        AppConstant.BaseUrl + AppConstant.API_LOGIN,
        data: formData,
      );

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());

        if (parsed['status'].toString().contains('true')) {
          sharePrefs.setUserData(response.data.toString());
          sharePrefs.setToken('' + parsed['login_token']);
          return "1";
        } else {
          // Check if error is specifically for email not verified
          if (parsed.containsKey('error') &&
              parsed['error'] == 'email_not_verified') {
            // Show the message but don't return error code "0"
            // Return special code "2" to indicate email verification needed
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
            return "2"; // Special code for email verification required
          } else {
            // Regular error - show toast and return error
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
            return "0";
          }
        }
      } else {
        return "0";
      }
    } catch (error) {
      print("DEBUG: Exception occurred during login (legacy): $error");
      return "0";
    }
  }
}
