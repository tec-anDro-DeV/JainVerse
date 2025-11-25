import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../../Model/ModelMusicList.dart';
import '../../../models/song_playback_payload.dart';
import '../common/audio_logger.dart';
import '../queue/audio_queue_builder.dart';
import '../queue/audio_queue_manager.dart';
import '../queue/audio_queue_state.dart';
import '../sources/single_song_source.dart';
import '../sources/station_source.dart';
import 'audio_preload_manager.dart';
import 'audio_retry_handler.dart';
import 'playback_lock_manager.dart';

/// High-level orchestration layer that coordinates queue mutations, preloading,
/// and playback retries. This keeps `MusicManager` thin.
class AudioPlaybackController {
  AudioPlaybackController({
    required AudioQueueManager queueManager,
    required AudioQueueBuilder queueBuilder,
    required AudioPreloadManager preloadManager,
    required AudioRetryHandler retryHandler,
    required AudioHandler audioHandler,
    SingleSongSource? singleSongSource,
    StationSource? stationSource,
    PlaybackLockManager? lockManager,
  }) : _queueManager = queueManager,
       _queueBuilder = queueBuilder,
       _preloadManager = preloadManager,
       _retryHandler = retryHandler,
       _audioHandler = audioHandler,
       _singleSongSource = singleSongSource ?? SingleSongSource(),
       _stationSource = stationSource ?? StationSource(),
       _lockManager = lockManager ?? PlaybackLockManager();

  final AudioQueueManager _queueManager;
  final AudioQueueBuilder _queueBuilder;
  final AudioPreloadManager _preloadManager;
  final AudioRetryHandler _retryHandler;
  final AudioHandler _audioHandler;
  final SingleSongSource _singleSongSource;
  final StationSource _stationSource;
  final PlaybackLockManager _lockManager;

  bool _autoPlayEnabled = true;
  bool _shuffleEnabled = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  AudioQueueState get queueState => _queueManager.state;
  bool get autoPlayEnabled => _autoPlayEnabled;
  bool get shuffleEnabled => _shuffleEnabled;
  AudioServiceRepeatMode get repeatMode => _repeatMode;

  Future<void> playPayloads(
    List<SongPlaybackPayload> payloads,
    int index,
  ) async {
    AudioLogger.log(
      '[DEBUG][AudioPlaybackController] playPayloads size=${payloads.length} index=$index',
    );
    await _queueManager.replaceQueue(payloads, index);
    await _retryHandler.runWithRetry(() async {
      await _audioHandler.skipToQueueItem(index);
      await _audioHandler.play();
    });
  }

  Future<void> playDataMusicContext({
    required List<DataMusic> musicList,
    required int startIndex,
    String contextType = 'playlist',
    String? contextId,
    Duration? resumePosition,
    bool autostart = true,
  }) async {
    if (musicList.isEmpty) {
      AudioLogger.log(
        '[WARN][AudioPlaybackController] playDataMusicContext called with 0 songs',
      );
      return;
    }

    final normalizedIndex = startIndex.clamp(0, musicList.length - 1);
    final mediaItems = await _queueBuilder.buildFromDataMusic(
      musicList: musicList,
      contextType: contextType,
      contextId: contextId,
    );

    if (mediaItems.isEmpty) {
      AudioLogger.log(
        '[WARN][AudioPlaybackController] No media items resolved for $contextType',
      );
      return;
    }

    await playMediaItems(
      mediaItems,
      normalizedIndex,
      resumePosition: resumePosition,
      autostart: autostart,
    );
  }

  Future<void> playStationContext({
    required List<DataMusic> orderedSongs,
    Duration? resumePosition,
    bool resumePlayback = true,
    String? contextId,
  }) async {
    await playDataMusicContext(
      musicList: orderedSongs,
      startIndex: 0,
      contextType: 'station',
      contextId: contextId,
      resumePosition: resumePosition,
      autostart: resumePlayback,
    );
  }

  Future<void> playSongById({
    required List<DataMusic> musicList,
    required int startIndex,
    String contextType = 'playlist',
    String? contextId,
    String? callSource,
  }) async {
    if (musicList.isEmpty) return;
    final normalizedIndex = startIndex.clamp(0, musicList.length - 1);
    final audioId = musicList[normalizedIndex].id.toString();

    await _lockManager.runLocked(audioId, () async {
      AudioLogger.log(
        '[DEBUG][AudioPlaybackController] $callSource playSongById id=$audioId',
      );
      await playDataMusicContext(
        musicList: musicList,
        startIndex: normalizedIndex,
        contextType: contextType,
        contextId: contextId,
      );
    });
  }

  Future<void> replaceQueueWithStation({
    required List<DataMusic> stationSongs,
    required DataMusic currentSong,
    String? contextId,
  }) async {
    if (stationSongs.isEmpty) {
      AudioLogger.log(
        '[WARN][AudioPlaybackController] replaceQueueWithStation invoked with empty list',
      );
      return;
    }

    final orderedSongs = _buildStationOrder(currentSong, stationSongs);
    if (orderedSongs.isEmpty) {
      AudioLogger.log(
        '[WARN][AudioPlaybackController] Station songs collapsed to 0 after de-dupe',
      );
      return;
    }

    final mediaItems = await _queueBuilder.buildFromDataMusic(
      musicList: orderedSongs,
      contextType: 'station',
      contextId: contextId ?? 'station_${currentSong.id}',
    );

    if (mediaItems.isEmpty) {
      AudioLogger.log(
        '[WARN][AudioPlaybackController] replaceQueueWithStation resolved no items',
      );
      return;
    }

    final playbackState = _audioHandler.playbackState.value;
    final currentAudioId = _resolveAudioId(_audioHandler.mediaItem.value);
    final stationAudioId = _resolveAudioId(mediaItems.first);
    final preservePosition =
        currentAudioId != null && currentAudioId == stationAudioId;

    await playMediaItems(
      mediaItems,
      0,
      resumePosition: preservePosition ? playbackState.updatePosition : null,
      autostart: preservePosition ? playbackState.playing : true,
    );
  }

