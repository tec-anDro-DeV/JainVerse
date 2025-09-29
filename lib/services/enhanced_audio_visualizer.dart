import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:jainverse/main.dart' show routeObserver;

/// Enhanced audio visualizer service that directly integrates with music playback
/// to provide accurate real-time visualization based on actual audio amplitude
class EnhancedAudioVisualizerService {
  static const MethodChannel _methodChannel = MethodChannel(
    'enhanced_audio_visualizer',
  );
  static const EventChannel _eventChannel = EventChannel(
    'enhanced_audio_visualizer_stream',
  );

  static StreamSubscription? _fftStreamSubscription;
  static final StreamController<List<double>> _fftController =
      StreamController<List<double>>.broadcast();

  /// Stream of FFT frequency band amplitudes (5 bands: 0.0 - 1.0)
  static Stream<List<double>> get fftStream => _fftController.stream;

  // Broadcast stream that emits when visualizer active state changes
  static final StreamController<bool> _activeStateController =
      StreamController<bool>.broadcast();
  static Stream<bool> get activeStateStream => _activeStateController.stream;

  /// Whether the visualizer is currently active
  static bool _isActive = false;
  static bool get isActive => _isActive;

  /// Last processed FFT frame (warm-up) so new subscribers can get an
  /// immediate sample while native stream stabilizes after navigation.
  static List<double>? _lastFrame;
  static List<double>? get lastFrame => _lastFrame;

  /// Current audio session ID for Android
  static int? _currentAudioSessionId;

  /// iOS fallback timer for simulated visualizer
  static Timer? _iosFallbackTimer;
  static bool _usingIOSFallback = false;

  /// Starts the enhanced audio visualizer
  static Future<bool> startVisualizer({int? audioSessionId}) async {
    // If we're already marked active, ensure we're listening to native
    // events. This can happen when a UI overlay unsubscribed locally but
    // the global service remains active (for example when using
    // nested navigators or fullscreen dialogs). In that case we still need
    // to ensure the EventChannel subscription exists so new listeners can
    // receive FFT data.
    if (_isActive) {
      try {
        if (!_usingIOSFallback && _fftStreamSubscription == null) {
          _startListening();
          // Re-emit active state to notify subscribers that we're active
          try {
            _activeStateController.add(_isActive);
          } catch (_) {}
        }
      } catch (_) {}
      return true;
    }

    // For iOS, use fallback visualizer since native audio analysis is limited
    if (Platform.isIOS) {
      return _startIOSFallbackVisualizer();
    }

    // For Android, try native visualizer first
    try {
      // Start the native visualizer
      final success = await _methodChannel.invokeMethod('startVisualizer', {
        'audioSessionId': audioSessionId ?? 0,
      });

      if (success == true) {
        _isActive = true;
        _currentAudioSessionId = audioSessionId;
        _usingIOSFallback = false;
        _startListening();
        debugPrint(
          '[EnhancedAudioVisualizer] Native Android visualizer started; audioSessionId=$audioSessionId',
        );
        // Notify listeners that visualizer became active
        try {
          _activeStateController.add(_isActive);
        } catch (_) {}
        return true;
      }
    } catch (e) {
      debugPrint('Enhanced Audio Visualizer: Failed to start native - $e');
      // On Android, if native fails, fall back to simulated visualizer
      if (Platform.isAndroid) {
        debugPrint(
          '[EnhancedAudioVisualizer] Native failed, using fallback visualizer',
        );
        return _startIOSFallbackVisualizer();
      }
    }

    return false;
  }

