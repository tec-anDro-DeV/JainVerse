import 'package:flutter/foundation.dart';

/// Simple manager to track which videos have been reported locally
/// This mirrors the approach used by LikeDislikeStateManager so screens
/// can react to report changes without re-fetching full lists.
class ReportStateManager {
  static final ReportStateManager _instance = ReportStateManager._internal();

  factory ReportStateManager() => _instance;

  ReportStateManager._internal();

  final Map<int, bool> _reported = {};
  final List<VoidCallback> _listeners = [];

  bool isReported(int videoId) => _reported[videoId] == true;

  void markReported(int videoId) {
    final prev = _reported[videoId] ?? false;
    if (!prev) {
      _reported[videoId] = true;
      _notifyListeners();
    }
  }

  void unmarkReported(int videoId) {
    if (_reported.containsKey(videoId)) {
      _reported.remove(videoId);
      _notifyListeners();
    }
  }

  void addListener(VoidCallback l) {
    if (!_listeners.contains(l)) _listeners.add(l);
  }

  void removeListener(VoidCallback l) {
    _listeners.remove(l);
  }

  void _notifyListeners() {
    for (final l in _listeners) {
      try {
        l();
      } catch (e) {
        if (kDebugMode) debugPrint('ReportStateManager listener error: $e');
      }
    }
  }
}
