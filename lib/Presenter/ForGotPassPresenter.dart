import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

class ForGotPassPresenter {
  late final Dio _dio = Dio();
  SharedPref sharePrefs = SharedPref();

  Future<String> getOtp(BuildContext context, String email) async {
    var formData = FormData.fromMap({AppConstant.email: email});
    try {
      final Response<String> response = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_FORGOT_PASSWORD,
        data: formData,
      );

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());
        return parsed['msg'];
      }

      return 'no';
    } on DioException catch (e) {
      // If token expired trigger global handler and return safe fallback
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return 'no';
    } catch (error) {
      return 'no';
    }
  }

  Future<String> getChangePass(
    BuildContext context,
    String email,
    String pass,
    String confPass,
    String otp,
  ) async {
    var formData = FormData.fromMap({
      AppConstant.email: email,
      AppConstant.password: pass,
      AppConstant.confirmationPassword: confPass,
      AppConstant.OTP: otp,
    });
    try {
      final Response<String> response = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_RESET_PASSWORD,
        data: formData,
      );

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());

        Fluttertoast.showToast(
          msg: ' ${parsed['msg']}!',
          toastLength: Toast.LENGTH_SHORT,
          timeInSecForIosWeb: 1,
          backgroundColor: appColors().black,
          textColor: appColors().colorBackground,
          fontSize: 14.0,
        );

        return parsed['msg'];
      } else {
        final Map parsed = json.decode(response.data.toString());
        return parsed['msg'];
      }
    } on DioException catch (e) {
      // Handle token expiration globally and return a safe fallback
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return 'no';
    } catch (error) {
      return 'no';
    }
  }
}
