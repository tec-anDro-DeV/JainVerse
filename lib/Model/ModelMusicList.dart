import 'package:jainverse/Model/song_model.dart';

export 'package:jainverse/Model/song_model.dart';

/// Temporary alias to ease migration. DataMusic now directly maps to SongModel.
typedef DataMusic = SongModel;

class ModelMusicList {
  final bool status;
  final String msg;
  final List<SongModel> data;
  final ParentData? parent;

  const ModelMusicList(this.status, this.msg, this.data, this.parent);

  factory ModelMusicList.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSongs = json['data'] is List
        ? json['data'] as List<dynamic>
        : const [];

    final songs = rawSongs
        .whereType<Map<String, dynamic>>()
        .map(SongModel.fromJson)
        .toList(growable: false);

    final parentData = json['parent'] is Map<String, dynamic>
        ? ParentData.fromJson(json['parent'] as Map<String, dynamic>)
        : null;

    return ModelMusicList(
      json['status'] ?? false,
      json['msg'] ?? '',
      songs,
      parentData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'msg': msg,
      'data': data.map((song) => song.toJson()).toList(),
      if (parent != null) 'parent': parent!.toJson(),
    };
  }
}

class ParentData {
  int id;
  String title;
  String image;
  String? description;
  int artistGenreId;
  String artistGenreName;
  String artistGenreSlug;

  ParentData(
    this.id,
    this.title,
    this.image,
    this.description,
    this.artistGenreId,
    this.artistGenreName,
    this.artistGenreSlug,
  );

  factory ParentData.fromJson(Map<String, dynamic> json) {
    return ParentData(
      json['id'] ?? 0,
      json['title'] ?? '',
      json['image'] ?? '',
      json['description'],
      json['artist_genre_id'] ?? 0,
      json['artist_genre_name'] ?? '',
      json['artist_genre_slug'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'description': description,
      'artist_genre_id': artistGenreId,
      'artist_genre_name': artistGenreName,
      'artist_genre_slug': artistGenreSlug,
    };
  }
}
