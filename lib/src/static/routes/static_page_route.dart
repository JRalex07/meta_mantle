import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/metadata.dart';
import '../../universal/components/mantle_component.dart';
import '../../universal/rendering/server_renderer.dart';
import '../../universal/routing/mantle_route.dart';

typedef StaticComponentBuilder = MantleComponent Function(
  MantleContext context,
);

/// Represents a route with associated SEO metadata, component tree, and static HTML content.
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

  /// Copies this route with optional overrides.
  StaticPageRoute copyWith({
    String? path,
    WebMetadata? metadata,
    MantleComponent? component,
    StaticComponentBuilder? componentBuilder,
    String? htmlContent,
    Object? dataSource,
  }) {
    return StaticPageRoute(
      path: path ?? this.path,
      metadata: metadata ?? this.metadata,
      component: component ?? this.component,
      componentBuilder: componentBuilder ?? this.componentBuilder,
      htmlContent: htmlContent ?? this.htmlContent,
      dataSource: dataSource ?? this.dataSource,
    );
  }

  /// Serializes this route to JSON for inter-process communication.
  Map<String, Object?> toJson() {
    return {
      'path': path,
      'metadata': metadata.toJson(),
      if (htmlContent != null) 'htmlContent': htmlContent,
      if (dataSource is Map)
        'dataSource': dataSource
      else if (dataSource != null)
        'dataSource': dataSource.toString(),
    };
  }

  /// Deserializes a route from JSON.
  factory StaticPageRoute.fromJson(Map<String, Object?> json) {
    final metaJson = json['metadata'];
    return StaticPageRoute(
      path: json['path'] as String,
      metadata: metaJson is Map
          ? WebMetadata.fromJson(Map<String, Object?>.from(metaJson))
          : const WebMetadata(),
      htmlContent: json['htmlContent'] as String?,
      dataSource: json['dataSource'],
    );
  }

  @override
  String toString() => 'StaticPageRoute(path: $path, title: ${metadata.title})';
}

/// Alias for [StaticPageRoute] for ergonomic route definitions.
typedef StaticRoute = StaticPageRoute;

/// Contract for objects that can resolve dynamic route patterns into concrete static routes.
abstract class StaticPatternResolver {
  FutureOr<List<StaticPageRoute>> resolve([MantleContext? context]);
}

/// Dynamic pattern expanding parameterized paths (e.g. `/products/:slug`)
/// from in-memory collections, async data loaders, or JSON data files.
class StaticRoutePattern<T> implements StaticPatternResolver {
  const StaticRoutePattern({
    String? path,
    String? pathPattern,
    this.items,
    this.dataFile,
    this.metadataTemplate,
    this.slugExtractor,
    this.slugField = 'slug',
    this.componentBuilder,
    this.metadataBuilder,
  }) : path = path ?? pathPattern ?? '';

  final String path;

  /// Backward-compatible alias for [path].
  String get pathPattern => path;

  final dynamic items;
  final String? dataFile;
  final Map<String, Object?>? metadataTemplate;
  final String Function(T item)? slugExtractor;
  final String slugField;
  final MantleComponent Function(T item, MantleContext context)?
  componentBuilder;
  final WebMetadata Function(T item)? metadataBuilder;

  factory StaticRoutePattern.fromJson(Map<String, Object?> json) {
    final template = json['metadataTemplate'];
    if (template is! Map) {
      throw FormatException(
        'Pattern ${json['pathPattern'] ?? json['path']} needs metadataTemplate.',
      );
    }
    return StaticRoutePattern(
      path: (json['pathPattern'] ?? json['path']) as String,
      dataFile: json['dataFile'] as String?,
      slugField: json['slugField'] as String? ?? 'slug',
      metadataTemplate: Map<String, Object?>.from(template),
    );
  }

