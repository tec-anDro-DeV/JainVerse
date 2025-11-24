/// Root response for the unified home endpoint.
class HomeResponse {
  final bool status;
  final String message;
  final HomeData? data;

  const HomeResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory HomeResponse.fromJson(Map<String, dynamic> json) {
    return HomeResponse(
      status: json['status'] == true,
      message: json['msg']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic>
          ? HomeData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'msg': message, 'data': data?.toJson()};
  }
}

/// Container for all sections exposed by the home endpoint.
class HomeData {
  final List<VideoModel> featuredVideos;
  final List<ChannelModel> channels;
  final List<SongModel> featuredSongs;
  final List<SongModel> latestSongs;
  final List<VideoModel> popularVideos;
  final List<GenreModel> trendingGenres;
  final List<VideoModel> newVideos;

  const HomeData({
    this.featuredVideos = const [],
    this.channels = const [],
    this.featuredSongs = const [],
    this.latestSongs = const [],
    this.popularVideos = const [],
    this.trendingGenres = const [],
    this.newVideos = const [],
  });

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      featuredVideos: _parseList(json['featuredVideos'], VideoModel.fromJson),
      channels: _parseList(json['channels'], ChannelModel.fromJson),
      featuredSongs: _parseList(json['featuredSongs'], SongModel.fromJson),
      latestSongs: _parseList(json['latestSongs'], SongModel.fromJson),
      popularVideos: _parseList(json['popularVideos'], VideoModel.fromJson),
      trendingGenres: _parseList(json['trendingGenres'], GenreModel.fromJson),
      newVideos: _parseList(json['newVideos'], VideoModel.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'featuredVideos': featuredVideos.map((e) => e.toJson()).toList(),
      'channels': channels.map((e) => e.toJson()).toList(),
      'featuredSongs': featuredSongs.map((e) => e.toJson()).toList(),
      'latestSongs': latestSongs.map((e) => e.toJson()).toList(),
      'popularVideos': popularVideos.map((e) => e.toJson()).toList(),
      'trendingGenres': trendingGenres.map((e) => e.toJson()).toList(),
      'newVideos': newVideos.map((e) => e.toJson()).toList(),
    };
  }
}

/// Video section model.
class VideoModel {
  final int? id;
  final int? channelId;
  final String title;
  final String? description;
  final String video;
  final String videoUrl;
  final String thumbnailImage;
  final String thumbnailUrl;
  final int? madeForKids;
  final int? ageRestriction;
  final String status;
  final String? rejectReason;
  final String duration;
  final int? block;
  final String? reason;
  final double? videoSize;
  final String? isFeatured;
  final String createdAt;
  final String updatedAt;
  final int? userId;
  final String image;
  final String imageUrl;
  final String name;
  final String handle;
  final String? bannerImage;
  final String? bannerUrl;
  final String? channelName;
  final String? channelHandle;
  final String? channelImageUrl;
  final int? totalViews;

