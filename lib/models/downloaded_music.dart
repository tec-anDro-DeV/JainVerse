import 'package:hive/hive.dart';

part 'downloaded_music.g.dart';

/// Clean model for downloaded music metadata
@HiveType(typeId: 1)
class DownloadedMusic extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String artist;

  @HiveField(3)
  final String albumName;

  @HiveField(4)
  final String imageUrl;

  @HiveField(5)
  final String audioUrl;

  @HiveField(6)
  final String duration;

  @HiveField(7)
  final String localAudioPath;

  @HiveField(8)
  final String localImagePath;

  @HiveField(9)
  final DateTime downloadedAt;

  @HiveField(10)
  final int fileSize;

  @HiveField(11)
  final bool isDownloadComplete;

  @HiveField(12)
  final String genre;

  @HiveField(13)
  final String language;

  DownloadedMusic({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumName,
    required this.imageUrl,
    required this.audioUrl,
    required this.duration,
    required this.localAudioPath,
    required this.localImagePath,
    required this.downloadedAt,
    required this.fileSize,
    required this.isDownloadComplete,
    this.genre = '',
    this.language = '',
  });

  /// Create from DataMusic model
  factory DownloadedMusic.fromDataMusic({
    required String id,
    required String title,
    required String artist,
    required String albumName,
    required String imageUrl,
    required String audioUrl,
    required String duration,
    required String localAudioPath,
    required String localImagePath,
    int fileSize = 0,
    bool isDownloadComplete = false,
    String genre = '',
    String language = '',
  }) {
    return DownloadedMusic(
      id: id,
      title: title,
      artist: artist,
      albumName: albumName,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      duration: duration,
      localAudioPath: localAudioPath,
      localImagePath: localImagePath,
      downloadedAt: DateTime.now(),
      fileSize: fileSize,
      isDownloadComplete: isDownloadComplete,
      genre: genre,
      language: language,
    );
  }

  /// Create a copy with updated fields
  DownloadedMusic copyWith({
    String? id,
    String? title,
    String? artist,
    String? albumName,
    String? imageUrl,
    String? audioUrl,
    String? duration,
    String? localAudioPath,
    String? localImagePath,
    DateTime? downloadedAt,
    int? fileSize,
    bool? isDownloadComplete,
    String? genre,
    String? language,
  }) {
    return DownloadedMusic(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumName: albumName ?? this.albumName,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      localImagePath: localImagePath ?? this.localImagePath,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      fileSize: fileSize ?? this.fileSize,
      isDownloadComplete: isDownloadComplete ?? this.isDownloadComplete,
      genre: genre ?? this.genre,
      language: language ?? this.language,
    );
  }

  @override
  String toString() {
    return 'DownloadedMusic(id: $id, title: $title, artist: $artist, isDownloadComplete: $isDownloadComplete)';
  }
}
