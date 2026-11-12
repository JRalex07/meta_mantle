import '../cache/cache_store.dart';
import '../content/frontmatter_extractor.dart';
import '../core/head_tag.dart';
import '../core/metadata_renderer.dart';
import '../html/html_node.dart';
import '../models/metadata.dart';
import '../providers/data_provider.dart';
import '../server/meta_route.dart';
import '../server/server_request.dart';
import '../server/server_response.dart';

/// Structured component descriptor representing a Jaspr head element.
class JasprTagDescriptor {
  const JasprTagDescriptor({
    required this.tag,
    required this.attributes,
    this.textContent,
  });

  final String tag;
  final Map<String, String> attributes;
  final String? textContent;

  /// Renders this descriptor to HTML string.
  String toHtml() {
    if (tag == 'title') {
      return '<title>${textContent ?? ''}</title>';
    }
    if (tag == 'script') {
      final attrStr = attributes.entries
          .map((e) => ' ${e.key}="${e.value}"')
          .join();
      return '<script$attrStr>${textContent ?? ''}</script>';
    }
    final attrStr = attributes.entries
        .map((e) => ' ${e.key}="${e.value}"')
        .join();
    return '<$tag$attrStr />';
  }
}

/// Renders MetaMantle metadata into Jaspr head element descriptors.
class MetaMantleHead {
  const MetaMantleHead({
    required this.metadata,
    this.config = const MetaMantleConfig(),
    this.renderer = const MetadataRenderer(),
  });

  final WebMetadata metadata;
  final MetaMantleConfig config;
  final MetadataRenderer renderer;

  /// Generates the list of rendered [HeadTag] elements suitable for Jaspr's head tree.
  List<HeadTag> renderHeadTags({String? currentUrl}) {
    return renderer.render(metadata, config: config, currentUrl: currentUrl);
  }

  /// Maps rendered head tags into typed [JasprTagDescriptor] instances for Jaspr component trees.
  List<JasprTagDescriptor> renderDescriptors({String? currentUrl}) {
    final tags = renderHeadTags(currentUrl: currentUrl);
    return tags.map((t) {
      return JasprTagDescriptor(
        tag: t.tagName,
        attributes: t.attributes,
        textContent: t.textContent,
      );
    }).toList();
  }

  /// Emits the raw HTML tags for direct embedding inside Jaspr HTML templates.
  String toHtmlString({String? currentUrl}) {
    final tags = renderer.render(
      metadata,
      config: config,
      currentUrl: currentUrl,
    );
    return tags.map((t) => t.toHtml()).join('\n');
  }
}

/// Provides ambient MetaMantle metadata and route context down Jaspr component trees.
class MetaMantleJasprProvider {
  const MetaMantleJasprProvider({
    required this.metadata,
    required this.context,
  });

  final WebMetadata metadata;
  final RouteDataContext context;
}

/// Full Jaspr-compatible document shell renderer with server-side SEO metadata injection.
class MetaMantleDocument {
  const MetaMantleDocument({
    required this.metadata,
    this.config = const MetaMantleConfig(),
    this.includeFlutterBootstrap = false,
    this.lang = 'en',
  });

  final WebMetadata metadata;
  final MetaMantleConfig config;
  final bool includeFlutterBootstrap;
  final String lang;

  /// Renders a complete HTML5 document shell with Jaspr root container.
  String renderDocumentShell({required String bodyHtml, String? currentUrl}) {
    final headHtml = MetaMantleHead(
      metadata: metadata,
      config: config,
    ).toHtmlString(currentUrl: currentUrl);

    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="$lang">');
    buf.writeln('<head>');
    buf.writeln(headHtml);
    buf.writeln('</head>');
    buf.writeln('<body>');
    buf.writeln('<div id="jaspr-root">');
    buf.writeln(bodyHtml);
    buf.writeln('</div>');
    if (includeFlutterBootstrap) {
      buf.writeln('<script src="flutter_bootstrap.js" async></script>');
    }
    buf.writeln('</body>');
    buf.writeln('</html>');
    return buf.toString();
  }
}