  const VideoModel({
    required this.id,
    required this.channelId,
    required this.title,
    required this.description,
    required this.video,
    required this.videoUrl,
    required this.thumbnailImage,
    required this.thumbnailUrl,
    required this.madeForKids,
    required this.ageRestriction,
    required this.status,
    required this.rejectReason,
    required this.duration,
    required this.block,
    required this.reason,
    required this.videoSize,
    required this.isFeatured,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.image,
    required this.imageUrl,
    required this.name,
    required this.handle,
    required this.bannerImage,
    required this.bannerUrl,
    this.channelName,
    this.channelHandle,
    this.channelImageUrl,
    this.totalViews,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: _parseInt(json['id']),
      channelId: _parseInt(json['channel_id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      video: json['video']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      thumbnailImage: json['thumbnail_image']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      madeForKids: _parseInt(json['made_for_kids']),
      ageRestriction: _parseInt(json['age_restriction']),
      status: json['status']?.toString() ?? '',
      rejectReason: json['reject_reason']?.toString(),
      duration: json['duration']?.toString() ?? '',
      block: _parseInt(json['block']),
      reason: json['reason']?.toString(),
      videoSize: _parseDouble(json['video_size']),
      isFeatured: json['is_featured']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      userId: _parseInt(json['user_id']),
      image: json['image']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      bannerImage: json['banner_image']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      channelName: json['channel_name']?.toString(),
      channelHandle: json['channel_handle']?.toString(),
      channelImageUrl: json['channel_image_url']?.toString(),
      totalViews: _parseInt(json['total_views']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channel_id': channelId,
      'title': title,
      'description': description,
      'video': video,
      'video_url': videoUrl,
      'thumbnail_image': thumbnailImage,
      'thumbnail_url': thumbnailUrl,
      'made_for_kids': madeForKids,
      'age_restriction': ageRestriction,
      'status': status,
      'reject_reason': rejectReason,
      'duration': duration,
      'block': block,
      'reason': reason,
      'video_size': videoSize,
      'is_featured': isFeatured,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'user_id': userId,
      'image': image,
      'image_url': imageUrl,
      'name': name,
      'handle': handle,
      'banner_image': bannerImage,
      'banner_url': bannerUrl,
      'channel_name': channelName,
      'channel_handle': channelHandle,
      'channel_image_url': channelImageUrl,
      'total_views': totalViews,
    };
  }
}

/// Channel / creator listing model.
class ChannelModel {
  final int? id;
  final int? userId;
  final String image;
  final String imageUrl;
  final String name;
  final String handle;
  final String? bannerImage;
  final String? bannerUrl;
  final String? description;
  final int? status;
  final String createdAt;
  final String updatedAt;
  final int? subscribersCount;

  const ChannelModel({
    required this.id,
    required this.userId,
    required this.image,
    required this.imageUrl,
    required this.name,
    required this.handle,
    required this.bannerImage,
    required this.bannerUrl,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.subscribersCount,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: _parseInt(json['id']),
      userId: _parseInt(json['user_id']),
      image: json['image']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      bannerImage: json['banner_image']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      description: json['description']?.toString(),
      status: _parseInt(json['status']),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      subscribersCount: _parseInt(json['subscribers_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'image': image,
      'image_url': imageUrl,
      'name': name,
      'handle': handle,
      'banner_image': bannerImage,
      'banner_url': bannerUrl,
      'description': description,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'subscribers_count': subscribersCount,
    };
  }
}

/// Song / audio listing model.
class SongModel {
  final int? id;
  final int? userId;
  final int? channelId;
  final String image;
  final String imageUrl;
  final String? bannerImage;
  final String? bannerImageUrl;
  final String audio;
  final String audioUrl;
  final String? isPrice;
  final String? downloadPrice;
  final String audioDuration;
  final int? awsUpload;
  final int? isExternal;
  final String? externalUrl;
  final String title;
  final String slug;
  final int? audioGenreId;
  final String? artistId;
  final String? audioLanguage;
  final String? copyright;
  final int? listeningCount;
  final int? isFeatured;
  final int? isTrending;
  final int? isRecommended;
  final int? status;
  final String? lyrics;
  final String? description;
  final String? releaseDate;
  final double? audioSize;
  final String createdAt;
  final String updatedAt;
  final String channelName;
  final String channelHandle;
  final String channelImageUrl;

  const SongModel({
    required this.id,
    required this.userId,
    required this.channelId,
    required this.image,
    required this.imageUrl,
    required this.bannerImage,
    required this.bannerImageUrl,
    required this.audio,
    required this.audioUrl,
    required this.isPrice,
    required this.downloadPrice,
    required this.audioDuration,
    required this.awsUpload,
    required this.isExternal,
    required this.externalUrl,
    required this.title,
    required this.slug,
    required this.audioGenreId,
    required this.artistId,
    required this.audioLanguage,
    required this.copyright,
    required this.listeningCount,
    required this.isFeatured,
    required this.isTrending,
    required this.isRecommended,
    required this.status,
    required this.lyrics,
    required this.description,
    required this.releaseDate,
    required this.audioSize,
    required this.createdAt,
    required this.updatedAt,
    required this.channelName,
    required this.channelHandle,
    required this.channelImageUrl,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: _parseInt(json['id']),
      userId: _parseInt(json['user_id']),
      channelId: _parseInt(json['channel_id']),
      image: json['image']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      bannerImage: json['banner_image']?.toString(),
      bannerImageUrl: json['banner_image_url']?.toString(),
      audio: json['audio']?.toString() ?? '',
      audioUrl: json['audio_url']?.toString() ?? '',
      isPrice: json['is_price']?.toString(),
      downloadPrice: json['download_price']?.toString(),
      audioDuration: json['audio_duration']?.toString() ?? '',
      awsUpload: _parseInt(json['aws_upload']),
      isExternal: _parseInt(json['is_external']),
      externalUrl: json['external_url']?.toString(),
      title: json['audio_title']?.toString() ?? '',
      slug: json['audio_slug']?.toString() ?? '',
      audioGenreId: _parseInt(json['audio_genre_id']),
      artistId: json['artist_id']?.toString(),
      audioLanguage: json['audio_language']?.toString(),
      copyright: json['copyright']?.toString(),
      listeningCount: _parseInt(json['listening_count']),
      isFeatured: _parseInt(json['is_featured']),
      isTrending: _parseInt(json['is_trending']),
      isRecommended: _parseInt(json['is_recommended']),
      status: _parseInt(json['status']),
      lyrics: json['lyrics']?.toString(),
      description: json['description']?.toString(),
      releaseDate: json['release_date']?.toString(),
      audioSize: _parseDouble(json['audio_size']),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      channelName: json['channel_name']?.toString() ?? '',
      channelHandle: json['channel_handle']?.toString() ?? '',
      channelImageUrl: json['channel_image_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'channel_id': channelId,
      'image': image,
      'image_url': imageUrl,
      'banner_image': bannerImage,
      'banner_image_url': bannerImageUrl,
      'audio': audio,
      'audio_url': audioUrl,
      'is_price': isPrice,
      'download_price': downloadPrice,
      'audio_duration': audioDuration,
      'aws_upload': awsUpload,
      'is_external': isExternal,
      'external_url': externalUrl,
      'audio_title': title,
      'audio_slug': slug,
      'audio_genre_id': audioGenreId,
      'artist_id': artistId,
      'audio_language': audioLanguage,
      'copyright': copyright,
      'listening_count': listeningCount,
      'is_featured': isFeatured,
      'is_trending': isTrending,
      'is_recommended': isRecommended,
      'status': status,
      'lyrics': lyrics,
      'description': description,
      'release_date': releaseDate,
      'audio_size': audioSize,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'channel_name': channelName,
      'channel_handle': channelHandle,
      'channel_image_url': channelImageUrl,
    };
  }
}

/// Genre listing model.
class GenreModel {
  final int? id;
  final String name;
  final String? slug;
  final String? description;
  final String? image;
  final String? imageUrl;

  const GenreModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.image,
    required this.imageUrl,
  });

  factory GenreModel.fromJson(Map<String, dynamic> json) {
    return GenreModel(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'image': image,
      'image_url': imageUrl,
    };
  }
}

List<T> _parseList<T>(
  dynamic source,
  T Function(Map<String, dynamic>) builder,
) {
  if (source is List) {
    return source
        .whereType<Map<String, dynamic>>()
        .map((item) => builder(item))
        .toList(growable: false);
  }
  return const [];
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString());
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
