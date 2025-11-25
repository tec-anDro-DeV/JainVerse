import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/controllers/music/download_state_linker.dart';
import 'package:jainverse/models/song_playback_payload.dart';
import 'package:jainverse/services/audio/common/audio_event_bus.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';
import 'package:jainverse/services/audio/core/audio_player_error_handler.dart';
import 'package:jainverse/services/audio/playback/audio_playback_controller.dart';
import 'package:jainverse/services/audio/playback/audio_preload_manager.dart';
import 'package:jainverse/services/audio/playback/audio_retry_handler.dart';
import 'package:jainverse/services/audio/queue/audio_queue_builder.dart';
import 'package:jainverse/services/audio/queue/audio_queue_manager.dart';
import 'package:jainverse/services/audio/sources/preload_source.dart';
import 'package:jainverse/services/audio/sources/single_song_source.dart';
import 'package:jainverse/services/audio/sources/song_source_resolver.dart';
import 'package:jainverse/services/audio/sources/station_source.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/single_music_service.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/synchronized.dart';

/// Public façade consumed by UI. Coordinates the lower-level modules that now
/// exist under `lib/services/audio/**` while preserving the legacy API surface
/// exposed by `lib/managers/music_manager.dart`.
class MusicManager extends ChangeNotifier {
  MusicManager._internal()
    : _eventBus = AudioEventBus.duplex(),
      _queueLock = Lock(),
      _queueBuilder = AudioQueueBuilder(resolver: SongSourceResolver()),
      _preloadManager = AudioPreloadManager(PreloadSource()),
      _retryHandler = AudioRetryHandler(const AudioPlayerErrorHandler()),
      _singleSongSource = SingleSongSource(service: SingleMusicService()),
      _stationSource = StationSource(),
      _downloadLinker = DownloadStateLinker(DownloadController()),
      processingAudioId = ValueNotifier<String?>(null);

  static MusicManager? _instance;

  factory MusicManager() => _instance ??= MusicManager._internal();

  static MusicManager get instance => MusicManager();

  final AudioEventBus _eventBus;
  final Lock _queueLock;
  final AudioQueueBuilder _queueBuilder;
  final AudioPreloadManager _preloadManager;
  final AudioRetryHandler _retryHandler;
  final SingleSongSource _singleSongSource;
  final StationSource _stationSource;
  final DownloadStateLinker _downloadLinker;
  final Map<String, Future<void>> _inflightOperations = {};
  final Map<String, DateTime> _operationStartTimes = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Duration _lockTtl = const Duration(seconds: 8);

  final ValueNotifier<String?> processingAudioId;

  AudioPlayerHandler? _audioHandler;
  AudioQueueManager? _queueManager;
  AudioPlaybackController? _playbackController;

  List<MediaItem> _queue = const <MediaItem>[];
  MediaItem? _currentMediaItem;
  int? _currentIndex;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isBuffering = false;
  bool _autoPlayEnabled = true;
  bool _shuffleEnabled = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  bool _notifyScheduled = false;
  bool _isDisposed = false;

  ValueStream<PlaybackState> get playbackState => _eventBus.playbackState;
  ValueStream<MediaItem?> get currentMediaItemStream => _eventBus.mediaItem;
  ValueStream<List<MediaItem>> get queueStream => _eventBus.queue;

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isBuffering => _isBuffering;
  bool get autoPlayEnabled => _autoPlayEnabled;
  bool get shuffleEnabled => _shuffleEnabled;
  AudioServiceRepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  List<MediaItem> get queue => List.unmodifiable(_queue);
  int? get currentIndex => _currentIndex;
  AudioPlayerHandler? get audioHandler => _audioHandler;

