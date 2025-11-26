import 'dart:async';

import '../../../Model/ModelMusicList.dart';
import '../../../services/single_music_service.dart';
import '../common/audio_logger.dart';

class _SingleSongCacheEntry {
  _SingleSongCacheEntry(this.future) : timestamp = DateTime.now();

  final Future<DataMusic?> future;
  final DateTime timestamp;
}

/// Fetches a single song when only an ID is available (Play Next/Add to Queue)
/// and memoizes requests to avoid hammering the API when users tap quickly.
class SingleSongSource {
  SingleSongSource({
    SingleMusicService? service,
    Duration cacheTtl = const Duration(seconds: 30),
  }) : _service = service ?? SingleMusicService(),
       _cacheTtl = cacheTtl;

  final SingleMusicService _service;
  final Duration _cacheTtl;
  final Map<String, _SingleSongCacheEntry> _cache = {};

  Future<DataMusic?> fetchById(String songId) async {
    if (songId.isEmpty) return null;
    final now = DateTime.now();
    final cached = _cache[songId];
    if (cached != null && now.difference(cached.timestamp) < _cacheTtl) {
      return cached.future;
    }

    final completer = Completer<DataMusic?>();
    final fetchFuture = completer.future;
    _cache[songId] = _SingleSongCacheEntry(fetchFuture);

    () async {
      try {
        final result = await _service.fetchSingleMusic(songId);
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (error, stackTrace) {
        AudioLogger.log(
          '[ERROR][SingleSongSource] Failed to fetch $songId',
          error: error,
          stackTrace: stackTrace,
          isError: true,
        );
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    }();

    final result = await fetchFuture;
    _evictExpired(now);
    return result;
  }

  Future<DataMusic?> fetchOrFallback(
    String songId, {
    String? songName,
    String? artistName,
    String? fallbackImagePath,
    String? fallbackAudioPath,
  }) async {
    final resolved = await fetchById(songId);
    if (resolved != null) return resolved;

    final int numericId =
        int.tryParse(songId) ?? DateTime.now().millisecondsSinceEpoch;
    return SongModel.legacy(
      numericId,
      fallbackImagePath ?? '',
      fallbackAudioPath ?? '',
      '',
      songName ?? 'Unknown Title',
      '',
      0,
      '',
      artistName ?? 'Unknown Artist',
      '',
      0,
      0,
      0,
      '',
      0,
      '',
      '',
      '',
    );
  }

  Future<List<DataMusic>> fetchMany(List<String> songIds) async {
    final List<DataMusic> songs = [];
    for (final id in songIds) {
      final song = await fetchById(id);
      if (song != null) {
        songs.add(song);
      }
    }
    return songs;
  }

  void _evictExpired(DateTime referenceTime) {
    _cache.removeWhere(
      (_, entry) => referenceTime.difference(entry.timestamp) >= _cacheTtl,
    );
  }
}
