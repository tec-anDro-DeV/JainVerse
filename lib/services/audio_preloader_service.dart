import 'dart:developer' as developer;
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Service for preloading audio sources to improve performance
class AudioPreloaderService {
  static final AudioPreloaderService _instance =
      AudioPreloaderService._internal();
  factory AudioPreloaderService() => _instance;
  AudioPreloaderService._internal();

  final Map<String, AudioSource> _preloadedSources = {};
  final Map<String, bool> _preloadingStatus = {};

  Future<AudioSource> preloadAudioSource(MediaItem mediaItem) async {
    // Use actual_audio_url from extras if available, otherwise fall back to mediaItem.id
    final url =
        mediaItem.extras?['actual_audio_url'] as String? ?? mediaItem.id;

    if (_preloadedSources.containsKey(url)) {
      return _preloadedSources[url]!;
    }

    if (_preloadingStatus[url] == true) {
      // Wait for preloading to complete
      while (_preloadingStatus[url] == true) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _preloadedSources[url] ?? _createAudioSource(mediaItem);
    }

    _preloadingStatus[url] = true;

    try {
      final audioSource = _createAudioSource(mediaItem);
      _preloadedSources[url] = audioSource;
      return audioSource;
    } catch (e) {
      developer.log(
        '[ERROR][AudioPreloaderService] Failed to preload: $url, error: $e',
        name: 'AudioPreloaderService',
        error: e,
      );
      return _createAudioSource(mediaItem);
    } finally {
      _preloadingStatus[url] = false;
    }
  }

  AudioSource _createAudioSource(MediaItem mediaItem) {
    try {
      // Use actual_audio_url from extras if available, otherwise fall back to mediaItem.id
      final audioUrl =
          mediaItem.extras?['actual_audio_url'] as String? ?? mediaItem.id;
      final uri = Uri.parse(audioUrl);
      if (!uri.hasScheme ||
          (!uri.scheme.startsWith('http') && !uri.scheme.startsWith('file'))) {
        throw Exception('Invalid URL scheme: ${uri.scheme}');
      }

      return AudioSource.uri(
        uri,
        headers: {
          'User-Agent': 'JainVerse/1.0',
          'Accept': 'audio/*',
          'Cache-Control': 'max-age=3600', // Cache for 1 hour
          'Connection': 'keep-alive',
        },
      );
    } catch (e) {
      developer.log(
        '[ERROR][AudioPreloaderService] Invalid URL: ${mediaItem.extras?['actual_audio_url'] ?? mediaItem.id}',
        name: 'AudioPreloaderService',
        error: e,
      );
      // Return a fallback empty audio source
      return AudioSource.uri(Uri.parse('https://example.com/dummy.mp3'));
    }
  }

  void clearCache() {
    _preloadedSources.clear();
    _preloadingStatus.clear();
  }

  void removeFromCache(String url) {
    _preloadedSources.remove(url);
    _preloadingStatus.remove(url);
  }
}
