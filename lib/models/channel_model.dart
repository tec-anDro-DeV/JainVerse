class ChannelModel {
  final int id;
  final int userId;
  final String image;
  final String imageUrl;
  final String name;
  final String handle;
  final String createdAt;
  final String updatedAt;

  ChannelModel({
    required this.id,
    required this.userId,
    required this.image,
    required this.imageUrl,
    required this.name,
    required this.handle,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      image: json['image'] ?? '',
      imageUrl: json['image_url'] ?? '',
      name: json['name'] ?? '',
      handle: json['handle'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
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
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
