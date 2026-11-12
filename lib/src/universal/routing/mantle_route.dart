import '../components/mantle_component.dart';

typedef MantleRouteBuilder = MantleComponent Function(MantleContext context);

/// Represents a single route declaration in MetaMantle's universal routing system.
class MantleRoute {
  const MantleRoute({
    required this.path,
    required this.builder,
    this.title,
  });

  /// Path pattern, supporting parameterized segments like `/products/:id`.
  final String path;
  final MantleRouteBuilder builder;
  final String? title;

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
  });

  final MantleRoute route;
  final String path;
  final Map<String, String> pathParameters;
  final Map<String, String> queryParameters;

  MantleComponent build(MantleContext context) => route.builder(context);
}

/// Universal route resolver and matching engine.
class MantleRouter {
  const MantleRouter({
    required this.routes,
    this.notFoundBuilder,
  });

  final List<MantleRoute> routes;
  final MantleRouteBuilder? notFoundBuilder;

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

  MantleRouter get router => MantleRouter(
        routes: routes,
        notFoundBuilder: notFoundBuilder,
      );
}

/// Concrete implementation of [MantleContext] for runtime navigation.
class MantleNavigationContext implements MantleContext {
  MantleNavigationContext({
    required this.currentPath,
    this.pathParameters = const {},
    this.queryParameters = const {},
    void Function(String path, {Map<String, String>? queryParameters})? onGo,
    void Function()? onBack,
  })  : _onGo = onGo,
        _onBack = onBack;

  @override
  final String currentPath;

  @override
  final Map<String, String> pathParameters;

  @override
  final Map<String, String> queryParameters;

  final void Function(String path, {Map<String, String>? queryParameters})?
      _onGo;
  final void Function()? _onBack;

  @override
  void go(String path, {Map<String, String>? queryParameters}) {
    _onGo?.call(path, queryParameters: queryParameters);
  }

  @override
  void back() {
    _onBack?.call();
  }
}
