import 'ModelMusicList.dart';

// Model for user playlists API (now includes imagePath and audioPath at top-level)

class ModelPlayList {
  bool status;
  String msg;

  /// Relative path returned by API for images (e.g. "images/audio/thumb/")
  String imagePath;

  /// Relative path returned by API for audio files (e.g. "images/audio/")
  String audioPath;

  List<DataCat> data;

  ModelPlayList(
    this.status,
    this.msg,
    this.data,
    this.imagePath,
    this.audioPath,
  );

  factory ModelPlayList.fromJson(Map<String, dynamic> json) {
    List<DataCat> d = [];
    if (json["data"] != null && json["data"] is List) {
      d = List<DataCat>.from(json["data"].map((x) => DataCat.fromJson(x)));
    }

    return ModelPlayList(
      json['status'] ?? false,
      json['msg'] ?? '',
      d,
      json['imagePath'] ?? '',
      json['audioPath'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'msg': msg,
      'imagePath': imagePath,
      'audioPath': audioPath,
      'data':
          data
              .map(
                (x) => {
                  'id': x.id,
                  'user_id': x.user_id,
                  'playlist_name': x.playlist_name,
                  'audio_count': x.audio_count,
                  'song_list': x.song_list.map((s) => s.toJson()).toList(),
                  'created_at': x.created_at,
                  'updated_at': x.updated_at,
                },
              )
              .toList(),
    };
  }
}

class DataCat {
  int id;
  int user_id;
  String playlist_name = "";

  /// New field returned by API: number of audios in the playlist
  int audio_count;

  List<DataMusic> song_list;
  String created_at = "";
  String updated_at = "";

  DataCat(
    this.id,
    this.user_id,
    this.playlist_name,
    this.audio_count,
    this.song_list,
    this.created_at,
    this.updated_at,
  );

  factory DataCat.fromJson(Map<String, dynamic> json) {
    List<DataMusic> d = [];
    if (json["song_list"] != null && json["song_list"] is List) {
      d = List<DataMusic>.from(
        json["song_list"].map((x) => DataMusic.fromJson(x)),
      );
    }

    return DataCat(
      json['id'] ?? 0,
      json['user_id'] ?? 0,
      json['playlist_name'] ?? '',
      json['audio_count'] ?? (d.length),
      d,
      json['created_at'] ?? '',
      json['updated_at'] ?? '',
    );
  }
}

class SubData {
  int id;

  String image = "";
  String audio = "";
  String audio_duration = "";
  String audio_title = "";
  String audio_slug = "";
  int audio_genre_id;

  String artist_id = "";
  String artists_name = "";
  String audio_language = "";
  int listening_count;
  int is_featured;

  int is_trending;
  int is_recommended;
  String created_at = "";

  SubData(
    this.id,
    this.image,
    this.audio,
    this.audio_duration,
    this.audio_title,
    this.audio_slug,
    this.audio_genre_id,
    this.artist_id,
    this.artists_name,
    this.audio_language,
    this.listening_count,
    this.is_featured,
    this.is_trending,
    this.created_at,
    this.is_recommended,
  );

  factory SubData.fromJson(Map<String, dynamic> json) {
    return SubData(
      json['id'] ?? 0,
      json['image'] ?? '',
      json['audio'] ?? '',
      json['audio_duration'] ?? '',
      json['audio_title'] ?? '',
      json['audio_slug'] ?? '',
      json['audio_genre_id'] ?? 0,
      json['artist_id'] ?? '',
      json['artists_name'] ?? '',
      json['audio_language'] ?? '',
      json['listening_count'] ?? 0,
      json['is_featured'] ?? 0,
      json['is_trending'] ?? 0,
      json['created_at'] ?? '',
      json['is_recommended'] ?? 0,
    );
  }
}