  /// Configure the singleton with the background [AudioHandler]. Must be called
  /// once during app bootstrap (e.g., in main.dart after `AudioService.init`).
  void setAudioHandler(AudioPlayerHandler handler) {
    if (_isDisposed) return;
    if (identical(_audioHandler, handler)) return;

    _teardownStreams();

    _audioHandler = handler;
    _queueManager = AudioQueueManager(
      builder: _queueBuilder,
      queueLock: _queueLock,
      audioHandler: handler,
    );
    _playbackController = AudioPlaybackController(
      queueManager: _queueManager!,
      preloadManager: _preloadManager,
      retryHandler: _retryHandler,
      audioHandler: handler,
    );

    _subscriptions.add(
      handler.playbackState.listen((state) {
        _eventBus.emitPlaybackState(state);
        _isPlaying = state.playing;
        _isLoading = state.processingState == AudioProcessingState.loading;
        _isBuffering = state.processingState == AudioProcessingState.buffering;
        _position = state.updatePosition;
        _currentIndex = state.queueIndex;
        _safeNotifyListeners();
      }),
    );

    _subscriptions.add(
      handler.mediaItem.listen((item) {
        _eventBus.emitMediaItem(item);
        _currentMediaItem = item;
        _safeNotifyListeners();
      }),
    );

    _subscriptions.add(
      handler.queue.listen((items) {
        _eventBus.emitQueue(items);
        _queue = items;
        _safeNotifyListeners();
      }),
    );

    _downloadLinker.start((_) => _safeNotifyListeners());
  }

  Future<void> playContext(
    List<SongPlaybackPayload> payloads, {
    int startIndex = 0,
  }) async {
    if (!_ensureReady('playContext')) return;
    await _playbackController!.playPayloads(payloads, startIndex);
    MusicPlayerStateManager().showMiniPlayerForMusicStart();
  }

  Future<void> playDataMusicContext({
    required List<DataMusic> musicList,
    required int startIndex,
    String contextType = 'playlist',
    String? contextId,
  }) async {
    if (!_ensureReady('playDataMusicContext')) return;
    if (musicList.isEmpty) return;

    final mediaItems = await _queueBuilder.buildFromDataMusic(
      musicList: musicList,
      contextType: contextType,
      contextId: contextId,
    );

    if (mediaItems.isEmpty) {
      AudioLogger.log(
        '[WARN][MusicManager] Resolver returned 0 media items for context $contextType',
      );
      return;
    }

    await _playbackController!.playMediaItems(
      mediaItems,
      startIndex.clamp(0, mediaItems.length - 1),
    );
    MusicPlayerStateManager().showMiniPlayerForMusicStart();
  }

  Future<void> playStationContext({
    required List<DataMusic> orderedSongs,
    Duration? resumePosition,
    bool resumePlayback = true,
    String? contextId,
  }) async {
    if (!_ensureReady('playStationContext')) return;
    if (orderedSongs.isEmpty) return;

    final mediaItems = await _queueBuilder.buildFromDataMusic(
      musicList: orderedSongs,
      contextType: 'station',
      contextId: contextId,
    );
    if (mediaItems.isEmpty) return;

    await _playbackController!.playMediaItems(
      mediaItems,
      0,
      resumePosition: resumePosition,
      autostart: resumePlayback,
    );
  }

  Future<void> playStationFromSeed(DataMusic seed) async {
    if (!_ensureReady('playStationFromSeed')) return;
    final station = await _stationSource.buildStationFromSeed(seed);
    if (station == null || station.songs.isEmpty) return;
    await replaceQueue(
      musicList: station.songs,
      startIndex: 0,
      pathImage: station.imagePath,
      audioPath: station.audioPath,
      contextType: 'station',
      contextId: station.contextId,
      callSource: 'MusicManager.playStationFromSeed',
    );
  }

