import 'package:jainverse/Model/SongModel.dart';

class PlaylistSongModel {
  final int id;
  final String name;
  final String slug;
  final String image;
  final List<SongModel> songList;

  PlaylistSongModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
    required this.songList,
  });

  factory PlaylistSongModel.fromJson(Map<String, dynamic> json) {
    List<SongModel> songs = [];

    if (json['song_list'] != null && json['song_list'] is List) {
      songs =
          (json['song_list'] as List)
              .map((songJson) => SongModel.fromJson(songJson))
              .toList();
    }

    return PlaylistSongModel(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      image: json['image'] ?? '',
      songList: songs,
    );
  }
}