  @override
  Future<List<StaticPageRoute>> resolve([MantleContext? context]) async {
    // 1. If explicit items/data source provided
    if (items != null) {
      Iterable<T> resolvedItems;
      if (items is Future<Iterable<T>>) {
        resolvedItems = await (items as Future<Iterable<T>>);
      } else if (items is Future<dynamic>) {
        final dyn = await (items as Future<dynamic>);
        resolvedItems = (dyn is Iterable) ? dyn.cast<T>() : <T>[];
      } else if (items is Iterable<T>) {
        resolvedItems = items as Iterable<T>;
      } else if (items is Iterable) {
        resolvedItems = (items as Iterable).cast<T>();
      } else if (items is Function) {
        final res = (items as Function)();
        if (res is Future) {
          final awaited = await res;
          resolvedItems = (awaited is Iterable) ? awaited.cast<T>() : <T>[];
        } else if (res is Iterable) {
          resolvedItems = res.cast<T>();
        } else {
          resolvedItems = const [];
        }
      } else {
        resolvedItems = const [];
      }

      final routes = <StaticPageRoute>[];
      for (final item in resolvedItems) {
        String slug;
        if (slugExtractor != null) {
          slug = slugExtractor!(item);
        } else if (item is Map) {
          slug = (item[slugField] ?? '').toString();
        } else {
          slug = item.toString();
        }

        if (slug.trim().isEmpty) continue;

        final concretePath = path.replaceAll(RegExp(r':[^/]+'), slug.trim());
        final metadata = metadataBuilder?.call(item) ?? const WebMetadata();

        routes.add(
          StaticPageRoute(
            path: concretePath,
            metadata: metadata,
            dataSource: item,
            componentBuilder: componentBuilder != null
                ? (ctx) => componentBuilder!(item, ctx)
                : null,
          ),
        );
      }
      return routes;
    }

    // 2. If dataFile provided for JSON file resolution
    if (dataFile != null) {
      final file = File(dataFile!);
      if (!await file.exists()) {
        return const [];
      }
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) {
        return const [];
      }

      final routes = <StaticPageRoute>[];
      for (final rawItem in raw) {
        if (rawItem is! Map) continue;
        final map = Map<String, Object?>.from(rawItem);
        final slug = map[slugField]?.toString() ?? '';
        if (slug.trim().isEmpty) continue;

        final concretePath = path.replaceAll(RegExp(r':[^/]+'), slug.trim());
        final metadata = metadataTemplate != null
            ? _applyTemplate(metadataTemplate!, map)
            : const WebMetadata();

        routes.add(
          StaticPageRoute(
            path: concretePath,
            metadata: metadata,
            dataSource: map,
          ),
        );
      }
      return routes;
    }

    return const [];
  }

  static WebMetadata _applyTemplate(
    Map<String, Object?> template,
    Map<String, Object?> data,
  ) {
    Object? replaceTokens(Object? input) {
      if (input is String) {
        return input.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) {
          final key = m[1]!;
          return data[key]?.toString() ?? '';
        });
      }
      if (input is Map) {
        return input.map((k, v) => MapEntry(k.toString(), replaceTokens(v)));
      }
      if (input is List) {
        return input.map(replaceTokens).toList();
      }
      return input;
    }

    final hydrated = replaceTokens(template) as Map<String, Object?>;
    return WebMetadata.fromJson(hydrated);
  }
}

/// Registry and resolver for statically buildable routes and dynamic data expansion.
class StaticRouteManifest {
  StaticRouteManifest({
    List<StaticPageRoute>? routes,
    List<StaticPageRoute>? initialRoutes,
    List<StaticPatternResolver>? patterns,
  }) {
    if (routes != null) {
      for (final r in routes) {
        register(r);
      }
    } else if (initialRoutes != null) {
      for (final r in initialRoutes) {
        register(r);
      }
    }
    if (patterns != null) {
      for (final p in patterns) {
        registerPattern(p);
      }
    }
  }

  final List<StaticPageRoute> _routes = [];
  final List<StaticPatternResolver> _patterns = [];

  /// All registered concrete static routes.
  List<StaticPageRoute> get routes => List.unmodifiable(_routes);

