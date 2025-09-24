import 'package:audio_service/audio_service.dart';

/// Media state combining MediaItem with playback position
class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  const MediaState(this.mediaItem, this.position);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaState &&
          runtimeType == other.runtimeType &&
          mediaItem == other.mediaItem &&
          position == other.position;

  @override
  int get hashCode => mediaItem.hashCode ^ position.hashCode;

  @override
  String toString() {
    return 'MediaState{mediaItem: ${mediaItem?.title}, position: $position}';
  }

  MediaState copyWith({MediaItem? mediaItem, Duration? position}) {
    return MediaState(mediaItem ?? this.mediaItem, position ?? this.position);
  }
}

/// Download progress data model
class DownloadProgress {
  final String songId;
  final String title;
  final double progress;
  final DownloadStatus status;
  final String? errorMessage;

  const DownloadProgress({
    required this.songId,
    required this.title,
    required this.progress,
    required this.status,
    this.errorMessage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadProgress &&
          runtimeType == other.runtimeType &&
          songId == other.songId &&
          title == other.title &&
          progress == other.progress &&
          status == other.status &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      songId.hashCode ^
      title.hashCode ^
      progress.hashCode ^
      status.hashCode ^
      errorMessage.hashCode;

  DownloadProgress copyWith({
    String? songId,
    String? title,
    double? progress,
    DownloadStatus? status,
    String? errorMessage,
  }) {
    return DownloadProgress(
      songId: songId ?? this.songId,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Download status enumeration
enum DownloadStatus {
  notStarted,
  starting,
  downloading,
  completed,
  failed,
  paused,
  cancelled,
}

/// Payment gateway data model
class PaymentGateway {
  final String id;
  final String name;
  final String imagePath;
  final bool isEnabled;
  final Map<String, String> config;

  const PaymentGateway({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.isEnabled,
    required this.config,
  });

  factory PaymentGateway.fromJson(Map<String, dynamic> json) {
    return PaymentGateway(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imagePath: json['image_path'] ?? '',
      isEnabled: json['is_enabled'] ?? false,
      config: Map<String, String>.from(json['config'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_path': imagePath,
      'is_enabled': isEnabled,
      'config': config,
    };
  }
}

/// Audio conversion data model for different quality/formats
class AudioConversionData {
  final String originalUrl;
  final String convertedUrl;
  final String quality;
  final String format;
  final int bitrate;
  final DateTime createdAt;

  const AudioConversionData({
    required this.originalUrl,
    required this.convertedUrl,
    required this.quality,
    required this.format,
    required this.bitrate,
    required this.createdAt,
  });

  factory AudioConversionData.fromJson(Map<String, dynamic> json) {
    return AudioConversionData(
      originalUrl: json['original_url'] ?? '',
      convertedUrl: json['converted_url'] ?? '',
      quality: json['quality'] ?? '',
      format: json['format'] ?? '',
      bitrate: json['bitrate'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'original_url': originalUrl,
      'converted_url': convertedUrl,
      'quality': quality,
      'format': format,
      'bitrate': bitrate,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
