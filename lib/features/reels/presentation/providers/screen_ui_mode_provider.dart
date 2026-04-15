import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier that tracks whether a reels-style screen is currently the top
/// route in a nested navigator, regardless of which tab is selected.
///
/// Managed exclusively by [ReelsUIModeScope]. [MainNavigationWrapper] reads
/// this to apply the correct scaffold background, status bar brightness, nav
/// bar gradient, and mini-player visibility.
class ReelsUIModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enterReelsMode() => state = true;
  void exitReelsMode() => state = false;
}

final reelsUIModeProvider =
    NotifierProvider<ReelsUIModeNotifier, bool>(ReelsUIModeNotifier.new);
