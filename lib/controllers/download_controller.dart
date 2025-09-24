import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/models/downloaded_music.dart';
import 'package:jainverse/services/download_service.dart';
import 'package:jainverse/repositories/download_repository.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter/material.dart'; // removed duplicate import
import 'package:jainverse/UI/Download.dart';
import 'package:jainverse/main.dart';

/// Controller for managing download state and operations
class DownloadController extends ChangeNotifier {
  // Local notification plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final DownloadController _instance = DownloadController._internal();
  factory DownloadController() => _instance;
  DownloadController._internal();

  final DownloadService _downloadService = DownloadService();
  final DownloadRepository _downloadRepository = DownloadRepository();

  static const String _hiveBoxName = 'downloaded_music';
  Box<DownloadedMusic>? _downloadBox;

  // State management
  List<DownloadedMusic> _downloadedTracks = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String _imagePath = '';
  String _audioPath = '';

  // Download progress tracking
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadStatus =
      {}; // 'downloading', 'completed', 'failed'
  final Map<String, double> _lastNotificationProgress =
      {}; // For throttling notifications

  // iOS UI callback for showing download progress messages
  Function(String message)? _iOSUICallback;

  // Getters
  List<DownloadedMusic> get downloadedTracks =>
      List.unmodifiable(_downloadedTracks);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get imagePath => _imagePath;
  String get audioPath => _audioPath;
  int get downloadedCount => _downloadedTracks.length;

  /// Set callback for iOS UI progress messages
  void setIOSUICallback(Function(String message)? callback) {
    _iOSUICallback = callback;
  }

  /// Show platform-specific download message
  /// iOS: Show UI messages via callback
  /// Android: Silent (relies on notifications only)
  void _showPlatformSpecificMessage(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    // iOS: Show UI message via callback
    if (Platform.isIOS && _iOSUICallback != null) {
      _iOSUICallback!(message);
    }

    // Android: Uses notifications only (no UI overlay)
    // The notifications are handled separately in _showDownloadProgressNotification
  }

  /// Initialize the download controller
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      developer.log(
        'Initializing DownloadController',
        name: 'DownloadController',
      );

      // Initialize download service
      await _downloadService.initialize();

      // Initialize Hive box
      await _initializeHiveBox();

      // Load existing downloads from Hive
      await _loadDownloadsFromHive();

      // Initialize local notifications
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Initialize notification channels and permissions
      await _initializeNotificationChannels();

      // Initialize notification channels and request permissions
      await _initializeNotificationChannels();

