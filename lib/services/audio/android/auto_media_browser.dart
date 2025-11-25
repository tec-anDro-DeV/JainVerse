import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';

/// Media library for organizing audio content with Android Auto support.
class MediaLibrary {
  static const albumsRootId = 'albums';

  final Map<String, List<MediaItem>> items = <String, List<MediaItem>>{
    AudioService.browsableRootId: const [
      MediaItem(
        id: albumsRootId,
        title: 'Music Library',
        playable: false,
        extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
      ),
      MediaItem(
        id: AudioService.recentRootId,
        title: 'Recently Played',
        playable: false,
        extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
      ),
    ],
    albumsRootId: [],
    AudioService.recentRootId: [],
  };

  void updateQueue(List<MediaItem> newQueue) {
    items[albumsRootId] = newQueue;
    if (newQueue.isNotEmpty) {
      items[AudioService.recentRootId] = newQueue.take(10).toList();
    }
  }
}

/// Encapsulates Android Auto tree operations for the audio handler.
class AutoMediaBrowser {
  AutoMediaBrowser({
    required MediaLibrary mediaLibrary,
    required BehaviorSubject<List<MediaItem>> recentSubject,
    required ValueStream<List<MediaItem>> queueStream,
  }) : _mediaLibrary = mediaLibrary,
       _recentSubject = recentSubject,
       _queueStream = queueStream;

  final MediaLibrary _mediaLibrary;
  final BehaviorSubject<List<MediaItem>> _recentSubject;
  final ValueStream<List<MediaItem>> _queueStream;

  Future<List<MediaItem>> getChildren(
    String parentMediaId, {
    Map<String, dynamic>? options,
  }) async {
    AudioLogger.log(
      '[AutoMediaBrowser] getChildren called for: $parentMediaId',
      name: 'AutoMediaBrowser',
    );

    switch (parentMediaId) {
      case AudioService.browsableRootId:
        return const [
          MediaItem(
            id: MediaLibrary.albumsRootId,
            title: 'Music Library',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
          MediaItem(
            id: AudioService.recentRootId,
            title: 'Recently Played',
            playable: false,
            extras: {'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1},
          ),
        ];
      case AudioService.recentRootId:
        final recentItems = _recentSubject.value;
        AudioLogger.log(
          '[AutoMediaBrowser] Returning ${recentItems.length} recent items',
          name: 'AutoMediaBrowser',
        );
        return recentItems;
      case MediaLibrary.albumsRootId:
        final libraryItems = _mediaLibrary.items[parentMediaId] ?? [];
        AudioLogger.log(
          '[AutoMediaBrowser] Returning ${libraryItems.length} library items',
          name: 'AutoMediaBrowser',
        );
        return libraryItems;
      default:
        final fallbackItems = _mediaLibrary.items[parentMediaId] ?? [];
        AudioLogger.log(
          '[AutoMediaBrowser] Fallback: Returning ${fallbackItems.length} items for $parentMediaId',
          name: 'AutoMediaBrowser',
        );
        return fallbackItems;
    }
  }

  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    switch (parentMediaId) {
      case AudioService.recentRootId:
        final stream = _recentSubject.map((_) => <String, dynamic>{});
        return _recentSubject.hasValue
            ? stream.shareValueSeeded(<String, dynamic>{})
            : stream.shareValue();
      default:
        return Stream.value(
          _mediaLibrary.items[parentMediaId] ?? const [],
        ).map((_) => <String, dynamic>{}).shareValue();
    }
  }

  Future<List<MediaItem>> search(
    String query, {
    Map<String, dynamic>? extras,
  }) async {
    AudioLogger.log(
      '[AutoMediaBrowser] Search called with query: $query',
      name: 'AutoMediaBrowser',
    );

    if (query.isEmpty) return [];

    final normalizedQuery = query.toLowerCase();
    final searchResults = <MediaItem>[];

    for (final item in _currentQueueSnapshot()) {
      if (_matchesQuery(item, normalizedQuery)) {
        searchResults.add(item);
      }
    }

    for (final item in _recentSubject.value) {
      if (_matchesQuery(item, normalizedQuery) &&
          !searchResults.any((existing) => existing.id == item.id)) {
        searchResults.add(item);
      }
    }

    AudioLogger.log(
      '[AutoMediaBrowser] Search returned ${searchResults.length} results',
      name: 'AutoMediaBrowser',
    );

    return searchResults.take(50).toList();
  }

  List<MediaItem> _currentQueueSnapshot() {
    if (_queueStream.hasValue) {
      return List<MediaItem>.from(_queueStream.value);
    }
    return const <MediaItem>[];
  }

  bool _matchesQuery(MediaItem item, String query) {
    final titleMatch = item.title.toLowerCase().contains(query);
    final artistMatch = item.artist?.toLowerCase().contains(query) ?? false;
    final albumMatch = item.album?.toLowerCase().contains(query) ?? false;
    return titleMatch || artistMatch || albumMatch;
  }
}
