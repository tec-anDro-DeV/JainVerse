import 'package:flutter/foundation.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';

@immutable
class ReelFeedState {
  final List<ReelItem> reels;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool hasReachedEnd;
  final int currentPage;
  final int totalPages;
  final String? errorMessage;

  /// The index of the page currently visible in the PageView.
  final int currentIndex;

  /// True while a non-destructive refresh (prepend) is in flight.
  /// Guards against concurrent refresh calls.
  final bool isRefreshing;

  const ReelFeedState({
    this.reels = const [],
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.hasReachedEnd = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.errorMessage,
    this.currentIndex = 0,
    this.isRefreshing = false,
  });

  ReelFeedState copyWith({
    List<ReelItem>? reels,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? hasReachedEnd,
    int? currentPage,
    int? totalPages,
    String? errorMessage,
    int? currentIndex,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return ReelFeedState(
      reels: reels ?? this.reels,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentIndex: currentIndex ?? this.currentIndex,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
