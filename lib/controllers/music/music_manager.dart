import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
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

import 'ui_playback_state.dart';

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
      _uiState = UIPlaybackState() {
    _downloadListener = (_) => _safeNotifyListeners();
    _uiState.addDownloadListener(_downloadListener);
  }

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
  final UIPlaybackState _uiState;
  late final DownloadUpdateListener _downloadListener;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  ValueNotifier<String?> get processingAudioId => _uiState.processingAudioId;

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
  bool _notifyScheduled = false;
  bool _isDisposed = false;

  ValueStream<PlaybackState> get playbackState => _eventBus.playbackState;
  ValueStream<MediaItem?> get currentMediaItemStream => _eventBus.mediaItem;
  ValueStream<List<MediaItem>> get queueStream => _eventBus.queue;

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isBuffering => _isBuffering;
  bool get autoPlayEnabled => _playbackController?.autoPlayEnabled ?? true;
  bool get shuffleEnabled => _playbackController?.shuffleEnabled ?? false;
  AudioServiceRepeatMode get repeatMode =>
      _playbackController?.repeatMode ?? AudioServiceRepeatMode.none;
  Duration get position => _position;
  List<MediaItem> get queue => List.unmodifiable(_queue);
  int? get currentIndex => _currentIndex;
  MediaItem? get currentMediaItem => _currentMediaItem;
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
      queueBuilder: _queueBuilder,
      preloadManager: _preloadManager,
      retryHandler: _retryHandler,
      audioHandler: handler,
      singleSongSource: _singleSongSource,
      stationSource: _stationSource,
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
    await _playbackController!.playDataMusicContext(
      musicList: musicList,
      startIndex: startIndex,
      contextType: contextType,
      contextId: contextId,
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
    await _playbackController!.playStationContext(
      orderedSongs: orderedSongs,
      resumePosition: resumePosition,
      resumePlayback: resumePlayback,
      contextId: contextId,
    );
    if (resumePlayback) {
      MusicPlayerStateManager().showMiniPlayerForMusicStart();
    }
  }

  Future<void> playStationFromSeed(DataMusic seed) async {
    if (!_ensureReady('playStationFromSeed')) return;
    await _uiState.runWithProcessing(seed.id.toString(), () async {
      await _playbackController!.playStationFromSeed(seed);
      MusicPlayerStateManager().showMiniPlayerForMusicStart();
    });
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

    await _uiState.runWithProcessing(optimisticId, () async {
      await _playbackController!.playPayloads(normalized, 0);
      MusicPlayerStateManager().showMiniPlayerForMusicStart();
    });
  }

  Future<void> playSongById({
    required List<DataMusic> musicList,
    required int startIndex,
    String? contextId,
    String? callSource,
  }) async {
    if (!_ensureReady('playSongById')) return;
    if (musicList.isEmpty) return;
    final int normalizedIndex = startIndex.clamp(0, musicList.length - 1);
    final String audioId = musicList[normalizedIndex].id.toString();

    await _uiState.runWithProcessing(audioId, () async {
      await _playbackController!.playSongById(
        musicList: musicList,
        startIndex: normalizedIndex,
        contextType: 'playlist',
        contextId: contextId,
        callSource: callSource ?? 'MusicManager.playSongById',
      );
      MusicPlayerStateManager().showMiniPlayerForMusicStart();
    });
  }

  Future<void> replaceQueue({
    required List<DataMusic> musicList,
    required int startIndex,
    String contextType = 'playlist',
    String? contextId,
    String? callSource,
  }) async {
    if (!_ensureReady('replaceQueue')) return;
    if (musicList.isEmpty) return;

    final int normalizedIndex = startIndex.clamp(0, musicList.length - 1);
    final String optimisticId = musicList[normalizedIndex].id.toString();

    await _uiState.runWithProcessing(optimisticId, () async {
      await _playbackController!.playDataMusicContext(
        musicList: musicList,
        startIndex: normalizedIndex,
        contextType: contextType,
        contextId: contextId,
      );
      MusicPlayerStateManager().showMiniPlayerForMusicStart();
    });
  }

  Future<void> replaceQueueWithStation({
    required List<DataMusic> stationSongs,
    required DataMusic currentSong,
  }) async {
    if (!_ensureReady('replaceQueueWithStation')) return;
    if (stationSongs.isEmpty) return;

    AudioLogger.log(
      '[MusicManager] replaceQueueWithStation stationSize=${stationSongs.length} currentSong=${currentSong.audio_title}',
    );

    await _uiState.runWithProcessing(currentSong.id.toString(), () async {
      await _playbackController!.replaceQueueWithStation(
        stationSongs: stationSongs,
        currentSong: currentSong,
        contextId: 'station_${currentSong.id}',
      );
      MusicPlayerStateManager().showMiniPlayerForMusicStart();
    });
  }

  Future<void> insertPlayNext(DataMusic track) async {
    if (!_ensureReady('insertPlayNext')) return;
    await _playbackController!.insertPlayNext(track);
  }

  Future<void> addToQueue(DataMusic track) async {
    if (!_ensureReady('addToQueue')) return;
    await _playbackController!.addToQueue(track);
  }

  Future<void> insertPlayNextById(
    String songId,
    String songName,
    String channelName, {
    String? fallbackImagePath,
    String? fallbackAudioPath,
  }) async {
    if (!_ensureReady('insertPlayNextById')) return;
    await _playbackController!.insertPlayNextById(
      songId,
      songName,
      channelName,
      fallbackImagePath: fallbackImagePath,
      fallbackAudioPath: fallbackAudioPath,
    );
  }

  Future<void> addToQueueById(
    String songId,
    String songName,
    String channelName, {
    String? fallbackImagePath,
    String? fallbackAudioPath,
  }) async {
    if (!_ensureReady('addToQueueById')) return;
    await _playbackController!.addToQueueById(
      songId,
      songName,
      channelName,
      fallbackImagePath: fallbackImagePath,
      fallbackAudioPath: fallbackAudioPath,
    );
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
    await _playbackController!.stopAndDisposeAll(reason: reason);
  }

  Future<void> skipToNext() async {
    if (!_ensureReady('skipToNext')) return;
    await _playbackController!.skipToNext();
  }

  Future<void> skipToPrevious() async {
    if (!_ensureReady('skipToPrevious')) return;
    await _playbackController!.skipToPrevious();
  }

  Future<void> seek(Duration newPosition) async {
    if (!_ensureReady('seek')) return;
    await _playbackController!.seek(newPosition);
  }

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    if (!_ensureReady('setRepeatMode')) return;
    await _playbackController!.setRepeatMode(mode);
  }

  Future<void> toggleShuffle() async {
    if (!_ensureReady('toggleShuffle')) return;
    await _playbackController!.toggleShuffle();
  }

  Future<void> toggleAutoPlay() async {
    if (!_ensureReady('toggleAutoPlay')) return;
    _playbackController!.toggleAutoPlay();
  }

  Future<void> preloadAround(int index) async {
    if (!_ensureReady('preloadAround')) return;
    await _playbackController!.preloadAroundIndex(index);
  }

  void updateCurrentSongFavoriteStatus(String newFavoriteStatus) {
    if (!_ensureReady('updateCurrentSongFavoriteStatus')) return;
    unawaited(
      _queueManager!.updateCurrentSongFavoriteStatus(newFavoriteStatus),
    );
  }

  void clearProcessingAudioId() {
    _uiState.clearProcessingAudioId();
  }

  void autoCleanupStaleLocks() {
    _playbackController?.autoCleanupStaleLocks();
  }

  void forceClearLocks() {
    _playbackController?.forceClearLocks();
    _uiState.clearProcessingAudioId();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _teardownStreams();
    _uiState.removeDownloadListener(_downloadListener);
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
