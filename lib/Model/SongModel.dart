import 'dart:convert';

class SongModel {
  final int id;
  final String name;
  final String slug;
  final String image;
  final String audioDuration;
  final String audio;
  final String audioLanguage;
  final int audioGenreId;
  final List<String> artistIds;

  SongModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.image,
    required this.audioDuration,
    required this.audio,
    required this.audioLanguage,
    required this.audioGenreId,
    required this.artistIds,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    List<String> artistIdList = [];

    // Handle artist_id which can be a string representation of a JSON array
    if (json['artist_id'] != null) {
      if (json['artist_id'] is String) {
        try {
          // Try to parse the string as JSON
          List<dynamic> parsedList = jsonDecode(json['artist_id']);
          artistIdList = parsedList.map((item) => item.toString()).toList();
        } catch (e) {
          // If parsing fails, use the string as a single item
          artistIdList = [json['artist_id'].toString()];
        }
      } else if (json['artist_id'] is List) {
        // If it's already a list, convert items to string
        artistIdList =
            (json['artist_id'] as List).map((item) => item.toString()).toList();
      }
    }

    return SongModel(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      image: json['image'] ?? '',
      audioDuration: json['audio_duration'] ?? '',
      audio: json['audio'] ?? '',
      audioLanguage: json['audio_language'] ?? '',
      audioGenreId: json['audio_genre_id'] ?? 0,
      artistIds: artistIdList,
    );
  }
}
