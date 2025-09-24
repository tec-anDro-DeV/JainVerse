List<DataMusic> d = [];

class ModelMusicList {
  bool status;
  String msg;
  String imagePath;
  String audioPath;
  List<DataMusic> data;
  ParentData? parent;

  ModelMusicList(
    this.status,
    this.msg,
    this.data,
    this.imagePath,
    this.audioPath,
    this.parent,
  );

  factory ModelMusicList.fromJson(Map<String, dynamic> json) {
    d = [];
    if (json["data"] != null && json["data"] is List) {
      d = List<DataMusic>.from(json["data"].map((x) => DataMusic.fromJson(x)));
    }

    ParentData? parentData;
    if (json["parent"] != null && json["parent"] is Map<String, dynamic>) {
      parentData = ParentData.fromJson(json["parent"]);
    }

    return ModelMusicList(
      json['status'] ?? false,
      json['msg'] ?? '',
      d,
      json['imagePath'] ?? '',
      json['audioPath'] ?? '',
      parentData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'msg': msg,
      'imagePath': imagePath,
      'audioPath': audioPath,
      'data': data.map((x) => x.toJson()).toList(),
      'parent': parent?.toJson(),
    };
  }
}

class DataMusic {
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
  String favourite = "";
  String download_price = "";
  String lyrics = "";

  DataMusic(
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
    this.favourite,
    this.download_price,
    this.lyrics,
  );

  factory DataMusic.fromJson(Map<String, dynamic> json) {
    return DataMusic(
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
      json['favourite'] ?? '',
      json['download_price'] ?? '',
      json['lyrics'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': image,
      'audio': audio,
      'audio_duration': audio_duration,
      'audio_title': audio_title,
      'audio_slug': audio_slug,
      'audio_genre_id': audio_genre_id,
      'artist_id': artist_id,
      'artists_name': artists_name,
      'audio_language': audio_language,
      'listening_count': listening_count,
      'is_featured': is_featured,
      'is_trending': is_trending,
      'created_at': created_at,
      'is_recommended': is_recommended,
      'favourite': favourite,
      'download_price': download_price,
      'lyrics': lyrics,
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
