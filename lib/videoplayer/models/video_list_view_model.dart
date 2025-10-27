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

  // Search state
  String searchQuery = '';
  bool isSearching = false;

  VideoListViewModel({Dio? dio, SharedPref? sharedPref, this.perPage = 10})
    : _dio = dio ?? Dio(),
      _sharedPref = sharedPref ?? SharedPref();

  // Set search query and refresh results
  Future<void> search(String query) async {
    if (searchQuery == query && items.isNotEmpty) return;
    searchQuery = query;
    isSearching = query.isNotEmpty;
    page = 1;
    items = [];
    await _loadPage(page);
  }

  // Clear search and reload all videos
  Future<void> clearSearch() async {
    if (searchQuery.isEmpty) return;
    searchQuery = '';
    isSearching = false;
    await refresh();
  }

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

      // Use search endpoint if searching, otherwise use all videos endpoint
      String endpoint;
      Map<String, dynamic> params;

      if (isSearching && searchQuery.isNotEmpty) {
        endpoint = AppConstant.BaseUrl + AppConstant.API_SEARCH_VIDEOS;
        params = {'query': searchQuery, 'page': p, 'per_page': perPage};
      } else {
        endpoint = AppConstant.BaseUrl + AppConstant.API_ALL_VIDEOS;
        params = {'page': p, 'per_page': perPage};
      }

      final resp = await _dio.request(
        endpoint,
        data: isSearching ? params : null,
        queryParameters: isSearching ? null : params,
        options: Options(
          method: isSearching ? 'POST' : 'GET',
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
          List<dynamic> raw;
          int currentPage;
          int lastPage;

          // Handle different response formats
          if (isSearching) {
            // Search API response: { data: { videos: [...], pagination: {...} } }
            final dataObj = data['data'];
            if (dataObj is Map<String, dynamic>) {
              raw = dataObj['videos'] ?? [];
              final pagination = dataObj['pagination'];
              if (pagination is Map<String, dynamic>) {
                currentPage = pagination['current_page'] ?? p;
                lastPage = pagination['last_page'] ?? 1;
              } else {
                currentPage = p;
                lastPage = 1;
              }
            } else {
              throw Exception('Invalid search response format');
            }
          } else {
            // All videos API response: { data: [...], currentPage: x, totalPages: y }
            raw = data['data'] ?? [];
            currentPage = (data['currentPage'] is int)
                ? data['currentPage']
                : p;
            lastPage = (data['totalPages'] is int) ? data['totalPages'] : 1;
          }

          final List<VideoItem> parsed = raw.map((e) {
            if (e is Map<String, dynamic>) return VideoItem.fromJson(e);
            return VideoItem.fromJson(Map<String, dynamic>.from(e));
          }).toList();

          page = currentPage;
          totalPages = lastPage;

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