  /// All registered dynamic route patterns.
  List<StaticPatternResolver> get patterns => List.unmodifiable(_patterns);

  /// Registers a concrete static route.
  /// If a route with the same normalized path exists, it is replaced deterministically.
  void register(StaticPageRoute route) {
    final norm = _normalizePath(route.path);
    final idx = _routes.indexWhere((r) => _normalizePath(r.path) == norm);
    if (idx >= 0) {
      _routes[idx] = route;
    } else {
      _routes.add(route);
    }
  }

  /// Registers a dynamic route pattern resolver.
  void registerPattern(StaticPatternResolver pattern) {
    _patterns.add(pattern);
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
      final concretePath = pathPattern.replaceAll(
        RegExp(r':[^/]+'),
        slug.trim(),
      );
      final metadata = metadataBuilder(item);

      register(
        StaticPageRoute(
          path: concretePath,
          metadata: metadata,
          dataSource: item,
          componentBuilder: componentBuilder != null
              ? (ctx) => componentBuilder(item, ctx)
              : null,
        ),
      );
    }
  }

  /// Resolves all registered static routes, expanding all dynamic patterns.
  /// Routes are returned in deterministic order: root `/` first, then alphabetically.
  Future<List<StaticPageRoute>> resolveAll([MantleContext? context]) async {
    final result = <StaticPageRoute>[..._routes];

    for (final pattern in _patterns) {
      final expanded = await pattern.resolve(context);
      for (final r in expanded) {
        final norm = _normalizePath(r.path);
        final idx = result.indexWhere(
          (existing) => _normalizePath(existing.path) == norm,
        );
        if (idx >= 0) {
          result[idx] = r;
        } else {
          result.add(r);
        }
      }
    }

    result.sort((a, b) {
      if (a.path == '/' || a.path == '') return -1;
      if (b.path == '/' || b.path == '') return 1;
      return a.path.compareTo(b.path);
    });

    return List.unmodifiable(result);
  }

  /// Clears all registered routes and patterns.
  void clear() {
    _routes.clear();
    _patterns.clear();
  }

  static String _normalizePath(String path) {
    if (path.isEmpty || path == '/') return '/';
    var p = path.trim();
    if (!p.startsWith('/')) p = '/$p';
    while (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}

/// Runner executed by consumer applications or CLI drivers to evaluate a manifest,
/// render all components to semantic HTML, and write a resolved manifest JSON.
Future<void> runStaticManifest(
  StaticRouteManifest manifest,
  List<String> args, {
  MantleServerRenderer serverRenderer = const MantleServerRenderer(
    emitHydrationMarkers: false,
  ),
}) async {
  final resolvedRoutes = await manifest.resolveAll();
  final routesData = <Map<String, Object?>>[];

  for (final route in resolvedRoutes) {
    final navContext = MantleNavigationContext(currentPath: route.path);
    String? semanticHtml = route.htmlContent;

    if (semanticHtml == null || semanticHtml.isEmpty) {
      final comp = route.resolveComponent(navContext);
      if (comp != null) {
        final node = comp.toNode(navContext);
        final htmlNode = serverRenderer.render(node);
        semanticHtml = htmlNode.toHtml();
      }
    }

    routesData.add({
      'path': route.path,
      'metadata': route.metadata.toJson(),
      if (semanticHtml != null) 'htmlContent': semanticHtml,
      if (route.dataSource is Map)
        'dataSource': route.dataSource
      else if (route.dataSource != null)
        'dataSource': route.dataSource.toString(),
    });
  }

  final outputJson = jsonEncode({
    'version': '0.2.0',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'routesCount': routesData.length,
    'routes': routesData,
  });

  if (args.isNotEmpty && args[0].isNotEmpty) {
    final file = File(args[0]);
    await file.parent.create(recursive: true);
    await file.writeAsString(outputJson, flush: true);
  } else {
    stdout.writeln(outputJson);
  }
}
