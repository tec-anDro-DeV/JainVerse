import 'dart:convert';

class ModelCatSubcatMusic {
  bool status;
  String msg;
  List<DataCat> data;

  ModelCatSubcatMusic(this.status, this.msg, this.data);

  factory ModelCatSubcatMusic.fromJson(dynamic json) {
    // Handle API returning list directly or object with 'data'
    if (json is List) {
      final List<DataCat> d =
          json.map((x) => DataCat.fromJson(x as Map<String, dynamic>)).toList();
      return ModelCatSubcatMusic(true, '', d);
    } else if (json is Map<String, dynamic>) {
      // Existing logic for object response
      List<DataCat> d = [];
      if (json["data"] != null && json["data"] is List) {
        d = (json["data"] as List).map((x) => DataCat.fromJson(x)).toList();
      }
      return ModelCatSubcatMusic(json['status'] ?? false, json['msg'] ?? '', d);
    } else {
      // Unexpected JSON format
      return ModelCatSubcatMusic(false, 'Invalid JSON format', []);
    }
  }

  // Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'msg': msg,
      'data': data.map((cat) => cat.toJson()).toList(),
    };
  }
}

class DataCat {
  String cat_name = "";
  String imagePath = "";
  List<SubData> sub_category;

  DataCat(this.cat_name, this.imagePath, this.sub_category);

  factory DataCat.fromJson(Map<String, dynamic> json) {
    // Optimize list parsing with null safety
    List<SubData> d = [];
    if (json["sub_category"] != null && json["sub_category"] is List) {
      d =
          (json["sub_category"] as List)
              .map((x) => SubData.fromJson(x))
              .toList();
    }

    return DataCat(json['cat_name'] ?? '', json['imagePath'] ?? '', d);
  }

  // Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'cat_name': cat_name,
      'imagePath': imagePath,
      'sub_category': sub_category.map((subCat) => subCat.toJson()).toList(),
    };
  }
}

class SubData {
  int id;
  String name = "";
  String slug = "";
  String image = "";
  List<SongData>? song_list;

  // New fields for enhanced data
  String? duration; // For songs
  String? audio; // For songs
  String? language; // For songs
  List<Artist>? artist; // For songs (may be list or object)
  Genre? genre; // For songs
  String? description; // For albums

  SubData(
    this.id,
    this.name,
    this.slug,
    this.image,
    this.song_list, {
    this.duration,
    this.audio,
    this.language,
    this.artist,
    this.genre,
    this.description,
  });

  factory SubData.fromJson(Map<String, dynamic> json) {
    // Handle song_list with efficient null handling
    List<SongData>? songList;
    if (json.containsKey('song_list') && json['song_list'] != null) {
      if (json['song_list'] is List) {
        songList =
            (json['song_list'] as List)
                .map((x) => SongData.fromJson(x))
                .toList();
      }
    }

    // Parse artist, handle both list and single object
    List<Artist>? artistList;
    if (json.containsKey('artist') && json['artist'] != null) {
      final art = json['artist'];
      if (art is List) {
        artistList =
            art.map((e) => Artist.fromJson(e as Map<String, dynamic>)).toList();
      } else if (art is Map<String, dynamic>) {
        artistList = [Artist.fromJson(art)];
      }
    }

    // Parse genre if present
    Genre? genre;
    if (json.containsKey('genre') && json['genre'] != null) {
      genre = Genre.fromJson(json['genre']);
    }

    return SubData(
      json['id'] ?? 0,
      json['name'] ?? '',
      json['slug'] ?? '',
      json['image'] ?? '',
      songList,
      duration: json['duration'],
      audio: json['audio'],
      language: json['language'],
      artist: artistList,
      genre: genre,
      description: json['description'],
    );
  }

  // Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'image': image,
      'song_list': song_list?.map((song) => song.toJson()).toList(),
      'duration': duration,
      'audio': audio,
      'language': language,
      'artist': artist?.map((a) => a.toJson()).toList(),
      'genre': genre?.toJson(),
      'description': description,
    };
  }
}

class SongData {
  int id;
  String name = "";
  String slug = "";
  String image = "";
  String audio_duration = "";
  String audio = "";
  String audio_language = "";
  int audio_genre_id;
  List<String> artist_id = [];

  SongData(
    this.id,
    this.name,
    this.slug,
    this.image,
    this.audio_duration,
    this.audio,
    this.audio_language,
    this.audio_genre_id,
    this.artist_id,
  );

  factory SongData.fromJson(Map<String, dynamic> json) {
    // Parse artist_id into list
    List<String> artistIds = [];
    final dynamic aField = json['artist_id'];
    if (aField != null) {
      if (aField is List) {
        artistIds = aField.map((e) => e.toString()).toList();
      } else if (aField is String) {
        try {
          final parsed = jsonDecode(aField);
          if (parsed is List) {
            artistIds = parsed.map((e) => e.toString()).toList();
          } else {
            artistIds = [aField];
          }
        } catch (_) {
          artistIds = [aField];
        }
      }
    }

    return SongData(
      json['id'] ?? 0,
      json['name'] ?? '',
      json['slug'] ?? '',
      json['image'] ?? '',
      json['audio_duration'] ?? '',
      json['audio'] ?? '',
      json['audio_language'] ?? '',
      json['audio_genre_id'] ?? 0,
      artistIds,
    );
  }

  // Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'image': image,
      'audio_duration': audio_duration,
      'audio': audio,
      'audio_language': audio_language,
      'audio_genre_id': audio_genre_id,
      'artist_id': artist_id,
    };
  }
}

// Artist model for handling artist information
class Artist {
  int id;
  String name;
  String? artist_name;
  String slug;
  String image;
  String? bio;

  Artist({
    required this.id,
    required this.name,
    this.artist_name,
    required this.slug,
    required this.image,
    this.bio,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] ?? 0,
      name: json['name'] ?? (json['artist_name'] ?? ''),
      artist_name: json['artist_name'],
      slug: json['slug'] ?? '',
      image: json['image'] ?? '',
      bio: json['bio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist_name': artist_name,
      'slug': slug,
      'image': image,
      'bio': bio,
    };
  }
}

// Genre model for handling genre information
class Genre {
  int id;
  String name;
  String slug;
  String image;

  Genre({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      image: json['image'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'slug': slug, 'image': image};
  }
}
