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
  final bool subscribed;
  final bool isOwn;

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
    required this.subscribed,
    this.isOwn = false,
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
      subscribersCount: json['total_subscribers'] ?? 0,
      subscribed: (json['subscribed'] ?? 0) == 1,
      isOwn: (json['is_own'] ?? 0) == 1,
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
    'total_subscribers': subscribersCount,
    'subscribed': subscribed ? 1 : 0,
    'is_own': isOwn ? 1 : 0,
  };
}

extension ChannelModelCopyWith on ChannelModel {
  ChannelModel copyWith({int? subscribersCount, bool? subscribed}) {
    return ChannelModel(
      id: id,
      userId: userId,
      image: image,
      imageUrl: imageUrl,
      name: name,
      handle: handle,
      bannerImage: bannerImage,
      bannerUrl: bannerUrl,
      description: description,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      subscribersCount: subscribersCount ?? this.subscribersCount,
      subscribed: subscribed ?? this.subscribed,
      isOwn: this.isOwn,
    );
  }
}
