import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/video_model.dart';
import 'package:jainverse/Presenter/SongHistoryPresenter.dart';
import 'package:jainverse/Presenter/VideoHistoryPresenter.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_action_handler.dart';
import 'package:jainverse/utils/video_player_launcher.dart';
import 'package:jainverse/videoplayer/models/video_item.dart';
import 'package:jainverse/widgets/cards/compact_video_card.dart';
import 'package:jainverse/widgets/common/image_with_fallback.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/ThemeMain/sizes.dart';

import '../main.dart';

enum _HistoryTab { songs, videos }

AudioPlayerHandler? _historyAudioHandler;

/// Modern redesigned history screen with improved UI/UX
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final SharedPref _sharedPref = SharedPref();
  final SongHistoryPresenter _songHistoryPresenter = SongHistoryPresenter();
  final VideoHistoryPresenter _videoHistoryPresenter = VideoHistoryPresenter();
  final FavoriteService _favoriteService = FavoriteService();

  late final MusicActionHandler _musicActionHandler;
  late TabController _tabController;

  final Set<int> _removingSongIds = {};
  final Set<int> _removingVideoIds = {};

  List<SongModel> _songHistory = [];
  List<VideoModel> _videoHistory = [];

  bool _loadingSongs = true;
  bool _loadingVideos = true;
  bool _clearingSongs = false;
  bool _clearingVideos = false;

  String? _songErrorMessage;
  String? _videoErrorMessage;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _historyAudioHandler = const MyApp().called();
    _musicActionHandler = MusicActionHandlerFactory.create(
      context: context,
      audioHandler: _historyAudioHandler,
      favoriteService: _favoriteService,
      onStateUpdate: () {
        if (!mounted) return;
        setState(() {});
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTokenAndHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenAndHistory() async {
    final tokenRaw = await _sharedPref.getToken();
    final normalizedToken =
        (tokenRaw is String ? tokenRaw : tokenRaw?.toString() ?? '').trim();
    if (!mounted) return;
    setState(() {
      _token = normalizedToken;
    });
    await _loadSongHistory();
    await _loadVideoHistory();
  }

  Future<void> _loadSongHistory({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _loadingSongs = true;
        _songErrorMessage = null;
      });
    } else {
      setState(() {
        _songErrorMessage = null;
      });
    }

    if (_token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _songHistory = [];
        _songErrorMessage = 'Sign in to view your song history.';
        if (showLoading) _loadingSongs = false;
      });
      return;
    }

    try {
      final response = await _songHistoryPresenter.getHistory(_token);
      final parsed = _safeJsonDecode(response) as Map<String, dynamic>?;
      if (parsed == null) {
        throw const FormatException('Song history response was not JSON.');
      }
      final normalized = _normalizeHistoryMap(parsed);
      final model = ModelMusicList.fromJson(normalized);
      if (!mounted) return;
      setState(() {
        _songHistory = model.data;
        _songErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _songHistory = [];
        _songErrorMessage = 'Unable to refresh song history.';
        if (showLoading) _loadingSongs = false;
      });
    } finally {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _loadingSongs = false;
        });
      }
    }
  }

  Future<void> _loadVideoHistory({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _loadingVideos = true;
        _videoErrorMessage = null;
      });
    } else {
      setState(() {
        _videoErrorMessage = null;
      });
    }

    if (_token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _videoHistory = [];
        _videoErrorMessage = 'Sign in to view your video history.';
        if (showLoading) _loadingVideos = false;
      });
      return;
    }

    try {
      final response = await _videoHistoryPresenter.getHistory(_token);
      final parsed = _safeJsonDecode(response) as Map<String, dynamic>?;
      if (parsed == null) {
        throw const FormatException('Video history response was not JSON.');
      }
      final rawList = _normalizeHistoryList(parsed['data']);
      final videos = rawList
          .whereType<Map<String, dynamic>>()
          .map(VideoModel.fromJson)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _videoHistory = videos;
        _videoErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _videoHistory = [];
        _videoErrorMessage = 'Unable to refresh video history.';
        if (showLoading) _loadingVideos = false;
      });
    } finally {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _loadingVideos = false;
        });
      }
    }
  }

  Future<void> _refreshCurrentTab() async {
    await Future.wait([_loadSongHistory(), _loadVideoHistory()]);
  }

  Future<void> _confirmRemoveSong(SongModel song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _buildModernDialog(
        dialogContext,
        title: 'Remove from history?',
        content:
            'This will remove "${song.audioTitle}" from your listening history.',
        confirmText: 'Remove',
        isDangerous: true,
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      await _removeSong(song);
    }
  }

  Future<void> _confirmRemoveVideo(VideoModel video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _buildModernDialog(
        dialogContext,
        title: 'Remove from history?',
        content: 'This will remove "${video.title}" from your watch history.',
        confirmText: 'Remove',
        isDangerous: true,
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      await _removeVideo(video);
    }
  }

  Widget _buildModernDialog(
    BuildContext dialogContext, {
    required String title,
    required String content,
    required String confirmText,
    bool isDangerous = false,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.w)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: AppSizes.fontMedium,
          fontWeight: FontWeight.w700,
          color: appColors().colorTextHead,
        ),
      ),
      content: Text(
        content,
        style: TextStyle(
          fontSize: AppSizes.fontSmall,
          color: appColors().gray[600],
          height: 1.4,
        ),
      ),
      actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.w),
      actions: [
        TextButton(
          onPressed: () {
            try {
              Navigator.of(dialogContext).pop(false);
            } catch (_) {}
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.w),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: AppSizes.fontMedium,
              fontWeight: FontWeight.w600,
              color: appColors().gray[600],
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            try {
              Navigator.of(dialogContext).pop(true);
            } catch (_) {}
          },
          style: FilledButton.styleFrom(
            backgroundColor: isDangerous
                ? appColors().primaryColorApp
                : appColors().primaryColorApp,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.w),
            ),
          ),
          child: Text(
            confirmText,
            style: TextStyle(
              fontSize: AppSizes.fontMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _removeSong(SongModel song) async {
    if (_token.isEmpty) {
      _showMessage('Please sign in to manage history.');
      return;
    }
    if (_removingSongIds.contains(song.id)) return;

    setState(() {
      _removingSongIds.add(song.id);
    });

    try {
      await _songHistoryPresenter.addHistory(
        song.id.toString(),
        _token,
        'remove',
      );
      if (!mounted) return;
      await _loadSongHistory(showLoading: false);
      if (!mounted) return;
      final stillPresent = _songHistory.any((entry) => entry.id == song.id);
      if (stillPresent) {
        _showMessage('Could not remove the song.');
      } else {
        // success - do not show a SnackBar for successful removal
      }
    } catch (error) {
      _showMessage('Could not remove the song.');
    } finally {
      if (!mounted) return;
      setState(() {
        _removingSongIds.remove(song.id);
      });
    }
  }

  Future<void> _removeVideo(VideoModel video) async {
    if (_token.isEmpty) {
      _showMessage('Please sign in to manage history.');
      return;
    }
    if (_removingVideoIds.contains(video.id)) return;

    setState(() {
      _removingVideoIds.add(video.id);
    });

    try {
      await _videoHistoryPresenter.removeVideoHistory(video.id);
      if (!mounted) return;
      await _loadVideoHistory(showLoading: false);
      if (!mounted) return;
      final stillPresent = _videoHistory.any((entry) => entry.id == video.id);
      if (stillPresent) {
        _showMessage('Could not remove the video.');
      } else {
        // success - do not show a SnackBar for successful removal
      }
    } catch (error) {
      _showMessage('Could not remove the video.');
    } finally {
      if (!mounted) return;
      setState(() {
        _removingVideoIds.remove(video.id);
      });
    }
  }

  Future<void> _handleClear(_HistoryTab tab) async {
    final hasItems = tab == _HistoryTab.songs
        ? _songHistory.isNotEmpty
        : _videoHistory.isNotEmpty;
    if (!hasItems) {
      _showMessage('Nothing to clear yet.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _buildModernDialog(
        dialogContext,
        title: 'Clear all history?',
        content: tab == _HistoryTab.songs
            ? 'This will permanently remove all songs from your listening history. This action cannot be undone.'
            : 'This will permanently remove all videos from your watch history. This action cannot be undone.',
        confirmText: 'Clear All',
        isDangerous: true,
      ),
    );

    if (confirmed != true) return;

    if (_token.isEmpty) {
      _showMessage('Please sign in to manage history.');
      return;
    }

    if (tab == _HistoryTab.songs) {
      setState(() {
        _clearingSongs = true;
      });
      try {
        await _songHistoryPresenter.clearMusicHistory(_token);
        // success - avoid showing a SnackBar for successful clear
      } catch (_) {
        _showMessage('Unable to clear song history.');
      } finally {
        if (!mounted) return;
        setState(() {
          _clearingSongs = false;
        });
        await _loadSongHistory();
      }
    } else {
      setState(() {
        _clearingVideos = true;
      });
      try {
        await _videoHistoryPresenter.clearVideoHistory();
        // success - avoid showing a SnackBar for successful clear
      } catch (_) {
        _showMessage('Unable to clear video history.');
      } finally {
        if (!mounted) return;
        setState(() {
          _clearingVideos = false;
        });
        await _loadVideoHistory();
      }
    }
  }

  void _playSong(SongModel song) {
    if (song.audioUrl.trim().isEmpty) {
      _showMessage('Song is not available.');
      return;
    }
    _musicActionHandler.handlePlaySong(song.id.toString(), song.audioTitle);
  }

  void _playVideo(VideoModel video) {
    if (video.videoUrl.isEmpty) {
      _showMessage('Video is not available.');
      return;
    }
    final contextItems = _videoHistory
        .map(VideoItem.fromVideoModel)
        .toList(growable: false);
    final tappedIndex = _videoHistory.indexWhere(
      (entry) => entry.id == video.id,
    );
    launchVideoPlayer(
      context,
      videoUrl: video.videoUrl,
      videoId: video.id.toString(),
      videoTitle: video.title,
      videoSubtitle: video.channelName,
      thumbnailUrl: _resolveMediaUrl(video.thumbnailUrl),
      videoItem: VideoItem.fromVideoModel(video),
      contextVideos: contextItems,
      contextLabel: 'History',
      playlistIndex: tappedIndex >= 0 ? tappedIndex : null,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.w),
        ),
        margin: EdgeInsets.all(16.w),
      ),
    );
  }

  String _resolveMediaUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    final candidate = '${AppConstant.ImageUrl}$raw';
    return candidate.replaceAll(RegExp(r'(?<!:)//+'), '/');
  }

  String _resolveSongImage(SongModel song) {
    final raw = song.imageUrl.isNotEmpty ? song.imageUrl : song.channelImageUrl;
    return _resolveMediaUrl(raw);
  }

  Map<String, dynamic> _normalizeHistoryMap(Map<String, dynamic> source) {
    final normalized = Map<String, dynamic>.from(source);
    final data = normalized['data'];
    if (data is Map<String, dynamic>) {
      normalized['data'] = data.values.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
    }
    return normalized;
  }

  List<dynamic> _normalizeHistoryList(dynamic source) {
    if (source is List) return source;
    if (source is Map) {
      return source.values.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
    }
    return const [];
  }

  dynamic _safeJsonDecode(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    try {
      return json.decode(trimmed);
    } catch (_) {
      final firstBrace = trimmed.indexOf(RegExp(r'[\{\[]'));
      if (firstBrace > 0) {
        final snippet = trimmed.substring(firstBrace);
        try {
          return json.decode(snippet);
        } catch (_) {}
      }
      return null;
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40.w,
            height: 40.w,
            child: CircularProgressIndicator(
              strokeWidth: 3.5.w,
              valueColor: AlwaysStoppedAnimation<Color>(
                appColors().primaryColorApp,
              ),
            ),
          ),
          SizedBox(height: 16.w),
          Text(
            'Loading history...',
            style: TextStyle(
              fontSize: AppSizes.fontMedium,
              color: appColors().gray[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: appColors().primaryColorApp.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48.w,
                color: appColors().primaryColorApp.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 24.w),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppSizes.fontMedium,
                color: appColors().gray[600],
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongHistoryTab() {
    return Column(
      children: [
        if (_songHistory.isNotEmpty || _clearingSongs)
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.w, 20.w, 12.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_songHistory.length} ${_songHistory.length == 1 ? 'song' : 'songs'}',
                  style: TextStyle(
                    fontSize: AppSizes.fontMedium,
                    fontWeight: FontWeight.w600,
                    color: appColors().gray[600],
                  ),
                ),
                _clearingSongs
                    ? SizedBox(
                        height: 20.w,
                        width: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5.w,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            appColors().primaryColorApp,
                          ),
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () => _handleClear(_HistoryTab.songs),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.w,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.w),
                          ),
                        ),
                        icon: Icon(Icons.delete_sweep_outlined, size: 20.w),
                        label: Text(
                          'Clear all',
                          style: TextStyle(
                            fontSize: AppSizes.fontSmall,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        Expanded(
          child: _loadingSongs
              ? _buildLoadingIndicator()
              : _songHistory.isEmpty
              ? _buildEmptyState(
                  _songErrorMessage ??
                      'No songs in your history yet.\nStart listening to build your collection.',
                  Icons.music_note_outlined,
                )
              : RefreshIndicator(
                  color: appColors().primaryColorApp,
                  onRefresh: _loadSongHistory,
                  child: ListView.separated(
                    padding: EdgeInsets.only(
                      top: 4.w,
                      bottom: AppPadding.bottom(context) + 20.w,
                      left: 16.w,
                      right: 16.w,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _songHistory.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.w),
                    itemBuilder: (context, index) {
                      final song = _songHistory[index];
                      return _buildModernSongTile(song);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildVideoHistoryTab() {
    return Column(
      children: [
        if (_videoHistory.isNotEmpty || _clearingVideos)
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.w, 20.w, 12.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_videoHistory.length} ${_videoHistory.length == 1 ? 'video' : 'videos'}',
                  style: TextStyle(
                    fontSize: AppSizes.fontMedium,
                    fontWeight: FontWeight.w600,
                    color: appColors().gray[600],
                  ),
                ),
                // Show clear action for videos (matching songs header).
                _clearingVideos
                    ? SizedBox(
                        height: 20.w,
                        width: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5.w,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            appColors().primaryColorApp,
                          ),
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () => _handleClear(_HistoryTab.videos),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 2.w,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.w),
                          ),
                        ),
                        icon: Icon(Icons.delete_sweep_outlined, size: 20.w),
                        label: Text(
                          'Clear all',
                          style: TextStyle(
                            fontSize: AppSizes.fontSmall,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        Expanded(
          child: _loadingVideos
              ? _buildLoadingIndicator()
              : _videoHistory.isEmpty
              ? _buildEmptyState(
                  _videoErrorMessage ??
                      'No videos in your history yet.\nStart watching to build your collection.',
                  Icons.video_library_outlined,
                )
              : RefreshIndicator(
                  color: appColors().primaryColorApp,
                  onRefresh: _loadVideoHistory,
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      top: 4.w,
                      bottom: AppPadding.bottom(context) + 20.w,
                      left: 16.w,
                      right: 16.w,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _videoHistory.length,
                    itemBuilder: (context, index) {
                      final video = _videoHistory[index];
                      return _buildModernVideoCard(video);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildModernSongTile(SongModel song) {
    final imageUrl = _resolveSongImage(song);
    final isRemoving = _removingSongIds.contains(song.id);
    final artistName = song.channelName.isNotEmpty
        ? song.channelName
        : song.channelHandle.isNotEmpty
        ? song.channelHandle
        : 'Unknown Artist';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.w),
          onTap: () => _playSong(song),
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                Hero(
                  tag: 'song_${song.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.w),
                      boxShadow: [
                        BoxShadow(
                          color: appColors().primaryColorApp.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.w),
                      child: ImageWithFallback(
                        imageUrl: imageUrl,
                        width: 64.w,
                        height: 64.w,
                        fit: BoxFit.cover,
                        fallbackAsset: 'assets/images/song_placeholder.png',
                        backgroundColor: appColors().gray[100],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.audioTitle.isNotEmpty
                            ? song.audioTitle
                            : 'Unknown title',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppSizes.fontMedium,
                          fontWeight: FontWeight.w600,
                          color: appColors().colorTextHead,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 6.w),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14.w,
                            color: appColors().gray[500],
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppSizes.fontSmall,
                                color: appColors().gray[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: appColors().primaryColorApp,
                    borderRadius: BorderRadius.circular(12.w),
                  ),
                  child: isRemoving
                      ? Center(
                          child: SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5.w,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                appColors().primaryColorApp,
                              ),
                            ),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Remove',
                          onPressed: () => _confirmRemoveSong(song),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: appColors().white,
                            size: 20.w,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernVideoCard(VideoModel video) {
    final isRemoving = _removingVideoIds.contains(video.id);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.w),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CompactVideoCard(
                item: VideoItem.fromVideoModel(video),
                onTap: () => _playVideo(video),
                showPopupMenu: false,
              ),
            ),
            SizedBox(width: 2.w),
            isRemoving
                ? Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12.w),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.w,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: appColors().primaryColorApp,
                      borderRadius: BorderRadius.circular(12.w),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      tooltip: 'Remove',
                      onPressed: () => _confirmRemoveVideo(video),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18.w,
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors().gray[50] ?? const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: Container(
          margin: EdgeInsets.all(4.w),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
            color: appColors().colorTextHead,
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
          ),
        ),
        title: Text(
          'History',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: appColors().colorTextHead,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 12.w),
            decoration: BoxDecoration(
              color: appColors().primaryColorApp.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.w),
            ),
            child: IconButton(
              onPressed: _refreshCurrentTab,
              icon: Icon(
                Icons.refresh_rounded,
                color: appColors().primaryColorApp,
                size: 22.w,
              ),
              tooltip: 'Refresh',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56.w),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.w),
            decoration: BoxDecoration(
              color: appColors().gray[100],
              borderRadius: BorderRadius.circular(14.w),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: appColors().gray[600],
              indicator: BoxDecoration(
                color: appColors().primaryColorApp,
                borderRadius: BorderRadius.circular(12.w),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(
                fontSize: AppSizes.fontMedium,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: AppSizes.fontMedium,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note_rounded, size: 18.w),
                      SizedBox(width: 6.w),
                      const Text('Songs'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_outline_rounded, size: 18.w),
                      SizedBox(width: 6.w),
                      const Text('Videos'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSongHistoryTab(), _buildVideoHistoryTab()],
      ),
    );
  }
}
