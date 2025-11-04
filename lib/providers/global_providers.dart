import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global ProviderContainer used for non-widget code that needs to read/write
/// Riverpod providers. This is created once in `main.dart` and passed into the
/// app's ProviderScope so reads from this container reflect the app state.
final ProviderContainer appProviderContainer = ProviderContainer();
