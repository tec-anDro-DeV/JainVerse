/// Model for a video channel
class ChannelItem {
  final int id;
  final int userId;
  final String name;
  final String handle;
  final String imageUrl;
  final String? bannerUrl;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? subscribed;
  final bool isOwn;

  ChannelItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.handle,
    required this.imageUrl,
    this.bannerUrl,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.subscribed,
    this.isOwn = false,
  });

  factory ChannelItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.tryParse(v.toString());
      } catch (_) {
        return null;
      }
    }

    bool? parseSubscribed(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is int) return v == 1;
      final s = v.toString().toLowerCase().trim();
      if (s == '1' || s == 'true') return true;
      if (s == '0' || s == 'false') return false;
      return null;
    }

    bool parseIsOwn(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v == 1;
      final s = v.toString().toLowerCase().trim();
      if (s == '1' || s == 'true') return true;
      return false;
    }

    return ChannelItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      bannerUrl: json['banner_url']?.toString(),
      description: json['description']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      subscribed: parseSubscribed(json['subscribed']),
      isOwn: parseIsOwn(json['is_own']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'handle': handle,
      'image_url': imageUrl,
      'banner_url': bannerUrl,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'subscribed': subscribed,
      'is_own': isOwn,
    };
  }

  ChannelItem copyWith({
    int? id,
    int? userId,
    String? name,
    String? handle,
    String? imageUrl,
    String? bannerUrl,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? subscribed,
    bool? isOwn,
  }) {
    return ChannelItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      imageUrl: imageUrl ?? this.imageUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscribed: subscribed ?? this.subscribed,
      isOwn: isOwn ?? this.isOwn,
    );
  }
}
