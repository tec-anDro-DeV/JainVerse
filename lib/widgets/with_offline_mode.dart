import 'package:flutter/material.dart';

import '../widgets/offline_mode_prompt.dart';

/// Wrapper widget that adds offline mode capabilities to any screen
/// This widget overlays the offline mode prompt and FAB on top of child content
class WithOfflineMode extends StatelessWidget {
  final Widget child;
  final bool showFAB;
  final bool showPrompt;

  const WithOfflineMode({
    super.key,
    required this.child,
    this.showFAB = true,
    this.showPrompt = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Original content
        child,

        // Offline mode prompt overlay
        if (showPrompt) const OfflineModePrompt(),

        // Offline mode FAB overlay
        if (showFAB)
          Positioned(bottom: 16, right: 16, child: const OfflineModeFAB()),
      ],
    );
  }
}

/// Extension to easily add offline mode to any widget
extension OfflineModeExtension on Widget {
  /// Wraps the widget with offline mode capabilities
  Widget withOfflineMode({bool showFAB = true, bool showPrompt = true}) {
    return WithOfflineMode(
      showFAB: showFAB,
      showPrompt: showPrompt,
      child: this,
    );
  }
}
