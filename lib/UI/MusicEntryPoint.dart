import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/UI/MusicPlayerLogic.dart';
import 'package:jainverse/controllers/music_controller.dart';
import 'package:jainverse/controllers/playback_controller.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/controllers/user_music_controller.dart';
import 'package:jainverse/controllers/payment_controller.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/widgets/common/loader.dart';
import 'package:provider/provider.dart';
import 'package:jainverse/widgets/musicplayer/MusicPlayerView.dart';

// Global variables maintained for backward compatibility
int indixes = 0;
int indexOnScreenSelect = 0;
List<DataMusic> listCopy = [];
String idTag = '';
String type = '';
String audioPathMain = '';
bool checkCurrent = false;
List<MediaItem> listDataa = [];

/// Enhanced Queue Operation Manager - Centralized Concurrency Control
class QueueOperationManager {
  static final QueueOperationManager _instance =
      QueueOperationManager._internal();
  factory QueueOperationManager() => _instance;
  QueueOperationManager._internal();

  // Queue operation state management
  bool _isOperationInProgress = false;
  String _currentOperationOwner = '';
  DateTime _lastOperationTime = DateTime(0);
  Timer? _debounceTimer;
  Completer<void>? _currentOperation;

  // Debounce configuration
  static const Duration _debounceDuration = Duration(
    milliseconds: 500,
  ); // Increased from 300ms
  static const Duration _operationTimeout = Duration(
    seconds: 15,
  ); // Increased from 10s

  /// Check if an operation can proceed
  bool canStartOperation(String requesterId) {
    // Extract category ID from requesterId to detect new category navigation
    final newCategoryId = _extractCategoryId(requesterId);
    final currentCategoryId = _extractCategoryId(_currentOperationOwner);

    developer.log(
      '[QueueOperationManager] 🔍 Checking operation: $requesterId vs $_currentOperationOwner',
      name: 'QueueOperationManager',
    );

    // If this is a new category navigation, always allow it (interrupt current operation)
    if (newCategoryId != null &&
        currentCategoryId != null &&
        newCategoryId != currentCategoryId) {
      developer.log(
        '[QueueOperationManager] 🚀 New category navigation detected ($currentCategoryId → $newCategoryId), interrupting current operation',
        name: 'QueueOperationManager',
      );
      _forceInterrupt();
      return true;
    }

    if (_isOperationInProgress) {
      developer.log(
        '[QueueOperationManager] 🔒 Operation blocked - already in progress by: $_currentOperationOwner, requested by: $requesterId',
        name: 'QueueOperationManager',
      );
      return false;
    }

    // Check if there's a pending debounced operation for the same category
    if (_debounceTimer != null && _debounceTimer!.isActive) {
      // Allow interruption if it's a different category
      if (newCategoryId != null &&
          currentCategoryId != null &&
          newCategoryId != currentCategoryId) {
        developer.log(
          '[QueueOperationManager] 🚀 Different category detected, canceling debounced operation',
          name: 'QueueOperationManager',
        );
        _debounceTimer?.cancel();
        return true;
      }

      developer.log(
        '[QueueOperationManager] ⏱️ Operation blocked - pending debounced operation exists',
        name: 'QueueOperationManager',
      );
      return false;
    }

    final timeSinceLastOperation = DateTime.now().difference(
      _lastOperationTime,
    );
    if (timeSinceLastOperation < _debounceDuration) {
      developer.log(
        '[QueueOperationManager] ⏱️ Operation debounced - too soon since last operation ($timeSinceLastOperation < $_debounceDuration)',
        name: 'QueueOperationManager',
      );
      return false;
    }

    return true;
  }

  /// Extract category ID from operation requester ID
  String? _extractCategoryId(String requesterId) {
    // Match pattern like "MusicEntryPoint._replaceQueueInBackground.1" or "MusicEntryPoint._loadMusicDataFromCategory.2"
    final match = RegExp(
      r'MusicEntryPoint\.(?:_replaceQueueInBackground|_loadMusicDataFromCategory)\.(\d+)',
    ).firstMatch(requesterId);
    return match?.group(1);
  }

