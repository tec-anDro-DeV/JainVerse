class ChannelModel {
  final int id;
  final int userId;
  final String image;
  final String imageUrl;
  final String name;
  final String handle;
  final String description;
  final String bannerImage;
  final String bannerImageUrl;
  final String createdAt;
  final String updatedAt;
  final int totalVideos;
  final int totalSubscribers;
  final int totalViews;

  ChannelModel({
    required this.id,
    required this.userId,
    required this.image,
    required this.imageUrl,
    required this.name,
    required this.handle,
    this.description = '',
    this.bannerImage = '',
    this.bannerImageUrl = '',
    required this.createdAt,
    required this.updatedAt,
    this.totalVideos = 0,
    this.totalSubscribers = 0,
    this.totalViews = 0,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      image: json['image'] ?? '',
      imageUrl: json['image_url'] ?? '',
      name: json['name'] ?? '',
      handle: json['handle'] ?? '',
      description: json['description'] ?? '',
      bannerImage: json['banner_image'] ?? '',
      // Some API responses use `banner_image_url` and some use `banner_url`.
      // Accept both so the UI receives the correct banner URL.
      bannerImageUrl: json['banner_image_url'] ?? json['banner_url'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      totalVideos:
          json['total_videos'] is int
              ? json['total_videos'] as int
              : int.tryParse((json['total_videos'] ?? '').toString()) ?? 0,
      totalSubscribers:
          json['total_subscribers'] is int
              ? json['total_subscribers'] as int
              : int.tryParse((json['total_subscribers'] ?? '').toString()) ?? 0,
      totalViews:
          json['total_views'] is int
              ? json['total_views'] as int
              : int.tryParse((json['total_views'] ?? '').toString()) ?? 0,
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
      'description': description,
      'banner_image': bannerImage,
      'banner_image_url': bannerImageUrl,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'total_videos': totalVideos,
      'total_subscribers': totalSubscribers,
      'total_views': totalViews,
    };
  }
}
