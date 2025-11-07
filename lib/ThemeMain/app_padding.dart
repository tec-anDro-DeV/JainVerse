import 'package:flutter/widgets.dart';

import 'sizes.dart';
import '../services/media_overlay_manager.dart';

/// Central helper to compute app paddings that take safe-area and active overlays into account.
class AppPadding {
  /// Computes bottom padding combining:
  /// - Safe area inset (MediaQuery.padding.bottom)
  /// - AppSizes.basePadding
  /// - Current mini-player / overlay height from MediaOverlayManager
  /// - Optional extra offset
  static double bottom(BuildContext context, {double extra = 0}) {
    final media = MediaQuery.of(context);
    final safeInsetBottom = media.padding.bottom;
    final overlayHeight = MediaOverlayManager.instance.miniPlayerHeight.value;
    return safeInsetBottom + AppSizes.basePadding + overlayHeight + extra;
  }
}
