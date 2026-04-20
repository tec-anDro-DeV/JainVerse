import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jainverse/features/reels/presentation/controllers/reel_feed_notifier.dart';
import 'package:jainverse/features/reels/presentation/controllers/reel_player_notifier.dart';
import 'package:jainverse/features/reels/presentation/controllers/reel_upload_notifier.dart';
import 'package:jainverse/features/reels/presentation/controllers/reel_like_notifier.dart';
import 'package:jainverse/features/reels/presentation/state/reel_feed_state.dart';
import 'package:jainverse/features/reels/presentation/state/reel_player_state.dart';
import 'package:jainverse/features/reels/presentation/state/reel_upload_state.dart';
import 'package:jainverse/features/reels/presentation/state/reel_like_state.dart';

/// Paginated feed of reels + current scroll index.
final reelFeedProvider =
    NotifierProvider<ReelFeedNotifier, ReelFeedState>(ReelFeedNotifier.new);

/// Active VideoPlayerController pool (±1 window around current page).
final reelPlayerProvider =
    NotifierProvider<ReelPlayerNotifier, ReelPlayerState>(ReelPlayerNotifier.new);

/// Upload pipeline state (pick → compress → upload).
/// Scoped at root ProviderScope so upload continues after screen pop.
final reelUploadProvider =
    NotifierProvider<ReelUploadNotifier, ReelUploadState>(ReelUploadNotifier.new);

/// Per-reel like state with optimistic updates.
final reelLikeProvider =
    NotifierProvider<ReelLikeNotifier, ReelLikeState>(ReelLikeNotifier.new);

/// Incremented each time the user taps the Reels tab icon while already on
/// the Reels screen. [ReelsScreen] listens to this and triggers scroll-to-top
/// followed by a non-destructive refresh.
final reelNavTapProvider =
    NotifierProvider<_ReelNavTapNotifier, int>(_ReelNavTapNotifier.new);

class _ReelNavTapNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}
