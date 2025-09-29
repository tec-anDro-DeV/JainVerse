import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelPlanList.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/CatSubCatMusicPresenter.dart';
import 'package:jainverse/Presenter/DownloadPresenter.dart';
import 'package:jainverse/Presenter/FavMusicPresenter.dart';
import 'package:jainverse/Presenter/HistoryPresenter.dart';
import 'package:jainverse/Presenter/PlanPresenter.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/audio_preloader_service.dart';
import 'package:jainverse/services/image_url_normalizer.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// Music controller responsible for managing music playback state,
/// user interactions, and business logic
class MusicController extends ChangeNotifier {
  // Singleton pattern
  static final MusicController _instance = MusicController._internal();
  factory MusicController() => _instance;
  MusicController._internal();

  // Core services
  final AudioPreloaderService _preloaderService = AudioPreloaderService();
  final SharedPref _sharePrefs = SharedPref();

  // Add disposal state guard to prevent "used after disposed" errors
  bool _isDisposed = false;

  // State variables
  List<DataMusic> _listCopy = [];
  int _currentIndex = 0;
  int _indexOnScreenSelect = 0;
  late UserModel _model;
  String _token = '';
  String _type = '';
  String _idTag = '';
  String _audioPathMain = '';
  String _imagePath = '';
  List<MediaItem> _listData = [];
  ModelTheme _sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  bool _checkCurrent = false;
  String _currencySym = '\$';
  final String _currentAmount = '';
  late ModelSettings _modelSettings;
  String _musicId = '';
  bool _allowDown = false;
  bool _allowAds = true;
  List<SubData> _listPlans = [];
  bool _isOpen = false;
  final bool _local = false;
  Duration? _remaining;
  Duration? _start;
  String _playing = '0:00';
  double _valueHolder = 0;
  double _maxi = 0.0;
  final double _min = 0.0;
  bool _isRepeat = false;
  late MediaItem _currentData;
  String _downloading = "Not";
  String _progressString = "";

  // Stream subscriptions
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _mediaItemSubscription;

  // Getters
  List<DataMusic> get listCopy => _listCopy;
  int get currentIndex => _currentIndex;
  int get indexOnScreenSelect => _indexOnScreenSelect;
  UserModel get model => _model;
  String get token => _token;
  String get type => _type;
  String get idTag => _idTag;
  String get audioPathMain => _audioPathMain;
  String get imagePath => _imagePath;
  List<MediaItem> get listData => _listData;
  ModelTheme get sharedPreThemeData => _sharedPreThemeData;
  bool get checkCurrent => _checkCurrent;
  String get currencySym => _currencySym;
  String get currentAmount => _currentAmount;
  ModelSettings get modelSettings => _modelSettings;
  String get musicId => _musicId;
  bool get allowDown => _allowDown;
  bool get allowAds => _allowAds;
  List<SubData> get listPlans => _listPlans;
  bool get isOpen => _isOpen;
  bool get local => _local;
  Duration? get remaining => _remaining;
  Duration? get start => _start;
  String get playing => _playing;
  double get valueHolder => _valueHolder;
  double get maxi => _maxi;
  double get min => _min;
  bool get isRepeat => _isRepeat;
  MediaItem get currentData => _currentData;
  String get downloading => _downloading;
  String get progressString => _progressString;

