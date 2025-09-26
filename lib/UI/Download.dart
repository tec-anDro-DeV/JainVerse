import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/DownloadPresenter.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/databasefolder/ListEntity.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/services/offline_mode_service.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/ConnectionCheck.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/music_player_state_manager.dart';
import 'package:jainverse/widgets/common/app_header.dart';
import 'package:jainverse/widgets/common/music_context_menu.dart';
import 'package:jainverse/widgets/common/music_long_press_handler.dart';

import '../main.dart';

AudioPlayerHandler? _audioHandler;

class Download extends StatefulWidget {
  const Download({super.key});

  @override
  StateClass createState() {
    return StateClass();
  }
}

class StateClass extends State {
  late final access;
  SharedPref shareprefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  List file = [];
  late List<ListEntity> listMain = [];
  late List<DataMusic> downloadedTracks = [];
  late final database;
  String token = '';
  var txtSearch = TextEditingController();
  int playIndex = 0;
  bool isLoading = false;
  bool _wasOffline = false; // Track previous offline state
  bool connected = true; // Track connectivity status
  int? _deletingIndex; // Track which item is being deleted

  // Enhanced download service for handling downloads and offline access
  final OfflineModeService _offlineModeService = OfflineModeService();

  // Download controller for tracking download progress
  final DownloadController _downloadController = DownloadController();

  // Download presenter for API calls
  final DownloadPresenter _downloadPresenter = DownloadPresenter();

