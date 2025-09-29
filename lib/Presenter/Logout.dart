import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

class Logout extends BasePresenter {
  final TokenExpirationHandler _tokenHandler = TokenExpirationHandler();

  SharedPref sharePrefs = SharedPref();

  Logout() : super();

  Future<void> logout(BuildContext context, String token) async {
    try {
      await post<void>(
        AppConstant.BaseUrl + AppConstant.API_logout,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
        ),
        context: context,
      );
    } on DioException catch (e) {
      // If token is already expired, it's ok during logout
      if (_tokenHandler.isTokenExpired(e.response)) {
        // nothing to do
      }
    }
  }

  Future<int> deleteApi(BuildContext context, String token, int userid) async {
    FormData formData;
    formData = FormData.fromMap({"user_id": userid});
    try {
      await post<void>(
        AppConstant.BaseUrl + AppConstant.API_delete,
        data: formData,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
        ),
        context: context,
      );

      return 1;
    } on DioException catch (e) {
      // Check for token expiration
      if (_tokenHandler.isTokenExpired(e.response)) {
        await _tokenHandler.handleTokenExpiration(context);
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
