import 'package:dio/dio.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/services/token_expiration_handler.dart';

class AppSettingsPresenter {
  late final Dio _dio;

  AppSettingsPresenter() {
    _dio = Dio();
    // Configure timeout settings - INCREASED to fix timeout issue
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  Future<String> getAppSettings(String token) async {
    try {
      final Response<String> response = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_GET_USER_SETTING_DETAILS,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data.toString();
      }

      return response.data.toString();
    } on DioException catch (e) {
      // If token expired, trigger global handler and return a safe fallback
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return 'error';
    } catch (error) {
      return 'error';
    }
  }
}
