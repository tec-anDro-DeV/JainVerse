import 'package:flutter/foundation.dart';

/// Holds the per-reel like state for optimistic UI updates.
///
/// Each entry stores the current like value (0 = neutral, 1 = liked) and
/// the running total count. When the API call succeeds, the state is already
/// correct. On failure, the entry is rolled back to its pre-toggle value.
@immutable
class ReelLikeState {
  final Map<int, ({int liked, int count})> entries;

  const ReelLikeState({this.entries = const {}});

  ReelLikeState copyWith({
    Map<int, ({int liked, int count})>? entries,
  }) {
    return ReelLikeState(entries: entries ?? this.entries);
  }

  /// Convenience: returns the like entry for [reelId], falling back to the
  /// provided [fallbackLiked] and [fallbackCount] if not yet seeded.
  ({int liked, int count}) entryFor(
    int reelId, {
    int fallbackLiked = 0,
    int fallbackCount = 0,
  }) {
    return entries[reelId] ?? (liked: fallbackLiked, count: fallbackCount);
  }
}
