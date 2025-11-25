class VideoModel {
  final int id;
  final int channelId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String duration;
  final String createdAt;

  final String channelName;
  final String channelHandle;
  final String channelImageUrl;

  final int? like;
  final int? subscribed;
  final int totalViews;
  final int isOwn;
  final int report;
  final int totalLikes;
  final int totalSubscribers;

  VideoModel({
    required this.id,
    required this.channelId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.createdAt,
    required this.channelName,
    required this.channelHandle,
    required this.channelImageUrl,
    required this.like,
    required this.subscribed,
    required this.totalViews,
    required this.isOwn,
    required this.report,
    required this.totalLikes,
    required this.totalSubscribers,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'],
      channelId: json['channel_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['video_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      duration: json['duration'] ?? '',
      createdAt: json['created_at'] ?? '',
      channelName: json['channel_name'] ?? '',
      channelHandle: json['channel_handle'] ?? '',
      channelImageUrl: json['channel_image_url'] ?? '',
      like: json['like'],
      subscribed: json['subscribed'],
      totalViews: json['total_views'] ?? 0,
      isOwn: json['is_own'] ?? 0,
      report: json['report'] ?? 0,
      totalLikes: json['total_likes'] ?? 0,
      totalSubscribers: json['total_subscribers'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'channel_id': channelId,
    'title': title,
    'description': description,
    'video_url': videoUrl,
    'thumbnail_url': thumbnailUrl,
    'duration': duration,
    'created_at': createdAt,
    'channel_name': channelName,
    'channel_handle': channelHandle,
    'channel_image_url': channelImageUrl,
    'like': like,
    'subscribed': subscribed,
    'total_views': totalViews,
    'is_own': isOwn,
    'report': report,
    'total_likes': totalLikes,
    'total_subscribers': totalSubscribers,
  };
}