  /// Initialize the music controller with provided data
  Future<void> initialize({
    required String idGet,
    required String typeGet,
    required List<DataMusic> listMain,
    required String audioPath,
    required int index,
  }) async {
    if (_isDisposed) return;

    developer.log(
      '[DEBUG][MusicController][initialize] Called',
      name: 'MusicController',
    );

    _currentIndex = index;
    _indexOnScreenSelect = index;

    if (listMain.isNotEmpty) {
      _listCopy = listMain;
    }

    _idTag = idGet;
    _type = typeGet;
    _audioPathMain = audioPath;
    _checkCurrent = false;

    await _loadUserData();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Load user data and settings
  Future<void> _loadUserData() async {
    if (_isDisposed) return;

    try {
      _token = await _sharePrefs.getToken();
      _model = await _sharePrefs.getUserData();
      _sharedPreThemeData = await _sharePrefs.getThemeData();
      await _loadSettings();
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][_loadUserData] Failed to load user data: $e',
        name: 'MusicController',
        error: e,
      );
    }
  }

  /// Load app settings
  Future<void> _loadSettings() async {
    if (_isDisposed) return;

    try {
      String? sett = await _sharePrefs.getSettings();
      if (sett != null) {
        final Map<String, dynamic> parsed = json.decode(sett);
        _modelSettings = ModelSettings.fromJson(parsed);
        _allowDown = _modelSettings.data.download == 1;
        _allowAds = _modelSettings.data.ads == 1;

        // Set currency symbol
        if (_modelSettings.data.currencySymbol.isNotEmpty) {
          _currencySym = _modelSettings.data.currencySymbol;
        }

        if (!_isDisposed) {
          notifyListeners();
        }
      }
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][_loadSettings] Failed to load settings: $e',
        name: 'MusicController',
        error: e,
      );
    }
  }

  /// Update current playing index
  void updateCurrentIndex(int index) {
    if (_isDisposed) return;

    _currentIndex = index;
    _indexOnScreenSelect = index;
    if (!_isDisposed) {
      notifyListeners();
    }
    developer.log(
      '[DEBUG][MusicController][updateCurrentIndex] Updated index to: $index',
      name: 'MusicController',
    );
  }

  /// Update current media item
  void updateCurrentData(MediaItem mediaItem) {
    if (_isDisposed) return;

    _currentData = mediaItem;
    _musicId = mediaItem.extras?['audio_id']?.toString() ?? '';
    if (!_isDisposed) {
      notifyListeners();
    }
    developer.log(
      '[DEBUG][MusicController][updateCurrentData] Updated current data: ${mediaItem.title}',
      name: 'MusicController',
    );
  }

  /// Update playback position and duration
  void updatePlaybackPosition({
    Duration? position,
    Duration? duration,
    String? playingText,
  }) {
    if (_isDisposed) return;

    if (position != null) {
      _remaining = position;
    }
    if (duration != null) {
      _start = duration;
    }
    if (playingText != null) {
      _playing = playingText;
    }

    // Update value holder for slider
    if (_start != null && _remaining != null && _start!.inSeconds > 0) {
      _valueHolder = _remaining!.inSeconds.toDouble();
      _maxi = _start!.inSeconds.toDouble();
    }

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Update repeat mode
  void updateRepeatMode(bool isRepeat) {
    if (_isDisposed) return;

    _isRepeat = isRepeat;
    if (!_isDisposed) {
      notifyListeners();
    }
    developer.log(
      '[DEBUG][MusicController][updateRepeatMode] Repeat mode: $isRepeat',
      name: 'MusicController',
    );
  }

  /// Update download progress
  void updateDownloadProgress(String progress, String status) {
    if (_isDisposed) return;

    _progressString = progress;
    _downloading = status;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Update dialog open state
  void updateDialogState(bool isOpen) {
    if (_isDisposed) return;

    _isOpen = isOpen;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Load music by category
  Future<void> loadMusicByCategory() async {
    if (_isDisposed) return;

    developer.log(
      '[DEBUG][MusicController][loadMusicByCategory] Called with idTag: $_idTag, type: $_type',
      name: 'MusicController',
    );

    try {
      // Resolve a BuildContext for presenter calls. Use the global navigatorKey
      // as a fallback when this controller isn't running inside a widget.
      BuildContext? resolvedContext;
      try {
        resolvedContext = navigatorKey.currentContext;
      } catch (_) {
        resolvedContext = null;
      }

      ModelMusicList mList;
      if (resolvedContext != null) {
        mList = await CatSubcatMusicPresenter().getMusicListByCategory(
          _idTag,
          _type,
          _token,
          resolvedContext,
        );
      } else {
        // Fall back to legacy method that doesn't require a BuildContext
        mList = await CatSubcatMusicPresenter().getMusicListByCategory(
          _idTag,
          _type,
          _token,
        );
      }

      if (_isDisposed) return;

      developer.log(
        '🔥 [QUEUE_FIX] MusicController loaded ${mList.data.length} songs from API',
        name: 'MusicController',
      );

      developer.log(
        '🔥 [QUEUE_FIX] MusicController about to call _convertToMediaItems',
        name: 'MusicController',
      );

      _listCopy = mList.data;
      _audioPathMain = mList.audioPath;
      _imagePath = mList.imagePath; // Store the correct image path from API

      // Convert to MediaItems
      _listData = _convertToMediaItems(mList.data, mList.imagePath);

      developer.log(
        '🔥 [QUEUE_FIX] MusicController _convertToMediaItems completed, generated ${_listData.length} MediaItems',
        name: 'MusicController',
      );

      if (!_isDisposed) {
        notifyListeners();
      }

      developer.log(
        '[DEBUG][MusicController][loadMusicByCategory] Loaded ${_listCopy.length} songs, imagePath: $_imagePath',
        name: 'MusicController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][loadMusicByCategory] Failed: $e',
        name: 'MusicController',
        error: e,
      );
    }
  }

  /// Convert DataMusic list to MediaItem list
  List<MediaItem> _convertToMediaItems(
    List<DataMusic> musicList,
    String imagePath,
  ) {
    developer.log(
      '🔥 [QUEUE_FIX] MusicController converting ${musicList.length} music items to MediaItems',
      name: 'MusicController',
    );
    developer.log('🔥 [QUEUE_FIX] MusicController Image path: $imagePath');

    return musicList.map((item) {
      String s = item.audio_duration.trim();

      // Remove any newline characters from the duration string
      s = s.replaceAll('\n', '').trim();

      Duration duration;
      try {
        List idx = s.split(':');

        if (idx.length == 3) {
          duration = Duration(
            hours: int.parse(idx[0]),
            minutes: int.parse(idx[1]),
            seconds: int.parse(double.parse(idx[2]).round().toString()),
          );
        } else {
          duration = Duration(
            minutes: int.parse(idx[0]),
            seconds: int.parse(idx[1]),
          );
        }
      } catch (e) {
        // Fallback to a default duration if parsing fails
        debugPrint(
          'Error parsing duration "${item.audio_duration}" for ${item.audio_title}: $e',
        );
        duration = const Duration(minutes: 3); // Default to 3 minutes
      }

      // Create unique MediaItem ID to ensure proper queue replacement
      // Format: audioUrl + contextual info (controller + timestamp)
      final uniqueId =
          '${item.audio}?controller=music&ts=${DateTime.now().millisecondsSinceEpoch}';

      developer.log(
        '🔥 [QUEUE_FIX] MusicController creating MediaItem with unique ID: $uniqueId for song: ${item.audio_title}',
        name: 'MusicController',
      );

      return MediaItem(
        id: uniqueId, // Use unique ID for proper queue replacement
        title: item.audio_title,
        artist: item.artists_name,
        duration: duration,
        artUri: Uri.parse(
          ImageUrlNormalizer.normalizeImageUrl(
            imageFileName: item.image,
            pathImage: imagePath,
          ),
        ),
        extras: {
          'audio_id': item.id.toString(),
          'actual_audio_url':
              item.audio, // Store the actual audio URL for playback
          'lyrics': item.lyrics,
          'favourite': item.favourite, // Include favorite status
        },
      );
    }).toList();
  }

  /// Load plans from API
  Future<void> loadPlans() async {
    if (_isDisposed) return;

    developer.log(
      '[DEBUG][MusicController][loadPlans] Called',
      name: 'MusicController',
    );

    try {
      String response = await PlanPresenter().getAllPlansLegacy(_token);
      if (_isDisposed) return;

      final Map<String, dynamic> parsed = json.decode(response.toString());
      ModelPlanList mList = ModelPlanList.fromJson(parsed);
      _listPlans = mList.data.first.all_plans;
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][loadPlans] Failed: $e',
        name: 'MusicController',
        error: e,
      );
    }
  }

  /// Add/Remove favorite
  Future<void> toggleFavorite(String id, String tag) async {
    if (_isDisposed) return;

    developer.log(
      '[DEBUG][MusicController][toggleFavorite] Called with id=$id, tag=$tag',
      name: 'MusicController',
    );

    try {
      // Resolve BuildContext from global navigatorKey so presenter can show
      // the login-expired dialog when necessary.
      BuildContext? resolvedContext;
      try {
        resolvedContext = navigatorKey.currentContext;
      } catch (_) {
        resolvedContext = null;
      }

      final FavMusicPresenter favPresenter = FavMusicPresenter();
      if (resolvedContext != null) {
        await favPresenter.getMusicAddRemoveWithContext(
          resolvedContext,
          id,
          _token,
          tag,
        );
      } else {
        await favPresenter.getMusicAddRemove(id, _token, tag);
      }
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][toggleFavorite] Failed: $e',
        name: 'MusicController',
        error: e,
      );
    }
  }

  /// Add/Remove from download
  Future<void> toggleDownload(String id) async {
    if (_isDisposed) return;

    developer.log(
      '[DEBUG][MusicController][toggleDownload] Called with id=$id',
      name: 'MusicController',
    );

    try {
      // Resolve BuildContext using global navigatorKey when not in a widget
      BuildContext? resolvedContext;
      try {
        resolvedContext = navigatorKey.currentContext;
      } catch (_) {
        resolvedContext = null;
      }

      if (resolvedContext != null) {
        await DownloadPresenter().addRemoveFromDownload(
          resolvedContext,
          id,
          _token,
        );
      } else {
        // Fallback to legacy method
        await DownloadPresenter().addRemoveFromDownloadLegacy(id, _token);
      }
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][toggleDownload] Failed: $e',
        name: 'MusicController',
        error: e,
      );
    }
  }

  /// Add to history
  Future<void> addToHistory(String id) async {
    if (_isDisposed) return;

    developer.log(
      '[DEBUG][MusicController][addToHistory] Called with id=$id',
      name: 'MusicController',
    );

    try {
      await HistoryPresenter().addHistory(id, _token, 'add');
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][addToHistory] Failed: $e',
        name: 'MusicController',
        error: e,
      );
    }
  }

  /// Preload next tracks for better performance
  Future<void> preloadNextTracks() async {
    if (_isDisposed) return;
    if (_listData.isEmpty || _currentIndex >= _listData.length - 1) return;

    try {
      // Preload next 2 tracks
      for (int i = 1; i <= 2 && (_currentIndex + i) < _listData.length; i++) {
        if (_isDisposed) return;
        final nextItem = _listData[_currentIndex + i];
        await _preloaderService.preloadAudioSource(nextItem);
      }
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][preloadNextTracks] Failed: $e',
        name: 'MusicController',
        error: e,
      );
    }
  }

  /// Set up stream listeners for playback state
  void setupStreamListeners(AudioPlayerHandler audioHandler) {
    if (_isDisposed) return;

    // Clean up existing subscriptions
    _playbackStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();

    // Listen to playback state changes
    _playbackStateSubscription = audioHandler.playbackState.listen((state) {
      if (_isDisposed) return;
      updatePlaybackPosition();
      if (!_isDisposed) {
        notifyListeners();
      }
    });

    // Listen to media item changes
    _mediaItemSubscription = audioHandler.mediaItem.listen((mediaItem) {
      if (_isDisposed) return;
      if (mediaItem != null) {
        updateCurrentData(mediaItem);
      }
    });
  }

  /// Clean up resources and prevent memory leaks
  @override
  void dispose() {
    developer.log(
      '[DEBUG][MusicController][dispose] Starting disposal cleanup',
      name: 'MusicController',
    );

    // Set disposal flag first to prevent further operations
    _isDisposed = true;

    try {
      // Cancel stream subscriptions with error handling
      _playbackStateSubscription?.cancel();
      _playbackStateSubscription = null;

      _mediaItemSubscription?.cancel();
      _mediaItemSubscription = null;

      developer.log(
        '[DEBUG][MusicController][dispose] Stream subscriptions cancelled',
        name: 'MusicController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][dispose] Error cancelling subscriptions: $e',
        name: 'MusicController',
        error: e,
      );
    }

    try {
      // Call parent dispose
      super.dispose();
      developer.log(
        '[DEBUG][MusicController][dispose] Disposal completed successfully',
        name: 'MusicController',
      );
    } catch (e) {
      developer.log(
        '[ERROR][MusicController][dispose] Error in super.dispose(): $e',
        name: 'MusicController',
        error: e,
      );
    }
  }
}