  /// Start iOS fallback visualizer with simulated audio-reactive patterns
  static bool _startIOSFallbackVisualizer() {
    if (_isActive) return true;

    try {
      _isActive = true;
      _usingIOSFallback = true;

      // Start simulated audio data stream
      _startIOSFallbackStream();

      debugPrint('[EnhancedAudioVisualizer] iOS fallback visualizer started');
      try {
        _activeStateController.add(_isActive);
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint(
        'Enhanced Audio Visualizer: Failed to start iOS fallback - $e',
      );
      return false;
    }
  }

  /// Generate simulated audio-reactive data for iOS
  static void _startIOSFallbackStream() {
    _iosFallbackTimer?.cancel();
    final random = math.Random();
    double bassPhase = random.nextDouble() * math.pi * 2;
    double midPhase = random.nextDouble() * math.pi * 2;
    double beatPhase = random.nextDouble() * math.pi * 2;
    double treblePhase = random.nextDouble() * math.pi * 2;

    _iosFallbackTimer = Timer.periodic(
      const Duration(milliseconds: 24), // ~41 FPS for ultra-smooth animation
      (timer) {
        // Simulate a rhythmic beat for bass
        final beat = (math.sin(beatPhase) + 1) / 2; // 0..1
        final bass =
            ((math.sin(bassPhase) * 0.5 + 0.5) * 0.5 + beat * 0.5) *
            (0.75 + random.nextDouble() * 0.2);

        // Low-mid: follows bass, but with less beat and more smoothness
        final lowMid =
            ((math.sin(bassPhase + 0.5) * 0.5 + 0.5) * 0.6 + beat * 0.3) *
            (0.65 + random.nextDouble() * 0.25);

        // Mid: more active, but less random spikes for smoothness
        double mid =
            ((math.sin(midPhase) * 0.5 + 0.5) * 0.7 +
                (random.nextDouble() * 0.18)) *
            (0.55 + random.nextDouble() * 0.35);

        // High-mid: erratic, but less jitter
        final highMid =
            ((math.sin(midPhase + 1.2) * 0.5 + 0.5) * 0.5 +
                (random.nextDouble() * 0.3)) *
            (0.45 + random.nextDouble() * 0.45);

        // Treble: most erratic, but less random spikes
        double treble =
            ((math.sin(treblePhase) * 0.5 + 0.5) * 0.4 +
                (random.nextDouble() * 0.35)) *
            (0.35 + random.nextDouble() * 0.55);

        // Rarely spike treble and mid for realism, but less often
        final spikeChance = random.nextDouble();
        if (spikeChance > 0.995) {
          treble += 0.18 + random.nextDouble() * 0.22;
        }
        if (spikeChance > 0.997) {
          mid += 0.12 + random.nextDouble() * 0.18;
        }

        // Update phases for next frame (smaller increments for smoothness)
        bassPhase += 0.045 + random.nextDouble() * 0.012;
        midPhase += 0.07 + random.nextDouble() * 0.018;
        beatPhase += 0.13 + random.nextDouble() * 0.02;
        treblePhase += 0.09 + random.nextDouble() * 0.018;

        // Clamp and process
        final simulatedData = [
          bass.clamp(0.0, 1.0),
          lowMid.clamp(0.0, 1.0),
          mid.clamp(0.0, 1.0),
          highMid.clamp(0.0, 1.0),
          treble.clamp(0.0, 1.0),
        ];
        final processedData = _processFFTData(simulatedData);
        // Store last frame for warm-up subscribers
        _lastFrame = processedData;
        _fftController.add(processedData);
      },
    );
  }

  /// Stop the audio visualizer
  static Future<void> stopVisualizer() async {
    try {
      if (_usingIOSFallback || Platform.isIOS) {
        // Stop iOS fallback timer
        _iosFallbackTimer?.cancel();
        _iosFallbackTimer = null;
        debugPrint('[EnhancedAudioVisualizer] iOS fallback visualizer stopped');
      } else {
        // Stop native visualizer (Android only)
        try {
          await _methodChannel.invokeMethod('stopVisualizer');
          debugPrint('[EnhancedAudioVisualizer] Native visualizer stopped');
        } catch (e) {
          // If native method fails, just log it and continue cleanup
          debugPrint(
            '[EnhancedAudioVisualizer] Failed to stop native visualizer: $e',
          );
        }
      }
    } finally {
      _isActive = false;
      _usingIOSFallback = false;
      _stopListening();
      try {
        _activeStateController.add(_isActive);
      } catch (_) {}
    }
  }

  /// Pause the visualizer temporarily. This will stop listening but keep
  /// internal state so a subsequent resumeVisualizer() can restart quickly.
  /// This is intended for UI transitions where RouteObserver events may not
  /// reliably fire (for example when using nested navigators or custom
  /// navigation logic). It's safe to call even if the visualizer is not
  /// currently active.
  static Future<void> pauseVisualizer() async {
    try {
      debugPrint(
        '[EnhancedAudioVisualizer] pauseVisualizer() called; isActive=$_isActive, usingIOSFallback=$_usingIOSFallback, currentAudioSessionId=$_currentAudioSessionId',
      );
      // For our implementation just stop the visualizer. The service keeps
      // enough state to restart when resumeVisualizer is called.
      await stopVisualizer();
      debugPrint(
        '[EnhancedAudioVisualizer] Visualizer paused (explicit); isActive=$_isActive',
      );
      try {
        _activeStateController.add(_isActive);
      } catch (_) {}
    } catch (e) {
      debugPrint('Enhanced Audio Visualizer: pause failed - $e');
    }
  }

  /// Resume the visualizer if it was previously active. This will attempt
  /// to start the visualizer again using the last known audio session ID.
  static Future<void> resumeVisualizer() async {
    try {
      debugPrint(
        '[EnhancedAudioVisualizer] resumeVisualizer() called; isActive=$_isActive, currentAudioSessionId=$_currentAudioSessionId',
      );
      if (!_isActive) {
        final started = await startVisualizer(
          audioSessionId: _currentAudioSessionId,
        );
        debugPrint(
          '[EnhancedAudioVisualizer] resumeVisualizer() startVisualizer returned: $started; isActive=$_isActive',
        );
        debugPrint(
          '[EnhancedAudioVisualizer] Visualizer resumed (explicit); isActive=$_isActive',
        );
        try {
          _activeStateController.add(_isActive);
        } catch (_) {}
      } else {
        // If we're already active but our native event subscription was
        // dropped (for example a UI overlay unsubscribed during transition),
        // ensure the event listener is re-attached so new subscribers can
        // receive FFT data.
        if (!_usingIOSFallback && _fftStreamSubscription == null) {
          try {
            debugPrint(
              '[EnhancedAudioVisualizer] resumeVisualizer() detected active state but no subscription - re-attaching listener',
            );
            _startListening();
            try {
              _activeStateController.add(_isActive);
            } catch (_) {}
          } catch (e) {
            debugPrint(
              '[EnhancedAudioVisualizer] Failed to reattach listener: $e',
            );
          }
        } else {
          debugPrint(
            '[EnhancedAudioVisualizer] resumeVisualizer() skipped because already active and subscription present',
          );
          // Still notify active state in case overlays need to resubscribe
          try {
            _activeStateController.add(_isActive);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Enhanced Audio Visualizer: resume failed - $e');
    }
  }

  /// Update audio session ID for Android (when track changes)
  /// For iOS, this is a no-op since we use fallback visualizer
  static Future<bool> updateAudioSessionId(int? audioSessionId) async {
    // iOS uses fallback, no need to update session ID
    if (Platform.isIOS || _usingIOSFallback) {
      return _isActive;
    }

    // Android native visualizer session ID update
    if (Platform.isAndroid &&
        _isActive &&
        audioSessionId != _currentAudioSessionId) {
      print(
        '[EnhancedAudioVisualizer] Updating audio session ID to: $audioSessionId',
      );

      try {
        // Restart visualizer with new session ID
        await stopVisualizer();
        return await startVisualizer(audioSessionId: audioSessionId);
      } catch (e) {
        debugPrint(
          'Enhanced Audio Visualizer: Failed to update session ID - $e',
        );
        return false;
      }
    }
    return _isActive;
  }

  /// Check if visualizer is active on native side
  static Future<bool> isVisualizerActive() async {
    // For iOS fallback or when using fallback mode, return the local state
    if (Platform.isIOS || _usingIOSFallback) {
      return _isActive;
    }

    // For Android native, check with native side
    try {
      final active = await _methodChannel.invokeMethod<bool>(
        'isVisualizerActive',
      );
      return active ?? false;
    } catch (e) {
      // If method channel fails, return local state
      debugPrint(
        'Enhanced Audio Visualizer: Failed to check native state - $e',
      );
      return _isActive;
    }
  }

  static void _startListening() {
    // For iOS fallback, listening is handled by the timer
    if (_usingIOSFallback) {
      return;
    }

    // For Android native, listen to the event channel
    _fftStreamSubscription?.cancel();
    _fftStreamSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is List) {
          final list = data.map((e) => (e as num).toDouble()).toList();

          if (list.length == 5) {
            // Check for special permission/error signals
            if (list.every((val) => val == -1.0)) {
              // Permission denied signal
              debugPrint(
                'Enhanced Audio Visualizer: Permission denied, using fallback',
              );
              _fftController.add([
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
              ]); // Send silence for fallback
              return;
            }
            if (list.every((val) => val == -2.0)) {
              // Visualizer error signal
              debugPrint(
                'Enhanced Audio Visualizer: Visualizer error, using fallback',
              );
              _fftController.add([
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
              ]); // Send silence for fallback
              return;
            }

            // Process and emit the FFT data
            final processedData = _processFFTData(list);
            // Store last frame for warm-up subscribers
            _lastFrame = processedData;
            _fftController.add(processedData);
          }
        }
      },
      onError: (error) {
        print('[EnhancedAudioVisualizer] Stream error: $error');
      },
      cancelOnError: false,
    );
  }

  /// Process raw FFT data to create more natural visualizer behavior
  static List<double> _processFFTData(List<double> rawData) {
    return rawData.map((value) {
      // Apply noise floor to eliminate very small movements during silence
      const double noiseFloor = 0.05;
      if (value < noiseFloor) {
        return 0.0;
      }

      // Apply gentle compression for more natural movement
      return math.pow(value, 0.8).toDouble().clamp(0.0, 1.0);
    }).toList();
  }

  static void _stopListening() {
    _fftStreamSubscription?.cancel();
    _fftStreamSubscription = null;
  }

  /// Dispose of resources
  static void dispose() {
    _stopListening();
    _iosFallbackTimer?.cancel();
    _iosFallbackTimer = null;
    _fftController.close();
  }
}

/// Enhanced music-aware visualizer that integrates with playback state
class MusicAwareVisualizer extends StatelessWidget {
  final List<double> values; // 5 normalized values 0..1
  final double width;
  final double height;
  final Color color;
  final double barSpacing;
  final double? barGapFraction;
  final bool isPlaying; // Controls animation state
  final bool isPaused; // Controls pause state visualization

