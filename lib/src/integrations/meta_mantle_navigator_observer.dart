import 'package:flutter/widgets.dart';

import '../runtime/meta_mantle.dart';

/// A [NavigatorObserver] that synchronizes the active browser URL
/// with [MetaMantle] for automatic canonical URL resolution.
///
/// Add this observer to your [MaterialApp] or [Navigator]:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [MetaMantleNavigatorObserver()],
///   // ...
/// );
/// ```
class MetaMantleNavigatorObserver extends NavigatorObserver {
  MetaMantleNavigatorObserver({
    this.urlExtractor,
    this.onRouteChanged,
    this.markReadyOnFirstFrame = true,
  }) {
    if (markReadyOnFirstFrame) {
      try {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          MetaMantle.markReady();
        });
      } catch (_) {
        // Ignored if executed outside of an initialized WidgetsBinding environment.
      }
    }
  }

  /// Optional custom extractor to derive the URL path from a [Route].
  final String? Function(Route<dynamic> route)? urlExtractor;

  /// Optional notification callback invoked whenever the user navigates to a new route.
  final void Function(String path)? onRouteChanged;

  /// Whether to automatically mark the client-ready handshake on the first frame.
  final bool markReadyOnFirstFrame;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _syncUrl(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _syncUrl(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _syncUrl(newRoute);
    }
  }

  void _syncUrl(Route<dynamic> route) {
    final customUrl = urlExtractor?.call(route);
    final name = route.settings.name;
    final path = customUrl ?? (name != null && name.isNotEmpty ? name : null);
    if (path != null) {
      MetaMantle.setCurrentUrl(path);
      onRouteChanged?.call(path);
    }
  }
}

/// Backward compatibility alias for [MetaMantleNavigatorObserver].
typedef WebHeadNavigatorObserver = MetaMantleNavigatorObserver;
