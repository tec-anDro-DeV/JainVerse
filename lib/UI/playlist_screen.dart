import 'dart:math' as math;
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelPlayList.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/UI/MusicList.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/tab_navigation_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/widgets/common/app_header.dart';
import 'package:jainverse/widgets/common/search_bar.dart';
import 'package:jainverse/widgets/playlist/create_playlist_dialog.dart';
import 'package:jainverse/widgets/playlist/playlist_service.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  // API integration
  List<DataCat> _playlists = [];
  bool _isLoading = true;
  String _error = '';
  String _imagePath = '';
  String _audioPath = '';
  bool _isDeleting = false;

  // Track when screen becomes visible to refresh data
  bool _isScreenVisible = true;
  DateTime? _lastRefreshTime;

  // Keep the tab alive so state is preserved
  @override
  bool get wantKeepAlive => true;
  // Tracks whether the options menu is currently open so we can dismiss it
  // when the user attempts to scroll the underlying list.
  bool _isOptionsMenuOpen = false;
  // Registered scroll listener used to dismiss the menu. Stored so it can
  // be removed reliably when the menu closes or when the widget disposes.
  VoidCallback? _menuScrollListener;
  // Listener for tab changes
  VoidCallback? _tabListener;
  // Overlay entry for a non-blocking options menu so underlying scroll
  // gestures continue to work. Kept here so we can remove it from other
  // places (scroll listener, dispose, selection handlers).
  OverlayEntry? _optionsOverlayEntry;
  // Key to measure the overlay menu's RenderBox so we can detect taps
  // outside the menu without blocking scroll gestures.
  final GlobalKey _optionsMenuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPlaylists();
    // Listen to tab changes so we can refresh when the Library tab becomes active
    try {
      _tabListener = () {
        if (TabNavigationService().selectedIndex.value == 1) {
          _isScreenVisible = true;
          refreshPlaylistsIfVisible();
        } else {
          _isScreenVisible = false;
        }
      };

      TabNavigationService().selectedIndex.addListener(_tabListener!);
    } catch (_) {}
  }

  Future<void> _loadPlaylists() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final playlistService = PlaylistService();
      // Use context-aware variant so token-expiration handling can present the
      // "Login Expired" dialog and auto-logout the user if needed.
      final response = await playlistService.getPlaylistsWithContext(
        context,
        forceRefresh: true,
      );

      if (mounted) {
        setState(() {
          _playlists = response.data;
          // API now returns relative paths; combine with AppConstant.ImageUrl which includes the public/ base
          _imagePath =
              response.imagePath.isNotEmpty
                  ? '${AppConstant.ImageUrl}${response.imagePath}'
                  : '';
          _audioPath =
              response.audioPath.isNotEmpty
                  ? '${AppConstant.ImageUrl}${response.audioPath}'
                  : '';
          _isLoading = false;
          _lastRefreshTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load playlists: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Handle app lifecycle changes - refresh when app becomes active
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshIfNeeded();
    }
  }

  // Check if we need to refresh based on time elapsed
  void _refreshIfNeeded() {
    final now = DateTime.now();
    if (_lastRefreshTime == null ||
        now.difference(_lastRefreshTime!).inSeconds > 5) {
      _loadPlaylists();
    }
  }

  // Add a method to manually refresh when the tab becomes visible
  void refreshPlaylistsIfVisible() {
    if (mounted && _isScreenVisible) {
      _loadPlaylists();
    }
  }

  List<DataCat> get _filteredPlaylists {
    if (_searchQuery.isEmpty) {
      return _playlists;
    }
    return _playlists.where((playlist) {
      return playlist.playlist_name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          playlist.song_list.any(
            (song) => song.audio_title.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ),
          );
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  Future<void> _showPlaylistOptions(
    DataCat playlist,
    Offset globalPosition,
  ) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Prefer opening the menu to the left of the icon so it doesn't sit
    // directly under the user's finger. Apply a left nudge but clamp to
    // the overlay bounds so the menu remains visible on small screens.
    // Increase left nudge so menu appears further left of the icon.
    final double leftNudge = (AppSizes.iconSize * 6) + 6.w;
    double dx = globalPosition.dx - leftNudge;
    double dy = globalPosition.dy - (AppSizes.iconSize);

    // Clamp to overlay bounds with a small safe margin
    final double safeMargin = 8.w;
    if (dx < safeMargin) dx = safeMargin;
    if (dy < safeMargin) dy = safeMargin;
    if (dx > overlay.size.width - safeMargin) {
      dx = overlay.size.width - safeMargin;
    }
    if (dy > overlay.size.height - safeMargin) {
      dy = overlay.size.height - safeMargin;
    }

    // Build a non-blocking OverlayEntry for the menu. The full-screen
    // background is wrapped with IgnorePointer so underlying gestures
    // (scroll/drag) continue to work; we rely on the scroll listener to
    // dismiss the menu when the user scrolls.
    _isOptionsMenuOpen = true;

    _menuScrollListener = () {
      if (!_isOptionsMenuOpen) return;
      _removeOptionsOverlay();
    };

    // Attach listener
    if (_menuScrollListener != null) {
      _scrollController.addListener(_menuScrollListener!);
    }

    // Build the overlay entry
    _optionsOverlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Use a raw pointer Listener to detect taps outside the menu
            // without participating in the gesture arena. This avoids
            // intercepting vertical drag gestures used for scrolling.
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  try {
                    final menuContext = _optionsMenuKey.currentContext;
                    if (menuContext == null) {
                      // If menu isn't mounted yet, remove overlay conservatively
                      _removeOptionsOverlay();
                      return;
                    }

                    final RenderBox rb =
                        menuContext.findRenderObject() as RenderBox;
                    final menuOffset = rb.localToGlobal(Offset.zero);
                    final menuSize = rb.size;
                    final dx = event.position.dx;
                    final dy = event.position.dy;

                    final inside =
                        dx >= menuOffset.dx &&
                        dx <= menuOffset.dx + menuSize.width &&
                        dy >= menuOffset.dy &&
                        dy <= menuOffset.dy + menuSize.height;

                    if (!inside) {
                      _removeOptionsOverlay();
                    }
                  } catch (_) {
                    // On any error, safely remove overlay
                    _removeOptionsOverlay();
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),

            Positioned(
              left: dx,
              top: dy,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.w),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      key: _optionsMenuKey,
                      decoration: BoxDecoration(
                        color: appColors().black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(8.w),
                        border: Border.all(
                          color: appColors().white.withOpacity(0.06),
                        ),
                      ),
                      child: IntrinsicWidth(
                        child: Padding(
                          padding: EdgeInsets.all(8.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildOptionTile(
                                icon: Icons.play_arrow,
                                label: 'Play',
                                enabled: playlist.song_list.isNotEmpty,
                                onTap: () async {
                                  _removeOptionsOverlay();
                                  if (playlist.song_list.isEmpty) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'No songs in this playlist',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final pathImage =
                                      _imagePath.isNotEmpty ? _imagePath : '';
                                  final audioPath =
                                      _audioPath.isNotEmpty ? _audioPath : '';

                                  try {
                                    await MusicManager().replaceQueue(
                                      musicList: playlist.song_list,
                                      startIndex: 0,
                                      pathImage: pathImage,
                                      audioPath: audioPath,
                                      contextType: 'playlist',
                                      contextId: playlist.id.toString(),
                                      callSource: 'PlaylistScreen.options.play',
                                    );
                                  } catch (e) {
                                    if (kDebugMode) {
                                      print(
                                        '[PlaylistScreen] Play action failed: $e',
                                      );
                                    }
                                    // Use captured messenger to avoid referencing BuildContext
                                    // after an await.
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to play playlist',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),

                              _buildOptionTile(
                                icon: Icons.shuffle,
                                label: 'Shuffle play',
                                enabled: playlist.song_list.isNotEmpty,
                                onTap: () async {
                                  _removeOptionsOverlay();
                                  if (playlist.song_list.isEmpty) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('No songs to shuffle'),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final shuffled = List<DataMusic>.from(
                                    playlist.song_list,
                                  );
                                  shuffled.shuffle(math.Random());

                                  final pathImage =
                                      _imagePath.isNotEmpty ? _imagePath : '';
                                  final audioPath =
                                      _audioPath.isNotEmpty ? _audioPath : '';

                                  try {
                                    await MusicManager().replaceQueue(
                                      musicList: shuffled,
                                      startIndex: 0,
                                      pathImage: pathImage,
                                      audioPath: audioPath,
                                      contextType: 'playlist',
                                      contextId: playlist.id.toString(),
                                      callSource:
                                          'PlaylistScreen.options.shuffle',
                                    );
                                  } catch (e) {
                                    if (kDebugMode) {
                                      print(
                                        '[PlaylistScreen] Shuffle action failed: $e',
                                      );
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to shuffle playlist',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),

                              _buildOptionTile(
                                icon: Icons.drive_file_rename_outline,
                                label: 'Rename',
                                onTap: () {
                                  _removeOptionsOverlay();
                                  _showRenameDialog(playlist);
                                },
                              ),

                              _buildOptionTile(
                                icon: Icons.delete_outline,
                                label: 'Delete',
                                onTap: () {
                                  _removeOptionsOverlay();
                                  _showDeleteConfirmation(playlist);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    // Insert the overlay into the current Overlay
    try {
      Overlay.of(context).insert(_optionsOverlayEntry!);
    } catch (e) {
      // If insertion fails, clean up state
      _removeOptionsOverlay();
      if (kDebugMode) print('[PlaylistScreen] Failed to show overlay: $e');
    }

    // Wait until the overlay is removed. Return when closed.
    // We'll complete when _isOptionsMenuOpen becomes false; polling briefly.
    while (_isOptionsMenuOpen && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // Helper to remove the overlay and clean up the scroll listener/state.
  void _removeOptionsOverlay() {
    if (!_isOptionsMenuOpen && _optionsOverlayEntry == null) return;

    _isOptionsMenuOpen = false;

    if (_optionsOverlayEntry != null) {
      try {
        _optionsOverlayEntry!.remove();
      } catch (_) {}
      _optionsOverlayEntry = null;
    }

    if (_menuScrollListener != null) {
      try {
        _scrollController.removeListener(_menuScrollListener!);
      } catch (_) {}
      _menuScrollListener = null;
    }
  }

  // Small helper builder for option rows to keep code concise
  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    Color? labelColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.w),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? appColors().white, size: 18.w),
            SizedBox(width: 12.w),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                label,
                style: TextStyle(color: labelColor ?? appColors().white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(DataCat playlist) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: appColors().colorBackground,
            title: Text(
              'Delete Playlist',
              style: TextStyle(
                color: appColors().primaryColorApp,
                fontSize: AppSizes.fontNormal,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Are you sure you want to delete "${playlist.playlist_name}"? This action cannot be undone.',
              style: TextStyle(
                color: appColors().black,
                fontSize: AppSizes.fontSmall,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: appColors().primaryColorApp),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deletePlaylist(playlist);
                },
                child: Text(
                  'Delete',
                  style: TextStyle(color: appColors().primaryColorApp),
                ),
              ),
            ],
          ),
    );
  }

  void _showRenameDialog(DataCat playlist) {
    final TextEditingController controller = TextEditingController(
      text: playlist.playlist_name,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: appColors().colorBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.w),
            ),
            title: Text(
              'Rename Playlist',
              style: TextStyle(
                color: appColors().primaryColorApp,
                fontSize: AppSizes.fontH2,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter a new name for this playlist',
                  style: TextStyle(
                    color: appColors().colorText.withOpacity(0.9),
                    fontSize: AppSizes.fontNormal - 1.sp,
                  ),
                ),
                SizedBox(height: AppSizes.paddingS),
                TextField(
                  controller: controller,
                  autofocus: true,
                  cursorColor: appColors().primaryColorApp,
                  style: TextStyle(color: appColors().colorText),
                  decoration: InputDecoration(
                    hintText: 'Playlist name',
                    filled: true,
                    fillColor: appColors().white.withOpacity(0.02),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.w),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: appColors().primaryColorApp),
                ),
              ),
              // Use ElevatedButton to emphasize the primary action and ensure
              // consistent primary color usage across the app.
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors().primaryColorApp,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.w),
                  ),
                ),
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isEmpty) {
                    // Capture messenger before async gap to avoid using BuildContext
                    // after awaits.
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Playlist name cannot be empty'),
                        backgroundColor: appColors().primaryColorApp,
                      ),
                    );
                    return;
                  }

                  // Capture navigator and messenger now so we don't reference
                  // the BuildContext across async gaps.
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  navigator.pop();

                  if (!mounted) return;
                  setState(() => _isLoading = true);

                  final service = PlaylistService();
                  final success = await service.updatePlaylist(
                    playlist.id.toString(),
                    newName,
                  );

                  if (!mounted) return;
                  setState(() => _isLoading = false);

                  if (success) {
                    if (mounted) await _loadPlaylists();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Playlist renamed'),
                        backgroundColor: appColors().primaryColorApp,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to rename playlist'),
                        backgroundColor: appColors().primaryColorApp,
                      ),
                    );
                  }
                },
                child: Text('Rename'),
              ),
            ],
          ),
    );
  }

  Future<void> _deletePlaylist(DataCat playlist) async {
    // Use an internal state flag for deleting to avoid orphaned dialogs
    if (!mounted) return;
    setState(() => _isDeleting = true);

    try {
      final service = PlaylistService();
      final res = await service.deletePlaylist(playlist.id.toString());

      final bool status = res['status'] == true || res['status'] == 'true';

      if (mounted) {
        setState(() => _isDeleting = false);

        if (status) {
          // Refresh playlists to reflect deletion
          await _loadPlaylists();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete playlist: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onSongTap(DataMusic song, DataCat playlist, int index) async {
    // Play the tapped song directly in the mini player by replacing the queue.
    // This avoids opening the full player screen.
    final pathImage = _imagePath.isNotEmpty ? _imagePath : '';
    final audioPath = _audioPath.isNotEmpty ? _audioPath : '';

    try {
      await MusicManager().replaceQueue(
        musicList: playlist.song_list,
        startIndex: index,
        pathImage: pathImage,
        audioPath: audioPath,
        contextType: 'playlist',
        contextId: playlist.id.toString(),
        callSource: 'PlaylistScreen.onSongTap',
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[PlaylistScreen] Failed to play song: $e');
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(SnackBar(content: Text('Failed to play song')));
      }
    }
  }

  void _onPlaylistTap(DataCat playlist) {
    // Navigate to MusicList Screen to show all songs in this playlist
    _navigateToMusicListById(playlist.id.toString(), playlist.playlist_name);
  }

  Future<void> _navigateToMusicListById(
    String playlistId,
    String playlistName,
  ) async {
    // Defensive logging to help diagnose wrong id/navigation issues
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[PlaylistScreen] Navigating to MusicList with id: $playlistId, name: $playlistName',
      );
    }
    // Await the pushed route and refresh playlists when the user returns.
    // This ensures any changes made inside MusicList (like removing songs)
    // are reflected when returning to this screen.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => MusicList(
              const MyApp().called(),
              playlistId,
              'User Playlist',
              playlistName,
            ),
      ),
    );

    // Perform a background refresh after coming back from MusicList.
    // We don't block the UI; _loadPlaylists manages its own loading state.
    if (mounted) {
      _loadPlaylists();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Call super.build to maintain AutomaticKeepAliveClientMixin functionality
    super.build(context);
    return Scaffold(
      backgroundColor: appColors().colorBackground,
      body: Stack(
        children: [
          // Remove SafeArea wrapper and handle status bar padding manually
          StreamBuilder<MediaItem?>(
            stream: const MyApp().called().mediaItem,
            builder: (context, snapshot) {
              final hasMiniPlayer = snapshot.hasData;
              final bottomPadding =
                  hasMiniPlayer
                      ? AppSizes.basePadding +
                          AppSizes.miniPlayerPadding +
                          100.w
                      : AppSizes.basePadding + 100.w;

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (FocusScope.of(context).hasFocus) {
                    FocusScope.of(context).unfocus();
                  }
                },
                child: RefreshIndicator(
                  onRefresh: _loadPlaylists,
                  displacement: 40.0,
                  color: appColors().primaryColorApp,
                  backgroundColor: appColors().white,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Fixed header with manual status bar padding
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _AppHeaderSliverDelegate(
                          child: Container(
                            // Add status bar padding manually
                            padding: EdgeInsets.only(
                              top: MediaQuery.of(context).padding.top,
                            ),
                            color: Colors.white, // Match your header background
                            child: Row(
                              children: [
                                Expanded(
                                  child: AppHeader(
                                    title: 'Playlist',
                                    showBackButton: true,
                                    showProfileIcon: false,
                                    backgroundColor: Colors.white,
                                    scrollAware: false,
                                    onBackPressed:
                                        () => Navigator.of(context).pop(),
                                    trailingWidget: Padding(
                                      padding: EdgeInsets.only(right: 12.w),
                                      child: SizedBox(
                                        height: AppSizes.iconSize + 4.w,
                                        width: AppSizes.iconSize + 4.w,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: Icon(
                                              Icons.add_circle_outline,
                                              color:
                                                  appColors().primaryColorApp,
                                              size: AppSizes.iconSize + 4.w,
                                            ),
                                            onPressed: () async {
                                              final result =
                                                  await CreatePlaylistDialog.show(
                                                    context,
                                                    songId: '',
                                                    onPlaylistCreated: () {
                                                      // legacy callback
                                                    },
                                                    onPlaylistCreatedWithName: (
                                                      String name,
                                                    ) {
                                                      // optional: could show a toast
                                                    },
                                                  );

                                              if (result == true) {
                                                if (mounted)
                                                  await _loadPlaylists();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Adjust extent to include status bar height
                          extent: 72.w + MediaQuery.of(context).padding.top,
                        ),
                      ),

                      // Search bar as part of scrollable content
                      SliverToBoxAdapter(
                        child: AnimatedSearchBar(
                          controller: _searchController,
                          hintText: 'Search here...',
                          onChanged: _onSearchChanged,
                          margin: EdgeInsets.fromLTRB(
                            AppSizes.paddingM,
                            AppSizes.paddingS,
                            AppSizes.paddingM,
                            AppSizes.paddingM,
                          ),
                        ),
                      ),

                      // Content based on loading state
                      if (_isLoading) ...[
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ] else if (_error.isNotEmpty) ...[
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64.w,
                                  color: appColors().gray[400],
                                ),
                                SizedBox(height: AppSizes.paddingM),
                                Text(
                                  _error,
                                  style: TextStyle(
                                    color: appColors().gray[400],
                                    fontSize: AppSizes.fontNormal,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: AppSizes.paddingM),
                                ElevatedButton(
                                  onPressed: _loadPlaylists,
                                  child: Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (_filteredPlaylists.isEmpty) ...[
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSizes.paddingM,
                            ),
                            child: _buildEmptyState(),
                          ),
                        ),
                      ] else ...[
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.paddingM,
                            vertical: AppSizes.paddingS,
                          ),
                          sliver: Builder(
                            builder: (context) {
                              // Responsive grid: 2 columns for tablet/iPad, 1 for phones
                              final bool isTablet =
                                  MediaQuery.of(context).size.shortestSide >=
                                  600;
                              final int columns = isTablet ? 2 : 1;

                              // Compute a childAspectRatio so card height matches the
                              // existing visual size (250.w). This keeps layout similar
                              // to the previous SliverList when using one column.
                              final double screenWidth =
                                  MediaQuery.of(context).size.width;
                              final double totalHorizontalPadding =
                                  AppSizes.paddingM * 2;
                              final double crossAxisSpacing =
                                  AppSizes.paddingM * (columns - 1);
                              final double itemWidth =
                                  (screenWidth -
                                      totalHorizontalPadding -
                                      crossAxisSpacing) /
                                  columns;
                              final double cardHeight =
                                  250.w; // matches _buildPlaylistCard
                              final double childAspectRatio =
                                  itemWidth / cardHeight;

                              return SliverGrid(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final playlist = _filteredPlaylists[index];
                                  return _buildPlaylistCard(playlist);
                                }, childCount: _filteredPlaylists.length),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: AppSizes.paddingM,
                                      mainAxisSpacing: AppSizes.paddingM,
                                      childAspectRatio:
                                          childAspectRatio > 0
                                              ? childAspectRatio
                                              : 1.0,
                                    ),
                              );
                            },
                          ),
                        ),
                      ],

                      // Bottom padding to account for navigation bar / mini player
                      SliverPadding(
                        padding: EdgeInsets.only(bottom: bottomPadding),
                        sliver: const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Global deleting overlay (blocks input and shows loader)
          if (_isDeleting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: appColors().primaryColorApp,
                    ),
                    SizedBox(height: AppSizes.paddingS),
                    Text('Deleting...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_play, size: 64.w, color: appColors().gray[400]),
          SizedBox(height: AppSizes.paddingM),
          Text(
            _searchQuery.isEmpty
                ? 'No playlists found'
                : 'No results for "$_searchQuery"',
            style: TextStyle(
              fontSize: AppSizes.fontH2,
              color: appColors().gray[400],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            SizedBox(height: AppSizes.paddingS),
            Text(
              'Try searching with different keywords',
              style: TextStyle(
                fontSize: AppSizes.fontSmall,
                color: appColors().gray[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(DataCat playlist) {
    return GestureDetector(
      onTap: () => _onPlaylistTap(playlist),
      child: Container(
        margin: EdgeInsets.only(bottom: AppSizes.paddingM),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius + 8.w),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              appColors().black.withOpacity(0.2),
              appColors().black.withOpacity(0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8.w,
              offset: Offset(0, 4.w),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius + 8.w),
          child: SizedBox(
            height: 250.w,
            child: Stack(
              children: [
                // Base linear gradient background for all cards (keeps consistent tone)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          appColors().black.withOpacity(0.2),
                          appColors().black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                // Image layer above the base gradient. For non-empty playlists we
                // show the album art and then a darker overlay for contrast. For
                // empty playlists we show the placeholder asset above the base
                // gradient (no extra dark overlay) so the image sits between the
                // linear gradient (below) and the text (above).
                if (playlist.song_list.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            _imagePath.isNotEmpty
                                ? '$_imagePath${playlist.song_list.first.image}'
                                : '${AppConstant.ImageUrl}images/audio/thumb/${playlist.song_list.first.image}',
                          ),
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) {
                            // keep base gradient if image fails
                          },
                        ),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                            'assets/images/playlist_placeholder.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                // Darkening overlay only for non-empty playlists to preserve
                // text contrast. Skip overlay for empty playlists so the
                // placeholder image remains clearly visible above the base
                // gradient.
                if (playlist.song_list.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            appColors().black.withOpacity(0.2),
                            appColors().black.withOpacity(0.85),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Content
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.paddingXS),
                    child: Column(
                      // Ensure the column fills the available height so we can
                      // separate header (top) and song thumbnails (bottom).
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with title on the left and options on the right (top-aligned)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  playlist.playlist_name,
                                  style: TextStyle(
                                    fontSize: AppSizes.fontLarge,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                // Use onTapDown to capture the global tap position so we can
                                // show a floating menu right beside the icon.
                                onTapDown:
                                    (details) => _showPlaylistOptions(
                                      playlist,
                                      details.globalPosition,
                                    ),
                                child: Container(
                                  padding: EdgeInsets.all(AppSizes.paddingXS),
                                  child: Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                    size: AppSizes.iconSize,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Use a flexible spacer so the thumbnails row is pushed to
                        // the bottom but will shrink if the content slightly
                        // exceeds the available height (prevents overflow).
                        Spacer(),

                        // Songs grid or empty-state message pinned to the bottom-center of the card
                        playlist.song_list.isEmpty
                            ? Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(height: AppSizes.paddingXS),
                                    Text(
                                      'No Songs in this Playlist',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: AppSizes.fontSmall + 1.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : Row(
                              // Ensure thumbnails align on the same horizontal line
                              // even when some titles take 2 lines. We always render
                              // exactly 5 slots so items don't expand to fill the
                              // entire row when there are fewer songs.
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(5, (i) {
                                // Determine total count (audio_count if provided else song_list length)
                                final int totalCount =
                                    playlist.audio_count > 0
                                        ? playlist.audio_count
                                        : playlist.song_list.length;

                                // If there are more than 5 songs, we want to display
                                // first 4 normally and the 5th as a glassmorphic "more" card.
                                final bool moreThanFive = totalCount > 5;

                                // For index 4 when there are more than 5 songs, we still
                                // show the 5th song's image (if available) but present
                                // the special overlay. remainingCount should reflect
                                // how many extra songs exist beyond the 4 shown.
                                final int remaining =
                                    moreThanFive
                                        ? (totalCount - 4)
                                        : (totalCount - 5);

                                final DataMusic? song =
                                    i < playlist.song_list.length
                                        ? playlist.song_list[i]
                                        : null;

                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: AppSizes.paddingXS,
                                    ),
                                    child: _buildSongThumbnail(
                                      song,
                                      playlist,
                                      index: i,
                                      remainingCount:
                                          remaining > 0 ? remaining : 0,
                                    ),
                                  ),
                                );
                              }),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongThumbnail(
    DataMusic? song,
    DataCat playlist, {
    int index = 0,
    int remainingCount = 0,
  }) {
    final bool isPlaceholder = song == null;

    if (isPlaceholder) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              // Keep only rounded corners; remove shadow for empty slots
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  AppSizes.borderRadius - 8.w,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppSizes.borderRadius - 8.w,
                ),
                child: Container(
                  // Intentionally transparent so empty slots remain blank
                  // but still occupy layout space.
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
          SizedBox(height: AppSizes.paddingXS),
          SizedBox(width: double.infinity, child: const SizedBox.shrink()),
        ],
      );
    }

    // song is non-null here
    final DataMusic s = song;
    return GestureDetector(
      onTap: () {
        // If this is the special 5th slot showing remaining count,
        // open the full MusicList for this playlist instead of
        // playing the 5th thumbnail directly.
        if (index == 4 && remainingCount > 0) {
          _navigateToMusicListById(
            playlist.id.toString(),
            playlist.playlist_name,
          );
          return;
        }

        _onSongTap(s, playlist, index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  AppSizes.borderRadius - 8.w,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4.w,
                    offset: Offset(0, 2.w),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppSizes.borderRadius - 8.w,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image or placeholder
                    s.image.isNotEmpty
                        ? Image.network(
                          _imagePath.isNotEmpty
                              ? '$_imagePath${s.image}'
                              : '${AppConstant.ImageUrl}images/audio/thumb/${s.image}',
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                                color: appColors().gray[200],
                                child: Icon(
                                  Icons.music_note,
                                  color: appColors().primaryColorApp,
                                  size: 24.w,
                                ),
                              ),
                        )
                        : Container(
                          color: appColors().gray[300],
                          child: Icon(
                            Icons.music_note,
                            color: appColors().primaryColorApp,
                            size: 24.w,
                          ),
                        ),
                    // Special glassmorphic overlay for the 5th slot when there are more songs than shown
                    if (index == 4 && remainingCount > 0)
                      // Make the overlay ignore pointer events so taps fall
                      // through to the underlying GestureDetector. This keeps
                      // the visual '+N' glass effect but allows playing the
                      // 5th song (or handling the tap) as expected.
                      Positioned.fill(
                        // Let pointer events pass through so the thumbnail can
                        // handle taps; we'll interpret taps on the 5th slot as
                        // a navigation to the full playlist (MusicList).
                        child: IgnorePointer(
                          ignoring: true,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSizes.borderRadius - 8.w,
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 3.0,
                                sigmaY: 3.0,
                              ),
                              child: Container(
                                color: Colors.black.withOpacity(0.25),
                                alignment: Alignment.center,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 6.w,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20.w),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                  ),
                                  child: Text(
                                    '+$remainingCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: AppSizes.fontNormal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: AppSizes.paddingXS),
          // Hide title for the special 5th glass card when it represents "more" count
          if (!(index == 4 && remainingCount > 0))
            SizedBox(
              width: double.infinity,
              child: Text(
                s.audio_title,
                style: TextStyle(
                  fontSize: AppSizes.fontSmall - 3.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          SizedBox(height: AppSizes.paddingS),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Remove any menu scroll listener if still attached.
    // Ensure overlay and listener are cleaned up
    _removeOptionsOverlay();

    _searchController.dispose();
    _scrollController.dispose();
    // Remove tab listener
    try {
      if (_tabListener != null) {
        TabNavigationService().selectedIndex.removeListener(_tabListener!);
      }
    } catch (_) {}
    super.dispose();
  }
}

// Delegate for SliverPersistentHeader to hold the AppHeader as a fixed-height pinned header
class _AppHeaderSliverDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double extent;

  _AppHeaderSliverDelegate({required this.child, required this.extent});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: maxExtent, child: child);
  }

  @override
  bool shouldRebuild(covariant _AppHeaderSliverDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}