  const MusicAwareVisualizer({
    super.key,
    required this.values,
    required this.width,
    required this.height,
    required this.isPlaying,
    this.isPaused = false,
    this.color = const Color.fromRGBO(255, 255, 255, 0.92),
    this.barSpacing = 4,
    this.barGapFraction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _EnhancedBarsPainter(
          values: values,
          color: color,
          barSpacing: barSpacing,
          barGapFraction: barGapFraction,
          isPlaying: isPlaying,
          isPaused: isPaused,
        ),
      ),
    );
  }
}

class _EnhancedBarsPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double barSpacing;
  final double? barGapFraction;
  final bool isPlaying;
  final bool isPaused;

  _EnhancedBarsPainter({
    required this.values,
    required this.color,
    required this.barSpacing,
    this.barGapFraction,
    required this.isPlaying,
    required this.isPaused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = isPaused ? color.withOpacity(0.88) : color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;

    final bars = values.length;
    double barWidth;
    double gap;

    if (barGapFraction != null) {
      barWidth = size.width / (bars + (bars - 1) * barGapFraction!);
      gap = barWidth * barGapFraction!;
    } else {
      final totalSpacing = barSpacing * (bars - 1);
      barWidth = (size.width - totalSpacing) / bars;
      gap = barSpacing;
    }

    final radius = Radius.circular(barWidth / 2);

    for (int i = 0; i < bars; i++) {
      double v = values[i].clamp(0.0, 1.0);

      // Apply different behavior based on playback state
      if (!isPlaying || isPaused) {
        // When paused or stopped, show minimal static bars
        v = v * 2; // Keep some minimal height
      }

      final h = v * size.height;
      final left = i * (barWidth + gap);

      // Center the bar vertically
      final centerY = size.height / 2;
      final top = centerY - (h / 2);

      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barWidth, h),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnhancedBarsPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    if (oldDelegate.isPlaying != isPlaying) return true;
    if (oldDelegate.isPaused != isPaused) return true;

    for (int i = 0; i < values.length; i++) {
      if ((oldDelegate.values[i] - values[i]).abs() > 0.005) return true;
    }
    return false;
  }
}

