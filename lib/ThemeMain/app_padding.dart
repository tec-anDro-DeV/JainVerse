import 'package:flutter/widgets.dart';
import 'sizes.dart';
import '../services/media_overlay_manager.dart';

class AppPadding {
  static double bottom(BuildContext context, {double extra = 0}) {
    final media = MediaQuery.of(context);
    final safeInsetBottom = media.padding.bottom;
    final overlayHeight = MediaOverlayManager.instance.miniPlayerHeight.value;
    return safeInsetBottom + AppSizes.basePadding + overlayHeight + extra;
  }
}
