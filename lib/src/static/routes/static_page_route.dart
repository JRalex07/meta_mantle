import '../../models/metadata.dart';
import '../../universal/components/mantle_component.dart';

typedef StaticComponentBuilder = MantleComponent Function(
  MantleContext context,
);

/// Represents a route with associated SEO metadata and static component content.
class StaticPageRoute {
  const StaticPageRoute({
    required this.path,
    this.metadata = const WebMetadata(),
    this.component,
    this.componentBuilder,
    this.htmlContent,
    this.dataSource,
  });

  final String path;
  final WebMetadata metadata;
  final MantleComponent? component;
  final StaticComponentBuilder? componentBuilder;
  final String? htmlContent;
  final Object? dataSource;

  /// Resolves the component for this route using [context].
  MantleComponent? resolveComponent(MantleContext context) {
    if (component != null) return component;
    if (componentBuilder != null) return componentBuilder!(context);
    return null;
  }
}

/// Registry and resolver for statically buildable routes and dynamic data expansion.
class StaticRouteManifest {
  StaticRouteManifest({List<StaticPageRoute>? initialRoutes}) {
    if (initialRoutes != null) {
      _routes.addAll(initialRoutes);
    }
  }

  final List<StaticPageRoute> _routes = [];

  /// All registered static routes.
  List<StaticPageRoute> get routes => List.unmodifiable(_routes);

  /// Registers a static route.
  void register(StaticPageRoute route) {
    _routes.add(route);
  }

  /// Registers an expanded set of routes from a dynamic data list.
  void registerDynamic<T>({
    required String pathPattern,
    required Iterable<T> items,
    required String Function(T item) slugExtractor,
    required WebMetadata Function(T item) metadataBuilder,
    MantleComponent Function(T item, MantleContext context)? componentBuilder,
  }) {
    for (final item in items) {
      final slug = slugExtractor(item);
      final path = pathPattern.replaceAll(RegExp(r':[^/]+'), slug);
      final metadata = metadataBuilder(item);

      _routes.add(
        StaticPageRoute(
          path: path,
          metadata: metadata,
          componentBuilder: componentBuilder != null
              ? (ctx) => componentBuilder(item, ctx)
              : null,
        ),
      );
    }
  }

  /// Clears all routes.
  void clear() => _routes.clear();
}
