// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/song_model.dart';
import 'package:jainverse/Model/video_model.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/presenters/base_presenter.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';

class ChannelDetailInfo {
  final int id;
  final int userId;
  final String name;
  final String handle;
  final String imageUrl;
  final String bannerUrl;
  final String description;
  final String createdAt;
  final bool isSubscribed;
  final bool isOwn;
  final int subscribersCount;

  const ChannelDetailInfo({
    required this.id,
    required this.userId,
    required this.name,
    required this.handle,
    required this.imageUrl,
    required this.bannerUrl,
    required this.description,
    required this.createdAt,
    required this.isSubscribed,
    required this.isOwn,
    required this.subscribersCount,
  });

  factory ChannelDetailInfo.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? 0;
    }

    bool toBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      final normalized = value.toString().trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }

    return ChannelDetailInfo(
      id: toInt(json['id']),
      userId: toInt(json['user_id']),
      name: (json['name'] ?? '').toString(),
      handle: (json['handle'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? json['image'] ?? '').toString(),
      bannerUrl:
          (json['banner_url'] ??
                  json['banner_image'] ??
                  json['banner_image_url'] ??
                  '')
              .toString(),
      description: (json['description'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      isSubscribed: toBool(json['subscribed']),
      isOwn: toBool(json['is_own']),
      subscribersCount: toInt(
        json['total_subscribers'] ?? json['total_subscribers'],
      ),
    );
  }

  ChannelDetailInfo copyWith({bool? isSubscribed}) {
    return ChannelDetailInfo(
      id: id,
      userId: userId,
      name: name,
      handle: handle,
      imageUrl: imageUrl,
      bannerUrl: bannerUrl,
      description: description,
      createdAt: createdAt,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      isOwn: isOwn,
      subscribersCount: subscribersCount,
    );
  }
}

class ChannelDetailPayload {
  final ChannelDetailInfo? channel;
  final List<VideoModel> videos;
  final List<SongModel> songs;

  const ChannelDetailPayload({
    required this.channel,
    required this.videos,
    required this.songs,
  });
}

class ChannelDetailRepository extends BasePresenter {
  ChannelDetailRepository({SharedPref? sharedPref})
    : _sharedPref = sharedPref ?? SharedPref();

  final SharedPref _sharedPref;

  Future<ChannelDetailPayload> fetchChannelDetail(int channelId) async {
    final token = await _sharedPref.getToken();
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null) {
      throw Exception('Unable to resolve context for channel detail request.');
    }

    final headers = token.isNotEmpty
        ? createAuthHeaders(token)
        : {'Accept': 'application/json'};

    final response = await post<dynamic>(
      AppConstant.BaseUrl + AppConstant.API_GET_MY_CHANNEL_DETAIL,
      data: FormData.fromMap({'channel_id': channelId.toString()}),
      options: Options(headers: headers),
      context: context,
    );

    final payload = _normalizeResponse(response.data);
    final channelMap = _extractMap(payload, 'channel');
    final videosRaw = _extractList(payload, ['videos']);
    final songsRaw = _extractList(payload, ['music', 'songs']);

    final videos = videosRaw
        .map((entry) => VideoModel.fromJson(entry))
        .toList(growable: false);
    final songs = songsRaw
        .map((entry) => SongModel.fromJson(entry))
        .toList(growable: false);

    return ChannelDetailPayload(
      channel: channelMap != null
          ? ChannelDetailInfo.fromJson(channelMap)
          : null,
      videos: videos,
      songs: songs,
    );
  }

  Map<String, dynamic> _normalizeResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic>? _extractMap(Map<String, dynamic> payload, String key) {
    final dynamic direct = payload[key];
    if (direct is Map<String, dynamic>) {
      return direct;
    }

    final dynamic nested = payload['data'];
    if (nested is Map<String, dynamic> && nested[key] is Map<String, dynamic>) {
      return nested[key] as Map<String, dynamic>;
    }
    return null;
  }

  List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> payload,
    List<String> possibleKeys,
  ) {
    dynamic candidate;
    for (final key in possibleKeys) {
      if (payload[key] != null) {
        candidate = payload[key];
        break;
      }
    }

    if (candidate == null && payload['data'] is Map<String, dynamic>) {
      final dataMap = payload['data'] as Map<String, dynamic>;
      for (final key in possibleKeys) {
        if (dataMap[key] != null) {
          candidate = dataMap[key];
          break;
        }
      }
    }

    // Legacy shape: `data` is already the list of videos
    if (candidate == null && payload['data'] is List) {
      candidate = payload['data'];
    }

    if (candidate is Map) {
      if (candidate['data'] is List) {
        candidate = candidate['data'];
      } else {
        return const <Map<String, dynamic>>[];
      }
    }

    if (candidate is List) {
      return candidate
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    return const <Map<String, dynamic>>[];
  }
}
