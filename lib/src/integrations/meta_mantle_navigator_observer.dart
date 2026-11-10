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
  MetaMantleNavigatorObserver({this.urlExtractor});

  /// Optional custom extractor to derive the URL path from a [Route].
  final String? Function(Route<dynamic> route)? urlExtractor;

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
    if (customUrl != null) {
      MetaMantle.setCurrentUrl(customUrl);
      return;
    }
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      MetaMantle.setCurrentUrl(name);
    }
  }
}

/// Backward compatibility alias for [MetaMantleNavigatorObserver].
typedef WebHeadNavigatorObserver = MetaMantleNavigatorObserver;
