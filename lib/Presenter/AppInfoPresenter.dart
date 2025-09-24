import 'package:dio/dio.dart';
import 'package:jainverse/utils/AppConstant.dart';

class AppInfoPresenter {
  late final Dio _dio = Dio();

  Future<String> getInfo(String token) async {
    Response<String> response;
    if (token.isNotEmpty) {
      response = await _dio.get(
          AppConstant.BaseUrl + AppConstant.API_GET_APP_INFO,
          options: Options(headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token"
          }));
    } else {
      response =
          await _dio.get(AppConstant.BaseUrl + AppConstant.API_GET_APP_INFO,
              options: Options(headers: {
                "Accept": "application/json",
              }));
    }

    try {
      if (response.statusCode == 200) {
        return response.data.toString();
      } else {
        return response.data.toString();
      }
    } catch (error) {
      return throw UnimplementedError();
    }
  }
}