      _isInitialized = true;
      developer.log(
        'DownloadController initialized successfully',
        name: 'DownloadController',
      );
    } catch (e) {
      developer.log(
        'Failed to initialize DownloadController: $e',
        name: 'DownloadController',
      );
    }
  }

  /// Initialize Hive box for storing download metadata
  Future<void> _initializeHiveBox() async {
    try {
      // Hive adapter will be generated and registered in main.dart
      _downloadBox = await Hive.openBox<DownloadedMusic>(_hiveBoxName);
    } catch (e) {
      developer.log(
        'Failed to initialize Hive box: $e',
        name: 'DownloadController',
      );
      rethrow;
    }
  }

  /// Load downloads from Hive storage
  Future<void> _loadDownloadsFromHive() async {
    try {
      if (_downloadBox == null) return;

      _downloadedTracks = _downloadBox!.values.toList();
      developer.log(
        'Loaded ${_downloadedTracks.length} downloads from Hive',
        name: 'DownloadController',
      );

      notifyListeners();
    } catch (e) {
      developer.log(
        'Failed to load downloads from Hive: $e',
        name: 'DownloadController',
      );
    }
  }

  /// Sync downloads with server and download missing files
  Future<void> syncDownloads() async {
    if (!_isInitialized) await initialize();

    _setLoading(true);

    try {
      developer.log('Starting download sync', name: 'DownloadController');

      // Get server download list
      final serverData = await _downloadRepository.getDownloadedMusicList();
      if (serverData == null) {
        throw Exception('Failed to fetch server download list');
      }

      _imagePath = serverData.imagePath;
      _audioPath = serverData.audioPath;

      // --- BEGIN: Remove local tracks not in server list ---
      final serverTrackIds =
          serverData.data.map((track) => track.id.toString()).toSet();
      final localTrackIds = _downloadedTracks.map((track) => track.id).toSet();
      final orphanedTrackIds = localTrackIds.difference(serverTrackIds);
      if (orphanedTrackIds.isNotEmpty) {
        developer.log(
          'Found orphaned local tracks: \\${orphanedTrackIds.toList()}',
          name: 'DownloadController',
        );
        for (final orphanId in orphanedTrackIds) {
          try {
            final orphanTrack = _downloadedTracks.firstWhere(
              (t) => t.id == orphanId,
            );
            await _downloadService.deleteDownloadedFiles(orphanTrack);
            await _removeLocalDownload(orphanId);
            developer.log(
              'Deleted orphaned local track: \\${orphanTrack.id}',
              name: 'DownloadController',
            );
          } catch (e) {
            developer.log(
              'Orphaned track with id $orphanId not found in local list',
              name: 'DownloadController',
            );
          }
        }
      }
      // --- END: Remove local tracks not in server list ---

      // Process each track from server
      for (final track in serverData.data) {
        await _syncTrack(track);
      }

      // Clean up orphaned files
      await _downloadService.cleanupOrphanedFiles(_downloadedTracks);

      developer.log(
        'Download sync completed successfully',
        name: 'DownloadController',
      );
    } catch (e) {
      developer.log('Download sync failed: $e', name: 'DownloadController');
    } finally {
      _setLoading(false);
    }
  }

  /// Sync a single track
  Future<void> _syncTrack(DataMusic track) async {
    try {
      final trackId = track.id.toString();

      // Check if track already exists in local storage
      final existingTrack = _downloadedTracks.firstWhere(
        (d) => d.id == trackId,
        orElse:
            () => DownloadedMusic(
              id: '',
              title: '',
              artist: '',
              albumName: '',
              imageUrl: '',
              audioUrl: '',
              duration: '',
              localAudioPath: '',
              localImagePath: '',
              downloadedAt: DateTime.now(),
              fileSize: 0,
              isDownloadComplete: false,
            ),
      );

      if (existingTrack.id.isNotEmpty && existingTrack.isDownloadComplete) {
        // Check if files still exist
        final audioExists = await _downloadService.fileExists(
          existingTrack.localAudioPath,
        );
        final imageExists = await _downloadService.fileExists(
          existingTrack.localImagePath,
        );

        if (audioExists && imageExists) {
          developer.log(
            'Track $trackId already downloaded and files exist',
            name: 'DownloadController',
          );
          return;
        }
      }

      // Download missing files
      await _downloadTrackFiles(track);
    } catch (e) {
      developer.log(
        'Failed to sync track ${track.id}: $e',
        name: 'DownloadController',
      );
    }
  }

  /// Download files for a track
  Future<void> _downloadTrackFiles(DataMusic track) async {
    final trackId = track.id.toString();

    try {
      _downloadStatus[trackId] = 'downloading';
      notifyListeners();

      // Show platform-specific starting message
      _showPlatformSpecificMessage(
        'Starting download for "${track.audio_title}"...',
      );

      // Show initial download notification (Android only for start)
      final notificationId = int.tryParse(trackId) ?? 0;
      if (Platform.isAndroid) {
        await _showDownloadProgressNotification(
          title: 'Downloading Song',
          trackId: trackId,
          songTitle: track.audio_title,
          progress: 0.0,
          id: notificationId,
        );
      }

      // Generate safe filenames
      final audioFileName =
          '${_downloadService.generateSafeFileName(track.audio_title)}_$trackId.${_getFileExtension(track.audio)}';
      final imageFileName =
          '${_downloadService.generateSafeFileName(track.audio_title)}_$trackId.${_getFileExtension(track.image)}';

      // Construct full URLs
      final audioUrl = _constructFullUrl(track.audio, _audioPath);
      final imageUrl = _constructFullUrl(track.image, _imagePath);

      // Download audio file with enhanced progress tracking
      final localAudioPath = await _downloadService.downloadAudioFile(
        url: audioUrl,
        fileName: audioFileName,
        trackId: trackId,
        onProgress: (progress) {
          _downloadProgress[trackId] = progress;

          // Show progress message for iOS UI (more frequent updates)
          if (Platform.isIOS) {
            final percentage = (progress * 100).round();
            final lastPercentage =
                (_lastNotificationProgress[trackId] ?? 0.0 * 100).round();

            // For iOS, update UI more frequently (every 5%) to ensure visibility
            bool shouldUpdate =
                percentage - lastPercentage >= 5 ||
                percentage == 100 ||
                percentage == 0 ||
                (percentage >= 25 && lastPercentage < 25) ||
                (percentage >= 50 && lastPercentage < 50) ||
                (percentage >= 75 && lastPercentage < 75);

            if (shouldUpdate) {
              _lastNotificationProgress[trackId] = progress;
              developer.log(
                'iOS UI Update: ${track.audio_title} - $percentage%',
                name: 'DownloadController',
              );
              _showPlatformSpecificMessage(
                'Downloading "${track.audio_title}": $percentage%',
              );
            }
          }

          // Show progress notifications for Android only
          if (Platform.isAndroid) {
            final currentPercentage = (progress * 100).round();
            final lastPercentage =
                (_lastNotificationProgress[trackId] ?? 0.0 * 100).round();

            // Throttle notification updates to every 5% to avoid spam
            if (currentPercentage - lastPercentage >= 5 ||
                currentPercentage == 100) {
              _lastNotificationProgress[trackId] = progress;

              // Update progress notification in real-time (Android only)
              _showDownloadProgressNotification(
                title: 'Downloading Song',
                trackId: trackId,
                songTitle: track.audio_title,
                progress: progress,
                id: notificationId,
              );
            }
          }

          notifyListeners();
        },
        onError: (error) {
          developer.log(
            'Audio download error for track $trackId: $error',
            name: 'DownloadController',
          );
        },
      );

      // Download image file
      final localImagePath = await _downloadService.downloadImageFile(
        url: imageUrl,
        fileName: imageFileName,
        trackId: trackId,
        onError: (error) {
          developer.log(
            'Image download error for track $trackId: $error',
            name: 'DownloadController',
          );
        },
      );

      if (localAudioPath != null) {
        // Save metadata to Hive
        final downloadedMusic = DownloadedMusic.fromDataMusic(
          id: trackId,
          title: track.audio_title,
          artist: track.artists_name,
          albumName: track.audio_slug,
          imageUrl: imageUrl,
          audioUrl: audioUrl,
          duration: track.audio_duration,
          localAudioPath: localAudioPath,
          localImagePath: localImagePath ?? '',
          isDownloadComplete: true,
        );

        await _saveDownloadToHive(downloadedMusic);

        _downloadStatus[trackId] = 'completed';
        developer.log(
          'Successfully downloaded track: $trackId',
          name: 'DownloadController',
        );

        // Show platform-specific completion message
        _showPlatformSpecificMessage(
          'Download completed: "${track.audio_title}"',
          isSuccess: true,
        );

        // Show completion notification:
        // - Android: Progress notification with 100%
        // - iOS: Completion notification only
        await _showDownloadProgressNotification(
          title: 'Download Complete',
          trackId: trackId,
          songTitle: track.audio_title,
          progress: 1.0,
          id: notificationId,
          isCompleted: true,
        );
      } else {
        _downloadStatus[trackId] = 'failed';
        developer.log(
          'Failed to download track: $trackId',
          name: 'DownloadController',
        );

        // Show platform-specific failure message
        _showPlatformSpecificMessage(
          'Download failed: "${track.audio_title}"',
          isError: true,
        );

        // Show failure notification (Android only)
        if (Platform.isAndroid) {
          await _showDownloadProgressNotification(
            title: 'Download Failed',
            trackId: trackId,
            songTitle: track.audio_title,
            progress: 0.0,
            id: notificationId,
            isFailed: true,
          );
        }
      }
    } catch (e) {
      _downloadStatus[trackId] = 'failed';
      developer.log(
        'Failed to download track $trackId: $e',
        name: 'DownloadController',
      );

      // Show platform-specific failure message
      _showPlatformSpecificMessage(
        'Download failed: "${track.audio_title}"',
        isError: true,
      );

      // Show failure notification for exceptions (Android only)
      if (Platform.isAndroid) {
        final notificationId = int.tryParse(trackId) ?? 0;
        await _showDownloadProgressNotification(
          title: 'Download Failed',
          trackId: trackId,
          songTitle: track.audio_title,
          progress: 0.0,
          id: notificationId,
          isFailed: true,
        );
      }
    } finally {
      _downloadProgress.remove(trackId);
      notifyListeners();
    }
  }

  /// Show progress notification for download with progress bar and percentage
  /// Android: Shows notifications for start, progress, and completion
  /// iOS: Shows notifications only for completion
  Future<void> _showDownloadProgressNotification({
    required String title,
    required String trackId,
    required String songTitle,
    required double progress,
    required int id,
    bool isCompleted = false,
    bool isFailed = false,
  }) async {
    final percentage = (progress * 100).round();

    String body;
    String channelId;
    String channelName;
    Importance importance;
    Priority priority;
    Color? notificationColor;

    if (isCompleted) {
      body = '✅ "$songTitle" downloaded successfully!';
      channelId = 'download_complete_channel';
      channelName = 'Download Complete';
      importance = Importance.high;
      priority = Priority.high;
      notificationColor = const Color(0xFF4CAF50); // Green for success
    } else if (isFailed) {
      body = '❌ Failed to download "$songTitle". Tap to retry.';
      channelId = 'download_failed_channel';
      channelName = 'Download Failed';
      importance = Importance.high;
      priority = Priority.high;
      notificationColor = const Color(0xFFF44336); // Red for failure
    } else {
      body = '📥 Downloading "$songTitle"... $percentage%';
      channelId = 'download_progress_channel';
      channelName = 'Download Progress';
      importance = Importance.max;
      priority = Priority.high;
      notificationColor = const Color(0xFF2196F3); // Blue for progress
    }

    // Enhanced subtext to show more detailed progress
    String? subText;
    if (!isCompleted && !isFailed) {
      subText = '$percentage% complete • Tap to cancel';
    } else if (isCompleted) {
      subText = 'Ready to play';
    } else if (isFailed) {
      subText = 'Check your internet connection';
    }

    // Android: Show notifications for all states (start, progress, completion, failure)
    if (Platform.isAndroid) {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription:
            isCompleted
                ? 'Notifies when downloads are complete'
                : isFailed
                ? 'Notifies when downloads fail'
                : 'Shows real-time download progress with progress bar',
        importance: importance,
        priority: priority,
        showWhen: false,
        when: DateTime.now().millisecondsSinceEpoch,
        ongoing: !isCompleted && !isFailed, // Keep notification during download
        autoCancel: isCompleted || isFailed,
        showProgress: !isCompleted && !isFailed,
        maxProgress: 100,
        progress: percentage,
        indeterminate: false,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: notificationColor,
        colorized: true, // Use the color for the entire notification
        category:
            isCompleted
                ? AndroidNotificationCategory.status
                : isFailed
                ? AndroidNotificationCategory.error
                : AndroidNotificationCategory.progress,
        visibility: NotificationVisibility.public,
        subText: subText,
        // Enhanced styling for better UX
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
          summaryText: subText,
          htmlFormatSummaryText: false,
        ),
        // Actions based on state
        actions: _getNotificationActions(isCompleted, isFailed, trackId),
      );

      final NotificationDetails androidNotificationDetails =
          NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        id,
        title,
        body,
        androidNotificationDetails,
        payload: trackId,
      );
    }

    // iOS: Show notification only for completion
    if (Platform.isIOS && isCompleted) {
      DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: null,
        subtitle: subText,
        threadIdentifier: 'download_complete',
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails iOSNotificationDetails = NotificationDetails(
        iOS: iOSDetails,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        iOSNotificationDetails,
        payload: trackId,
      );
    }

    // Auto-dismiss completed/failed notifications after a delay
    if (isCompleted || isFailed) {
      Timer(const Duration(seconds: 5), () async {
        await _cancelDownloadProgressNotification(id);

        // Show a simple confirmation notification after dismissing the progress notification
        // Only for Android or iOS completion
        if (isCompleted && ((Platform.isAndroid) || Platform.isIOS)) {
          await _showSimpleDownloadConfirmation(songTitle, trackId);
        }
      });
    }
  }

  /// Get notification actions based on download state
  List<AndroidNotificationAction>? _getNotificationActions(
    bool isCompleted,
    bool isFailed,
    String trackId,
  ) {
    if (isCompleted) {
      return null;
    } else if (isFailed) {
      return [
        const AndroidNotificationAction(
          'retry_download',
          '🔄 Retry',
          cancelNotification: true,
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'dismiss_failed',
          'Dismiss',
          cancelNotification: true,
          showsUserInterface: false,
        ),
      ];
    } else {
      return null;
    }
  }

  /// Cancel download progress notification
  Future<void> _cancelDownloadProgressNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Show a simple confirmation notification after download completes
  Future<void> _showSimpleDownloadConfirmation(
    String songTitle,
    String trackId,
  ) async {
    // Generate a unique notification ID for the confirmation
    final confirmationId =
        int.tryParse(trackId) ?? 0 + 10000; // Add offset to avoid conflicts

    const String title = '🎵 Download Complete';
    final String body = '"$songTitle" is ready to play offline';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'download_confirmation_channel',
          'Download Confirmation',
          channelDescription: 'Simple confirmation when downloads complete',
          importance: Importance.high, // Changed to high for better visibility
          priority: Priority.high, // Changed to high for better visibility
          showWhen: true,
          when: null, // Use current time
          ongoing: false,
          autoCancel: true,
          showProgress: false,
          icon: '@mipmap/ic_launcher', // Use app launcher icon
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: const Color(0xFF4CAF50), // Green color for success
          colorized: true, // Enable colorization for success feel
          category: AndroidNotificationCategory.status,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(
            '"$songTitle" is ready to play offline',
            htmlFormatBigText: false,
            contentTitle: '🎵 Download Complete',
            htmlFormatContentTitle: false,
            summaryText: 'Tap to open JainVerse',
            htmlFormatSummaryText: false,
          ),
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1, // Add badge to indicate new download
        subtitle: 'Tap to open JainVerse',
        threadIdentifier: 'download_complete',
        interruptionLevel: InterruptionLevel.active, // Make it prominent
        categoryIdentifier: 'DOWNLOAD_COMPLETE', // Category for grouping
      ),
    );

    await _localNotifications.show(
      confirmationId,
      title,
      body,
      notificationDetails,
      payload: trackId,
    );
    developer.log(
      'Simple download confirmation shown for: $songTitle',
      name: 'DownloadController',
    );
  }

  /// Handle notification response (e.g., cancel button press)
  /// Handle notification response (e.g., cancel button press)
  void _onNotificationResponse(NotificationResponse response) {
    final trackId = response.payload ?? '';
    final actionId = response.actionId ?? '';

    // Handle tap on notification (no specific action)
    if (actionId.isEmpty) {
      // Navigate to downloads screen
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const Download()),
      );
      return;
    }
    developer.log(
      'Notification response: actionId=$actionId, trackId=$trackId',
      name: 'DownloadController',
    );

    switch (actionId) {
      case 'cancel_download':
        if (trackId.isNotEmpty) {
          // Cancel the download
          _downloadService.cancelDownload(trackId);
          _downloadStatus[trackId] = 'cancelled';
          _downloadProgress.remove(trackId);

          // Cancel the progress notification
          final notificationId = int.tryParse(trackId) ?? 0;
          _cancelDownloadProgressNotification(notificationId);

          notifyListeners();

          developer.log(
            'Download cancelled by user for track: $trackId',
            name: 'DownloadController',
          );
        }
        break;

      case 'retry_download':
        if (trackId.isNotEmpty) {
          // Retry the download
          developer.log(
            'Retrying download for track: $trackId',
            name: 'DownloadController',
          );
          // Find the track and retry download
          _retryDownload(trackId);
        }
        break;

      case 'play_song':
        if (trackId.isNotEmpty) {
          developer.log(
            'Play song requested for track: $trackId',
            name: 'DownloadController',
          );
          // You can implement navigation to music player here
          // or trigger an event that the music player can listen to
        }
        break;

      case 'minimize_notification':
        // For minimize, we don't cancel but might want to show a minimal version
        developer.log(
          'Notification minimized for track: $trackId',
          name: 'DownloadController',
        );
        break;

      case 'dismiss_complete':
      case 'dismiss_failed':
        if (trackId.isNotEmpty) {
          final notificationId = int.tryParse(trackId) ?? 0;
          _cancelDownloadProgressNotification(notificationId);
        }
        break;

      case 'dismiss_confirmation':
        if (trackId.isNotEmpty) {
          final confirmationId = int.tryParse(trackId) ?? 0 + 10000;
          _localNotifications.cancel(confirmationId);
        }
        break;

      default:
        developer.log(
          'Unknown notification action: $actionId',
          name: 'DownloadController',
        );
    }
  }

  /// Retry a failed download
  Future<void> _retryDownload(String trackId) async {
    try {
      // Clear previous status
      _downloadStatus.remove(trackId);
      _downloadProgress.remove(trackId);

      // Find the track data from server or local storage
      // For now, we'll need to get the track data to retry
      // This assumes you have a way to get track data by ID
      developer.log(
        'Implementing retry logic for track: $trackId',
        name: 'DownloadController',
      );

      // TODO: Implement actual retry logic based on your app's architecture
      // You might need to:
      // 1. Get track data from your API or local storage
      // 2. Call _downloadTrackFiles(track) again
    } catch (e) {
      developer.log(
        'Failed to retry download for track $trackId: $e',
        name: 'DownloadController',
      );
    }
  }

  /// Toggle download status for a track
  Future<bool> toggleDownload(String trackId) async {
    if (!_isInitialized) await initialize();

    try {
      final isDownloaded = isTrackDownloaded(trackId);

      if (isDownloaded) {
        return await removeFromDownloads(trackId);
      } else {
        return await addToDownloads(trackId);
      }
    } catch (e) {
      developer.log(
        'Failed to toggle download for track $trackId: $e',
        name: 'DownloadController',
      );
      return false;
    }
  }

  /// Add a track to downloads
  Future<bool> addToDownloads(String trackId) async {
    try {
      // Add to server
      final success = await _downloadRepository.addTrackToDownloads(trackId);
      if (success) {
        // Trigger sync to download the file
        await syncDownloads();
      }
      return success;
    } catch (e) {
      developer.log(
        'Failed to add track $trackId to downloads: $e',
        name: 'DownloadController',
      );
      return false;
    }
  }

  /// Remove a track from downloads
  Future<bool> removeFromDownloads(String trackId) async {
    try {
      // Remove from server
      final success = await _downloadRepository.removeTrackFromDownloads(
        trackId,
      );
      if (success) {
        // Remove local files and metadata
        await _removeLocalDownload(trackId);
      }
      return success;
    } catch (e) {
      developer.log(
        'Failed to remove track $trackId from downloads: $e',
        name: 'DownloadController',
      );
      return false;
    }
  }

  /// Remove local download data
  Future<void> _removeLocalDownload(String trackId) async {
    try {
      final track = _downloadedTracks.firstWhere(
        (d) => d.id == trackId,
        orElse:
            () => DownloadedMusic(
              id: '',
              title: '',
              artist: '',
              albumName: '',
              imageUrl: '',
              audioUrl: '',
              duration: '',
              localAudioPath: '',
              localImagePath: '',
              downloadedAt: DateTime.now(),
              fileSize: 0,
              isDownloadComplete: false,
            ),
      );

      if (track.id.isNotEmpty) {
        // Delete files
        await _downloadService.deleteDownloadedFiles(track);

        // Remove from Hive
        await _downloadBox?.delete(trackId);

        // Update local list
        _downloadedTracks.removeWhere((d) => d.id == trackId);

        notifyListeners();
        developer.log(
          'Removed local download for track: $trackId',
          name: 'DownloadController',
        );
      }
    } catch (e) {
      developer.log(
        'Failed to remove local download for track $trackId: $e',
        name: 'DownloadController',
      );
    }
  }

  /// Save download metadata to Hive
  Future<void> _saveDownloadToHive(DownloadedMusic download) async {
    try {
      await _downloadBox?.put(download.id, download);

      // Update local list
      final index = _downloadedTracks.indexWhere((d) => d.id == download.id);
      if (index >= 0) {
        _downloadedTracks[index] = download;
      } else {
        _downloadedTracks.add(download);
      }

      notifyListeners();
    } catch (e) {
      developer.log(
        'Failed to save download to Hive: $e',
        name: 'DownloadController',
      );
    }
  }

  /// Check if a track is downloaded (with file verification)
  bool isTrackDownloaded(String trackId) {
    // Use the robust verification method
    return isTrackActuallyDownloaded(trackId);
  }

  /// Check if a track is actually downloaded with file verification
  bool isTrackActuallyDownloaded(String trackId) {
    try {
      final track = _downloadedTracks.firstWhere(
        (d) => d.id == trackId,
        orElse:
            () => DownloadedMusic(
              id: '',
              title: '',
              artist: '',
              albumName: '',
              imageUrl: '',
              audioUrl: '',
              duration: '',
              localAudioPath: '',
              localImagePath: '',
              downloadedAt: DateTime.now(),
              fileSize: 0,
              isDownloadComplete: false,
            ),
      );

      if (track.id.isEmpty || !track.isDownloadComplete) {
        return false;
      }

      // Verify actual files exist and are valid
      return _verifyLocalFiles(track);
    } catch (e) {
      developer.log(
        'Error checking track download status: $e',
        name: 'DownloadController',
      );
      return false;
    }
  }

  /// Verify local files exist and are valid
  bool _verifyLocalFiles(DownloadedMusic track) {
    try {
      // Check audio file
      if (track.localAudioPath.isNotEmpty) {
        final audioFile = File(track.localAudioPath);
        if (!audioFile.existsSync() || audioFile.lengthSync() == 0) {
          developer.log(
            'Audio file missing or empty for track ${track.id}',
            name: 'DownloadController',
          );
          return false;
        }
      } else {
        return false;
      }

      // Image file is optional, but if path exists, verify it
      if (track.localImagePath.isNotEmpty) {
        final imageFile = File(track.localImagePath);
        if (!imageFile.existsSync() || imageFile.lengthSync() == 0) {
          developer.log(
            'Image file missing or empty for track ${track.id}',
            name: 'DownloadController',
          );
          // Don't fail for missing image, just log
        }
      }

      return true;
    } catch (e) {
      developer.log(
        'Error verifying local files for track ${track.id}: $e',
        name: 'DownloadController',
      );
      return false;
    }
  }

  /// Verify download integrity and clean up invalid downloads
  Future<void> verifyAndCleanupDownloads() async {
    if (!_isInitialized) await initialize();

    try {
      final invalidTracks = <String>[];

      for (final track in _downloadedTracks) {
        if (!_verifyLocalFiles(track)) {
          invalidTracks.add(track.id);
          developer.log(
            'Found invalid download for track ${track.id}',
            name: 'DownloadController',
          );
        }
      }

      // Remove invalid downloads
      for (final trackId in invalidTracks) {
        await _removeLocalDownload(trackId);
        developer.log(
          'Cleaned up invalid download for track $trackId',
          name: 'DownloadController',
        );
      }

      if (invalidTracks.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      developer.log(
        'Error during download verification: $e',
        name: 'DownloadController',
      );
    }
  }

  /// Get local audio path for a track
  String? getLocalAudioPath(String trackId) {
    final track = _downloadedTracks.firstWhere(
      (d) => d.id == trackId && d.isDownloadComplete,
      orElse:
          () => DownloadedMusic(
            id: '',
            title: '',
            artist: '',
            albumName: '',
            imageUrl: '',
            audioUrl: '',
            duration: '',
            localAudioPath: '',
            localImagePath: '',
            downloadedAt: DateTime.now(),
            fileSize: 0,
            isDownloadComplete: false,
          ),
    );

    return track.id.isNotEmpty ? track.localAudioPath : null;
  }

  /// Get download progress for a track
  double getDownloadProgress(String trackId) {
    return _downloadProgress[trackId] ?? 0.0;
  }

  /// Check if a track is currently downloading
  bool isDownloading(String trackId) {
    return _downloadStatus[trackId] == 'downloading';
  }

  /// Get download status for a track
  String getDownloadStatus(String trackId) {
    return _downloadStatus[trackId] ?? 'not_downloaded';
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Construct full URL from relative path
  String _constructFullUrl(String relativePath, String basePath) {
    if (relativePath.startsWith('http')) {
      return relativePath;
    }

    const baseUrl = 'http://143.244.213.49/heargod-staging/public';

    // If relativePath starts with '/', it's already a complete path
    if (relativePath.startsWith('/')) {
      return '$baseUrl$relativePath';
    }

    // If basePath exists and relativePath doesn't start with '/', use basePath
    if (basePath.isNotEmpty) {
      return '$baseUrl/$basePath$relativePath';
    } else {
      return '$baseUrl/$relativePath';
    }
  }

  /// Get file extension from URL or filename
  String _getFileExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot >= 0) {
        return path.substring(lastDot + 1);
      }
    }

    // Default extensions
    if (url.contains('audio') || url.contains('.mp3') || url.contains('.m4a')) {
      return 'mp3';
    } else if (url.contains('image') ||
        url.contains('.jpg') ||
        url.contains('.png')) {
      return 'jpg';
    }

    return 'file';
  }

  /// Initialize notification channels and request permissions
  Future<void> _initializeNotificationChannels() async {
    // Request permissions explicitly for iOS
    if (Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Create notification channels for Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      // Download Progress Channel
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'download_progress_channel',
          'Download Progress',
          description: 'Shows real-time download progress with progress bar',
          importance: Importance.max,
          enableVibration: false,
          playSound: false,
        ),
      );

      // Download Complete Channel
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'download_complete_channel',
          'Download Complete',
          description: 'Notifies when downloads are complete',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      // Download Failed Channel
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'download_failed_channel',
          'Download Failed',
          description: 'Notifies when downloads fail',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      // Download Confirmation Channel
      await androidImplementation?.createNotificationChannel(
        const AndroidNotificationChannel(
          'download_confirmation_channel',
          'Download Confirmation',
          description: 'Simple confirmation when downloads complete',
          importance: Importance.defaultImportance,
          enableVibration: false,
          playSound: false,
        ),
      );
    }

    developer.log(
      'Notification channels initialized for ${Platform.isIOS ? 'iOS' : 'Android'}',
      name: 'DownloadController',
    );
  }

  /// Dispose method
  @override
  void dispose() {
    _downloadBox?.close();
    super.dispose();
  }
}
