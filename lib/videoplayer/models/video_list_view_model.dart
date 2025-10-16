import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'video_item.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/AppConstant.dart';

class VideoListViewModel extends ChangeNotifier {
  final Dio _dio;
  final SharedPref _sharedPref;

  List<VideoItem> items = [];
  bool isLoading = false;
  bool hasError = false;
  String errorMessage = '';

  int page = 1;
  final int perPage;
  int totalPages = 1;

  VideoListViewModel({Dio? dio, SharedPref? sharedPref, this.perPage = 10})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref();

  Future<void> refresh() async {
    page = 1;
    items = [];
    await _loadPage(page);
  }

  Future<void> loadNext() async {
    if (isLoading) return;
    if (page >= totalPages) return;
    await _loadPage(page + 1);
  }

  Future<void> _loadPage(int p) async {
    isLoading = true;
    hasError = false;
    errorMessage = '';
    notifyListeners();

    try {
      final token = await _sharedPref.getToken();
      final resp = await _dio.get(
        AppConstant.BaseUrl + AppConstant.API_ALL_VIDEOS,
        queryParameters: {'page': p, 'per_page': perPage},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.toString().isNotEmpty)
              'Authorization': 'Bearer ${token.toString()}',
          },
        ),
      );

      if (resp.statusCode == 200) {
        final data = resp.data;
        if (data is Map<String, dynamic>) {
          final List<dynamic> raw = data['data'] ?? [];
          final List<VideoItem> parsed =
              raw.map((e) {
                if (e is Map<String, dynamic>) return VideoItem.fromJson(e);
                return VideoItem.fromJson(Map<String, dynamic>.from(e));
              }).toList();

          page =
              (data['currentPage'] is int)
                  ? data['currentPage']
                  : p; // fallback
          totalPages =
              (data['totalPages'] is int) ? data['totalPages'] : totalPages;

          if (p == 1) {
            items = parsed;
          } else {
            items = [...items, ...parsed];
          }
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } catch (e) {
      hasError = true;
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
