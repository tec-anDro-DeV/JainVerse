import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:jainverse/utils/AppConstant.dart';

/// Creates [AudioSource] instances with consistent headers and tagging.
class AudioSourceFactory {
  AudioSourceFactory(this._mediaItemExpando);

  final Expando<MediaItem> _mediaItemExpando;

  AudioSource create(MediaItem mediaItem) {
    final uri = _resolveUri(mediaItem);

    final audioSource = AudioSource.uri(
      uri,
      headers: const {
        'User-Agent': 'JainVerse/1.0',
        'Accept': 'audio/*',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'max-age=3600',
        'Connection': 'close',
        'Accept-Ranges': 'bytes',
      },
      tag: {
        'title': mediaItem.title,
        'artist': mediaItem.artist,
        'id': mediaItem.id,
        'preload': true,
      },
    );

    _mediaItemExpando[audioSource] = mediaItem;
    return audioSource;
  }

  List<AudioSource> createAll(List<MediaItem> mediaItems) =>
      mediaItems.map(create).toList();

  Uri _resolveUri(MediaItem mediaItem) {
    try {
      final audioUrl =
          mediaItem.extras?['actual_audio_url'] as String? ?? mediaItem.id;

      AudioLogger.log(
        '[AudioSourceFactory] Using audio URL: $audioUrl for ${mediaItem.title}',
        name: 'AudioSourceFactory',
      );

      if (audioUrl.startsWith('http') || audioUrl.startsWith('https')) {
        return Uri.parse(audioUrl);
      }

      if (audioUrl.startsWith('file://')) {
        return Uri.parse(audioUrl);
      }

      const baseUrl = '${AppConstant.SiteUrl}public/';
      return Uri.parse('$baseUrl$audioUrl');
    } catch (error) {
      AudioLogger.log(
        '[AudioSourceFactory] Invalid URL for ${mediaItem.title}: $error',
        name: 'AudioSourceFactory',
        error: error,
      );
      return Uri.parse('https://example.com/dummy.mp3');
    }
  }
}
