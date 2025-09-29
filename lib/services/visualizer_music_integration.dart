import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../managers/music_manager.dart';
import 'enhanced_audio_visualizer.dart';

/// Service that integrates the enhanced audio visualizer with the music playback system
class VisualizerMusicIntegration {
  static final VisualizerMusicIntegration _instance =
      VisualizerMusicIntegration._internal();
  factory VisualizerMusicIntegration() => _instance;
  VisualizerMusicIntegration._internal();

  MusicManager? _musicManager;
  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _mediaItemSubscription;

  bool _isVisualizerActive = false;
  bool _isCurrentlyPlaying = false;
  bool _isCurrentlyPaused = false;
  int? _currentAudioSessionId;

  /// Initialize the integration with the music manager
  void initialize(MusicManager musicManager) {
    _musicManager = musicManager;
    _setupListeners();
  }

  /// Setup listeners for playback state changes
  void _setupListeners() {
    final audioHandler = _musicManager?.audioHandler;
    if (audioHandler == null) return;

    // Listen to playback state changes
    _playbackStateSubscription?.cancel();
    _playbackStateSubscription = audioHandler.playbackState.listen((state) {
      final wasPlaying = _isCurrentlyPlaying;

      _isCurrentlyPlaying = state.playing;
      _isCurrentlyPaused =
          !state.playing &&
          state.processingState != AudioProcessingState.idle &&
          state.processingState != AudioProcessingState.completed;

      // Handle visualizer state based on playback changes
      if (_isCurrentlyPlaying && !wasPlaying) {
        _startVisualizerIfNeeded();
      } else if (!_isCurrentlyPlaying && wasPlaying) {
        _stopVisualizerIfNeeded();
      }
    });

    // Listen to media item changes to update audio session ID
    _mediaItemSubscription?.cancel();
    _mediaItemSubscription = audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        _updateAudioSessionId();
      }
    });
  }

  /// Start the visualizer if conditions are met
  Future<void> _startVisualizerIfNeeded() async {
    if (_isCurrentlyPlaying && !_isVisualizerActive) {
      await _updateAudioSessionId();
      final started = await EnhancedAudioVisualizerService.startVisualizer(
        audioSessionId: _currentAudioSessionId,
      );
      _isVisualizerActive = started;

      if (started) {
        print('[VisualizerMusicIntegration] Visualizer started successfully');
      } else {
        print('[VisualizerMusicIntegration] Failed to start visualizer');
      }
    }
  }

  /// Stop the visualizer if needed
  Future<void> _stopVisualizerIfNeeded() async {
    if (_isVisualizerActive) {
      await EnhancedAudioVisualizerService.stopVisualizer();
      _isVisualizerActive = false;
      print('[VisualizerMusicIntegration] Visualizer stopped');
    }
  }

  /// Update audio session ID for Android (iOS uses fallback so no session ID needed)
  Future<void> _updateAudioSessionId() async {
    if (Platform.isAndroid) {
      try {
        // Since we don't have direct access to the AudioPlayer instance here,
        // we'll use the system audio output session ID (0) which captures all app audio
        _currentAudioSessionId = 0;

        print(
          '[VisualizerMusicIntegration] Using system audio output session ID: $_currentAudioSessionId',
        );

        // Update visualizer if it's already active
        if (_isVisualizerActive) {
          await EnhancedAudioVisualizerService.updateAudioSessionId(
            _currentAudioSessionId,
          );
        }
      } catch (e) {
        print(
          '[VisualizerMusicIntegration] Failed to update audio session ID: $e',
        );
        _currentAudioSessionId = 0; // Fallback to system audio output mix
      }
    } else {
      // iOS uses fallback visualizer, no session ID needed
      _currentAudioSessionId = null;
      print(
        '[VisualizerMusicIntegration] iOS detected, using fallback visualizer',
      );
    }
  }

  /// Get current playback state information
  PlaybackStateInfo get currentState {
    return PlaybackStateInfo(
      isPlaying: _isCurrentlyPlaying,
      isPaused: _isCurrentlyPaused,
      audioSessionId: _currentAudioSessionId,
      isVisualizerActive: _isVisualizerActive,
    );
  }

  /// Force start visualizer (for testing or manual control)
  Future<bool> forceStartVisualizer() async {
    await _updateAudioSessionId();
    final started = await EnhancedAudioVisualizerService.startVisualizer(
      audioSessionId: _currentAudioSessionId,
    );
    _isVisualizerActive = started;
    return started;
  }

  /// Force stop visualizer
  Future<void> forceStopVisualizer() async {
    await EnhancedAudioVisualizerService.stopVisualizer();
    _isVisualizerActive = false;
  }

  /// Dispose of resources
  void dispose() {
    _playbackStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    _musicManager = null;
  }
}

