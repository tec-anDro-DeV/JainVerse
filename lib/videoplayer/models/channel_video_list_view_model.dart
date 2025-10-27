import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'video_item.dart';
import '../services/channel_video_service.dart';

/// ViewModel for channel videos. Notifies listeners on state changes and
/// supports pull-to-refresh and incremental loading.
class ChannelVideoListViewModel extends ChangeNotifier {
  final ChannelVideoService _service;

  List<VideoItem> items = [];
  bool isLoading = false;
  bool hasError = false;
  String errorMessage = '';

  // Channel information from API
  Map<String, dynamic>? channelInfo;

  int page = 1;
  final int perPage;
  int totalPages = 1;

  CancelToken? _cancelToken;

  ChannelVideoListViewModel({ChannelVideoService? service, this.perPage = 10})
    : _service = service ?? ChannelVideoService();

  Future<void> refresh({required int channelId}) async {
    page = 1;
    items = [];
    await _loadPage(channelId, page, replace: true);
  }

  Future<void> loadNext({required int channelId}) async {
    if (isLoading) return;
    if (page >= totalPages) return;
    await _loadPage(channelId, page + 1);
  }

  Future<void> _loadPage(int channelId, int p, {bool replace = false}) async {
    isLoading = true;
    hasError = false;
    errorMessage = '';
    notifyListeners();

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    try {
      final resp = await _service.fetchChannelVideos(
        channelId: channelId,
        page: p,
        perPage: perPage,
        cancelToken: _cancelToken,
      );

      final List<VideoItem> fetched = List<VideoItem>.from(resp['data'] ?? []);
      page = resp['currentPage'] is int ? resp['currentPage'] : p;
      totalPages = resp['totalPages'] is int ? resp['totalPages'] : totalPages;

      // Store channel info from first page
      if (p == 1 && resp['channel'] != null) {
        channelInfo = resp['channel'];
      }

      if (p == 1 || replace) {
        items = fetched;
      } else {
        items = [...items, ...fetched];
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // canceled - ignore
        return;
      }
      hasError = true;
      errorMessage = e.message ?? e.toString();
    } catch (e) {
      hasError = true;
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}
