import 'package:flutter/widgets.dart';
import 'sizes.dart';
import '../services/media_overlay_manager.dart';

class AppPadding {
  /// Compute bottom padding for in-page content.
  ///
  /// This includes the mini-player overlay height so individual screens can
  /// position bottom controls (submit buttons, CTA) correctly above the
  /// navigation / mini-player area without needing to listen to the global
  /// overlay directly.
  static double bottom(BuildContext context, {double extra = 0}) {
    final media = MediaQuery.of(context);
    final safeInsetBottom = media.padding.bottom;
    final overlayHeight = MediaOverlayManager.instance.miniPlayerHeight.value;
    return safeInsetBottom + AppSizes.basePadding + overlayHeight + extra;
  }
}