  Future<void> playInstant({
    required SongPlaybackPayload payload,
    List<SongPlaybackPayload> context = const <SongPlaybackPayload>[],
    int contextIndex = 0,
  }) async {
    if (!_ensureReady('playInstant')) return;

    final List<SongPlaybackPayload> normalized;
    if (context.isEmpty) {
      normalized = <SongPlaybackPayload>[payload];
    } else {
      final int idx = contextIndex.clamp(0, context.length - 1);
      normalized = <SongPlaybackPayload>[
        ...context.sublist(idx),
        ...context.sublist(0, idx),
      ];
      if (normalized.isEmpty) {
        normalized.add(payload);
      }
    }

    final String optimisticId =
        payload.extras['audio_id']?.toString() ?? payload.id;
    processingAudioId.value = optimisticId.isEmpty ? null : optimisticId;

    try {
      await _playbackController!.playPayloads(normalized, 0);
      MusicPlayerStateManager().showMiniPlayerForMusicStart();
    } finally {
      processingAudioId.value = null;
    }
  }

  Future<void> playSongById({
    required List<DataMusic> musicList,
    required int startIndex,
    required String pathImage,
    required String audioPath,
    String? contextId,
    String? callSource,
  }) async {
    if (musicList.isEmpty) return;
    final int normalizedIndex = startIndex.clamp(0, musicList.length - 1);
    final String audioId = musicList[normalizedIndex].id.toString();
    final Future<void>? inFlight = _inflightOperations[audioId];
    if (inFlight != null) return inFlight;

    final completer = Completer<void>();
    _inflightOperations[audioId] = completer.future;
    _operationStartTimes[audioId] = DateTime.now();
    processingAudioId.value = audioId;

    () async {
      try {
        await replaceQueue(
          musicList: musicList,
          startIndex: normalizedIndex,
          pathImage: pathImage,
          audioPath: audioPath,
          contextType: 'playlist',
          contextId: contextId,
          callSource: callSource ?? 'MusicManager.playSongById',
        );
      } finally {
        _inflightOperations.remove(audioId);
        _operationStartTimes.remove(audioId);
        processingAudioId.value = null;
        if (!completer.isCompleted) completer.complete();
      }
    }();

    return completer.future;
  }

  Future<void> replaceQueue({
    required List<DataMusic> musicList,
    required int startIndex,
    required String pathImage,
    required String audioPath,
    String contextType = 'playlist',
    String? contextId,
    String? callSource,
  }) async {
    if (!_ensureReady('replaceQueue')) return;
    if (musicList.isEmpty) return;

    final int normalizedIndex = startIndex.clamp(0, musicList.length - 1);
    final mediaItems = await _queueBuilder.buildFromDataMusic(
      musicList: musicList,
      contextType: contextType,
      contextId: contextId,
    );
    if (mediaItems.isEmpty) {
      AudioLogger.log('[WARN][MusicManager] replaceQueue resolved no items');
      return;
    }

    final String optimisticId = musicList[normalizedIndex].id.toString();
    processingAudioId.value = optimisticId;

    try {
      await _playbackController!.playMediaItems(mediaItems, normalizedIndex);
      MusicPlayerStateManager().showMiniPlayerForMusicStart();
    } finally {
      processingAudioId.value = null;
    }
  }

  Future<void> replaceQueueWithStation({
    required List<DataMusic> stationSongs,
    required DataMusic currentSong,
    required String pathImage,
    required String audioPath,
  }) async {
    if (!_ensureReady('replaceQueueWithStation')) return;
    if (stationSongs.isEmpty) return;

    AudioLogger.log(
      '[MusicManager] replaceQueueWithStation stationSize=${stationSongs.length} currentSong=${currentSong.audio_title} path=$pathImage audioPath=$audioPath',
    );

    final orderedSongs = <DataMusic>[];
    final seenIds = <int>{};

    void append(DataMusic song) {
      if (seenIds.add(song.id)) {
        orderedSongs.add(song);
      }
    }

    append(currentSong);
    for (final song in stationSongs) {
      append(song);
    }

    if (orderedSongs.isEmpty) {
      AudioLogger.log(
        '[MusicManager] Station songs collapsed to 0 after de-dupe',
      );
      return;
    }

    processingAudioId.value = currentSong.id.toString();

    try {
      final mediaItems = await _queueBuilder.buildFromDataMusic(
        musicList: orderedSongs,
        contextType: 'station',
        contextId: 'station_${currentSong.id}',
      );

      if (mediaItems.isEmpty) {
        AudioLogger.log(
          '[MusicManager] replaceQueueWithStation resolved no items',
        );
        return;
      }

      final playbackState = _audioHandler!.playbackState.value;
      final currentAudioId =
          _currentMediaItem?.extras?['audio_id']?.toString() ??
          _currentMediaItem?.id;
      final stationAudioId =
          mediaItems.first.extras?['audio_id']?.toString() ??
          mediaItems.first.id;
      final preservePosition =
          currentAudioId != null && currentAudioId == stationAudioId;

      await _playbackController!.playMediaItems(
        mediaItems,
        0,
        resumePosition: preservePosition ? playbackState.updatePosition : null,
        autostart: preservePosition ? playbackState.playing : true,
      );

      MusicPlayerStateManager().showMiniPlayerForMusicStart();
    } finally {
      processingAudioId.value = null;
    }
  }