  /// Force interrupt current operation to allow new category navigation
  void _forceInterrupt() {
    if (_isOperationInProgress) {
      developer.log(
        '[QueueOperationManager] 🛑 Force interrupting operation: $_currentOperationOwner',
        name: 'QueueOperationManager',
      );
      _isOperationInProgress = false;
      _currentOperationOwner = '';
      _currentOperation?.complete();
      _currentOperation = null;
    }
    _debounceTimer?.cancel();

    // Also force clear MusicManager locks to ensure clean state
    developer.log(
      '[QueueOperationManager] 🧹 Clearing MusicManager locks for clean category switch',
      name: 'QueueOperationManager',
    );
    final musicManager = MusicManager();
    musicManager.forceClearLocks();
  }

  /// Start a queue operation with timeout protection
  Future<T> executeOperation<T>(
    String operationId,
    Future<T> Function() operation,
  ) async {
    if (!canStartOperation(operationId)) {
      throw StateError('Queue operation already in progress or debounced');
    }

    _isOperationInProgress = true;
    _currentOperationOwner = operationId;
    _lastOperationTime = DateTime.now();
    _currentOperation = Completer<void>();

    developer.log(
      '[QueueOperationManager] 🚀 Starting: $operationId',
      name: 'QueueOperationManager',
    );

    try {
      final result = await operation().timeout(_operationTimeout);
      developer.log(
        '[QueueOperationManager] ✅ Completed: $operationId',
        name: 'QueueOperationManager',
      );
      return result;
    } catch (e) {
      developer.log(
        '[QueueOperationManager] ❌ Failed: $operationId - $e',
        name: 'QueueOperationManager',
        error: e,
      );
      rethrow;
    } finally {
      _isOperationInProgress = false;
      _currentOperationOwner = '';
      _currentOperation?.complete();
      _currentOperation = null;
    }
  }

  /// Debounced queue replacement to prevent rapid-fire calls
  Future<void> debouncedQueueReplacement(
    String operationId,
    Future<void> Function() operation,
  ) async {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    // Set up new debounce timer
    final completer = Completer<void>();
    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        await executeOperation(operationId, operation);
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// Force reset the operation state (emergency only)
  void forceReset() {
    developer.log(
      '[QueueOperationManager] 🚨 Force resetting operation state',
      name: 'QueueOperationManager',
    );
    _isOperationInProgress = false;
    _currentOperationOwner = '';
    _debounceTimer?.cancel();
    _currentOperation?.complete();
    _currentOperation = null;
  }

  /// Get current operation status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'isOperationInProgress': _isOperationInProgress,
      'currentOperationOwner': _currentOperationOwner,
      'lastOperationTime': _lastOperationTime.toIso8601String(),
      'timeSinceLastOperation':
          DateTime.now().difference(_lastOperationTime).inMilliseconds,
      'hasPendingDebounce': _debounceTimer?.isActive ?? false,
    };
  }
}

/// Refactored Music Widget - Clean Entry Point
///
/// This widget now serves as a clean entry point that sets up all controllers
/// and delegates to the MusicPlayerUI for the actual interface.
/// All complex business logic has been moved to dedicated controllers.
class Music extends StatefulWidget {
  final bool isOpn;
  final dynamic ontap;
  final AudioPlayerHandler? audioHandler;
  final String idGet;
  final String typeGet;
  final List<DataMusic> listMain;
  final String audioPath;
  final int index;

  Music(
    this.audioHandler,
    this.idGet,
    this.typeGet,
    this.listMain,
    this.audioPath,
    this.index,
    this.isOpn,
    this.ontap, {
    super.key,
  }) {
    // Constructor debug - this should appear immediately when Music widget is created
    print('🎯🎯🎯 MUSIC WIDGET CONSTRUCTOR CALLED 🎯🎯🎯');
    print(
      '🎯 Constructor params: id=$idGet, type=$typeGet, listLength=${listMain.length}, index=$index, isOpn=$isOpn',
    );
    if (listMain.isNotEmpty) {
      print('🎯 First song: ${listMain[0].audio_title}');
    }
    print('🎯🎯🎯 MUSIC CONSTRUCTOR END 🎯🎯🎯');
  }

  @override
  State<Music> createState() => _MusicState();
}

