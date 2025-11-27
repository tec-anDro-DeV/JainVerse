import 'package:jainverse/Model/song_model.dart';

import 'ModelCatSubcatMusic.dart' show Artist;

class ModelAllCat {
  final bool status;
  final String msg;
  final List<SubData> subCategory;
  final String? type;
  final String? catName;
  final int? currentPage;
  final int? totalPages;
  final int? totalItems;

  ModelAllCat(
    this.status,
    this.msg,
    this.subCategory, {
    this.type,
    this.catName,
    this.currentPage,
    this.totalPages,
    this.totalItems,
  });

  factory ModelAllCat.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? dataNode = json['data'] is Map<String, dynamic>
        ? json['data']
        : null;
    final dynamic subCategorySource = dataNode != null
        ? dataNode['sub_category']
        : json['sub_category'];

    List<SubData> subCategoryList = [];
    if (subCategorySource is List) {
      subCategoryList = subCategorySource
          .map(
            (dynamic item) =>
                SubData.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
    }

    final Map<String, dynamic> metaSource = dataNode != null ? dataNode : json;

    return ModelAllCat(
      json['status'] ?? false,
      json['msg'] ?? '',
      subCategoryList,
      type: json['type'] ?? dataNode?['type'],
      catName: json['cat_name'] ?? dataNode?['cat_name'],
      currentPage:
          _parseInt(metaSource['current_page']) ??
          _parseInt(metaSource['currentPage']),
      totalPages:
          _parseInt(metaSource['total_pages']) ??
          _parseInt(metaSource['totalPages']),
      totalItems:
          _parseInt(metaSource['total_items']) ??
          _parseInt(metaSource['totalItems']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'msg': msg,
      'sub_category': subCategory.map((x) => x.toJson()).toList(),
      'type': type,
      'cat_name': catName,
      'current_page': currentPage,
      'total_pages': totalPages,
      'total_items': totalItems,
    };
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

/*class DataCat {

  String cat_name = "";
  String imagePath = "";
  List<SubData> sub_category;
  DataCat(this.cat_name,this.imagePath, this.sub_category);
  factory DataCat.fromJson(Map<String, dynamic> json) {

    List<SubData> d=   List<SubData>.from(json["sub_category"].map((x) => SubData.fromJson(x)));


    return DataCat(json['cat_name'],json['imagePath'] ?? '', d);
  }

}*/

class SubData {
  int id;
  String name = '';
  String slug = '';
  String image = '';
  int is_featured;
  int is_trending;
  int is_recommended;

  String playlist_name = '';
  int user_id;
  String? song_list;
  String? image_url;
  String? handle;
  String? banner_image;
  String? banner_url;
  String? description;
  int? total_subscribers;
  int? status;
  String? created_at;
  String? updated_at;

  List<dynamic>? audios;

  String? artist_id;
  String? lyrics;
  List<Artist>? artists;
  SongModel? song;

  SubData(
    this.id,
    this.name,
    this.slug,
    this.image,
    this.is_featured,
    this.is_trending,
    this.is_recommended, {
    this.playlist_name = '',
    this.user_id = 0,
    this.song_list,
    this.image_url,
    this.handle,
    this.banner_image,
    this.banner_url,
    this.description,
    this.total_subscribers,
    this.status,
    this.created_at,
    this.updated_at,
    this.audios,
    this.artist_id,
    this.lyrics,
    this.artists,
    this.song,
  });

  factory SubData.fromJson(Map<String, dynamic> json) {
    // Parse artists array if present
    List<Artist>? artistsList;
    if (json.containsKey('artists') && json['artists'] != null) {
      final artistsData = json['artists'];
      if (artistsData is List) {
        artistsList = artistsData
            .map(
              (artistJson) =>
                  Artist.fromJson(artistJson as Map<String, dynamic>),
            )
            .toList();
      }
    }

    final songModel = _isSongPayload(json) ? SongModel.fromJson(json) : null;

    return SubData(
      json['id'] ?? 0,
      json['name'] ?? json['playlist_name'] ?? '',
      json['slug'] ?? '',
      json['image'] ?? '',
      json['is_featured'] ?? 0,
      json['is_trending'] ?? 0,
      json['is_recommended'] ?? 0,
      playlist_name: json['playlist_name'] ?? '',
      user_id: json['user_id'] ?? 0,
      song_list: json['song_list'],
      image_url: json['image_url'] ?? json['imageUrl'],
      handle: json['handle'],
      banner_image: json['banner_image'],
      banner_url: json['banner_url'],
      description: json['description'],
      total_subscribers: json['total_subscribers'],
      status: json['status'],
      created_at: json['created_at'],
      updated_at: json['updated_at'],
      audios: json['audios'],
      artist_id: json['artist_id'],
      lyrics: json['lyrics'],
      artists: artistsList,
      song: songModel,
    );
  }

  // Add toJson method for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'image': image,
      'is_featured': is_featured,
      'is_trending': is_trending,
      'is_recommended': is_recommended,
      'playlist_name': playlist_name,
      'user_id': user_id,
      'song_list': song_list,
      'image_url': image_url,
      'handle': handle,
      'banner_image': banner_image,
      'banner_url': banner_url,
      'description': description,
      'total_subscribers': total_subscribers,
      'status': status,
      'created_at': created_at,
      'updated_at': updated_at,
      'audios': audios,
      'artist_id': artist_id,
      'lyrics': lyrics,
      'artists': artists?.map((a) => a.toJson()).toList(),
      if (song != null) 'song': song!.toJson(),
    };
  }
}

bool _isSongPayload(Map<String, dynamic> json) {
  const songIndicators = [
    'audio_url',
    'audio',
    'audio_title',
    'audio_slug',
    'audio_duration',
  ];

  for (final key in songIndicators) {
    if (json[key] != null && json[key].toString().isNotEmpty) {
      return true;
    }
  }

  return false;
}