/// Route adapter connecting MetaMantle `MetaRoute<T>` to Jaspr SSR request handling.
class MetaMantleRouteAdapter<T> {
  const MetaMantleRouteAdapter(this.route);

  final MetaRoute<T> route;

  /// Resolves data and renders complete Jaspr SSR document for a given request path.
  Future<ServerResponse> handleJasprRequest(ServerRequest request) async {
    final params = route.match(request.path);
    if (params == null) {
      return ServerResponse.notFound();
    }

    final context = RouteDataContext(
      path: request.path,
      parameters: params,
      queryParameters: request.queryParameters,
      headers: request.headers,
    );

    final result = await route.dataProvider.load(context);
    if (result.isDeleted) {
      return ServerResponse.gone();
    }
    if (!result.isFound || result.data == null) {
      return ServerResponse.notFound();
    }

    final metadata = route.buildMetadata(result.data, context);
    final nodes = route.buildHtml(result.data, context);
    final bodyHtml = nodes.map((n) => n.toHtml()).join('\n');

    final doc = MetaMantleDocument(
      metadata: metadata,
      includeFlutterBootstrap: route.includeFlutterBootstrap,
    );

    final fullHtml = doc.renderDocumentShell(
      bodyHtml: bodyHtml,
      currentUrl: request.path,
    );

    return ServerResponse.okHtml(fullHtml);
  }
}

/// Component adapter loading data from [MetaMantleDataProvider] before rendering.
class MetaMantleDataComponent<T> {
  const MetaMantleDataComponent({
    required this.dataProvider,
    required this.builder,
    this.loadingPlaceholder,
    this.errorPlaceholder,
  });

  final MetaMantleDataProvider<T> dataProvider;
  final List<HtmlNode> Function(T data, RouteDataContext context) builder;
  final List<HtmlNode>? loadingPlaceholder;
  final List<HtmlNode>? errorPlaceholder;

  Future<List<HtmlNode>> loadAndBuild(RouteDataContext context) async {
    try {
      final res = await dataProvider.load(context);
      if (res.isFound && res.data != null) {
        return builder(res.data as T, context);
      }
      return errorPlaceholder ?? [H.p('Content not found.')];
    } catch (_) {
      return errorPlaceholder ?? [H.p('Failed to load content.')];
    }
  }
}

/// Cache adapter bridging Jaspr SSR responses to MetaMantle [MetaMantleCacheStore].
class MetaMantleCacheAdapter {
  const MetaMantleCacheAdapter(this.cacheStore);

  final MetaMantleCacheStore cacheStore;

  Future<CacheEntry?> getCachedPage(String key) => cacheStore.get(key);

  Future<void> cachePage(String key, CacheEntry entry) =>
      cacheStore.put(key, entry);

  Future<void> invalidateTags(List<String> tags) =>
      cacheStore.deleteByTags(tags);
}

/// Content adapter reading Markdown frontmatter and generating Jaspr/MetaMantle metadata.
class MetaMantleContentAdapter {
  const MetaMantleContentAdapter({
    this.extractor = const FrontmatterExtractor(),
  });

  final FrontmatterExtractor extractor;

  /// Extracts document metadata from a markdown string for documentation and blog sites.
  WebMetadata extractMetadata({
    required String markdownContent,
    String? fallbackTitle,
    String? fallbackCanonical,
  }) {
    final parsed = extractor.parse(markdownContent);
    final title = parsed.title ?? fallbackTitle;
    final description = parsed.description;
    final canonical = parsed.canonical ?? fallbackCanonical;

    return WebMetadata(
      title: title,
      description: description,
      canonical: canonical,
      author: parsed.author,
      keywords: parsed.tags,
      openGraph: OpenGraph(
        title: title,
        description: description,
        image: parsed.image,
      ),
      twitter: TwitterCard(
        title: title,
        description: description,
        image: parsed.image,
      ),
    );
  }
}