class _MusicState extends State<Music> {
  late MusicController musicController;
  late PlaybackController playbackController;
  late DownloadController downloadController;
  late UserMusicController userMusicController;
  late PaymentController paymentController;

  List<DataMusic> _currentMusicList = [];
  bool _isLoadingData = false;
  bool _isDisposed = false;

  // Enhanced queue operation management
  final QueueOperationManager _queueManager = QueueOperationManager();
  Timer? _debounceTimer;
  String? _lastCategoryId;

  // Track initialization state to prevent redundant operations
  bool _isInitialized = false;
  bool _isPlayerReady = false;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;

  @override
  void initState() {
    super.initState();

    // SUPER PROMINENT DEBUGGING - Should appear in ALL logs
    print('🚨🚨🚨 MUSIC WIDGET INITSTATE CALLED 🚨🚨🚨');
    print('🚨 ID: ${widget.idGet}, TYPE: ${widget.typeGet}');
    print('🚨 LIST MAIN LENGTH: ${widget.listMain.length}');
    print('🚨 INDEX: ${widget.index}');
    print('🚨🚨🚨 END PROMINENT DEBUG 🚨🚨🚨');

    developer.log(
      '[DEBUG][Music][initState] Initializing Music widget',
      name: 'Music',
    );

    // DON'T hide navigation or mini player - this is now a modal overlay
    // The mini player should remain visible underneath
    // IMPORTANT: Don't call showFullPlayer here to prevent auto-opening full player

    // Initialize global variables for backward compatibility
    _initializeGlobalVariables();

    // Initialize controllers
    _initializeControllers();

    // Set initial music list
    _currentMusicList = widget.listMain;
  }

  void _initializeGlobalVariables() {
    indixes = widget.index;
    indexOnScreenSelect = widget.index;

    if (widget.listMain.isNotEmpty) {
      listCopy = widget.listMain;
    }

    idTag = widget.idGet;
    type = widget.typeGet;
    audioPathMain = widget.audioPath;
    checkCurrent = false;

    developer.log(
      '[DEBUG][Music][_initializeGlobalVariables] Global variables initialized',
      name: 'Music',
    );
  }