  Future<void> playStationFromSeed(DataMusic seed) async {
    final station = await _stationSource.buildStationFromSeed(seed);
    if (station == null || station.songs.isEmpty) return;
    await replaceQueueWithStation(
      stationSongs: station.songs,
      currentSong: seed,
      contextId: station.contextId,
    );
  }

  Future<void> insertPlayNext(DataMusic track) async {
    final mediaItem = await _queueBuilder.buildSingleItem(
      track: track,
      contextType: 'play_next',
      contextId: 'play_next_${track.id}',
    );
    if (mediaItem == null) return;
    await _queueManager.insertAfterCurrent(mediaItem);
  }

  Future<void> addToQueue(DataMusic track) async {
    final mediaItem = await _queueBuilder.buildSingleItem(
      track: track,
      contextType: 'add_to_queue',
      contextId: 'add_to_queue_${track.id}',
    );
    if (mediaItem == null) return;
    await _queueManager.appendItems(<MediaItem>[mediaItem]);
  }

  Future<void> insertPlayNextById(
    String songId,
    String songName,
    String artistName, {
    String? fallbackImagePath,
    String? fallbackAudioPath,
  }) async {
    final track = await _singleSongSource.fetchOrFallback(
      songId,
      songName: songName,
      artistName: artistName,
      fallbackImagePath: fallbackImagePath,
      fallbackAudioPath: fallbackAudioPath,
    );
    if (track == null) return;
    await insertPlayNext(track);
  }

  Future<void> addToQueueById(
    String songId,
    String songName,
    String artistName, {
    String? fallbackImagePath,
    String? fallbackAudioPath,
  }) async {
    final track = await _singleSongSource.fetchOrFallback(
      songId,
      songName: songName,
      artistName: artistName,
      fallbackImagePath: fallbackImagePath,
      fallbackAudioPath: fallbackAudioPath,
    );
    if (track == null) return;
    await addToQueue(track);
  }

  Future<void> playMediaItems(
    List<MediaItem> items,
    int index, {
    Duration? resumePosition,
    bool autostart = true,
  }) async {
    if (items.isEmpty) {
      AudioLogger.log(
        '[WARN][AudioPlaybackController] playMediaItems called with empty list',
      );
      await _queueManager.replaceWithMediaItems(const <MediaItem>[], 0);
      return;
    }

    final normalizedIndex = index.clamp(0, items.length - 1);
    AudioLogger.log(
      '[DEBUG][AudioPlaybackController] playMediaItems count=${items.length} index=$normalizedIndex',
    );

    await _queueManager.replaceWithMediaItems(items, normalizedIndex);
    await _retryHandler.runWithRetry(() async {
      await _audioHandler.skipToQueueItem(normalizedIndex);
      if (resumePosition != null) {
        await _audioHandler.seek(resumePosition);
      }
      if (autostart) {
        await _audioHandler.play();
      } else {
        await _audioHandler.pause();
      }
    });
  }

  Future<void> preloadAroundIndex(int index) async {
    final queue = queueState.queue;
    if (queue.isEmpty || index >= queue.length) return;
    AudioLogger.log('[DEBUG][AudioPlaybackController] Preloading index=$index');
    await _preloadManager.preload(queue[index]);
  }

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    await _audioHandler.setRepeatMode(mode);
    _repeatMode = mode;
    if (mode != AudioServiceRepeatMode.none) {
      _autoPlayEnabled = false;
    }
  }

  Future<void> toggleShuffle() async {
    final enableShuffle = !_shuffleEnabled;
    await _audioHandler.setShuffleMode(
      enableShuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
    _shuffleEnabled = enableShuffle;
  }

  bool toggleAutoPlay() {
    if (_repeatMode != AudioServiceRepeatMode.none) {
      return false;
    }
    _autoPlayEnabled = !_autoPlayEnabled;
    return true;
  }

  Future<void> stopAndDisposeAll({String reason = 'media-switch'}) async {
    AudioLogger.log(
      '[INFO][AudioPlaybackController] stopAndDisposeAll reason=$reason',
    );
    await _audioHandler.stop();
    await _queueManager.clearQueue();
  }

  Future<void> skipToNext() async {
    await _queueManager.skipToNext();
  }

  Future<void> skipToPrevious() async {
    await _queueManager.skipToPrevious();
  }

  Future<void> seek(Duration newPosition) async {
    await _audioHandler.seek(newPosition);
  }

  void autoCleanupStaleLocks() {
    _lockManager.cleanupStaleLocks();
  }

  void forceClearLocks() {
    _lockManager.forceClear();
  }

  List<DataMusic> _buildStationOrder(
    DataMusic current,
    List<DataMusic> candidates,
  ) {
    final ordered = <DataMusic>[];
    final seenIds = <int>{};

    void append(DataMusic song) {
      if (seenIds.add(song.id)) {
        ordered.add(song);
      }
    }

    append(current);
    for (final song in candidates) {
      append(song);
    }
    return ordered;
  }

  String? _resolveAudioId(MediaItem? item) {
    if (item == null) return null;
    return item.extras?['audio_id']?.toString() ?? item.id;
  }
}
