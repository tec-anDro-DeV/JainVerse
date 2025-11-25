class ChannelModel {
  final int id;
  final int userId;
  final String image;
  final String imageUrl;
  final String name;
  final String handle;
  final String? bannerImage;
  final String bannerUrl;
  final String? description;
  final int status;
  final String createdAt;
  final String updatedAt;
  final int subscribersCount;

  ChannelModel({
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
      id: json['id'],
      userId: json['user_id'],
      image: json['image'] ?? '',
      imageUrl: json['image_url'] ?? '',
      name: json['name'] ?? '',
      handle: json['handle'] ?? '',
      bannerImage: json['banner_image'],
      bannerUrl: json['banner_url'] ?? '',
      description: json['description'],
      status: json['status'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      subscribersCount: json['subscribers_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
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