/// Silent state detector that monitors audio levels
class SilenceDetector {
  static const double _silenceThreshold = 0.02;
  static const int _silenceFrames = 30; // ~0.5 seconds at 60fps

  int _consecutiveSilentFrames = 0;
  bool _isSilent = true;

  /// Check if current audio levels indicate silence
  bool detectSilence(List<double> audioLevels) {
    final maxLevel = audioLevels.reduce(math.max);

    if (maxLevel < _silenceThreshold) {
      _consecutiveSilentFrames++;
      if (_consecutiveSilentFrames >= _silenceFrames) {
        _isSilent = true;
      }
    } else {
      _consecutiveSilentFrames = 0;
      _isSilent = false;
    }

    return _isSilent;
  }

  bool get isSilent => _isSilent;

  void reset() {
    _consecutiveSilentFrames = 0;
    _isSilent = true;
  }
}

/// Enhanced visualizer overlay that integrates with music manager
class EnhancedVisualizerOverlay extends StatefulWidget {
  final Widget child;
  final bool show;
  final bool isPlaying;
  final bool isPaused;
  final int? audioSessionId;
  final double coverageFraction;
  final double maxHeightFraction;
  final Color color;
  final AlignmentGeometry alignment;
  final double barGapFraction;
  final double minVisualWidth;
  final double minVisualHeight;
  final EdgeInsets visualizerPadding;

