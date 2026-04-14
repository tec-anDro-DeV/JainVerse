import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';
import 'package:jainverse/features/reels/data/repository/reels_repository.dart';
import 'package:jainverse/features/reels/presentation/state/reel_like_state.dart';

class ReelLikeNotifier extends Notifier<ReelLikeState> {
  late final ReelsRepository _repository;

  @override
  ReelLikeState build() {
    _repository = ReelsRepository();
    return const ReelLikeState();
  }

  /// Seeds initial like state from a freshly loaded page.
  /// Uses [putIfAbsent] so user-toggled state is never overwritten.
  void seedFromReels(List<ReelItem> reels) {
    final updated = Map.of(state.entries);
    for (final r in reels) {
      updated.putIfAbsent(r.id, () => (liked: r.like, count: r.totalLikes));
    }
    state = state.copyWith(entries: updated);
  }

  /// Toggles the like state for [reelId] with an optimistic UI update.
  /// Rolls back to the previous value if the API call fails.
  Future<void> toggleLike(int reelId) async {
    final current = state.entries[reelId] ?? (liked: 0, count: 0);
    final isLiked = current.liked == 1;

    // Optimistic update
    final optimisticLiked = isLiked ? 0 : 1;
    final optimisticCount = isLiked ? current.count - 1 : current.count + 1;
    _setEntry(reelId, optimisticLiked, optimisticCount.clamp(0, 999999999));

    try {
      final success = await _repository.toggleLike(
        shortId: reelId,
        isLike: optimisticLiked,
      );
      if (!success) {
        _setEntry(reelId, current.liked, current.count); // rollback
      }
    } catch (_) {
      _setEntry(reelId, current.liked, current.count); // rollback
    }
  }

  void _setEntry(int reelId, int liked, int count) {
    state = state.copyWith(
      entries: {...state.entries, reelId: (liked: liked, count: count)},
    );
  }
}
