import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/ModelMusicGenre.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';

class MusicGenrePresenter {
  late final Dio _dio = Dio();

  Future<ModelMusicGenre> getMusicGenre(String token) async {
    try {
      Response<String> response = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_MUSIC_GENRE,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
        ),
      );

      if (response.statusCode == 200) {
        final Map parsed = json.decode(response.data.toString());
        return ModelMusicGenre.fromJson(parsed);
      } else {
        final Map parsed = json.decode(response.data.toString());
        return ModelMusicGenre.fromJson(parsed);
      }
    } on DioException catch (e) {
      // Handle token expiration and return safe fallback
      try {
        await TokenExpirationHandler().checkAndHandleResponse(e.response);
      } catch (_) {}
      return ModelMusicGenre(false, '', '', [], []);
    } catch (error) {
      // Return empty model on unexpected parse errors
      return ModelMusicGenre(false, '', '', [], []);
    }
  }

  /// Sends the selected genre ids to the server.
  /// Returns true when server responds with a success message (status 200 and success flag),
  /// otherwise returns false.
  Future<bool> setMusicGenre(
    BuildContext context,
    String list,
    String token,
  ) async {
    FormData formData;
    formData = FormData.fromMap({AppConstant.genre_id: list});

    print(
      '>>>setMusicGenre: POST URL: '
      '${AppConstant.BaseUrl + AppConstant.API_SET_MUSIC_GENRE}',
    );
    print('>>>setMusicGenre: Request Headers: ');
    print({"Accept": "application/json", "authorization": "Bearer $token"});
    print('>>>setMusicGenre: Request Body: ');
    print(formData.fields);

    try {
      Response<String> response = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_SET_MUSIC_GENRE,
        data: formData,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
        ),
      );

      final Map parsed = json.decode(response.data.toString());
      Fluttertoast.showToast(
        msg: parsed['msg'] ?? '',
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: 14.0,
      );

      // Interpret response success: prefer explicit 'status' or 'success' fields when present
      if (parsed.containsKey('status')) {
        return (parsed['status'] == 200 ||
            parsed['status'] == '200' ||
            parsed['status'] == true);
      }
      if (parsed.containsKey('success')) {
        return (parsed['success'] == 1 ||
            parsed['success'] == true ||
            parsed['success'] == '1');
      }

      // Fallback: consider HTTP 200 as success
      return true;
    } on DioException catch (e) {
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      // Return early on token expiry or network error
      return false;
    } catch (error) {
      // Swallow parse/display errors - show a generic toast
      Fluttertoast.showToast(
        msg: 'Something went wrong',
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: 14.0,
      );
      return false;
    }
  }
}
