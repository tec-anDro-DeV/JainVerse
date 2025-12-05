import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Model/home_models.dart';
import 'package:jainverse/repositories/home_repository.dart';
import 'package:jainverse/utils/SharedPref.dart';

/// ChangeNotifier that coordinates fetching, caching, and exposing
/// data for the redesigned Home Discover experience.
class HomeController extends ChangeNotifier {
  HomeController({HomeRepository? repository})
    : _repository = repository ?? HomeRepository();

  final HomeRepository _repository;
  final SharedPref _sharedPref = SharedPref();

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasInitialized = false;
  String? _errorMessage;
  DateTime? _lastUpdated;

  ModelTheme _theme = ModelTheme('', '', '', '', '', '');
  UserModel? _user;

  List<VideoModel> _featuredVideos = const [];
  List<ChannelModel> _channels = const [];
  List<SongModel> _featuredSongs = const [];
  List<SongModel> _latestSongs = const [];
  List<VideoModel> _popularVideos = const [];
  List<GenreModel> _trendingGenres = const [];
  List<VideoModel> _newVideos = const [];
  bool _isDisposed = false;

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasError => _errorMessage != null && _errorMessage!.isNotEmpty;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasContent =>
      _featuredVideos.isNotEmpty ||
      _channels.isNotEmpty ||
      _featuredSongs.isNotEmpty ||
      _latestSongs.isNotEmpty ||
      _popularVideos.isNotEmpty ||
      _trendingGenres.isNotEmpty ||
      _newVideos.isNotEmpty;

  ModelTheme get theme => _theme;
  UserModel? get user => _user;

  List<VideoModel> get featuredVideos => List.unmodifiable(_featuredVideos);
  List<ChannelModel> get channelList => List.unmodifiable(_channels);
  List<SongModel> get featuredSongs => List.unmodifiable(_featuredSongs);
  List<SongModel> get latestSongs => List.unmodifiable(_latestSongs);
  List<VideoModel> get popularVideos => List.unmodifiable(_popularVideos);
  List<GenreModel> get trendingGenres => List.unmodifiable(_trendingGenres);
  List<VideoModel> get newVideos => List.unmodifiable(_newVideos);

  /// Initialize shared preferences data and kick off the first load.
  Future<void> initialize() async {
    if (_hasInitialized) return;
    _hasInitialized = true;

    await Future.wait([_loadTheme(), _loadUser()]);

    await loadContent();
  }

  /// Fetch the latest content. When [forceRefresh] is true the cache is bypassed.
  Future<void> loadContent({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (forceRefresh) {
      _isRefreshing = true;
    } else if (!hasContent) {
      _isLoading = true;
    }
    notifyListeners();

    try {
      final response = await _repository.fetchHomeList(
        forceRefresh: forceRefresh,
      );

      if (response.data == null) {
        throw Exception(
          response.message.isNotEmpty
              ? response.message
              : 'No home data returned.',
        );
      }

      final newData = response.data!;

      final changed = _hasDataChanged(newData);
      debugPrint('[HomeController] Home data changed: $changed');

      if (changed) {
        _applyData(newData);
        _lastUpdated = DateTime.now();
      } else {
        // No structural change detected; keep previous data and timestamp.
      }

      _errorMessage = null;
    } catch (error) {
      debugPrint('HomeController.loadContent error: $error');
      if (!hasContent) {
        _errorMessage = error.toString();
      }
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Shortcut for pull-to-refresh gestures.
  Future<void> refresh() => loadContent(forceRefresh: true);

  Future<void> _loadTheme() async {
    try {
      final data = await _sharedPref.getThemeData();
      if (data is ModelTheme) {
        _theme = data;
      }
    } catch (error) {
      debugPrint('HomeController._loadTheme error: $error');
    }
  }

  Future<void> _loadUser() async {
    try {
      final userData = await _sharedPref.getUserData();
      if (userData is UserModel) {
        _user = userData;
      }
    } catch (error) {
      debugPrint('HomeController._loadUser error: $error');
    }
  }

  void _applyData(HomeData data) {
    _featuredVideos = data.featuredVideos;
    _channels = data.channels;
    _featuredSongs = data.featuredSongs;
    _latestSongs = data.latestSongs;
    _popularVideos = data.popularVideos;
    _trendingGenres = data.trendingGenres;
    _newVideos = data.newVideos;
  }

  bool _hasDataChanged(HomeData newData) {
    try {
      bool listChanged<T>(
        List<T> oldList,
        List<T> newList,
        int Function(T) idGetter,
      ) {
        if (oldList.length != newList.length) return true;
        final oldIds = oldList.map(idGetter).toSet();
        final newIds = newList.map(idGetter).toSet();
        return !(oldIds.length == newIds.length && oldIds.containsAll(newIds));
      }

      if (listChanged<VideoModel>(
        _featuredVideos,
        newData.featuredVideos,
        (v) => v.id,
      ))
        return true;
      if (listChanged<ChannelModel>(_channels, newData.channels, (c) => c.id))
        return true;
      if (listChanged<SongModel>(
        _featuredSongs,
        newData.featuredSongs,
        (s) => s.id,
      ))
        return true;
      if (listChanged<SongModel>(
        _latestSongs,
        newData.latestSongs,
        (s) => s.id,
      ))
        return true;
      if (listChanged<VideoModel>(
        _popularVideos,
        newData.popularVideos,
        (v) => v.id,
      ))
        return true;
      if (listChanged<GenreModel>(
        _trendingGenres,
        newData.trendingGenres,
        (g) => (g.id ?? -1),
      ))
        return true;
      if (listChanged<VideoModel>(_newVideos, newData.newVideos, (v) => v.id))
        return true;

      // Fallback: no structural change detected
      return false;
    } catch (e) {
      debugPrint('HomeController._hasDataChanged error: $e');
      return true;
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    } else {
      if (kDebugMode) {
        debugPrint(
          '[HomeController] notifyListeners called after dispose - ignored',
        );
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
