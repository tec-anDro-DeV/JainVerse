import 'package:audio_service/audio_service.dart';

import '../../../Model/ModelMusicList.dart';
import '../../../models/song_playback_payload.dart';
import '../common/audio_constants.dart';
import '../common/audio_logger.dart';
import '../sources/song_source_resolver.dart';

/// Responsible for translating domain payloads into fully-formed [MediaItem]s.
class AudioQueueBuilder {
  AudioQueueBuilder({SongSourceResolver? resolver})
    : _resolver = resolver ?? SongSourceResolver();

  final SongSourceResolver _resolver;

  Future<List<MediaItem>> buildFromPayloads(
    List<SongPlaybackPayload> payloads,
  ) async {
    final List<MediaItem> items = [];

    for (final payload in payloads) {
      if (payload.audioUrl.isEmpty && payload.id.isEmpty) {
        AudioLogger.log(
          '[WARN][AudioQueueBuilder] Skipping payload with no audio id',
        );
        continue;
      }
      items.add(_mediaItemFromPayload(payload));
    }

    return items;
  }

  Future<List<MediaItem>> buildFromDataMusic({
    required List<DataMusic> musicList,
    String contextType = 'playlist',
    String? contextId,
  }) async {
    final List<MediaItem> items = [];
    for (final entry in musicList.asMap().entries) {
      final item = await _resolver.resolveDataMusic(
        music: entry.value,
        queueIndex: entry.key,
        contextType: contextType,
        contextId: contextId,
      );
      items.add(item);
    }
    return items;
  }

  Future<MediaItem?> buildSingleItem({
    required DataMusic track,
    String contextType = 'playlist',
    String? contextId,
  }) async {
    final items = await buildFromDataMusic(
      musicList: <DataMusic>[track],
      contextType: contextType,
      contextId: contextId,
    );
    if (items.isEmpty) {
      AudioLogger.log(
        '[WARN][AudioQueueBuilder] Failed to build media item for ${track.audio_title}',
      );
      return null;
    }
    return items.first;
  }

  MediaItem _mediaItemFromPayload(SongPlaybackPayload payload) {
    final extras = Map<String, dynamic>.from(payload.extras);
    extras['audio_id'] ??= payload.id;
    extras['actual_audio_url'] ??= payload.audioUrl;
    if (payload.imageUrl.isNotEmpty) {
      extras['image_url'] = payload.imageUrl;
    }
    if (payload.channelName != null) {
      extras['channel_name'] = payload.channelName;
    }
    if (payload.channelImageUrl != null) {
      extras['channel_image_url'] = payload.channelImageUrl;
    }
    extras['playback_source'] ??= 'instant_play';

    return MediaItem(
      id: payload.audioUrl.isNotEmpty ? payload.audioUrl : payload.id,
      title: payload.title,
      artist: payload.channelName ?? 'Unknown Artist',
      album: payload.channelName ?? 'JainVerse',
      duration: payload.duration ?? AudioConstants.defaultSongDuration,
      artUri: payload.imageUrl.isNotEmpty
          ? Uri.tryParse(payload.imageUrl)
          : null,
      extras: extras,
    );
  }
}
