import '../cache/cache_store.dart';
import '../html/html_node.dart';
import '../models/metadata.dart';
import '../providers/data_provider.dart';

/// Function signature for building page metadata from loaded data.
typedef RouteMetadataBuilder<T> = WebMetadata Function(
  T data,
  RouteDataContext context,
);

/// Function signature for building semantic body HTML nodes from loaded data.
typedef RouteHtmlBuilder<T> = List<HtmlNode> Function(
  T data,
  RouteDataContext context,
);

/// Typed definition of an SSR page route.
class MetaRoute<T> {
  MetaRoute({
    required this.pattern,
    required this.dataProvider,
    required this.metadataBuilder,
    required this.htmlBuilder,
    this.cachePolicy = const CachePolicy(),
    this.includeFlutterBootstrap = false,
  }) : _segments = _parseSegments(pattern);

  /// Path pattern (e.g. `/`, `/about`, `/products/:slug`).
  final String pattern;

  /// Underlying data provider.
  final MetaMantleDataProvider<T> dataProvider;

  /// Builds metadata from resolved data.
  final RouteMetadataBuilder<T> metadataBuilder;

  /// Builds semantic HTML nodes from resolved data.
  final RouteHtmlBuilder<T> htmlBuilder;

  /// Route-specific caching rules.
  final CachePolicy cachePolicy;

  /// Whether to embed the Flutter Web bootstrap script for progressive enhancement.
  final bool includeFlutterBootstrap;

  final List<String> _segments;

  /// Invokes [metadataBuilder] with typed casting to prevent generic variance errors.
  WebMetadata buildMetadata(dynamic data, RouteDataContext context) {
    return metadataBuilder(data as T, context);
  }

  /// Invokes [htmlBuilder] with typed casting to prevent generic variance errors.
  List<HtmlNode> buildHtml(dynamic data, RouteDataContext context) {
    return htmlBuilder(data as T, context);
  }

  /// Attempts to match [path] against this route's pattern.
  /// Returns a map of extracted parameters if matched, or `null` if no match.
  Map<String, String>? match(String path) {
    final cleanPath = path.replaceAll(RegExp(r'^/|/$'), '');
    final pathSegments = cleanPath.isEmpty ? <String>[] : cleanPath.split('/');

    if (pathSegments.length != _segments.length) {
      return null;
    }

    final params = <String, String>{};
    for (var i = 0; i < _segments.length; i++) {
      final patternSeg = _segments[i];
      final pathSeg = pathSegments[i];

      if (patternSeg.startsWith(':')) {
        final paramName = patternSeg.substring(1);
        params[paramName] = Uri.decodeComponent(pathSeg);
      } else if (patternSeg != pathSeg) {
        return null;
      }
    }

    return params;
  }

  static List<String> _parseSegments(String pattern) {
    final clean = pattern.replaceAll(RegExp(r'^/|/$'), '');
    return clean.isEmpty ? <String>[] : clean.split('/');
  }
}
