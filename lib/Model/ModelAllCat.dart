import 'ModelCatSubcatMusic.dart' show Artist;

class ModelAllCat {
  bool status;
  String msg;
  String imagePath;
  List<SubData> sub_category;
  String? type; // Add type field as it's in the response
  // Optional pagination meta returned by API
  int? currentPage;
  int? totalPages;
  int? totalItems;

  ModelAllCat(
    this.status,
    this.msg,
    this.sub_category,
    this.imagePath, {
    this.type,
    this.currentPage,
    this.totalPages,
    this.totalItems,
  });

  factory ModelAllCat.fromJson(Map<String, dynamic> json) {
    // Handle the case where sub_category might be null or not a list
    List<SubData> subCategoryList = [];

    if (json["sub_category"] != null && json["sub_category"] is List) {
      subCategoryList = List<SubData>.from(
        json["sub_category"].map((x) => SubData.fromJson(x)),
      );
    }

    return ModelAllCat(
      json['status'] ?? false,
      json['msg'] ?? '',
      subCategoryList,
      json['imagePath'] ?? '',
      type: json['type'],
      currentPage: json['current_page'] ?? json['currentPage'],
      totalPages: json['total_pages'] ?? json['totalPages'],
      totalItems: json['total_items'] ?? json['totalItems'],
    );
  }

  // Add toJson method for caching
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'msg': msg,
      'imagePath': imagePath,
      'sub_category': sub_category.map((x) => x.toJson()).toList(),
      'type': type,
      'current_page': currentPage,
      'total_pages': totalPages,
      'total_items': totalItems,
    };
  }
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
  String name = "";
  String slug = "";
  String image = "";
  int is_featured;
  int is_trending;
  int is_recommended;

  // Playlist-specific fields
  String playlist_name = "";
  int user_id;
  String? song_list;
  String? image_url;
  String? created_at;
  String? updated_at;

  // Audio list for playlists
  List<dynamic>? audios;

  // Artist information for songs
  String? artist_id;
  String? lyrics;
  List<Artist>? artists;

  SubData(
    this.id,
    this.name,
    this.slug,
    this.image,
    this.is_featured,
    this.is_trending,
    this.is_recommended, {
    this.playlist_name = "",
    this.user_id = 0,
    this.song_list,
    this.image_url,
    this.created_at,
    this.updated_at,
    this.audios,
    this.artist_id,
    this.lyrics,
    this.artists,
  });

  factory SubData.fromJson(Map<String, dynamic> json) {
    // Parse artists array if present
    List<Artist>? artistsList;
    if (json.containsKey('artists') && json['artists'] != null) {
      final artistsData = json['artists'];
      if (artistsData is List) {
        artistsList =
            artistsData
                .map(
                  (artistJson) =>
                      Artist.fromJson(artistJson as Map<String, dynamic>),
                )
                .toList();
      }
    }

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
      image_url: json['image_url'],
      created_at: json['created_at'],
      updated_at: json['updated_at'],
      audios: json['audios'],
      artist_id: json['artist_id'],
      lyrics: json['lyrics'],
      artists: artistsList,
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
      'created_at': created_at,
      'updated_at': updated_at,
      'audios': audios,
      'artist_id': artist_id,
      'lyrics': lyrics,
      'artists': artists?.map((a) => a.toJson()).toList(),
    };
  }
}
