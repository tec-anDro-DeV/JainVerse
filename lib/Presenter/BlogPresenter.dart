import 'package:dio/dio.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/services/token_expiration_handler.dart';

class BlogPresenter {
  late final Dio _dio = Dio();

  Future<String> getBlog(String token) async {
    try {
      final Response<String> response = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_Blog,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
        ),
      );

      // Best-effort: handle token expiration responses centrally
      await TokenExpirationHandler().checkAndHandleResponse(response);

      if (response.statusCode == 200) {
        return response.data.toString();
      }
      return '';
    } on DioException catch (e) {
      // Trigger token-expiration handler if a response is present (e.g., 401)
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      // Return safe fallback so callers can handle an empty response
      return '';
    }
  }
}
