import 'dart:async';

import 'dart:io';

import 'package:jainverse/models/channel_model.dart';
import 'package:jainverse/presenters/channel_presenter.dart';

/// Service that centralizes channel fetching, caching and update operations.
/// This keeps UI code small and coalesces parallel network requests.
class ChannelService {
  ChannelService._();
  static final ChannelService instance = ChannelService._();

  final Map<int, Map<String, dynamic>> _cache = {};
  final Map<int, Future<ChannelModel>?> _inflight = {};
  final Duration _cacheTTL = const Duration(seconds: 30);

  /// Returns cached ChannelModel if it exists and is fresh according to TTL.
  ChannelModel? getCachedIfFresh(int id) {
    final cached = _cache[id];
    if (cached == null) return null;
    try {
      final fetchedAt = DateTime.parse(cached['fetchedAt'] as String);
      final age = DateTime.now().toUtc().difference(fetchedAt);
      if (age <= _cacheTTL) return cached['model'] as ChannelModel;
    } catch (_) {}
    return null;
  }

  /// Fetches the channel from network and updates the internal cache. Coalesces
  /// parallel calls for the same id.
  Future<ChannelModel> fetchChannelAndCache(int id) async {
    if (_inflight[id] != null) return await _inflight[id]!;

    final future = () async {
      final presenter = ChannelPresenter();
      final resp = await presenter.getChannel();
      if (resp['status'] == true && resp['data'] != null) {
        final fresh = ChannelModel.fromJson(resp['data']);
        try {
          _cache[fresh.id] = {
            'model': fresh,
            'fetchedAt': DateTime.now().toUtc().toIso8601String(),
          };
        } catch (_) {}
        return fresh;
      }

      throw Exception(resp['msg'] ?? 'Failed to load channel');
    }();

    _inflight[id] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(id);
    }
  }

  /// Proxy to presenter.updateChannel to keep caller code simple.
  Future<Map<String, dynamic>> updateChannel({
    required String name,
    required String handle,
    required String description,
    File? image,
    File? bannerImage,
  }) async {
    final presenter = ChannelPresenter();
    return await presenter.updateChannel(
      name: name,
      handle: handle,
      description: description,
      image: image,
      bannerImage: bannerImage,
    );
  }
}