  Future<void> insertPlayNext(DataMusic track) async {
    if (!_ensureReady('insertPlayNext')) return;
    final mediaItem = await _buildSingleItem(
      track,
      contextType: 'play_next',
      contextId: 'play_next_${track.id}',
    );
    if (mediaItem == null) return;
    await _queueManager!.insertAfterCurrent(mediaItem);
  }

  Future<void> addToQueue(DataMusic track) async {
    if (!_ensureReady('addToQueue')) return;
    final mediaItem = await _buildSingleItem(
      track,
      contextType: 'add_to_queue',
      contextId: 'add_to_queue_${track.id}',
    );
    if (mediaItem == null) return;
    await _queueManager!.appendItems(<MediaItem>[mediaItem]);
  }

  Future<void> insertPlayNextById(
    String songId,
    String songName,
    String artistName, {
    String? fallbackImagePath,
    String? fallbackAudioPath,
  }) async {
    final track = await _fetchSongById(
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
    final track = await _fetchSongById(
      songId,
      songName: songName,
      artistName: artistName,
      fallbackImagePath: fallbackImagePath,
      fallbackAudioPath: fallbackAudioPath,
    );
    if (track == null) return;
    await addToQueue(track);
  }

  Future<void> play() async {
    if (!_ensureReady('play')) return;
    await _audioHandler!.play();
  }

  Future<void> pause() async {
    if (!_ensureReady('pause')) return;
    await _audioHandler!.pause();
  }

  Future<void> stop() async {
    if (!_ensureReady('stop')) return;
    await _audioHandler!.stop();
  }

  Future<void> stopAndDisposeAll({String reason = 'media-switch'}) async {
    if (!_ensureReady('stopAndDisposeAll')) return;
    await _queueLock.synchronized(() async {
      await _audioHandler!.stop();
      await _audioHandler!.updateQueue(<MediaItem>[]);
      _queue = const <MediaItem>[];
      _currentMediaItem = null;
      _currentIndex = null;
      _safeNotifyListeners();
    });
  }

  Future<void> skipToNext() async {
    if (!_ensureReady('skipToNext')) return;
    await _audioHandler!.skipToNext();
  }

  Future<void> skipToPrevious() async {
    if (!_ensureReady('skipToPrevious')) return;
    await _audioHandler!.skipToPrevious();
  }

  Future<void> seek(Duration newPosition) async {
    if (!_ensureReady('seek')) return;
    await _audioHandler!.seek(newPosition);
  }

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    if (!_ensureReady('setRepeatMode')) return;
    _repeatMode = mode;
    await _audioHandler!.setRepeatMode(mode);
    if (mode != AudioServiceRepeatMode.none) {
      _autoPlayEnabled = false;
    }
    _safeNotifyListeners();
  }

