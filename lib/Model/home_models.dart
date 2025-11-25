// Central home models: keep HomeResponse, HomeData, GenreModel and helpers here.
import 'package:jainverse/Model/video_model.dart';
import 'package:jainverse/Model/channel_model.dart';
import 'package:jainverse/Model/song_model.dart';

export 'package:jainverse/Model/video_model.dart';
export 'package:jainverse/Model/channel_model.dart';
export 'package:jainverse/Model/song_model.dart';

/// Root response for the unified home endpoint.
class HomeResponse {
  final bool status;
  final String message;
  final HomeData? data;

  const HomeResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory HomeResponse.fromJson(Map<String, dynamic> json) {
    return HomeResponse(
      status: json['status'] == true,
      message: json['msg']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic>
          ? HomeData.fromJson(json['data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'msg': message,
        'data': data?.toJson(),
      };
}

/// Container for all sections exposed by the home endpoint.
class HomeData {
  final List<VideoModel> featuredVideos;
  final List<ChannelModel> channels;
  final List<SongModel> featuredSongs;
  final List<SongModel> latestSongs;
  final List<VideoModel> popularVideos;
  final List<GenreModel> trendingGenres;
  final List<VideoModel> newVideos;

  const HomeData({
    this.featuredVideos = const [],
    this.channels = const [],
    this.featuredSongs = const [],
    this.latestSongs = const [],
    this.popularVideos = const [],
    this.trendingGenres = const [],
    this.newVideos = const [],
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      featuredVideos: _parseList(json['featuredVideos'], VideoModel.fromJson),
      channels: _parseList(json['channels'], ChannelModel.fromJson),
      featuredSongs: _parseList(json['featuredSongs'], SongModel.fromJson),
      latestSongs: _parseList(json['latestSongs'], SongModel.fromJson),
      popularVideos: _parseList(json['popularVideos'], VideoModel.fromJson),
      trendingGenres: _parseList(json['trendingGenres'], GenreModel.fromJson),
      newVideos: _parseList(json['newVideos'], VideoModel.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'featuredVideos': featuredVideos.map((e) => e.toJson()).toList(),
        'channels': channels.map((e) => e.toJson()).toList(),
        'featuredSongs': featuredSongs.map((e) => e.toJson()).toList(),
        'latestSongs': latestSongs.map((e) => e.toJson()).toList(),
        'popularVideos': popularVideos.map((e) => e.toJson()).toList(),
        'trendingGenres': trendingGenres.map((e) => e.toJson()).toList(),
        'newVideos': newVideos.map((e) => e.toJson()).toList(),
      };
}

//
// GENRE MODEL
//

class GenreModel {
  final int? id;
  final String name;
  final String? slug;
  final String? description;
  final String? image;
  final String? imageUrl;

  GenreModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.image,
    required this.imageUrl,
  });

  factory GenreModel.fromJson(Map<String, dynamic> json) {
    return GenreModel(
      id: _parseInt(json['id']),
      name: json['name'] ?? '',
      slug: json['slug'],
      description: json['description'],
      image: json['image'],
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'image': image,
        'image_url': imageUrl,
      };
}

//
// HELPERS
//

List<T> _parseList<T>(
  dynamic source,
  T Function(Map<String, dynamic>) builder,
) {
  if (source is List) {
    return source
        .whereType<Map<String, dynamic>>()
        .map(builder)
        .toList(growable: false);
  }
  return const [];
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
