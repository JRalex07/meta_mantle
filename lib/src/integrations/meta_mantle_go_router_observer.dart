import 'package:flutter/widgets.dart';

import '../models/metadata.dart';
import '../runtime/meta_mantle.dart';

/// Function signature for extracting metadata from a GoRouter route.
typedef GoRouteMetadataProvider = WebMetadata? Function(
  Route<dynamic> route,
  String path,
);

/// An official [NavigatorObserver] tailored for [go_router] applications.
///
/// Synchronizes active route changes, nested shell routes, and browser URLs with
/// [MetaMantle], applies route-specific metadata, and coordinates the first-frame
/// readiness lifecycle to fade out the static prerender snapshot smoothly.
///
/// Example:
/// ```dart
/// final router = GoRouter(
///   observers: [
///     MetaMantleGoRouterObserver(
///       onRouteChanged: (path) => print('Navigated to $path'),
///     ),
///   ],
///   routes: [ ... ],
/// );
/// ```
class MetaMantleGoRouterObserver extends NavigatorObserver {
  MetaMantleGoRouterObserver({
    this.urlExtractor,
    this.metadataProvider,
    this.onRouteChanged,
    this.markReadyOnFirstFrame = true,
  }) {
    if (markReadyOnFirstFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MetaMantle.markReady();
      });
    }
  }

  /// Custom extractor to resolve the URL location from a [Route].
  final String? Function(Route<dynamic> route)? urlExtractor;

  /// Optional provider returning [WebMetadata] based on the current route and resolved path.
  final GoRouteMetadataProvider? metadataProvider;

  /// Optional notification callback invoked whenever the user navigates to a new route.
  final void Function(String path)? onRouteChanged;

  /// Whether to automatically notify [MetaMantle.markReady()] on the first rendered frame.
  final bool markReadyOnFirstFrame;

  String? _lastSynchronizedPath;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _syncRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _syncRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _syncRoute(newRoute);
    }
  }

  void _syncRoute(Route<dynamic> route) {
    final customUrl = urlExtractor?.call(route);
    final resolvedPath = customUrl ?? route.settings.name;

    if (resolvedPath != null && resolvedPath.isNotEmpty) {
      if (_lastSynchronizedPath == resolvedPath) return;
      _lastSynchronizedPath = resolvedPath;

      // 1. Synchronize URL and Canonical
      MetaMantle.setCurrentUrl(resolvedPath);

      // 2. Apply dynamic metadata if provider is configured
      if (metadataProvider != null) {
        final meta = metadataProvider!(route, resolvedPath);
        if (meta != null) {
          MetaMantle.update(meta);
        }
      }

      onRouteChanged?.call(resolvedPath);
    }
  }
}
