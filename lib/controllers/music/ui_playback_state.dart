import 'package:flutter/foundation.dart';

import '../../models/downloaded_music.dart';
import 'download_state_linker.dart';

typedef DownloadUpdateListener = void Function(List<DownloadedMusic> downloads);

/// Aggregates playback-related UI state that does not belong on the
/// lower-level audio stack. Owns the processing indicator and propagates
/// download state updates to interested listeners.
class UIPlaybackState {
  UIPlaybackState._internal()
    : processingAudioId = ValueNotifier<String?>(null);

  static final UIPlaybackState _instance = UIPlaybackState._internal();

  factory UIPlaybackState() => _instance;

  final ValueNotifier<String?> processingAudioId;
  DownloadStateLinker? _downloadLinker;
  final List<DownloadUpdateListener> _downloadListeners = [];
  bool _downloadSyncStarted = false;

  void attachDownloadLinker(
    DownloadStateLinker linker, {
    bool startImmediately = false,
  }) {
    _downloadLinker?.dispose();
    _downloadLinker = linker;
    _downloadSyncStarted = false;
    if (startImmediately) {
      startDownloadSync();
    }
  }

  void startDownloadSync() {
    if (_downloadLinker == null || _downloadSyncStarted) return;
    _downloadSyncStarted = true;
    _downloadLinker!.start(_notifyDownloadListeners);
  }

  void addDownloadListener(DownloadUpdateListener listener) {
    if (_downloadListeners.contains(listener)) return;
    _downloadListeners.add(listener);
  }

  void removeDownloadListener(DownloadUpdateListener listener) {
    _downloadListeners.remove(listener);
  }

  Future<T> runWithProcessing<T>(
    String? audioId,
    Future<T> Function() operation,
  ) async {
    final previous = processingAudioId.value;
    if (audioId != null && audioId.isNotEmpty) {
      processingAudioId.value = audioId;
    } else {
      processingAudioId.value = null;
    }
    try {
      return await operation();
    } finally {
      processingAudioId.value = previous;
    }
  }

  void clearProcessingAudioId() {
    processingAudioId.value = null;
  }

  void dispose() {
    _downloadLinker?.dispose();
    _downloadLinker = null;
    _downloadListeners.clear();
    processingAudioId.dispose();
    _downloadSyncStarted = false;
  }

  void _notifyDownloadListeners(List<DownloadedMusic> downloads) {
    final listeners = List<DownloadUpdateListener>.from(_downloadListeners);
    for (final listener in listeners) {
      try {
        listener(downloads);
      } catch (error, stackTrace) {
        debugPrint('UIPlaybackState listener error: $error\n$stackTrace');
      }
    }
  }
}
