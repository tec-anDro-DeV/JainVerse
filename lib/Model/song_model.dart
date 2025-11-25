class SongModel {
  final int id;
  final int channelId;
  final String imageUrl;
  final String? bannerImage;
  final String audioUrl;
  final String audioDuration;
  final String audioTitle;
  final String audioSlug;
  final String copyright;
  final int listeningCount;
  final String? lyrics;
  final String description;
  final String releaseDate;
  final int isFeatured;
  final int isTrending;
  final int isRecommended;
  final String channelName;
  final String channelHandle;
  final String channelImageUrl;
  final int isFavourite;

  SongModel({
    required this.id,
    required this.channelId,
    required this.imageUrl,
    required this.bannerImage,
    required this.audioUrl,
    required this.audioDuration,
    required this.audioTitle,
    required this.audioSlug,
    required this.copyright,
    required this.listeningCount,
    required this.lyrics,
    required this.description,
    required this.releaseDate,
    required this.isFeatured,
    required this.isTrending,
    required this.isRecommended,
    required this.channelName,
    required this.channelHandle,
    required this.channelImageUrl,
    required this.isFavourite,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'],
      channelId: json['channel_id'],
      imageUrl: json['image_url'] ?? '',
      bannerImage: json['banner_image'],
      audioUrl: json['audio_url'] ?? '',
      audioDuration: json['audio_duration'] ?? '',
      audioTitle: json['audio_title'] ?? '',
      audioSlug: json['audio_slug'] ?? '',
      copyright: json['copyright'] ?? '',
      listeningCount: json['listening_count'] ?? 0,
      lyrics: json['lyrics'],
      description: json['description'] ?? '',
      releaseDate: json['release_date'] ?? '',
      isFeatured: json['is_featured'] ?? 0,
      isTrending: json['is_trending'] ?? 0,
      isRecommended: json['is_recommended'] ?? 0,
      channelName: json['channel_name'] ?? '',
      channelHandle: json['channel_handle'] ?? '',
      channelImageUrl: json['channel_image_url'] ?? '',
      isFavourite: json['is_favourite'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'channel_id': channelId,
    'image_url': imageUrl,
    'banner_image': bannerImage,
    'audio_url': audioUrl,
    'audio_duration': audioDuration,
    'audio_title': audioTitle,
    'audio_slug': audioSlug,
    'copyright': copyright,
    'listening_count': listeningCount,
    'lyrics': lyrics,
    'description': description,
    'release_date': releaseDate,
    'is_featured': isFeatured,
    'is_trending': isTrending,
    'is_recommended': isRecommended,
    'channel_name': channelName,
    'channel_handle': channelHandle,
    'channel_image_url': channelImageUrl,
    'is_favourite': isFavourite,
  };
}
