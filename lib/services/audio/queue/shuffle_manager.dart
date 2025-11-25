import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:jainverse/services/audio/common/audio_logger.dart';

/// Manages shuffle state and custom shuffle indices independent of the handler.
class ShuffleManager {
  ShuffleManager();

  final BehaviorSubject<List<int>?> _indicesSubject =
      BehaviorSubject<List<int>?>.seeded(null);

  bool _isEnabled = false;
  List<int> _shuffledIndices = const [];

  ValueStream<List<int>?> get indicesStream => _indicesSubject;
  bool get isShuffleEnabled => _isEnabled;

  void setShuffleMode({
    required AudioServiceShuffleMode shuffleMode,
    required int queueLength,
    required int currentIndex,
  }) {
    _isEnabled = shuffleMode == AudioServiceShuffleMode.all;
    if (!_isEnabled || queueLength <= 0) {
      _disableShuffle();
      return;
    }

    _generateShuffleIndices(queueLength, currentIndex);
  }

  void regenerateIndicesIfNeeded({
    required int queueLength,
    required int currentIndex,
  }) {
    if (!_isEnabled || queueLength <= 0) {
      return;
    }
    _generateShuffleIndices(queueLength, currentIndex);
  }

  int? getNextIndex(int currentIndex, int queueLength) {
    if (!_isEnabled) {
      return currentIndex + 1 < queueLength ? currentIndex + 1 : null;
    }

    final position = _shuffledIndices.indexOf(currentIndex);
    if (position == -1 || position + 1 >= _shuffledIndices.length) {
      return null;
    }
    return _shuffledIndices[position + 1];
  }

  int? getPreviousIndex(int currentIndex) {
    if (!_isEnabled) {
      return currentIndex > 0 ? currentIndex - 1 : null;
    }

    final position = _shuffledIndices.indexOf(currentIndex);
    if (position <= 0) {
      return null;
    }
    return _shuffledIndices[position - 1];
  }

  void _generateShuffleIndices(int queueLength, int currentIndex) {
    final normalizedIndex = queueLength == 0
        ? 0
        : max(0, min(currentIndex, queueLength - 1));

    final indices = List<int>.generate(queueLength, (index) => index);
    if (indices.isEmpty) {
      _disableShuffle();
      return;
    }

    indices.removeAt(normalizedIndex);
    indices.shuffle();
    indices.insert(0, normalizedIndex);
    _shuffledIndices = indices;
    _indicesSubject.add(indices);

    AudioLogger.log(
      '[ShuffleManager] Generated shuffle indices: $_shuffledIndices',
      name: 'ShuffleManager',
    );
  }

  void _disableShuffle() {
    if (!_isEnabled && _indicesSubject.valueOrNull == null) {
      return;
    }
    _isEnabled = false;
    _shuffledIndices = const [];
    _indicesSubject.add(null);

    AudioLogger.log(
      '[ShuffleManager] Shuffle disabled',
      name: 'ShuffleManager',
    );
  }

  void dispose() {
    _indicesSubject.close();
  }
}
