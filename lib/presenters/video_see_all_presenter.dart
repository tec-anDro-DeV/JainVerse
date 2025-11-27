import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/channel_model.dart';
import 'package:jainverse/Model/video_model.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Section types supported by the unified "See All" flow.
enum SeeAllSectionType { featuredVideos, popularVideos, latestVideos, channels }

extension SeeAllSectionTypeX on SeeAllSectionType {
  String get apiValue {
    switch (this) {
      case SeeAllSectionType.featuredVideos:
        return 'featured_videos';
      case SeeAllSectionType.popularVideos:
        return 'popular_videos';
      case SeeAllSectionType.latestVideos:
        return 'latest_videos';
      case SeeAllSectionType.channels:
        return 'channels';
    }
  }

  String get label {
    switch (this) {
      case SeeAllSectionType.featuredVideos:
        return 'Featured Videos';
      case SeeAllSectionType.popularVideos:
        return 'Popular Videos';
      case SeeAllSectionType.latestVideos:
        return 'Latest Videos';
      case SeeAllSectionType.channels:
        return 'Channels';
    }
  }

  bool get isVideo => this != SeeAllSectionType.channels;
}

/// Presenter that owns the See All data lifecycle (loading, paging, errors).
class HomeSectionSeeAllPresenter extends ChangeNotifier {
  HomeSectionSeeAllPresenter({
    required this.type,
    this.pageSize = 12,
    SharedPref? sharedPref,
  }) : _sharedPref = sharedPref ?? SharedPref();

  final SeeAllSectionType type;
  final int pageSize;
  final SharedPref _sharedPref;
  final _SeeAllSectionApi _api = _SeeAllSectionApi();

  final List<VideoModel> _videos = [];
  final List<ChannelModel> _channels = [];

  bool _isDisposed = false;
  bool _requestInFlight = false;
  bool _initializing = false;

  bool isInitialLoading = false;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  bool hasError = false;
  String? errorMessage;
  int _page = 0;
  int _totalPages = 1;

  List<VideoModel> get videos => List.unmodifiable(_videos);
  List<ChannelModel> get channels => List.unmodifiable(_channels);

  bool get hasContent =>
      type.isVideo ? _videos.isNotEmpty : _channels.isNotEmpty;
  bool get hasMore => _page < _totalPages;
  bool get isEmpty =>
      !hasError && !isInitialLoading && !isRefreshing && !hasContent;

  Future<void> initialize(BuildContext context) async {
    if (_initializing || _page > 0) return;
    _initializing = true;
    await _fetchPage(context, page: 1, reset: true, isRefresh: false);
    _initializing = false;
  }

  Future<void> refresh(BuildContext context) async {
    return _fetchPage(context, page: 1, reset: true, isRefresh: true);
  }

  Future<void> loadMore(BuildContext context) async {
    if (!hasMore) return;
    await _fetchPage(context, page: _page + 1, reset: false, isRefresh: false);
  }

  Future<void> _fetchPage(
    BuildContext context, {
    required int page,
    required bool reset,
    required bool isRefresh,
  }) async {
    if (_requestInFlight) return;
    _requestInFlight = true;

    if (page == 1) {
      if (isRefresh) {
        isRefreshing = true;
      } else {
        isInitialLoading = true;
      }
      if (reset) {
        _page = 0;
        _totalPages = 1;
        _videos.clear();
        _channels.clear();
      }
    } else {
      isLoadingMore = true;
    }

    hasError = false;
    errorMessage = null;
    _notifySafely();

    try {
      final dynamic storedToken = await _sharedPref.getToken();
      final token = storedToken?.toString() ?? '';
      if (token.isEmpty) {
        throw Exception('Please log in again to continue.');
      }

      final response = await _api.fetchSection(
        token: token,
        type: type,
        page: page,
        limit: pageSize,
        context: context,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Unexpected response format.');
      }

      if (data['status'] != true) {
        throw Exception(data['msg']?.toString() ?? 'Failed to load data.');
      }

      final payloadRaw = data['data'];
      final payload = payloadRaw is Map<String, dynamic>
          ? payloadRaw
          : <String, dynamic>{};
      final totalPages = _parseInt(payload['total_pages']) ?? 1;
      final List<Map<String, dynamic>> normalized = _normalizeItems(
        payload['sub_category'],
      );

      if (type.isVideo) {
        final parsed = normalized.map(VideoModel.fromJson).toList();
        if (page == 1) {
          _videos
            ..clear()
            ..addAll(parsed);
        } else {
          _videos.addAll(parsed);
        }
      } else {
        final parsed = normalized.map(ChannelModel.fromJson).toList();
        if (page == 1) {
          _channels
            ..clear()
            ..addAll(parsed);
        } else {
          _channels.addAll(parsed);
        }
      }

      _page = page;
      _totalPages = totalPages <= 0 ? 1 : totalPages;
    } on DioException catch (dioError) {
      hasError = true;
      errorMessage = _extractDioMessage(dioError);
    } catch (e) {
      hasError = true;
      errorMessage = e.toString();
    } finally {
      _requestInFlight = false;
      if (page == 1) {
        isInitialLoading = false;
        isRefreshing = false;
      } else {
        isLoadingMore = false;
      }
      _notifySafely();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Update the subscription state for a specific channel in-memory.
  /// This performs an optimistic update of the channel's `subscribed`
  /// flag and `subscribersCount`, and notifies listeners.
  void updateChannelSubscription(int channelId, bool subscribed) {
    final idx = _channels.indexWhere((c) => c.id == channelId);
    if (idx == -1) return;
    final current = _channels[idx];
    final int currentCount = current.subscribersCount;
    final int nextCount = subscribed
        ? currentCount + 1
        : (currentCount - 1).clamp(0, currentCount);
    _channels[idx] = current.copyWith(
      subscribed: subscribed,
      subscribersCount: nextCount,
    );
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }
}

class _SeeAllSectionApi extends BasePresenter {
  Future<Response<dynamic>> fetchSection({
    required String token,
    required SeeAllSectionType type,
    required int page,
    required int limit,
    required BuildContext context,
  }) {
    return post<dynamic>(
      AppConstant.BaseUrl + AppConstant.API_GET_VIDEOS,
      data: FormData.fromMap({
        'type': type.apiValue,
        'page': page,
        'limit': limit,
      }),
      options: Options(headers: createAuthHeaders(token)),
      context: context,
    );
  }
}

List<Map<String, dynamic>> _normalizeItems(dynamic source) {
  if (source is List) {
    return source.whereType<Map<String, dynamic>>().toList();
  }
  if (source is Map) {
    return source.values.whereType<Map<String, dynamic>>().toList();
  }
  return const [];
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String _extractDioMessage(DioException error) {
  final responseData = error.response?.data;
  if (responseData is Map<String, dynamic>) {
    if (responseData['msg'] != null) {
      return responseData['msg'].toString();
    }
    if (responseData['message'] != null) {
      return responseData['message'].toString();
    }
  }
  return error.message ?? 'Unable to load data. Please try again.';
}
