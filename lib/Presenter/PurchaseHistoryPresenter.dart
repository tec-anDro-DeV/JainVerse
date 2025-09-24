import 'package:dio/dio.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/services/token_expiration_handler.dart';

class PurchaseHistoryPresenter {
  late final Dio _dio = Dio();

  Future<String> purchaseHistoryInfo(String token) async {
    try {
      final response = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_USER_PURCHASE_HISTORY,
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

      return "";
    } on DioException catch (dioError) {
      // If this was a 401 due to token expiration, let the centralized
      // handler take care of showing the dialog + performing logout.
      try {
        await TokenExpirationHandler().checkAndHandleResponse(
          dioError.response,
        );
      } catch (_) {
        // ignore handler errors - we still want to return a safe fallback
      }

      return "";
    } catch (error) {
      return "";
    }
  }
}
