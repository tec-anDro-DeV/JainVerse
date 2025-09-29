import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:jainverse/Model/ModelChannelYT.dart';
import 'package:jainverse/utils/AppConstant.dart';

class YTPresenter {
  late final Dio _dio = Dio();

  Future<ModelChannelYT> getYTPlayList(String token) async {
    Response<String> response = await _dio.get(
      AppConstant.BaseUrl + AppConstant.API_YT_PLAYLISTS,
      options: Options(
        headers: {
          "Accept": "application/json",
          "authorization": "Bearer $token",
        },
      ),
    );

    try {
      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );

        return ModelChannelYT.fromJson(parsed);
      } else {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );
        return ModelChannelYT.fromJson(parsed);
      }
    } catch (error) {
      return throw UnimplementedError();
    }
  }
}
