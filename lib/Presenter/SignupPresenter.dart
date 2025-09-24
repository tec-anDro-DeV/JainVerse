import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/UserModel.dart';

import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/presenters/base_presenter.dart';

class SignupPresenter extends BasePresenter {
  SharedPref sharePrefs = SharedPref();

  SignupPresenter() : super();

  Future<UserModel> getRegister(
    BuildContext context,
    String fname,
    String lname,
    String email,
    String pass,
    String mobileNum, {
    String? gender,
    String? dob,
    String? countryId,
  }) async {
    var formData = FormData.fromMap({
      AppConstant.fname: fname,
      AppConstant.lname: lname,
      AppConstant.email: email,
      AppConstant.mobile: mobileNum,
      AppConstant.password: pass,
      AppConstant.password_confirmation: pass,
      "accept_term_and_policy": "1",
      "gender": gender,
      "dob": dob,
      "country_id": countryId, // This will now contain the country name
    });

    // Debug: Print all form data being sent
    print("========== API REQUEST DATA ==========");
    print("First Name: $fname");
    print("Last Name: $lname");
    print("Email: $email");
    print("Mobile: $mobileNum");
    print("Gender: $gender");
    print("DOB: $dob");
    print("Country: $countryId");
    print("FormData fields:");
    for (var field in formData.fields) {
      print("  ${field.key}: ${field.value}");
    }
    print("=====================================");

    print("register response-------------------------");
    try {
      Response<String> response = await post<String>(
        AppConstant.BaseUrl + AppConstant.API_SIGNUP,
        data: formData,
        options: Options(),
        context: context,
      );

      print("register response-------------------------check");

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());

        // Debug: Print the actual response
        print("Parsed response: $parsed");

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
          // For new flow, we should only save data if we have a login_token
          // Otherwise, it's just an OTP sent response
          if (parsed.containsKey('login_token') &&
              parsed['login_token'] != null &&
              parsed['login_token'].toString().isNotEmpty) {
            sharePrefs.setUserData(response.data.toString());
            sharePrefs.setToken(parsed['login_token']);
          }
          return UserModel.fromJson(parsed);
        }

        return UserModel.fromJson(parsed);
      } else {
        print("register response------------------------errr${response.data}");

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
          // Return empty model without showing toast
          return UserModel.fromJson({});
        }
      }
    } catch (e) {
      print("register response $e");

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
}