  Future<void> downListAPI(String token) async {
    if (token.isEmpty) return;

    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      // Use the download controller to sync and get downloads
      await _downloadController.initialize();

      // Load existing downloads first to show them immediately
      _loadExistingDownloads();

      // Show downloads immediately, then start sync in background
      if (mounted) {
        setState(() {
          isLoading = false; // Stop loading to show existing downloads
        });
      }

      // Now sync downloads in background (this may start new downloads)
      await _downloadController.syncDownloads();

      // Update UI with any new downloads after sync
      _loadExistingDownloads();

      print(
        '[Download] Loaded ${downloadedTracks.length} downloads from controller',
      );
    } catch (error) {
      print('[Download] downListAPI error: $error');
      if (mounted) {
        _showErrorMessage('Failed to load downloads from server.');
      }
      downloadedTracks = [];
      listMain = [];
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Load existing downloads from controller and update UI
  void _loadExistingDownloads() {
    // Convert DownloadedMusic objects to DataMusic objects for UI compatibility
    downloadedTracks =
        _downloadController.downloadedTracks
            .map(
              (downloaded) => DataMusic(
                downloaded.id.isNotEmpty ? int.tryParse(downloaded.id) ?? 0 : 0,
                downloaded.imageUrl, // image
                downloaded.audioUrl, // audio
                downloaded.duration, // audio_duration
                downloaded.title, // audio_title
                downloaded.albumName, // audio_slug
                0, // audio_genre_id
                '', // artist_id
                downloaded.artist, // artists_name
                '', // audio_language
                0, // listening_count
                0, // is_featured
                0, // is_trending
                '', // created_at
                0, // is_recommended
                '', // favourite
                '', // download_price
                '', // lyrics
              ),
            )
            .toList();

    // Refresh the UI list immediately and trigger UI update
    getDb();

    // Ensure UI gets updated
    if (mounted) {
      setState(() {});
    }
  }

  Future<dynamic> value() async {
    model = await shareprefs.getUserData();
    token = await shareprefs.getToken();
    sharedPreThemeData = await shareprefs.getThemeData();
    if (mounted) {
      setState(() {});
    }
    return model;
  }

  Future<dynamic> getDb() async {
    // Build listMain from downloaded tracks from server API
    listMain = [];

    for (int i = 0; i < downloadedTracks.length; i++) {
      final track = downloadedTracks[i];

      // Build proper URLs for images and audio from server response
      String imageUrl = track.image;
      String audioUrl = track.audio;

      // The server returns complete relative paths starting with '/'
      // We just need to prepend the base URL
      const baseUrl = '${AppConstant.SiteUrl}public';

      if (track.image.isNotEmpty && !track.image.startsWith('http')) {
        if (track.image.startsWith('/')) {
          // Server provided complete path
          imageUrl = '$baseUrl${track.image}';
        } else {
          // Legacy format - just filename
          imageUrl = '$baseUrl/images/audio/thumb/${track.image}';
        }
      }

      if (!track.audio.startsWith('http')) {
        if (track.audio.startsWith('/')) {
          // Server provided complete path
          audioUrl = '$baseUrl${track.audio}';
        } else {
          // Legacy format - just filename
          audioUrl = '$baseUrl/images/audio/${track.audio}';
        }
      } else {
        audioUrl = track.audio; // Use the full URL from server
      }

      listMain.add(
        ListEntity(
          track.id.toString(), // AudioId
          model.data.id.toString(), // userId
          track.audio_duration, // duration
          track.id.toString(), // id
          track.audio_title, // name
          audioUrl, // url - from server response
          imageUrl, // image - constructed URL
          track.artists_name, // artistname
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
    return listMain;
  }

  // Method removed - using new _playTrack method instead

  Future<void> searchDbRefresh() async {
    // Filter downloaded tracks based on search text
    if (txtSearch.text.isEmpty) {
      await dataDbRefresh();
      return;
    }

    final searchText = txtSearch.text.toLowerCase();

    // Filter downloadedTracks directly instead of using service
    final filteredTracks =
        downloadedTracks.where((track) {
          return track.audio_title.toLowerCase().contains(searchText) ||
              track.artists_name.toLowerCase().contains(searchText);
        }).toList();

    // Convert filtered results to ListEntity using same logic as getDb
    listMain = [];

    for (int i = 0; i < filteredTracks.length; i++) {
      final track = filteredTracks[i];

      // Build proper URLs for images and audio from server response
      String imageUrl = track.image;
      String audioUrl = track.audio;

      // The server returns complete relative paths starting with '/'
      // We just need to prepend the base URL
      const baseUrl = '${AppConstant.SiteUrl}public';

      if (track.image.isNotEmpty && !track.image.startsWith('http')) {
        if (track.image.startsWith('/')) {
          // Server provided complete path
          imageUrl = '$baseUrl${track.image}';
        } else {
          // Legacy format - just filename
          imageUrl = '$baseUrl/images/audio/thumb/${track.image}';
        }
      }

      if (!track.audio.startsWith('http')) {
        if (track.audio.startsWith('/')) {
          // Server provided complete path
          audioUrl = '$baseUrl${track.audio}';
        } else {
          // Legacy format - just filename
          audioUrl = '$baseUrl/images/audio/${track.audio}';
        }
      } else {
        audioUrl = track.audio; // Use the full URL from server
      }

      listMain.add(
        ListEntity(
          track.id.toString(), // AudioId
          model.data.id.toString(), // userId
          track.audio_duration, // duration
          track.id.toString(), // id
          track.audio_title, // name
          audioUrl, // url - from server response
          imageUrl, // image - constructed URL
          track.artists_name, // artistname
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> dataDbRefresh() async {
    await getDb(); // This will rebuild the UI list from downloadedTracks
  }

  Future<void> addToDownloads(String musicId) async {
    if (token.isEmpty) {
      if (mounted) {
        _showErrorMessage('Please log in to manage downloads');
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      // Add to server using the download controller
      final downloadController = DownloadController();
      final success = await downloadController.addToDownloads(musicId);

      if (success) {
        // Update local state by refreshing data
        await dataDbRefresh();

        if (mounted) {
          _showSuccessMessage('Added to downloads');
        }
      } else {
        if (mounted) {
          _showErrorMessage('Failed to add to downloads');
        }
      }
    } catch (error) {
      print('[Download] addToDownloads error: $error');
      if (mounted) {
        _showErrorMessage('Failed to add to downloads');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showErrorMessage(String message) async {
    if (!mounted) return; // Check if widget is still mounted

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 14.sp,
          ),
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  Future<void> _showSuccessMessage(String message) async {
    if (!mounted) return; // Check if widget is still mounted

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontSize: 14.sp,
          ),
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  Future<void> _showOfflineRefreshMessage() async {
    if (!mounted) return; // Check if widget is still mounted

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 18.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'You\'re offline. Downloads will sync when you\'re back online.',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  // Add this as a class field at the top
  void _onDownloadControllerChange() {
    if (mounted) {
      _loadExistingDownloads();
    }
  }

  @override
  void initState() {
    super.initState();
    _audioHandler = const MyApp().called();

    // Initialize offline state tracking
    _wasOffline = _offlineModeService.isOfflineMode;

    // Set up iOS download message callback
    _setupIOSDownloadCallback();

    // Listen to download controller changes
    _downloadController.addListener(_onDownloadControllerChange);

    // Listen to offline mode changes
    _offlineModeService.offlineModeStream.listen((isOffline) {
      if (mounted) {
        // Show toast when coming back online
        if (_wasOffline && !isOffline) {
          _showSuccessMessage(
            'You are back online! Pull to refresh for latest data.',
          );
        } else if (!_wasOffline && isOffline) {
          _showOfflineRefreshMessage();
        }
        _wasOffline = isOffline;

        // Update UI when connectivity changes
        setState(() {});
      }
    });

    // Listen to connectivity changes from the service
    _offlineModeService.connectivityStream.listen((hasConnectivity) {
      if (mounted) {
        setState(() {
          connected = hasConnectivity;
        });
      }
    });

    _initializeData();
  }

  void _setupIOSDownloadCallback() {
    // iOS download messages are no longer handled via callback
    // Download progress is shown through notifications only
    if (Platform.isIOS) {
      debugPrint('iOS: Download feedback handled via notifications only');
    }
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // First load user data and token
      await value();

      // Check connection
      await checkConn();

      // Load downloads from server if token is available
      if (token.isNotEmpty) {
        await downListAPI(token);
      } else {
        // No token, show empty state
        downloadedTracks = [];
        listMain = [];
      }
    } catch (error) {
      print('[Download] _initializeData error: $error');
      if (mounted) {
        _showErrorMessage(
          'Failed to load downloads. Please check your connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> checkConn() async {
    connected = await ConnectionCheck().checkConnection();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Remove download controller listener
    _downloadController.removeListener(_onDownloadControllerChange);

    // Stop any audio playback through the audio handler
    // Do NOT stop or pause the global audio handler here.
    // The Download screen should not control global playback lifecycle
    // when user navigates away — that causes currently playing
    // audio to be paused unintentionally. Only remove local listeners.
    // Keep _audioHandler reference untouched so playback continues.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appColors().white,
      body: StreamBuilder<MediaItem?>(
        stream: _audioHandler?.mediaItem,
        builder: (context, snapshot) {
          // Dynamic bottom padding for mini player
          final bottomPadding =
              _offlineModeService.isOfflineMode
                  ? 165.w
                  : AppSizes.basePadding + 140.w;

          return SafeArea(
            child: Column(
              children: [
                // Sticky Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: AppHeader(
                    title: 'Downloads',
                    showBackButton: !_offlineModeService.isOfflineMode,
                    showProfileIcon: false,
                    backgroundColor: Colors.transparent,
                    titleStyle: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: Colors.black87,
                    ),
                  ),
                ),
                // The rest of the content scrolls
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshDownloads,
                    color:
                        connected && !_offlineModeService.isOfflineMode
                            ? appColors().primaryColorApp
                            : Colors.orange[600],
                    backgroundColor: Colors.white,
                    strokeWidth: 3.w,
                    displacement: 50.0,
                    triggerMode: RefreshIndicatorTriggerMode.anywhere,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        // Search Bar as Sliver
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.w,
                            ),
                            child: _buildSearchBar(),
                          ),
                        ),

                        // Download Status Indicator as Sliver
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.w,
                            ),
                            child: _buildDownloadStatusIndicator(),
                          ),
                        ),

                        // Main Content as Sliver
                        SliverPadding(
                          padding: EdgeInsets.only(
                            left: 16.w,
                            right: 16.w,
                            bottom: bottomPadding,
                          ),
                          sliver:
                              isLoading
                                  ? SliverToBoxAdapter(
                                    child: SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.5,
                                      child: _buildLoadingState(),
                                    ),
                                  )
                                  : listMain.isEmpty
                                  ? SliverToBoxAdapter(
                                    child: SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.6,
                                      child: _buildEmptyState(),
                                    ),
                                  )
                                  : SliverList(
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                        child: _buildDownloadCard(index),
                                      );
                                    }, childCount: listMain.length),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.grey.shade200, width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: txtSearch,
        onChanged: (value) {
          if (value.length > 2) {
            searchDbRefresh();
          }
          if (value.isEmpty) {
            dataDbRefresh();
          }
        },
        style: TextStyle(
          fontSize: 16.sp,
          fontFamily: 'Poppins',
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: Resources.of(context).strings.searchHint,
          hintStyle: TextStyle(
            fontSize: 16.sp,
            fontFamily: 'Poppins',
            color: appColors().gray[400],
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Icon(Icons.search, size: 22.sp, color: Colors.grey[600]),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 18.w,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.download_outlined,
              size: 60.sp,
              color: appColors().gray[300],
            ),
          ),
          SizedBox(height: 32.w),
          Text(
            'No Downloads Yet',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.w),
          Text(
            'Download your favorite songs to\nlisten offline anytime',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w400,
              fontFamily: 'Poppins',
              color: appColors().gray[500],
              height: 1.5,
            ),
          ),
          SizedBox(height: 32.w),
          // Pull to refresh hint
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25.r),
              border: Border.all(color: Colors.grey.shade200, width: 1.w),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 18.sp, color: Colors.grey[600]),
                SizedBox(width: 8.w),
                Text(
                  connected && !_offlineModeService.isOfflineMode
                      ? 'Pull down to refresh'
                      : 'Pull down to refresh local data',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                    color: appColors().gray[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build download status indicator
  Widget _buildDownloadStatusIndicator() {
    return AnimatedBuilder(
      animation: _downloadController,
      builder: (context, child) {
        // Count active downloads
        int activeDownloads = 0;
        if (listMain.isNotEmpty) {
          for (final item in listMain) {
            if (_downloadController.isDownloading(item.id)) {
              activeDownloads++;
            }
          }
        }

        if (activeDownloads == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: appColors().primaryColorApp.withOpacity(0.2),
              width: 1.w,
            ),
            boxShadow: [
              BoxShadow(
                color: appColors().primaryColorApp.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Download progress indicator
              SizedBox(
                width: 24.w,
                height: 24.w,
                child: CircularProgressIndicator(
                  strokeWidth: 3.w,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    appColors().primaryColorApp,
                  ),
                ),
              ),

              SizedBox(width: 16.w),

              // Status text
              Expanded(
                child: Text(
                  activeDownloads == 1
                      ? 'Downloading 1 song...'
                      : 'Downloading $activeDownloads songs...',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    color: appColors().primaryColorApp,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshDownloads() async {
    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();

    try {
      // Check connectivity status first
      await checkConn();

      if (connected && !_offlineModeService.isOfflineMode) {
        // Online mode: Refresh local data first, then sync with server in background
        await dataDbRefresh();

        // Sync with server if token is available (this runs in background)
        if (token.isNotEmpty) {
          // Don't await this - let it run in background while showing current downloads
          downListAPI(token)
              .then((_) {
                if (mounted) {
                  _showSuccessMessage('Downloads refreshed from server');
                }
              })
              .catchError((error) {
                if (mounted) {
                  _showErrorMessage('Failed to refresh downloads from server');
                }
              });
        } else {
          if (mounted) {
            _showSuccessMessage('Local downloads refreshed');
          }
        }
      } else {
        // Offline mode: Just refresh local data and show informative message
        await dataDbRefresh();

        if (mounted) {
          _showOfflineRefreshMessage();
        }
      }
    } catch (error) {
      print('[Download] _refreshDownloads error: $error');
      if (mounted) {
        if (connected && !_offlineModeService.isOfflineMode) {
          _showErrorMessage('Failed to refresh downloads from server');
        } else {
          _showErrorMessage('Failed to refresh local downloads');
        }
      }
    }
  }

  Widget _buildDownloadCard(int index) {
    final bool isBeingDeleted = _deletingIndex == index;

    return MusicCardWrapper(
      menuData: _createMenuData(index),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.w),
        decoration: BoxDecoration(
          color: isBeingDeleted ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isBeingDeleted ? 0.02 : 0.08),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isBeingDeleted ? Colors.red.shade200 : Colors.grey.shade100,
            width: 1.w,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isBeingDeleted ? null : () => _togglePlayback(index),
            borderRadius: BorderRadius.circular(20.r),
            child: Opacity(
              opacity: isBeingDeleted ? 0.6 : 1.0,
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Row(
                  children: [
                    // Song Image with enhanced styling
                    _buildStaticTrackImage(index),

                    SizedBox(width: 18.w),

                    // Song Info with improved layout
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listMain[index].name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 6.w),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  listMain[index].artistname,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Poppins',
                                    color: appColors().gray[500],
                                  ),
                                ),
                              ),
                              // Duration removed as per request
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 16.w),

                    // Action Buttons with enhanced design
                    _buildActionButtons(index),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Create menu data for context menu and long press
  MusicContextMenuData _createMenuData(int index) {
    String imageUrl = listMain[index].image;

    return MusicContextMenuData(
      title: listMain[index].name,
      subtitle: listMain[index].artistname,
      imageUrl: imageUrl,
      type: MusicType.song,
      actions: [
        // Play action
        MusicContextAction(
          title: 'Play',
          icon: Icons.play_arrow,
          iconColor: appColors().primaryColorApp,
          onTap: () => _togglePlayback(index),
        ),
        // Remove from downloads action
        MusicContextAction(
          title: 'Remove from Downloads',
          icon: Icons.delete_outline,
          iconColor: Colors.red[600],
          isDestructive: true,
          onTap: () => _removeFromDownloadsAPI(index),
        ),
      ],
    );
  }

  /// Build action buttons area - shows download progress or normal controls
  Widget _buildActionButtons(int index) {
    return AnimatedBuilder(
      animation: _downloadController,
      builder: (context, child) {
        final trackId = listMain[index].id;
        final isDownloading = _downloadController.isDownloading(trackId);
        final progress = _downloadController.getDownloadProgress(trackId);

        if (isDownloading) {
          // Show download progress instead of normal controls
          return _buildDownloadProgressWidget(progress);
        } else {
          // Show simple three-dot menu for context actions or just call context menu directly
          return _buildSimpleThreeDotMenu(index);
        }
      },
    );
  }

  /// Build simple three-dot menu that shows context menu
  Widget _buildSimpleThreeDotMenu(int index) {
    return GestureDetector(
      onTap: () => _showContextMenu(index),
      child: Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: appColors().gray[100],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200, width: 1.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.more_vert, color: appColors().gray[500], size: 22.sp),
      ),
    );
  }

  // Show context menu for three-dot button
  void _showContextMenu(int index) {
    MusicContextMenuHelper.show(
      context: context,
      data: _createMenuData(index),
      position: const Offset(0, 0), // Will be calculated by the helper
      cardSize: const Size(200, 100), // Default size
    );
  }

  /// Build download progress widget
  Widget _buildDownloadProgressWidget(double progress) {
    return SizedBox(
      width: 88.w, // Wider to accommodate progress text
      height: 44.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: appColors().gray[100],
              shape: BoxShape.circle,
            ),
          ),

          // Progress circle
          SizedBox(
            width: 36.w,
            height: 36.w,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.w,
              backgroundColor: appColors().gray[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                appColors().primaryColorApp,
              ),
            ),
          ),

          // Download icon
          Icon(Icons.download, color: appColors().primaryColorApp, size: 16.sp),

          // Progress percentage text (positioned to the right)
          Positioned(
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.w),
              decoration: BoxDecoration(
                color: appColors().primaryColorApp.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: appColors().primaryColorApp.withOpacity(0.3),
                  width: 1.w,
                ),
              ),
              child: Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: appColors().primaryColorApp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build enhanced track image with improved styling
  Widget _buildStaticTrackImage(int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: SizedBox(
          width: 64.w,
          height: 64.w,
          child: CachedNetworkImage(
            imageUrl: listMain[index].image,
            width: 64.w,
            height: 64.w,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildImagePlaceholder(),
            errorWidget: (context, url, error) => _buildImagePlaceholder(),
            memCacheWidth: 64,
            memCacheHeight: 64,
          ),
        ),
      ),
    );
  }

  /// Build image placeholder widget
  Widget _buildImagePlaceholder() {
    return Container(
      width: 64.w,
      height: 64.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[300]!, Colors.grey[200]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Icon(Icons.music_note, color: appColors().gray[400], size: 28.w),
    );
  }

  void _togglePlayback(int index) async {
    HapticFeedback.lightImpact();

    if (_audioHandler == null) return;

    try {
      // Check if this track is currently playing
      final currentMediaItem = _audioHandler!.mediaItem.value;
      final isCurrentTrack =
          currentMediaItem?.extras?['audio_id']?.toString() ==
          listMain[index].id;
      final isPlaying = _audioHandler!.playbackState.value.playing;

      if (isCurrentTrack && isPlaying) {
        // Pause current track
        await _audioHandler!.pause();
      } else {
        // Play new track or resume current track
        await _playTrack(index);
      }
    } catch (e) {
      debugPrint('Error toggling playback: $e');
      if (mounted) {
        _showErrorMessage('Failed to play audio');
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _playTrack(int index) async {
    try {
      print('[Download] _playTrack called with index: $index');

      if (index < 0 || index >= downloadedTracks.length) {
        _showErrorMessage('Invalid track selection');
        return;
      }

      // Use MusicManager for seamless playback integration
      final musicManager = MusicManager();

      print('[Download] Playing track: ${downloadedTracks[index].audio_title}');
      print('[Download] Total downloaded tracks: ${downloadedTracks.length}');

      try {
        // Replace queue with downloaded tracks and start playback
        await musicManager.replaceQueue(
          musicList: downloadedTracks,
          startIndex: index,
          pathImage:
              "images/audio/thumb/", // Default path for downloaded tracks
          audioPath: "audio/", // Default audio path
          contextType: 'downloaded_music',
          contextId: 'offline_mode',
          callSource: 'Download._playTrack',
        );

        print('[Download] Queue replacement completed successfully');

        // Navigate to music player UI if not already there
        if (mounted) {
          _navigateToMusicPlayer(index);
        }
      } catch (e) {
        print('[Download] Queue replacement failed: $e');
        if (mounted) {
          _showErrorMessage('Failed to start playback: ${e.toString()}');
        }
      }
    } catch (e) {
      debugPrint('[Download] Error in _playTrack: $e');
      if (mounted) {
        _showErrorMessage('Failed to play audio');
      }
    }
  }

  /// Navigate to the music player with the downloaded tracks
  void _navigateToMusicPlayer(int index) {
    // Instead of navigating to full music player directly,
    // let the mini player handle this. The mini player is already shown
    // when the queue is replaced. User can tap mini player to open full player.
    print('[Download] Music started - mini player should be visible');

    // Ensure mini player state is set correctly
    final stateManager = MusicPlayerStateManager();
    stateManager.showMiniPlayerForMusicStart();

    // NO NAVIGATION TO FULL PLAYER - let mini player handle this
    // User can tap mini player to open full player if needed
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              strokeWidth: 4.w,
              valueColor: AlwaysStoppedAnimation<Color>(
                appColors().primaryColorApp,
              ),
            ),
          ),
          SizedBox(height: 32.w),
          Text(
            'Loading Downloads...',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8.w),
          Text(
            'Please wait while we load your downloads',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              fontFamily: 'Poppins',
              color: appColors().gray[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Remove track from downloads using API
  Future<void> _removeFromDownloadsAPI(int index) async {
    try {
      HapticFeedback.lightImpact();

      if (token.isEmpty) {
        _showErrorMessage('Please log in to manage downloads');
        return;
      }

      // Show confirmation dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: Text(
                'Remove Download',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: Colors.black87,
                ),
              ),
              content: Text(
                'Are you sure you want to remove "${listMain[index].name}" from downloads?',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Poppins',
                  color: appColors().gray[500],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                      color: appColors().gray[500],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Remove',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: Colors.red[600],
                    ),
                  ),
                ),
              ],
            ),
      );

      if (confirmed != true) return;

      // Validate index before proceeding
      if (index < 0 || index >= listMain.length) {
        _showErrorMessage('Invalid selection. Please try again.');
        return;
      }

      if (mounted) {
        setState(() {
          isLoading = true;
          _deletingIndex = index; // Track which item is being deleted
        });
      }

      // Get the track ID for removal
      String trackId = listMain[index].id;

      // Call the API using DownloadPresenter (pass BuildContext first)
      await _downloadPresenter.addRemoveFromDownload(
        context,
        trackId,
        token,
        tag: "remove",
      );

      // Update download controller state
      await _downloadController.removeFromDownloads(trackId);

      // Immediately update local state for better UX with animation
      if (mounted) {
        setState(() {
          // Remove the item from the current lists with smooth animation
          if (index < listMain.length) {
            listMain.removeAt(index);
          }
          if (index < downloadedTracks.length) {
            downloadedTracks.removeAt(index);
          }
        });

        // Small delay to show the removal animation
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // Refresh data from server to ensure consistency
      await _downloadController.syncDownloads();
      _loadExistingDownloads();

      if (mounted) {
        _showSuccessMessage('Removed from downloads successfully');
        HapticFeedback.mediumImpact();
      }
    } catch (error) {
      debugPrint('[Download] _removeFromDownloadsAPI error: $error');
      if (mounted) {
        _showErrorMessage('Failed to remove from downloads. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          _deletingIndex = null; // Reset deleting state
        });
      }
    }
  }
}

class Resources {
  Resources(BuildContext context);

  StringsLocalization get strings {
    switch ('en') {
      case 'ar':
        return ArabicStrings();
      case 'fn':
        return FranchStrings();
      default:
        return EnglishStrings();
    }
  }

  static Resources of(BuildContext context) {
    return Resources(context);
  }
}