  Future<void> toggleShuffle() async {
    if (!_ensureReady('toggleShuffle')) return;
    final bool enableShuffle = !_shuffleEnabled;
    await _audioHandler!.setShuffleMode(
      enableShuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
    _shuffleEnabled = enableShuffle;
    _safeNotifyListeners();
  }

  Future<void> toggleAutoPlay() async {
    if (_repeatMode != AudioServiceRepeatMode.none) return;
    _autoPlayEnabled = !_autoPlayEnabled;
    _safeNotifyListeners();
  }

  Future<void> preloadAround(int index) async {
    if (!_ensureReady('preloadAround')) return;
    await _playbackController!.preloadAroundIndex(index);
  }

  Future<MediaItem?> _buildSingleItem(
    DataMusic track, {
    required String contextType,
    String? contextId,
  }) async {
    final items = await _queueBuilder.buildFromDataMusic(
      musicList: <DataMusic>[track],
      contextType: contextType,
      contextId: contextId,
    );
    if (items.isEmpty) {
      AudioLogger.log(
        '[WARN][MusicManager] Failed to build media item for ${track.audio_title}',
      );
      return null;
    }
    return items.first;
  }

  MediaItem? getCurrentMediaItem() {
    return _currentMediaItem ?? _audioHandler?.mediaItem.valueOrNull;
  }

  Future<Duration> getCurrentPosition() async {
    if (_audioHandler == null) return _position;
    final Duration latest = _audioHandler!.playbackState.value.updatePosition;
    _position = latest;
    return latest;
  }

  void updateCurrentSongFavoriteStatus(String newFavoriteStatus) {
    final MediaItem? current = _audioHandler?.mediaItem.valueOrNull;
    if (current == null) return;
    final Map<String, dynamic> extras = Map<String, dynamic>.from(
      current.extras ?? const {},
    );
    extras['favourite'] = newFavoriteStatus;
    final MediaItem updated = current.copyWith(extras: extras);
    try {
      _audioHandler?.updateMediaItem(updated);
      _currentMediaItem = updated;
      _queue = _queue
          .map((item) => item.id == updated.id ? updated : item)
          .toList(growable: false);
      _safeNotifyListeners();
    } catch (error, stackTrace) {
      AudioLogger.log(
        '[ERROR][MusicManager] Failed to update favorite status',
        error: error,
        stackTrace: stackTrace,
        isError: true,
      );
    }
  }

  void clearProcessingAudioId() {
    processingAudioId.value = null;
  }

  void autoCleanupStaleLocks() {
    if (_operationStartTimes.isEmpty) return;
    final DateTime threshold = DateTime.now().subtract(_lockTtl);
    final List<String> stale = _operationStartTimes.entries
        .where((entry) => entry.value.isBefore(threshold))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in stale) {
      _operationStartTimes.remove(id);
      _inflightOperations.remove(id);
    }
    if (stale.isNotEmpty) {
      processingAudioId.value = null;
    }
  }

  void forceClearLocks() {
    _operationStartTimes.clear();
    _inflightOperations.clear();
    processingAudioId.value = null;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _teardownStreams();
    processingAudioId.dispose();
    _downloadLinker.dispose();
    super.dispose();
  }

  bool _ensureReady(String action) {
    if (_audioHandler != null &&
        _queueManager != null &&
        _playbackController != null) {
      return true;
    }
    AudioLogger.log(
      '[WARN][MusicManager] $action aborted - audio handler not configured',
    );
    return false;
  }

  Future<DataMusic?> _fetchSongById(
    String songId, {
    String? songName,
    String? artistName,
    String? fallbackImagePath,
    String? fallbackAudioPath,
  }) async {
    if (songId.isEmpty) return null;
    final DataMusic? resolved = await _singleSongSource.fetchById(songId);
    if (resolved != null) return resolved;

    final int numericId =
        int.tryParse(songId) ?? DateTime.now().millisecondsSinceEpoch;
    return DataMusic(
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

  void _teardownStreams() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
  }

  void _safeNotifyListeners() {
    if (_isDisposed || _notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }
}
