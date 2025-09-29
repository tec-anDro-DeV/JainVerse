import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

/// Utility to compute a sharePositionOrigin Rect for Share.share on iPad.
///
/// On iPad, the platform requires a non-zero origin for the share sheet when
/// invoked from a button or a view. This helper computes a Rect anchored to
/// the provided BuildContext's RenderBox. If the box is not available or the
/// platform is not iOS, it returns null so callers can omit the parameter.
Rect? computeSharePosition(BuildContext? context) {
  if (context == null) return null;

  // Only necessary on iOS (iPad/touch devices). Returning null on other
  // platforms keeps behavior unchanged.
  if (!(Platform.isIOS)) return null;

  try {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    // Ensure non-zero size
    if (size.width == 0 || size.height == 0) return null;
    return Rect.fromLTWH(origin.dx, origin.dy, size.width, size.height);
  } catch (e) {
    // If any error occurs, return null and let caller fallback to default behavior
    return null;
  }
}
