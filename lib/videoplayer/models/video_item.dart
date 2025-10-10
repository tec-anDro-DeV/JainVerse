class VideoItem {
  final int id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String duration;
  final String? description;
  final int? channelId;
  final String? channelName;
  final String? channelImageUrl;
  final DateTime? createdAt;

  VideoItem({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    this.description,
    this.channelId,
    this.channelName,
    this.channelImageUrl,
    this.createdAt,
  });

  factory VideoItem.fromJson(Map<String, dynamic> j) {
    // Support multiple possible key names coming from the API
    String extractString(Map<String, dynamic> map, List<String> keys) {
      for (final k in keys) {
        if (map.containsKey(k) && map[k] != null) return map[k].toString();
      }
      return '';
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.tryParse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return VideoItem(
      id: parseInt(j['id']) ?? 0,
      title: extractString(j, ['title', 'name']),
      videoUrl: extractString(j, ['video_url', 'video']),
      thumbnailUrl: extractString(j, [
        'thumbnail_url',
        'thumbnail_image',
        'thumbnail',
      ]),
      duration: extractString(j, ['duration']),
      description:
          j['description'] != null ? j['description'].toString() : null,
      channelId: parseInt(j['channel_id']),
      channelName:
          j['channel_name'] != null ? j['channel_name'].toString() : null,
      channelImageUrl:
          j['channel_image_url'] != null
              ? j['channel_image_url'].toString()
              : null,
      createdAt: parseDate(j['created_at']),
    );
  }
}