  void _initializeControllers() {
    if (_isInitialized) {
      developer.log(
        '[DEBUG][Music][_initializeControllers] Already initialized, skipping',
        name: 'Music',
      );
      return;
    }

    // SUPER PROMINENT DEBUGGING
    print('🔧🔧🔧 INITIALIZE CONTROLLERS CALLED 🔧🔧🔧');
    print('🔧 widget.listMain.isEmpty: ${widget.listMain.isEmpty}');
    print('🔧 widget.listMain.length: ${widget.listMain.length}');

    musicController = MusicController();
    playbackController = PlaybackController();
    downloadController = DownloadController();
    userMusicController = UserMusicController();
    paymentController = PaymentController();

    // Initialize music data
    developer.log(
      '🔍 [QUEUE_FIX] Checking widget.listMain: isEmpty=${widget.listMain.isEmpty}, length=${widget.listMain.length}',
      name: 'Music',
    );

    if (widget.listMain.isNotEmpty) {
      print('📋📋📋 USING PROVIDED LISTMAIN 📋📋📋');
      developer.log(
        '📋 [QUEUE_FIX] Using provided listMain with ${widget.listMain.length} songs',
        name: 'Music',
      );
      musicController.initialize(
        idGet: widget.idGet,
        typeGet: widget.typeGet,
        listMain: widget.listMain,
        audioPath: widget.audioPath,
        index: widget.index,
      );
      _isInitialized = true;

      // For search results and other direct lists, immediately setup queue
      // This ensures songs from search play immediately
      _currentMusicList = widget.listMain;

      // Trigger queue replacement for provided list (like search results)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted && widget.audioHandler != null) {
          developer.log(
            '🎵 [SEARCH_FIX] Triggering queue replacement for provided list (${widget.typeGet})',
            name: 'Music',
          );
          _performDebouncedQueueReplacement();
        }
      });
    } else {
      // Check if this is a fast/medium path that should skip queue operations
      final isFastOrMediumPath =
          widget.idGet.contains('favorite_fast') ||
          widget.idGet.contains('favorite_medium') ||
          widget.typeGet.contains('fast_path') ||
          widget.typeGet.contains('medium_path');

      if (isFastOrMediumPath) {
        print(
          '🚀🚀🚀 FAST/MEDIUM PATH DETECTED - SKIPPING QUEUE OPERATIONS 🚀🚀🚀',
        );
        developer.log(
          '🚀 [FAST_PATH] Detected fast/medium path (${widget.idGet}/${widget.typeGet}) - skipping all queue operations',
          name: 'Music',
        );

        // Initialize with minimal data - no queue operations
        musicController.initialize(
          idGet: widget.idGet,
          typeGet: widget.typeGet,
          listMain: [], // Keep empty
          audioPath: widget.audioPath,
          index: widget.index,
        );
        _isInitialized = true;
        // Skip any queue replacement - playback is already handled
      } else {
        print('🔄🔄🔄 CALLING LOAD MUSIC DATA FROM CATEGORY 🔄🔄🔄');
        developer.log(
          '🔄 [QUEUE_FIX] No listMain provided, calling _loadMusicDataFromCategory()',
          name: 'Music',
        );
        // Load music data when list is empty
        _loadMusicDataFromCategory();
      }
    }

    developer.log(
      '[DEBUG][Music][_initializeControllers] Controllers initialized',
      name: 'Music',
    );
  }

  /// Load music data from category when list is empty
  Future<void> _loadMusicDataFromCategory() async {
    // Prevent duplicate category loading
    if (widget.idGet == _lastCategoryId && _isInitialized) {
      developer.log(
        '[DEBUG][Music][_loadMusicDataFromCategory] Same category already loaded, skipping',
        name: 'Music',
      );
      return;
    }

    // SUPER PROMINENT DEBUGGING
    print('📱📱📱 LOAD MUSIC DATA FROM CATEGORY CALLED 📱📱📱');
    print('📱 ID: ${widget.idGet}, TYPE: ${widget.typeGet}');
    print('📱 _isLoadingData: $_isLoadingData, _isDisposed: $_isDisposed');

    if (_isLoadingData || _isDisposed) {
      print('📱 EARLY RETURN: Loading=$_isLoadingData, Disposed=$_isDisposed');
      return; // Prevent duplicate loading and check disposal
    }

    developer.log(
      '[DEBUG][Music][_loadMusicDataFromCategory] Loading music data for category: id=${widget.idGet}, type=${widget.typeGet}',
      name: 'Music',
    );

    // Set loading state immediately but only for UI feedback
    if (mounted && !_isDisposed) {
      setState(() {
        _isLoadingData = true;
      });
    }

    try {
      // Initialize controller with basic data
      await musicController.initialize(
        idGet: widget.idGet,
        typeGet: widget.typeGet,
        listMain: [],
        audioPath: widget.audioPath,
        index: widget.index,
      );

      if (_isDisposed) return;

      // Load music data by category
      await musicController.loadMusicByCategory();

      print('📱 STEP AFTER API CALL: loadMusicByCategory completed');
      print(
        '📱 musicController.listCopy.length: ${musicController.listCopy.length}',
      );
      print('📱 _isDisposed: $_isDisposed');

      if (_isDisposed) return;

      // Update global variables with loaded data
      listCopy = musicController.listCopy;
      audioPathMain = musicController.audioPathMain;
      listDataa = musicController.listData;

      print('📱 STEP AFTER GLOBAL UPDATE: Global variables updated');

      // CRITICAL: Always clear loading state after data loads, regardless of queue operation
      if (mounted && !_isDisposed) {
        setState(() {
          // DON'T update _currentMusicList here - only update it after queue replacement succeeds
          // This ensures queueAlreadySetup remains false until the new queue is actually set up
          _isLoadingData = false; // Clear loading immediately after data loads
        });
      }

      // Mark as initialized and update last category
      _isInitialized = true;
      _lastCategoryId = widget.idGet;

      print('📱 STEP AFTER STATE UPDATE: State updated, starting queue checks');

      print(
        '🔍🔍🔍 QUEUE_FIX - Unconditional queue replacement for song switching',
      );
      print(
        '🔍 musicController.listCopy.length: ${musicController.listCopy.length}',
      );
      print('🔍 mounted: $mounted');
      print('🔍 !_isDisposed: ${!_isDisposed}');
      print('🔍 widget.audioHandler != null: ${widget.audioHandler != null}');

      developer.log(
        '[DEBUG][Music][_loadMusicDataFromCategory] Data loaded successfully, ${listCopy.length} songs, starting queue replacement',
        name: 'Music',
      );

      // CRITICAL FIX: Always trigger queue replacement when loading music from category
      // This is needed for proper song switching behavior when user selects from different screens
      developer.log(
        '🚀 [QUEUE_FIX] UNCONDITIONAL QUEUE REPLACEMENT - User selected new music category',
        name: 'Music',
      );
      developer.log(
        '🚀 [QUEUE_FIX] Category ID: ${widget.idGet}, Songs loaded: ${musicController.listCopy.length}',
        name: 'Music',
      );

      // Check basic requirements for queue replacement
      final hasMusic = musicController.listCopy.isNotEmpty;
      final hasAudioHandler = widget.audioHandler != null;
      final isValidState = mounted && !_isDisposed;

      developer.log(
        '🔍 [QUEUE_FIX] Basic checks - hasMusic: $hasMusic, hasAudioHandler: $hasAudioHandler, isValidState: $isValidState',
        name: 'Music',
      );

      if (hasMusic && hasAudioHandler && isValidState) {
        developer.log(
          '✅ [QUEUE_FIX] All basic requirements met, checking if queue operation is already in progress',
          name: 'Music',
        );
        developer.log(
          '🔍 [QUEUE_FIX] Using paths - imagePath: ${musicController.imagePath}, audioPath: ${musicController.audioPathMain}',
          name: 'Music',
        );

        // Check if queue manager is already busy before attempting replacement
        if (_queueManager.canStartOperation(
          'MusicEntryPoint._loadMusicDataFromCategory.${widget.idGet}',
        )) {
          developer.log(
            '✅ [QUEUE_FIX] Queue manager available, proceeding with debounced queue replacement',
            name: 'Music',
          );
          // Use debounced queue replacement to prevent concurrent operations
          _performDebouncedQueueReplacement();
        } else {
          developer.log(
            '⏸️ [QUEUE_FIX] Queue manager busy, skipping queue replacement to prevent conflicts',
            name: 'Music',
          );
        }
      } else {
        developer.log(
          '❌ [QUEUE_FIX] Basic requirements not met:',
          name: 'Music',
        );
        if (!hasMusic) developer.log('   ❌ No music loaded', name: 'Music');
        if (!hasAudioHandler) {
          developer.log('   ❌ AudioHandler is null', name: 'Music');
        }
        if (!isValidState) {
          developer.log(
            '   ❌ Widget state invalid (mounted: $mounted, disposed: $_isDisposed)',
            name: 'Music',
          );
        }
      }
    } catch (e) {
      developer.log(
        '[ERROR][Music][_loadMusicDataFromCategory] Failed to load music data: $e',
        name: 'Music',
        error: e,
      );
      // Always clear loading state on error
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  /// Perform debounced queue replacement to prevent rapid-fire calls
  void _performDebouncedQueueReplacement() {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    developer.log(
      '[DEBUG][Music][_performDebouncedQueueReplacement] Setting up debounced queue replacement for category: ${widget.idGet}',
      name: 'Music',
    );

    // Set up new debounce timer with longer delay to ensure stability
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!_isDisposed && mounted) {
        developer.log(
          '[DEBUG][Music][_performDebouncedQueueReplacement] Executing debounced queue replacement for category: ${widget.idGet}',
          name: 'Music',
        );
        _replaceQueueWithConcurrencyControl();
      } else {
        developer.log(
          '[DEBUG][Music][_performDebouncedQueueReplacement] Skipping - widget disposed or unmounted',
          name: 'Music',
        );
      }
    });
  }

  /// Replace queue with enhanced concurrency control
  Future<void> _replaceQueueWithConcurrencyControl() async {
    final operationId =
        'MusicEntryPoint._replaceQueueInBackground.${widget.idGet}';

    try {
      developer.log(
        '[DEBUG][Music][_replaceQueueWithConcurrencyControl] Attempting queue replacement for category: ${widget.idGet}',
        name: 'Music',
      );

      await _queueManager.executeOperation(operationId, () async {
        await _replaceQueueInBackground();
      });

      developer.log(
        '[DEBUG][Music][_replaceQueueWithConcurrencyControl] Queue replacement completed successfully for category: ${widget.idGet}',
        name: 'Music',
      );

      // Listen for player readiness (first mediaItem non-null)
      _mediaItemSubscription?.cancel();
      _mediaItemSubscription = widget.audioHandler?.mediaItem.listen((
        mediaItem,
      ) {
        if (!_isPlayerReady && mediaItem != null) {
          developer.log(
            '[Music] Player is ready with first media item: \\${mediaItem.title}',
            name: 'Music',
          );
          if (mounted && !_isDisposed) {
            setState(() {
              _isLoadingData = false;
              _isPlayerReady = true;
              _currentMusicList = musicController.listCopy;
            });
          }
          _mediaItemSubscription?.cancel();
        }
      });
    } catch (e) {
      developer.log(
        '[Music] Queue replacement with concurrency control failed for category ${widget.idGet}: $e',
        name: 'Music',
        error: e,
      );
      // Only retry if it's not an interruption (interruptions are expected when switching categories)
      if (e.toString().contains('already in progress') &&
          !e.toString().contains('interrupted')) {
        developer.log(
          '[Music] Queue operation blocked for category ${widget.idGet}, scheduling retry in 300ms',
          name: 'Music',
        );
        Timer(const Duration(milliseconds: 300), () {
          if (!_isDisposed && mounted) {
            developer.log(
              '[Music] Retrying queue replacement for category ${widget.idGet}',
              name: 'Music',
            );
            _performDebouncedQueueReplacement();
          }
        });
      } else {
        developer.log(
          '[Music] Queue operation failed or was interrupted for category ${widget.idGet}, not retrying',
          name: 'Music',
        );
        // On error, hide loading
        if (mounted && !_isDisposed) {
          setState(() {
            _isLoadingData = false;
            _isPlayerReady = false;
          });
        }
      }
    }
  }

  /// Replace queue in background without blocking UI - ULTRA OPTIMIZED
  Future<void> _replaceQueueInBackground() async {
    // Use current music list if available, fallback to controller's list
    final musicListToUse =
        _currentMusicList.isNotEmpty
            ? _currentMusicList
            : musicController.listCopy;

    if (musicListToUse.isEmpty || widget.audioHandler == null) {
      developer.log(
        '[Music] Cannot replace queue: musicList isEmpty=${musicListToUse.isEmpty}, audioHandler null=${widget.audioHandler == null}',
      );
      return;
    }

    try {
      developer.log('[Music] Starting ultra-optimized queue replacement');
      developer.log(
        '[Music] Music list to use: ${musicListToUse.length} songs, type: ${widget.typeGet}',
      );

      // Determine the correct image and audio paths
      String imagePathToUse =
          _currentMusicList.isNotEmpty
              ? widget
                  .audioPath // For search and direct lists, use the provided audioPath
              : musicController.imagePath;
      String audioPathToUse =
          _currentMusicList.isNotEmpty
              ? widget
                  .audioPath // For search and direct lists, use the provided audioPath
              : musicController.audioPathMain;

      // Use the simplified queue replacement
      developer.log(
        '[Music] 🎯 STARTING QUEUE REPLACEMENT: ${musicListToUse.length} songs, startIndex=${widget.index}',
      );
      developer.log(
        '[Music] 🎯 Song that SHOULD play: ${musicListToUse[widget.index.clamp(0, musicListToUse.length - 1)].audio_title}',
      );
      developer.log(
        '[Music] 🎯 First song in list: ${musicListToUse[0].audio_title}',
      );

      await MusicManager().replaceQueue(
        musicList: musicListToUse,
        startIndex: widget.index,
        pathImage: imagePathToUse,
        audioPath: audioPathToUse,
        contextType:
            widget.typeGet.isNotEmpty ? widget.typeGet : 'music_player',
        contextId: widget.idGet,
        callSource:
            'MusicEntryPoint._replaceQueueInBackground.${widget.typeGet}:${widget.idGet}',
      );

      developer.log(
        '[Music] Ultra-optimized queue replacement completed successfully for ${widget.typeGet}',
      );
    } catch (e) {
      developer.log('[Music] Ultra-optimized queue replacement failed: $e');

      // Fallback to simple single song playback
      try {
        if (musicListToUse.isNotEmpty) {
          final selectedSong =
              musicListToUse[widget.index.clamp(0, musicListToUse.length - 1)];

          // Use simplified single song playback as fallback
          await MusicManager().replaceQueue(
            musicList: [selectedSong],
            startIndex: 0,
            pathImage: widget.audioPath,
            audioPath: widget.audioPath,
            contextType: 'single_song',
            callSource: 'MusicEntryPoint._replaceQueueInBackground.fallback',
          );

          developer.log('[Music] Fallback single song playback completed');
        }
      } catch (fallbackError) {
        developer.log('[Music] Final fallback failed: $fallbackError');
        // Last resort - use MusicManager basic play instead of direct audioHandler
        try {
          await MusicManager().play();
        } catch (playError) {
          developer.log('[Music] Even basic play failed: $playError');
        }
      }
    }
  }

  @override
  void dispose() {
    developer.log(
      '[DEBUG][Music][dispose] Disposing Music widget',
      name: 'Music',
    );

    // Set disposal flag first to prevent further operations
    _isDisposed = true;

    // Clean up timers and operations
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _mediaItemSubscription?.cancel();

    // Check and log queue manager status for debugging
    final queueStatus = _queueManager.getStatus();
    developer.log(
      '[DEBUG][Music][dispose] Queue manager status: $queueStatus',
      name: 'Music',
    );

    // DON'T hide full player state - let the mini player stay visible
    // This was causing the mini player to disappear after navigation

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show MusicPlayerUI when music data and player are ready
    final hasMusicData =
        _currentMusicList.isNotEmpty || musicController.listCopy.isNotEmpty;
    if (_isLoadingData || !_isPlayerReady || !hasMusicData) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text('Loading Music...'), centerTitle: true),
        body: Column(
          children: [
            Expanded(
              flex: 2,
              child: Center(
                child: CircleLoader(
                  size: 250.w,
                  showBackground: false,
                  showLogo: true,
                ),
              ),
            ),
            Expanded(flex: 1, child: SizedBox()),
          ],
        ),
      );
    }

    // Determine the correct image path to pass to MusicPlayerUI
    String imagePathToPass =
        widget.audioPath.isNotEmpty &&
                !widget.audioPath.contains('search') &&
                !widget.audioPath.contains('bottomSlider')
            ? widget
                .idGet // Use the category ID for compatibility when data is already loaded
            : musicController.imagePath.isNotEmpty
            ? musicController.imagePath
            : widget.idGet;

    developer.log(
      '[DEBUG][Music][build] Passing image path to MusicPlayerUI: $imagePathToPass',
      name: 'Music',
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: musicController),
        ChangeNotifierProvider.value(value: playbackController),
        ChangeNotifierProvider.value(value: downloadController),
        ChangeNotifierProvider.value(value: userMusicController),
        ChangeNotifierProvider.value(value: paymentController),
      ],
      child: MusicPlayerUI(
        widget.audioHandler!,
        imagePathToPass, // pathImage - now using correct image path
        widget.audioPath,
        _currentMusicList, // Use loaded data instead of widget.listMain
        widget.typeGet, // catImages
        widget.index,
        false, // isOffline - defaulting to false for online music
        widget.audioPath, // audioPathMain
        isOpn: widget.isOpn,
        ontap:
            widget.ontap is VoidCallback ? widget.ontap as VoidCallback : null,
        skipQueueSetup:
            true, // Always skip queue setup in MusicPlayerLogic since we handle it here
        queueAlreadySetup:
            _currentMusicList
                .isNotEmpty, // Indicate if we've already set up the queue
      ),
    );
  }
}

/// Provides access to a library of media items. In your app, this could come
/// from a database or web service.
class MediaLibrary {
  static const albumsRootId = 'albums';

  Map<String, List<MediaItem>> items = <String, List<MediaItem>>{
    AudioService.browsableRootId: const [
      MediaItem(id: albumsRootId, title: "Albums", playable: false),
    ],
    albumsRootId: listDataa,
  };
}
