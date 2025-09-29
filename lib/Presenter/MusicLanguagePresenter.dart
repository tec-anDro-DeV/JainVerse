import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicLanguage.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/utils/AppConstant.dart';

class MusicLanguagePresenter extends BasePresenter {
  // New method with token expiration handling
  Future<ModelMusicLanguage> getMusicLanguage(
    String token,
    BuildContext context,
  ) async {
    try {
      Response<String> response = await get<String>(
        AppConstant.BaseUrl + AppConstant.API_MUSIC_LANGUAGES,
        options: Options(headers: createAuthHeaders(token)),
        context: context,
      );

      print('>>>$response');

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());
        print('$response');
        return ModelMusicLanguage.fromJson(parsed);
      } else {
        final Map parsed = json.decode(response.data.toString());
        return ModelMusicLanguage.fromJson(parsed);
      }
    } catch (error) {
      print('>>>     $error $error');
      throw UnimplementedError();
    }
  }

  // Legacy method for backward compatibility (without token expiration handling)
  Future<ModelMusicLanguage> getMusicLanguageLegacy(String token) async {
    try {
      final response = await dio.get(
        AppConstant.BaseUrl + AppConstant.API_MUSIC_LANGUAGES,
        options: Options(headers: createAuthHeaders(token)),
      );

      print('>>>$response');

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());
        print('$response');
        return ModelMusicLanguage.fromJson(parsed);
      } else {
        final Map parsed = json.decode(response.data.toString());
        return ModelMusicLanguage.fromJson(parsed);
      }
    } catch (error) {
      print('>>>     $error $error');
      throw UnimplementedError();
    }
  }

  Future<void> setMusicLanguage(
    BuildContext context,
    String list,
    String token,
  ) async {
    FormData formData = FormData.fromMap({AppConstant.language_id: list});

    await post<String>(
      AppConstant.BaseUrl + AppConstant.API_SET_MUSIC_LANGUAGES,
      data: formData,
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );

    // final Map parsed = json.decode(response.data.toString());
    // Fluttertoast.showToast(
    //     msg: parsed['msg'],
    //     toastLength: Toast.LENGTH_SHORT,
    //     timeInSecForIosWeb: 1,
    //     backgroundColor: appColors().black,
    //     textColor: appColors().colorBackground,
    //     fontSize: 14.0);
  }
}
