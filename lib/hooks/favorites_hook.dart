import 'package:flutter/material.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/providers/favorites_provider.dart';
import 'package:provider/provider.dart';

/// Hook for easy access to favorites functionality across the app
/// This provides a clean, consistent interface for managing favorites
class FavoritesHook {
  final FavoritesProvider _provider;

  FavoritesHook._(this._provider);

  /// Create a FavoritesHook from context
  factory FavoritesHook.of(BuildContext context) {
    final provider = Provider.of<FavoritesProvider>(context, listen: false);
    return FavoritesHook._(provider);
  }

  /// Create a FavoritesHook that listens to changes
  factory FavoritesHook.listen(BuildContext context) {
    final provider = Provider.of<FavoritesProvider>(context, listen: true);
    return FavoritesHook._(provider);
  }

  // Getters
  List<DataMusic> get favoritesList => _provider.favoritesList;
  String get favoritesImagePath => _provider.favoritesImagePath;
  String get favoritesAudioPath => _provider.favoritesAudioPath;
  bool get isLoading => _provider.isLoading;
  bool get isInitialized => _provider.isInitialized;
  Set<String> get favoriteIds => _provider.favoriteIds;

  /// Stream for listening to favorite changes
  Stream<Map<String, bool>> get favoritesStream => _provider.favoritesStream;

  /// Check if a song is favorited
  bool isFavorite(String songId) => _provider.isFavorite(songId);

  /// Check if a song is favorited (alternative method taking DataMusic)
  bool isSongFavorite(DataMusic song) =>
      _provider.isFavorite(song.id.toString());

  /// Toggle favorite status for a song
  Future<bool> toggleFavorite(String songId, {DataMusic? songData}) =>
      _provider.toggleFavorite(songId, songData: songData);

  /// Toggle favorite status using DataMusic object
  Future<bool> toggleSongFavorite(DataMusic song) =>
      _provider.toggleFavorite(song.id.toString(), songData: song);

  /// Add multiple songs to favorites
  Future<List<String>> addToFavoritesBatch(List<String> songIds) =>
      _provider.addToFavoritesBatch(songIds);

  /// Remove multiple songs from favorites
  Future<List<String>> removeFromFavoritesBatch(List<String> songIds) =>
      _provider.removeFromFavoritesBatch(songIds);

  /// Search favorites
  List<DataMusic> searchFavorites(String query) =>
      _provider.searchFavorites(query);

  /// Refresh favorites from server
  Future<void> refreshFavorites() => _provider.refreshFavorites();

  /// Load favorites from server
  Future<void> loadFavorites() => _provider.loadFavorites();
}

/// Widget that provides favorites functionality to its children
/// Use this to wrap parts of your app that need favorites access
class FavoritesScope extends StatelessWidget {
  final Widget child;
  final bool autoInitialize;

  const FavoritesScope({
    super.key,
    required this.child,
    this.autoInitialize = true,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FavoritesProvider>(
      create: (context) {
        final provider = FavoritesProvider();
        if (autoInitialize) {
          // Initialize asynchronously
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.initialize();
          });
        }
        return provider;
      },
      child: child,
    );
  }
}

/// Consumer widget for favorites that rebuilds when favorites change
class FavoritesConsumer extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    FavoritesHook favoritesHook,
    Widget? child,
  )
  builder;
  final Widget? child;

  const FavoritesConsumer({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesProvider>(
      builder: (context, provider, child) {
        final favoritesHook = FavoritesHook._(provider);
        return builder(context, favoritesHook, child);
      },
      child: child,
    );
  }
}

/// Selector widget for favorites that only rebuilds when specific data changes
class FavoritesSelector<T> extends StatelessWidget {
  final T Function(FavoritesProvider provider) selector;
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;

  const FavoritesSelector({
    super.key,
    required this.selector,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<FavoritesProvider, T>(
      selector: (context, provider) => selector(provider),
      builder: builder,
      child: child,
    );
  }
}

/// Stream builder for favorites that listens to real-time changes
class FavoritesStreamBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    AsyncSnapshot<Map<String, bool>> snapshot,
  )
  builder;

  const FavoritesStreamBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final favoritesHook = FavoritesHook.of(context);

    return StreamBuilder<Map<String, bool>>(
      stream: favoritesHook.favoritesStream,
      builder: builder,
    );
  }
}

/// Extension methods for easier favorites access
extension FavoritesContextExtension on BuildContext {
  /// Get favorites hook without listening to changes
  FavoritesHook get favorites => FavoritesHook.of(this);

  /// Get favorites hook that listens to changes
  FavoritesHook get favoritesWithListener => FavoritesHook.listen(this);
}

/// Mixin for widgets that need favorites functionality
mixin FavoritesMixin<T extends StatefulWidget> on State<T> {
  late FavoritesHook _favoritesHook;

  FavoritesHook get favoritesHook => _favoritesHook;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _favoritesHook = context.favorites;
  }

  /// Check if a song is favorite
  bool isFavorite(String songId) => _favoritesHook.isFavorite(songId);

  /// Toggle favorite status
  Future<bool> toggleFavorite(String songId, {DataMusic? songData}) =>
      _favoritesHook.toggleFavorite(songId, songData: songData);
}
