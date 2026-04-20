import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jainverse/features/reels/data/repository/reels_repository.dart';
import 'package:jainverse/features/reels/presentation/providers/reel_providers.dart';
import 'package:jainverse/features/reels/presentation/state/reel_feed_state.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';

class ReelFeedNotifier extends Notifier<ReelFeedState> {
  late final ReelsRepository _repository;

  /// Tracks which reel IDs have had a view event sent this session.
  /// Lives on the notifier (not in immutable state) — intentional.
  final Set<int> _viewedReels = {};

  @override
  ReelFeedState build() {
    _repository = ReelsRepository();
    // Kick off initial load asynchronously so build() returns immediately.
    Future.microtask(loadInitial);
    return const ReelFeedState(isLoadingInitial: true);
  }

  Future<void> loadInitial() async {
    state = state.copyWith(
      isLoadingInitial: true,
      clearError: true,
    );
    try {
      final result = await _repository.getReelsFeed(page: 1);
      state = state.copyWith(
        reels: result.items,
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        isLoadingInitial: false,
        hasReachedEnd: result.currentPage >= result.totalPages,
        currentIndex: 0,
      );
      // Seed the like notifier with fresh data.
      ref.read(reelLikeProvider.notifier).seedFromReels(result.items);
      // Seed global subscription state so subscribe buttons across the app stay in sync.
      SubscriptionStateManager().batchUpdate(
        {for (final r in result.items) r.channelId: r.subscribed == 1},
      );
      // Activate the first controller immediately.
      if (result.items.isNotEmpty) {
        ref
            .read(reelPlayerProvider.notifier)
            .onPageChanged(0, result.items);
        // Fire a view for the first reel (user is already looking at it).
        _trackView(result.items[0].id);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ReelFeedNotifier.loadInitial error: $e');
      state = state.copyWith(
        isLoadingInitial: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Non-destructive refresh: fetches page 1, deduplicates, and prepends
  /// only unseen reels at the top. Existing feed, playback state, and
  /// pagination cursor are all preserved.
  ///
  /// Safe to call concurrently — guarded by [ReelFeedState.isRefreshing].
  Future<void> refresh() async {
    if (state.isRefreshing || state.isLoadingInitial) return;
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final result = await _repository.getReelsFeed(page: 1);
      final existingIds = state.reels.map((r) => r.id).toSet();
      final newItems =
          result.items.where((r) => !existingIds.contains(r.id)).toList();

      if (newItems.isEmpty) {
        state = state.copyWith(isRefreshing: false);
        return;
      }

      final merged = [...newItems, ...state.reels];
      state = state.copyWith(reels: merged, isRefreshing: false);
      // currentPage / totalPages intentionally unchanged — the pagination
      // cursor from loadMore() is still valid after a prepend-only refresh.

      ref.read(reelLikeProvider.notifier).seedFromReels(newItems);
      SubscriptionStateManager().batchUpdate(
        {for (final r in newItems) r.channelId: r.subscribed == 1},
      );

      // The player's window (indices 0/1) now points to different reels.
      // resetForNewFeed saves existing positions, clears the pool, and
      // re-initialises controllers for the updated feed.
      ref
          .read(reelPlayerProvider.notifier)
          .resetForNewFeed(state.currentIndex, merged);
    } catch (e) {
      if (kDebugMode) debugPrint('ReelFeedNotifier.refresh error: $e');
      state = state.copyWith(isRefreshing: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.hasReachedEnd || state.isLoadingInitial) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final result =
          await _repository.getReelsFeed(page: state.currentPage + 1);

      // Deduplicate by id before appending.
      final existingIds = state.reels.map((r) => r.id).toSet();
      final newItems =
          result.items.where((r) => !existingIds.contains(r.id)).toList();

      state = state.copyWith(
        reels: [...state.reels, ...newItems],
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        isLoadingMore: false,
        hasReachedEnd: result.currentPage >= result.totalPages,
      );
      ref.read(reelLikeProvider.notifier).seedFromReels(newItems);
      SubscriptionStateManager().batchUpdate(
        {for (final r in newItems) r.channelId: r.subscribed == 1},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ReelFeedNotifier.loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Called by [ReelsScreen] on every [PageView] page change.
  void setCurrentIndex(int index) {
    if (index == state.currentIndex) return;
    state = state.copyWith(currentIndex: index);

    // Trigger pagination when within 2 items of the end.
    if (index >= state.reels.length - 2) {
      loadMore();
    }

    // Sync the player controller window.
    ref
        .read(reelPlayerProvider.notifier)
        .onPageChanged(index, state.reels);

    // Fire view once per reel per session (fire-and-forget).
    if (index < state.reels.length) {
      _trackView(state.reels[index].id);
    }
  }

  /// Sends a view event for [reelId] if it hasn't been sent this session.
  void _trackView(int reelId) {
    if (_viewedReels.contains(reelId)) return;
    _viewedReels.add(reelId);
    // No await — truly fire-and-forget. Repository swallows all errors.
    _repository.sendView(shortId: reelId);
  }
}
