import 'package:flutter/material.dart';

/// Service to route pushes into the current tab's nested Navigator
class TabNavigationService {
  static final TabNavigationService _instance =
      TabNavigationService._internal();
  factory TabNavigationService() => _instance;
  TabNavigationService._internal();

  TabController? _tabController;
  List<GlobalKey<NavigatorState>> _navigatorKeys = const [];

  /// Notifier for the currently selected tab index. Other widgets can listen
  /// to this to react when the user switches tabs (for example to refresh
  /// content when a tab becomes visible again).
  final ValueNotifier<int> selectedIndex = ValueNotifier<int>(0);

  void initialize(
    TabController tabController,
    List<GlobalKey<NavigatorState>> navigatorKeys,
  ) {
    _tabController = tabController;
    _navigatorKeys = navigatorKeys;
    // Keep the notifier in sync with the TabController
    selectedIndex.value = _tabController!.index;
    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        selectedIndex.value = _tabController!.index;
      }
    });
  }

  bool get isInitialized => _tabController != null && _navigatorKeys.isNotEmpty;

  NavigatorState? get currentNavigator {
    if (!isInitialized) return null;
    final index = _tabController!.index;
    if (index < 0 || index >= _navigatorKeys.length) return null;
    return _navigatorKeys[index].currentState;
  }

  Future<T?>? pushOnCurrentTab<T>(Route<T> route) {
    final navigator = currentNavigator;
    if (navigator == null) {
      debugPrint('[TabNavigationService] No current tab navigator available');
      return null;
    }
    return navigator.push(route);
  }
}
