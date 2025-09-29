import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/services/token_expiration_handler.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

class HistoryPresenter {
  late final Dio _dio;
  final SharedPref _sharePrefs = SharedPref();

  // Prevent rapid duplicate history additions for the same music id.
  // Use static so it works across multiple HistoryPresenter instances.
  static final Map<String, DateTime> _lastAddTimestamps = {};
  static const Duration _addDebounce = Duration(seconds: 2);

  HistoryPresenter() {
    _dio = Dio();
    // Configure timeout settings - INCREASED to fix timeout issue
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);
  }

  // Simple automatic history tracking for all played songs
  Future<void> trackSongPlay(String musicId) async {
    try {
      final token = await _sharePrefs.getToken();
      if (token.isEmpty || musicId.isEmpty) return;

      // Call addHistory with 'add' tag for automatic tracking
      await addHistory(musicId, token, 'add');
    } catch (error) {
      // Silent fail for automatic tracking to not interrupt playback
    }
  }

  Future<String> getHistory(String token) async {
    Response<String> response;
    try {
      response = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_MUSIC_HISTORY,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
        ),
      );
      // Check for token expiration (best-effort)
      await TokenExpirationHandler().checkAndHandleResponse(response);
    } on DioException catch (e) {
      // If we have a response, check for token expiration and do not rethrow
      // to avoid crashing callers. Return a safe empty JSON string so callers
      // can handle the absence of data gracefully.
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return '{}';
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

  Future<void> addHistory(String MusId, String token, String tag) async {
    // Debounce rapid duplicate 'add' requests for the same music id.
    if (tag == 'add') {
      final now = DateTime.now();
      final last = _lastAddTimestamps[MusId];
      if (last != null && now.difference(last) < _addDebounce) {
        // Skip duplicate rapid calls.
        return;
      }
      _lastAddTimestamps[MusId] = now;
    }

    FormData formData = FormData.fromMap({
      AppConstant.music_id: MusId,
      AppConstant.tag: tag,
    });

    Response<String> response;
    try {
      response = await _dio.post(
        AppConstant.BaseUrl + AppConstant.API_ADD_REMOVE_MUSIC_HISTORY,
        data: formData,
        options: Options(
          headers: {
            "Accept": "application/json",
            "authorization": "Bearer $token",
          },
        ),
      );
      // Check for token expiration (best-effort)
      await TokenExpirationHandler().checkAndHandleResponse(response);
    } on DioException catch (e) {
      // If we have a response, check for token expiration and return an
      // empty JSON so callers can handle missing data. Avoid rethrow to
      // prevent uncaught DioExceptions from crashing the app during logout.
      await TokenExpirationHandler().checkAndHandleResponse(e.response);
      return;
    }

    try {
      if (response.statusCode == 200) {
        final Map<String, dynamic> parsed = json.decode(
          response.data.toString(),
        );

        if (parsed['msg'].contains('Removed')) {
          try {
            Fluttertoast.showToast(
              msg: parsed['msg'],
              toastLength: Toast.LENGTH_SHORT,
              timeInSecForIosWeb: 1,
              backgroundColor: appColors().black,
              textColor: appColors().colorBackground,
              fontSize: 14.0,
            );
          } catch (_) {
            // Ignore toast failures on background threads or removed UI context
          }
        }
      }
    } catch (error) {
      // swallow errors to avoid interrupting playback
    }
  }
}