/// Data class containing current playback state information
class PlaybackStateInfo {
  final bool isPlaying;
  final bool isPaused;
  final int? audioSessionId;
  final bool isVisualizerActive;

  const PlaybackStateInfo({
    required this.isPlaying,
    required this.isPaused,
    required this.audioSessionId,
    required this.isVisualizerActive,
  });

  @override
  String toString() {
    return 'PlaybackStateInfo(isPlaying: $isPlaying, isPaused: $isPaused, '
        'audioSessionId: $audioSessionId, isVisualizerActive: $isVisualizerActive)';
  }
}

/// Widget that automatically manages visualizer state based on music manager
class AutoManagedVisualizerOverlay extends StatefulWidget {
  final Widget child;
  final bool show;
  final MusicManager musicManager;
  final double coverageFraction;
  final double maxHeightFraction;
  final Color color;
  final AlignmentGeometry alignment;
  final double barGapFraction;
  final double minVisualWidth;
  final double minVisualHeight;

  const AutoManagedVisualizerOverlay({
    super.key,
    required this.child,
    required this.show,
    required this.musicManager,
    this.coverageFraction = 0.55,
    this.maxHeightFraction = 0.80,
    this.color = const Color.fromRGBO(255, 255, 255, 0.88),
    this.alignment = const Alignment(0, 0.25),
    this.barGapFraction = 0.9,
    this.minVisualWidth = 30.0,
    this.minVisualHeight = 20.0,
  });

  @override
  State<AutoManagedVisualizerOverlay> createState() =>
      _AutoManagedVisualizerOverlayState();
}

class _AutoManagedVisualizerOverlayState
    extends State<AutoManagedVisualizerOverlay> {
  late VisualizerMusicIntegration _integration;
  StreamSubscription? _stateSubscription;
  PlaybackStateInfo _currentState = const PlaybackStateInfo(
    isPlaying: false,
    isPaused: false,
    audioSessionId: null,
    isVisualizerActive: false,
  );

  @override
  void initState() {
    super.initState();
    _integration = VisualizerMusicIntegration();
    _integration.initialize(widget.musicManager);
    _setupStateListener();
  }

  void _setupStateListener() {
    // Listen to music manager changes and update state accordingly
    _stateSubscription?.cancel();

    // Use a periodic timer to check state changes
    _stateSubscription = Stream.periodic(
      const Duration(milliseconds: 100),
    ).listen((_) {
      final newState = _integration.currentState;
      if (newState.toString() != _currentState.toString()) {
        if (mounted) {
          setState(() {
            _currentState = newState;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EnhancedVisualizerOverlay(
      show: widget.show,
      isPlaying: _currentState.isPlaying,
      isPaused: _currentState.isPaused,
      audioSessionId: _currentState.audioSessionId,
      coverageFraction: widget.coverageFraction,
      maxHeightFraction: widget.maxHeightFraction,
      color: widget.color,
      alignment: widget.alignment,
      barGapFraction: widget.barGapFraction,
      minVisualWidth: widget.minVisualWidth,
      minVisualHeight: widget.minVisualHeight,
      child: widget.child,
    );
  }
}

/// Enhanced album art widget with automatic music integration
class SmartAlbumArtWithVisualizer extends StatelessWidget {
  final ImageProvider image;
  final bool isCurrent;
  final MusicManager musicManager;
  final double size;
  final Color color;

  const SmartAlbumArtWithVisualizer({
    super.key,
    required this.image,
    required this.isCurrent,
    required this.musicManager,
    this.size = 150,
    this.color = const Color.fromRGBO(255, 255, 255, 0.88),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AutoManagedVisualizerOverlay(
          show: isCurrent,
          musicManager: musicManager,
          color: color,
          child: Image(image: image, fit: BoxFit.fill),
        ),
      ),
    );
  }
}
