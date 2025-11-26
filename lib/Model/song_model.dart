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
  int isFavourite;

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
    final image = json['image_url'] ?? json['image'] ?? '';
    final audio = json['audio_url'] ?? json['audio'] ?? '';
    final duration = json['audio_duration'] ?? json['audioDuration'] ?? '';
    final title = json['audio_title'] ?? json['title'] ?? '';
    final slug = json['audio_slug'] ?? json['slug'] ?? '';
    final channelIdValue =
        json['channel_id'] ??
        json['channelId'] ??
        (json['artist_id'] != null
            ? int.tryParse(json['artist_id'].toString())
            : null);
    final channelNameValue =
        json['channel_name'] ??
        json['channelName'] ??
        json['artists_name'] ??
        '';
    final channelImageValue =
        json['channel_image_url'] ??
        json['channelImageUrl'] ??
        json['channel_image'] ??
        image;

    return SongModel(
      id: json['id'] ?? 0,
      channelId: channelIdValue is int
          ? channelIdValue
          : int.tryParse(channelIdValue?.toString() ?? '0') ?? 0,
      imageUrl: image,
      bannerImage: json['banner_image'],
      audioUrl: audio,
      audioDuration: duration,
      audioTitle: title,
      audioSlug: slug,
      copyright: json['copyright'] ?? '',
      listeningCount: json['listening_count'] ?? json['listeningCount'] ?? 0,
      lyrics: json['lyrics'],
      description: json['description'] ?? '',
      releaseDate: json['release_date'] ?? json['created_at'] ?? '',
      isFeatured: json['is_featured'] ?? json['isFeatured'] ?? 0,
      isTrending: json['is_trending'] ?? json['isTrending'] ?? 0,
      isRecommended: json['is_recommended'] ?? json['isRecommended'] ?? 0,
      channelName: channelNameValue,
      channelHandle:
          json['channel_handle'] ??
          json['channelHandle'] ??
          json['artist_id']?.toString() ??
          '',
      channelImageUrl: channelImageValue,
      isFavourite:
          json['is_favourite'] ??
          json['isFavourite'] ??
          (json['favourite'] is num
              ? (json['favourite'] as num).toInt()
              : int.tryParse(json['favourite']?.toString() ?? '0') ?? 0),
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

  /// Legacy factory matching the old `DataMusic` constructor signature so we
  /// can progressively migrate call sites without losing data fidelity.
  factory SongModel.legacy(
    int id,
    String image,
    String audio,
    String audioDuration,
    String audioTitle,
    String audioSlug,
    int audioGenreId,
    String artistId,
    String artistsName,
    String audioLanguage,
    int listeningCount,
    int isFeatured,
    int isTrending,
    String createdAt,
    int isRecommended,
    String favourite,
    String downloadPrice,
    String lyrics,
  ) {
    final parsedChannelId = int.tryParse(artistId) ?? 0;
    final favouriteValue =
        int.tryParse(favourite) ??
        (favourite == 'true'
            ? 1
            : favourite == 'false'
            ? 0
            : 0);

    return SongModel(
      id: id,
      channelId: parsedChannelId,
      imageUrl: image,
      bannerImage: null,
      audioUrl: audio,
      audioDuration: audioDuration,
      audioTitle: audioTitle,
      audioSlug: audioSlug,
      copyright: '',
      listeningCount: listeningCount,
      lyrics: lyrics.isNotEmpty ? lyrics : null,
      description: '',
      releaseDate: createdAt,
      isFeatured: isFeatured,
      isTrending: isTrending,
      isRecommended: isRecommended,
      channelName: artistsName,
      channelHandle: artistId,
      channelImageUrl: image,
      isFavourite: favouriteValue,
    );
  }
}

/// Temporary legacy bridge so existing widgets can continue using the old
/// snake_case field names until they are migrated. All values map back to the
/// canonical SongModel properties to keep the app on the new data contract.
extension LegacySongModelFields on SongModel {
  String get image => imageUrl;
  String get audio => audioUrl;
  String get audio_duration => audioDuration;
  String get audio_title => audioTitle;
  String get audio_slug => audioSlug;
  int get audio_genre_id => 0;
  String get artist_id => channelId.toString();
  String get artists_name => channelName;
  String get audio_language => '';
  int get listening_count => listeningCount;
  int get is_featured => isFeatured;
  int get is_trending => isTrending;
  String get created_at => releaseDate;
  int get is_recommended => isRecommended;
  String get favourite => isFavourite.toString();
  String get download_price => '';
  String get lyrics => this.lyrics ?? '';

  set favourite(String value) {
    isFavourite =
        int.tryParse(value) ??
        (value == 'true'
            ? 1
            : value == 'false'
            ? 0
            : 0);
  }
}
