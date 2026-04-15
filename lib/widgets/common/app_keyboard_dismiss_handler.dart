import 'package:flutter/material.dart';

/// Globally intercepts the Android back button / IME dismiss event.
///
/// When the software keyboard is visible, dismisses it and consumes the
/// back event (no navigation pop). When the keyboard is hidden, lets the
/// event pass through to the Navigator so all existing [WillPopScope] /
/// [PopScope] handlers work normally.
///
/// Uses [WidgetsBindingObserver.didPopRoute] — the earliest point in
/// Flutter's back-event pipeline for classic [Navigator]-based apps
/// (i.e. [MaterialApp] without a [Router]). Observers added later are
/// called first (LIFO), so this fires before [WidgetsApp]'s own observer
/// that calls [NavigatorState.maybePop].
///
/// Placed in [MaterialApp.builder] this applies globally to every screen
/// without any per-screen changes.
class AppKeyboardDismissHandler extends StatefulWidget {
  const AppKeyboardDismissHandler({super.key, required this.child});

  final Widget child;

  @override
  State<AppKeyboardDismissHandler> createState() =>
      _AppKeyboardDismissHandlerState();
}

class _AppKeyboardDismissHandlerState extends State<AppKeyboardDismissHandler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Register AFTER WidgetsApp's observer so we are called FIRST (LIFO order).
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called by [WidgetsBinding] when the Android back button is pressed,
  /// before any [WillPopScope] / [PopScope] route handler.
  ///
  /// Returns true  → event consumed, Navigator will NOT pop.
  /// Returns false → event falls through to [WidgetsApp] → Navigator.maybePop().
  @override
  Future<bool> didPopRoute() async {
    // viewInsets.bottom > 0 is the canonical Flutter indicator for the
    // software keyboard being open. Physical / floating keyboards report ~0.
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    if (keyboardVisible) {
      // primaryFocus?.unfocus() works even when the focused widget is deep
      // inside a nested Navigator, dialog, or bottom sheet.
      FocusManager.instance.primaryFocus?.unfocus();
      return true; // consumed — no pop
    }

    return false; // keyboard closed — let Navigator handle normally
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