  const EnhancedVisualizerOverlay({
    super.key,
    required this.child,
    required this.show,
    required this.isPlaying,
    this.isPaused = false,
    this.audioSessionId,
    this.coverageFraction = 0.55,
    this.maxHeightFraction = 0.95,
    this.color = const Color.fromRGBO(255, 255, 255, 0.92),
    this.alignment = const Alignment(0, 0.25),
    this.barGapFraction = 0.8,
    this.minVisualWidth = 40.0,
    this.minVisualHeight = 30.0,
    this.visualizerPadding = EdgeInsets.zero,
  });

  @override
  State<EnhancedVisualizerOverlay> createState() =>
      _EnhancedVisualizerOverlayState();
}

class _EnhancedVisualizerOverlayState extends State<EnhancedVisualizerOverlay>
    with SingleTickerProviderStateMixin, RouteAware {
  StreamSubscription<List<double>>? _sub;
  StreamSubscription<bool>? _activeSub;
  List<double> _values = [
    0.15,
    0.2,
    0.25,
    0.2,
    0.15,
  ]; // Minimal starting values
  List<double> _target = [0.15, 0.2, 0.25, 0.2, 0.15];
  bool _started = false;
  Ticker? _ticker;
  final SilenceDetector _silenceDetector = SilenceDetector();

  // Debouncing to prevent rapid start/stop cycles from multiple overlays
  Timer? _debounceTimer;
  bool _pendingUpdate = false;

  @override
  void initState() {
    super.initState();
    _maybeUpdate();
    // Listen to active state changes so we can re-evaluate start when the
    // visualizer becomes active elsewhere in the app (fallback for missing
    // RouteAware events).
    try {
      _activeSub = EnhancedAudioVisualizerService.activeStateStream.listen((
        active,
      ) {
        debugPrint(
          '[EnhancedVisualizerOverlay] Active state changed: $active, widget.show=${widget.show}, _started=$_started, _sub=${_sub != null ? "active" : "null"}',
        );
        if (active && widget.show) {
          // Attempt to re-subscribe/start if our widget should be showing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint(
              '[EnhancedVisualizerOverlay] Active state listener triggering _maybeUpdate',
            );
            _maybeUpdate();
          });
        }
      });
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      // Subscribe to route changes so we can resume when returning to this screen
      final ModalRoute? route = ModalRoute.of(context);
      if (route is PageRoute) {
        // Use the global routeObserver from main.dart
        routeObserver.subscribe(this, route);
      }
    } catch (e) {
      debugPrint(
        'EnhancedVisualizer: failed to subscribe to routeObserver - $e',
      );
    }
  }

  @override
  void didUpdateWidget(covariant EnhancedVisualizerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioSessionId != widget.audioSessionId &&
        widget.audioSessionId != null) {
      _updateAudioSession();
    }
    _maybeUpdate();
  }

  Future<void> _updateAudioSession() async {
    if (_started && widget.audioSessionId != null) {
      await EnhancedAudioVisualizerService.updateAudioSessionId(
        widget.audioSessionId,
      );
    }
  }

  Future<void> _maybeUpdate() async {
    // Debounce rapid updates to prevent multiple overlays from competing
    if (_pendingUpdate) {
      return;
    }

    _pendingUpdate = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () async {
      _pendingUpdate = false;
      await _performUpdate();
    });
  }

  Future<void> _performUpdate() async {
    debugPrint(
      '[EnhancedVisualizerOverlay] _performUpdate called; show=${widget.show}, isPlaying=${widget.isPlaying}, isPaused=${widget.isPaused}, _started=$_started, _sub=${_sub != null ? "active" : "null"}',
    );
    final shouldStart = widget.show && widget.isPlaying && !widget.isPaused;

    if (shouldStart && !_started) {
      debugPrint(
        '[EnhancedVisualizerOverlay] Attempting to start visualizer (overlay)',
      );
      final started = await EnhancedAudioVisualizerService.startVisualizer(
        audioSessionId: widget.audioSessionId,
      );

      debugPrint(
        '[EnhancedVisualizerOverlay] startVisualizer returned: $started',
      );

      if (started) {
        _sub?.cancel();
        debugPrint('[EnhancedVisualizerOverlay] Subscribing to fftStream');
        bool firstData = true;
        _sub = EnhancedAudioVisualizerService.fftStream.listen((data) {
          if (data.length == 5) {
            if (firstData) {
              debugPrint(
                '[EnhancedVisualizerOverlay] Received first FFT data: $data',
              );
              firstData = false;
            }
            // Detect silence and update target values accordingly
            final isSilent = _silenceDetector.detectSilence(data);

            if (isSilent) {
              // During silence, fade to minimal values
              _target = [0.05, 0.1, 0.15, 0.1, 0.05];
            } else {
              // During audio playback, use actual data
              _target = data;
            }
          }
        });
        // If we have a warm-up lastFrame from the service, apply it immediately
        try {
          final frame = EnhancedAudioVisualizerService.lastFrame;
          if (frame != null && frame.length == 5) {
            debugPrint(
              '[EnhancedVisualizerOverlay] Applying warm-up lastFrame: $frame',
            );
            _target = frame;
            if (mounted) setState(() {});
          }
        } catch (_) {}

        _ticker ??= createTicker(_onTick);
        if (!_ticker!.isActive) {
          debugPrint('[EnhancedVisualizerOverlay] Starting ticker');
          _ticker!.start();
        }
        _started = true;
        debugPrint('[EnhancedVisualizerOverlay] Overlay started');
        _silenceDetector.reset();
      }
    } else if (shouldStart && _started && _sub == null) {
      // Handle case where we think we're started but subscription was lost
      // This can happen after navigation when the global visualizer resumes
      // but our local subscription was cancelled
      debugPrint(
        '[EnhancedVisualizerOverlay] Resubscribing to existing visualizer stream',
      );
      bool firstData = true;
      _sub = EnhancedAudioVisualizerService.fftStream.listen((data) {
        if (data.length == 5) {
          if (firstData) {
            debugPrint(
              '[EnhancedVisualizerOverlay] Received first FFT data after resubscribe: $data',
            );
            firstData = false;
          }
          // Detect silence and update target values accordingly
          final isSilent = _silenceDetector.detectSilence(data);

          if (isSilent) {
            // During silence, fade to minimal values
            _target = [0.05, 0.1, 0.15, 0.1, 0.05];
          } else {
            // During audio playback, use actual data
            _target = data;
          }
        }
      });

      _ticker ??= createTicker(_onTick);
      if (!_ticker!.isActive) {
        debugPrint('[EnhancedVisualizerOverlay] Restarting ticker');
        _ticker!.start();
      }
      debugPrint('[EnhancedVisualizerOverlay] Resubscribed to visualizer');
    } else if (shouldStart && _sub == null) {
      // This handles the case where overlay should be active but isn't subscribed
      // (regardless of _started state). This can happen after navigation.
      debugPrint(
        '[EnhancedVisualizerOverlay] Overlay should be active but not subscribed - checking global visualizer state',
      );

      // Check if global visualizer is active
      final isGlobalVisualizerActive =
          await EnhancedAudioVisualizerService.isVisualizerActive();
      if (isGlobalVisualizerActive) {
        debugPrint(
          '[EnhancedVisualizerOverlay] Global visualizer is active, resubscribing to stream',
        );
        bool firstData = true;
        _sub = EnhancedAudioVisualizerService.fftStream.listen((data) {
          if (data.length == 5) {
            if (firstData) {
              debugPrint(
                '[EnhancedVisualizerOverlay] Received first FFT data after global check: $data',
              );
              firstData = false;
            }
            // Detect silence and update target values accordingly
            final isSilent = _silenceDetector.detectSilence(data);

            if (isSilent) {
              // During silence, fade to minimal values
              _target = [0.05, 0.1, 0.15, 0.1, 0.05];
            } else {
              // During audio playback, use actual data
              _target = data;
            }
          }
        });

        _ticker ??= createTicker(_onTick);
        if (!_ticker!.isActive) {
          debugPrint(
            '[EnhancedVisualizerOverlay] Restarting ticker after global check',
          );
          _ticker!.start();
        }
        _started = true;
        debugPrint(
          '[EnhancedVisualizerOverlay] Resubscribed to active global visualizer',
        );
      } else {
        debugPrint(
          '[EnhancedVisualizerOverlay] Global visualizer not active, attempting to start',
        );
        // Fall back to trying to start the visualizer
        final started = await EnhancedAudioVisualizerService.startVisualizer(
          audioSessionId: widget.audioSessionId,
        );
        if (started) {
          // Restart the logic by calling _performUpdate again
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _performUpdate();
          });
        }
      }
    } else if (!shouldStart && _started) {
      debugPrint('[EnhancedVisualizerOverlay] Stopping overlay visualizer');
      // Only stop if no other overlay is using the visualizer
      _sub?.cancel();
      _sub = null;
      if (_ticker?.isActive ?? false) {
        debugPrint('[EnhancedVisualizerOverlay] Stopping ticker');
        _ticker?.stop();
      }
      _started = false;

      // Reset to minimal values when stopped
      if (mounted) {
        setState(() {
          _values = [0.15, 0.2, 0.25, 0.2, 0.15];
          _target = [0.15, 0.2, 0.25, 0.2, 0.15];
        });
      }
      debugPrint(
        '[EnhancedVisualizerOverlay] Overlay stopped (subscription cancelled)',
      );
    }
  }

  void _onTick(Duration elapsed) {
    bool changed = false;
    final next = List<double>.filled(5, 0.0);

    for (int i = 0; i < 5; i++) {
      final curr = i < _values.length ? _values[i] : 0.0;
      final tgt = i < _target.length ? _target[i] : 0.0;
      final diff = tgt - curr;

      // Frequency-specific easing for natural movement
      double easeUp, easeDown;
      switch (i) {
        case 0: // Bass - slow and smooth
          easeUp = 0.03;
          easeDown = 0.02;
          break;
        case 1: // Low-mid - moderate
          easeUp = 0.04;
          easeDown = 0.025;
          break;
        case 2: // Mid - responsive
          easeUp = 0.06;
          easeDown = 0.04;
          break;
        case 3: // High-mid - more responsive
          easeUp = 0.08;
          easeDown = 0.05;
          break;
        case 4: // Treble - most responsive
          easeUp = 0.1;
          easeDown = 0.07;
          break;
        default:
          easeUp = 0.05;
          easeDown = 0.03;
      }

      final a = diff >= 0 ? easeUp : easeDown;
      final v = (curr + diff * a).clamp(0.0, 1.0);
      next[i] = v;

      if ((v - curr).abs() > 0.002) {
        changed = true;
      }
    }

    if (changed && mounted) {
      setState(() => _values = next);
    }
  }

  @override
  void dispose() {
    // Unsubscribe from route observer
    try {
      final ModalRoute? route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.unsubscribe(this);
      }
    } catch (_) {}

    // Clean up debounce timer
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingUpdate = false;

    _sub?.cancel();
    _sub = null;
    _activeSub?.cancel();
    _activeSub = null;
    if (_started) {
      // Only stop the global visualizer if we were the one that started it
      // Multiple overlays may share the global visualizer
      debugPrint(
        '[EnhancedVisualizerOverlay] Disposing overlay - stopping local subscription only',
      );
    }
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  // RouteAware callbacks -------------------------------------------------
  @override
  void didPopNext() {
    // Called when the top route has been popped and this route shows up again.
    // Ensure visualizer resumes if needed.
    debugPrint('[EnhancedVisualizerOverlay] didPopNext fired for $widget');

    // Cancel any pending debounced update first
    _debounceTimer?.cancel();
    _pendingUpdate = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force a check regardless of current state, but reset the started flag
      // to ensure proper restart after navigation
      debugPrint(
        '[EnhancedVisualizerOverlay] didPopNext: resetting state and forcing _maybeUpdate check',
      );
      _started = false;
      _sub?.cancel();
      _sub = null;
      _maybeUpdate();
    });
  }

  @override
  void didPushNext() {
    // Another route was pushed on top of this one. Pause visualizer to save
    // resources (it will be resumed in didPopNext).
    debugPrint('[EnhancedVisualizerOverlay] didPushNext fired for $widget');

    // Cancel any pending updates
    _debounceTimer?.cancel();
    _pendingUpdate = false;

    if (_started) {
      // Stop listening but keep state so it can restart quickly
      _sub?.cancel();
      _sub = null;
      _ticker?.stop();
      // Reset started state so didPopNext can restart properly
      _started = false;
    }
  }

  @override
  void didPush() {
    debugPrint('[EnhancedVisualizerOverlay] didPush fired for $widget');
    super.didPush();
  }

  @override
  void didPop() {
    debugPrint('[EnhancedVisualizerOverlay] didPop fired for $widget');
    super.didPop();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth * widget.coverageFraction;
        double h = constraints.maxHeight * widget.maxHeightFraction;

        w = w.clamp(widget.minVisualWidth, constraints.maxWidth);
        h = h.clamp(widget.minVisualHeight, constraints.maxHeight);

        return Stack(
          alignment: widget.alignment,
          children: [
            widget.child,
            if (widget.show)
              IgnorePointer(
                child: Padding(
                  padding: widget.visualizerPadding,
                  child: MusicAwareVisualizer(
                    values: _values,
                    width: w,
                    height: h,
                    color: widget.color,
                    barGapFraction: widget.barGapFraction,
                    isPlaying: widget.isPlaying,
                    isPaused: widget.isPaused,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Enhanced album art widget with improved visualizer
class EnhancedAlbumArtWithVisualizer extends StatelessWidget {
  final ImageProvider image;
  final bool isCurrent;
  final bool isPlaying;
  final bool isPaused;
  final int? audioSessionId;
  final double size;
  final Color color;
  final EdgeInsets visualizerPadding;

  const EnhancedAlbumArtWithVisualizer({
    super.key,
    required this.image,
    required this.isCurrent,
    required this.isPlaying,
    this.isPaused = false,
    this.audioSessionId,
    this.size = 150,
    this.color = const Color.fromRGBO(255, 255, 255, 0.92),
    this.visualizerPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: EnhancedVisualizerOverlay(
          show: isCurrent,
          isPlaying: isPlaying,
          isPaused: isPaused,
          audioSessionId: audioSessionId,
          color: color,
          visualizerPadding: visualizerPadding,
          child: Image(image: image, fit: BoxFit.fill),
        ),
      ),
    );
  }
}
