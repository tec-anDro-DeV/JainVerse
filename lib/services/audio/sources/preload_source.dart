import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';

import '../common/audio_logger.dart';

/// Abstracts how we cache metadata or audio bits ahead of playback.
class PreloadSource {
  PreloadSource({Duration cacheTtl = const Duration(seconds: 45)})
    : _cacheTtl = cacheTtl;

  final Duration _cacheTtl;
  final Map<String, DateTime> _warmEntries = {};
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4);

  Future<void> ensureCached(MediaItem item) async {
    final audioUrl = _deriveAudioUrl(item);
    if (audioUrl == null || _isWarm(audioUrl)) return;

    await _primeUrl(audioUrl);
    _warmEntries[audioUrl] = DateTime.now();

    final artUri = item.artUri;
    if (artUri != null && _isNetworkUri(artUri)) {
      await _primeUrl(artUri.toString(), byteRange: 'bytes=0-16383');
    }
  }

  String? _deriveAudioUrl(MediaItem item) {
    final extras = item.extras ?? const {};
    final dynamic actual = extras['actual_audio_url'];
    final url = (actual is String && actual.isNotEmpty) ? actual : item.id;
    if (url.isEmpty || url.startsWith('file://')) {
      return null;
    }
    return url;
  }

  bool _isWarm(String url) {
    final lastWarm = _warmEntries[url];
    if (lastWarm == null) return false;
    return DateTime.now().difference(lastWarm) < _cacheTtl;
  }

  bool _isNetworkUri(Uri uri) => uri.isScheme('http') || uri.isScheme('https');

  Future<void> _primeUrl(String url, {String? byteRange}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !_isNetworkUri(uri)) return;

    try {
      final request = await _client.getUrl(uri);
      if (byteRange != null) {
        request.headers.set(HttpHeaders.rangeHeader, byteRange);
      } else {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-8191');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException('Preload timed out'),
      );
      await response.drain();
    } catch (error, stackTrace) {
      AudioLogger.log(
        '[WARN][PreloadSource] Failed to warm $url',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
