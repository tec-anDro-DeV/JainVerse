import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jainverse/main.dart' show routeObserver, tabNavigatorObservers;
import 'package:jainverse/features/reels/presentation/providers/screen_ui_mode_provider.dart';

/// Wraps any screen that should activate "Reels UI mode" while it is the top
/// route in its navigator.
///
/// Subscribes to [routeObserver] (root navigator) **and** every observer in
/// [tabNavigatorObservers] (nested tab navigators). Only the observer that
/// belongs to the same navigator as this route will actually fire callbacks;
/// all others are harmless no-ops.
///
/// Place this as the outermost widget returned by a reels screen's [build]:
///
/// ```dart
/// return ReelsUIModeScope(
///   child: AnnotatedRegion<SystemUiOverlayStyle>(
///     value: ...,
///     child: Scaffold(...),
///   ),
/// );
/// ```
class ReelsUIModeScope extends ConsumerStatefulWidget {
  final Widget child;
  const ReelsUIModeScope({required this.child, super.key});

  @override
  ConsumerState<ReelsUIModeScope> createState() => _ReelsUIModeScopeState();
}

class _ReelsUIModeScopeState extends ConsumerState<ReelsUIModeScope>
    with RouteAware {
  /// The route we last subscribed to. We only re-subscribe when this changes.
  ///
  /// CRITICAL: Do NOT unsubscribe-then-resubscribe on every
  /// [didChangeDependencies] call. [ModalRoute.of] internally observes
  /// [_ModalScopeStatus], an InheritedWidget that changes during navigation
  /// events (including the pop animation). This causes [didChangeDependencies]
  /// to fire repeatedly while the route is alive. Each unsubscribe→subscribe
  /// cycle calls [RouteObserver.subscribe], which internally calls
  /// [routeAware.didPush()] whenever [Set.add] returns true (i.e., every time
  /// after an unsubscribe). That auto-[didPush] schedules [_enterReelsMode],
  /// which fires in a post-frame callback *after* [_exitReelsModeNow] already
  /// ran synchronously from [didPop] — re-entering reels mode and causing the
  /// ghost re-entry bug where the UI never resets on back navigation.
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _enterReelsMode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _subscribedRoute) {
      // Route changed (first call, or genuinely different route object).
      // Unsubscribe from the previous route's observers first.
      if (_subscribedRoute != null) {
        routeObserver.unsubscribe(this);
        for (final obs in tabNavigatorObservers) {
          obs.unsubscribe(this);
        }
      }
      _subscribedRoute = route;
      // Subscribe to root and all tab observers. Only the observer whose
      // navigator owns this route will fire RouteAware callbacks.
      routeObserver.subscribe(this, route);
      for (final obs in tabNavigatorObservers) {
        obs.subscribe(this, route);
      }
    }
    // If route is the same object, the subscription is already in place —
    // do nothing. Skipping the re-subscribe prevents ghost auto-didPush().
  }

  @override
  void dispose() {
    if (_subscribedRoute != null) {
      routeObserver.unsubscribe(this);
      for (final obs in tabNavigatorObservers) {
        obs.unsubscribe(this);
      }
    }
    // Exit synchronously BEFORE super.dispose() while ref is still valid.
    _exitReelsModeNow();
    super.dispose();
  }

  // RouteAware callbacks ──────────────────────────────────────────────────────

  @override
  void didPush() => _enterReelsMode();

  @override
  void didPopNext() => _enterReelsMode();

  @override
  void didPushNext() => _exitReelsModeNow();

  @override
  void didPop() => _exitReelsModeNow();

  // Helpers ──────────────────────────────────────────────────────────────────

  void _enterReelsMode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Belt-and-suspenders: abort if this route is no longer the top route.
      // Catches any stray _enterReelsMode calls that slip past the
      // didChangeDependencies guard (e.g., from initState during a hot reload
      // where the route has already been superseded).
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      ref.read(reelsUIModeProvider.notifier).enterReelsMode();
    });
  }

  /// Synchronous exit — safe to call from [dispose], [didPop], [didPushNext]
  /// because those are all invoked outside the build phase and [ref] is valid.
  void _exitReelsModeNow() {
    try {
      ref.read(reelsUIModeProvider.notifier).exitReelsMode();
    } catch (_) {
      // Guard against the unlikely case ref is already invalidated.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
