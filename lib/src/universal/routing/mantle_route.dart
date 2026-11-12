import '../components/mantle_component.dart';

typedef MantleRouteBuilder = MantleComponent Function(MantleContext context);
typedef MantleRouteGuard = String? Function(MantleContext context);

/// Represents a single route declaration in MetaMantle's universal routing system.
class MantleRoute {
  const MantleRoute({
    required this.path,
    required this.builder,
    this.title,
    this.guard,
    this.children = const [],
    this.meta = const {},
  });

  /// Path pattern, supporting parameterized segments like `/products/:id`.
  final String path;
  final MantleRouteBuilder builder;
  final String? title;
  final MantleRouteGuard? guard;
  final List<MantleRoute> children;
  final Map<String, Object?> meta;

  /// Tests if this route matches [actualPath] and extracts path parameters.
  Map<String, String>? match(String actualPath) {
    final patternSegments = Uri.parse(path).pathSegments;
    final actualSegments = Uri.parse(actualPath).pathSegments;

    if (patternSegments.length != actualSegments.length) {
      return null;
    }

    final params = <String, String>{};
    for (var i = 0; i < patternSegments.length; i++) {
      final pSeg = patternSegments[i];
      final aSeg = actualSegments[i];

      if (pSeg.startsWith(':')) {
        params[pSeg.substring(1)] = Uri.decodeComponent(aSeg);
      } else if (pSeg != aSeg) {
        return null;
      }
    }
    return params;
  }
}

/// Result of matching a path against registered [MantleRoute]s.
class MantleRouteMatch {
  const MantleRouteMatch({
    required this.route,
    required this.path,
    this.pathParameters = const {},
    this.queryParameters = const {},
    this.redirectPath,
  });

  final MantleRoute route;
  final String path;
  final Map<String, String> pathParameters;
  final Map<String, String> queryParameters;
  final String? redirectPath;

  bool get isRedirect => redirectPath != null;

  MantleComponent build(MantleContext context) => route.builder(context);
}

/// Universal route resolver and matching engine.
class MantleRouter {
  const MantleRouter({required this.routes, this.notFoundBuilder});

  final List<MantleRoute> routes;
  final MantleRouteBuilder? notFoundBuilder;

  /// Returns all static discoverable paths declared in this router (for SSG/sitemap).
  List<String> getDiscoverableRoutes() {
    final list = <String>[];
    for (final r in routes) {
      if (!r.path.contains(':') && !r.path.contains('*')) {
        list.add(r.path);
      }
    }
    return list;
  }

  /// Matches [uriOrPath] against registered routes.
  MantleRouteMatch? match(String uriOrPath) {
    final uri = Uri.parse(uriOrPath);
    final targetPath = uri.path.isEmpty ? '/' : uri.path;

    for (final route in routes) {
      final params = route.match(targetPath);
      if (params != null) {
        return MantleRouteMatch(
          route: route,
          path: targetPath,
          pathParameters: params,
          queryParameters: uri.queryParameters,
        );
      }
    }

    if (notFoundBuilder != null) {
      return MantleRouteMatch(
        route: MantleRoute(
          path: targetPath,
          builder: notFoundBuilder!,
          title: 'Not Found',
        ),
        path: targetPath,
        queryParameters: uri.queryParameters,
      );
    }
    return null;
  }
}

/// Universal application root definition.
class MantleApp {
  const MantleApp({
    required this.routes,
    this.initialPath = '/',
    this.title = 'MetaMantle Application',
    this.notFoundBuilder,
  });

  final List<MantleRoute> routes;
  final String initialPath;
  final String title;
  final MantleRouteBuilder? notFoundBuilder;

  MantleRouter get router =>
      MantleRouter(routes: routes, notFoundBuilder: notFoundBuilder);
}

/// Concrete implementation of [MantleContext] for runtime navigation.
class MantleNavigationContext implements MantleContext {
  MantleNavigationContext({
    required this.currentPath,
    this.pathParameters = const {},
    this.queryParameters = const {},
    this.onGo,
    this.onBack,
    MantleStateRegistry? stateRegistry,
  }) : stateRegistry = stateRegistry ?? MantleStateRegistry();

  @override
  final String currentPath;

  @override
  final Map<String, String> pathParameters;

  @override
  final Map<String, String> queryParameters;

  @override
  final MantleStateRegistry stateRegistry;

  final void Function(String path, {Map<String, String>? queryParameters})?
  onGo;
  final void Function()? onBack;

  @override
  void go(String path, {Map<String, String>? queryParameters}) {
    onGo?.call(path, queryParameters: queryParameters);
  }

  @override
  void back() {
    onBack?.call();
  }
}
