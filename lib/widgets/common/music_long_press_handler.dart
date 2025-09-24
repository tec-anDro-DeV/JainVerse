import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'music_context_menu.dart';

/// Mixin to add long-press context menu functionality to music cards
mixin MusicCardLongPressHandler<T extends StatefulWidget> on State<T> {
  GlobalKey? _cardKey;

  @override
  void initState() {
    super.initState();
    _cardKey = GlobalKey();
  }

  /// Get the global key for the card widget
  GlobalKey get cardKey => _cardKey!;

  /// Handle long press and show context menu
  void handleLongPress({required MusicContextMenuData menuData}) {
    final RenderBox? renderBox =
        _cardKey?.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final center = Offset(
      position.dx + size.width / 2,
      position.dy + size.height / 1,
    );

    // Trigger haptic feedback
    HapticFeedback.mediumImpact();

    MusicContextMenuHelper.show(
      context: context,
      data: menuData,
      position: center,
      cardSize: size,
    );
  }

  /// Create a long-pressable wrapper widget
  Widget buildLongPressWrapper({
    required Widget child,
    required MusicContextMenuData menuData,
  }) {
    return GestureDetector(
      key: _cardKey,
      onLongPress: () => handleLongPress(menuData: menuData),
      child: child,
    );
  }
}

/// Enhanced wrapper widget for existing music cards to add context menu
class MusicCardWrapper extends StatefulWidget {
  final Widget child;
  final MusicContextMenuData menuData;

  const MusicCardWrapper({
    super.key,
    required this.child,
    required this.menuData,
  });

  @override
  State<MusicCardWrapper> createState() => _MusicCardWrapperState();
}

class _MusicCardWrapperState extends State<MusicCardWrapper>
    with MusicCardLongPressHandler {
  @override
  Widget build(BuildContext context) {
    return buildLongPressWrapper(
      menuData: widget.menuData,
      child: widget.child,
    );
  }
}

/// Utility functions for creating menu data
class MusicMenuDataFactory {
  /// Create menu data for a song
  static MusicContextMenuData createSongMenuData({
    required String title,
    required String artist,
    String? imageUrl,
    VoidCallback? onPlay,
    VoidCallback? onPlayNext,
    VoidCallback? onAddToQueue,
    VoidCallback? onDownload,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onShare,
    VoidCallback? onFavorite,
    VoidCallback? onRemove,
    bool isFavorite = false, // Add favorite status parameter
  }) {
    return MusicContextMenuData(
      title: title,
      subtitle: artist,
      imageUrl: imageUrl,
      type: MusicType.song,
      actions: MusicContextMenuHelper.getDefaultActions(
        type: MusicType.song,
        onPlay: onPlay,
        onPlayNext: onPlayNext,
        onAddToQueue: onAddToQueue,
        onDownload: onDownload,
        onAddToPlaylist: onAddToPlaylist,
        onRemove: onRemove,
        onShare: onShare,
        onFavorite: onFavorite,
        isFavorite: isFavorite, // Pass favorite status to actions
      ),
    );
  }

  /// Create menu data for a playlist
  static MusicContextMenuData createPlaylistMenuData({
    required String title,
    required String songCount,
    String? imageUrl,
    VoidCallback? onShare,
    VoidCallback? onRemove,
  }) {
    final actions = MusicContextMenuHelper.getDefaultActions(
      type: MusicType.playlist,
      onShare: onShare,
      // onRemove: onRemove,
    );

    // print(
    //   'DEBUG: Creating playlist menu data for "$title" with ${actions.length} actions',
    // );

    return MusicContextMenuData(
      title: title,
      subtitle: songCount,
      imageUrl: imageUrl,
      type: MusicType.playlist,
      actions: actions,
    );
  }

  /// Create menu data for an album
  static MusicContextMenuData createAlbumMenuData({
    required String title,
    required String artist,
    String? imageUrl,
    VoidCallback? onShare,
  }) {
    return MusicContextMenuData(
      title: title,
      subtitle: artist,
      imageUrl: imageUrl,
      type: MusicType.album,
      actions: MusicContextMenuHelper.getDefaultActions(
        type: MusicType.album,
        onShare: onShare,
      ),
    );
  }
}
