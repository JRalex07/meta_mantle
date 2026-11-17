import '../core/head_tag.dart';
import '../core/metadata_renderer.dart';
import '../models/metadata.dart';
import 'html_node.dart';

/// Renders a complete, valid, SEO-ready semantic HTML5 document.
class HtmlDocument {
  const HtmlDocument({
    required this.metadata,
    this.config = const MetaMantleConfig(),
    this.bodyNodes = const [],
    this.includeFlutterBootstrap = false,
    this.flutterBootstrapSrc = 'flutter_bootstrap.js',
    this.customHeadTags = const [],
    this.baseHref = '/',
  });

  final WebMetadata metadata;
  final MetaMantleConfig config;
  final List<HtmlNode> bodyNodes;
  final bool includeFlutterBootstrap;
  final String flutterBootstrapSrc;
  final List<HeadTag> customHeadTags;
  final String baseHref;

  /// Renders the complete HTML5 document to string.
  String render({String? currentUrl}) {
    const renderer = MetadataRenderer();
    final headTags = [
      ...renderer.render(metadata, config: config, currentUrl: currentUrl),
      ...customHeadTags,
    ];

    final lang = _escapeAttr(metadata.language ?? config.language ?? 'en');
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="$lang">');
    buf.writeln('<head>');
    buf.writeln('  <meta charset="UTF-8">');
    buf.writeln(
      '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',
    );

    final hasCustomBase = headTags.any(
      (t) => t.tagName.toLowerCase() == 'base',
    );
    if (!hasCustomBase && baseHref.isNotEmpty) {
      buf.writeln('  <base href="${_escapeAttr(baseHref)}">');
    }

    // Render title first if present
    for (final tag in headTags) {
      if (tag.tagName.toLowerCase() == 'title') {
        buf.writeln('  <title>${_escape(tag.textContent ?? '')}</title>');
        break;
      }
    }

    const voidTags = {'meta', 'link', 'base'};

    // Render other head tags
    for (final tag in headTags) {
      final lowerTag = tag.tagName.toLowerCase();
      if (lowerTag == 'title' ||
          lowerTag == 'html' ||
          lowerTag == 'head' ||
          lowerTag == 'body') {
        continue; // handled at document structure level
      }

      final attrBuf = StringBuffer();
      for (final attr in tag.attributes.entries) {
        attrBuf.write(' ${attr.key}="${_escapeAttr(attr.value)}"');
      }

      if (voidTags.contains(lowerTag)) {
        buf.writeln('  <$lowerTag$attrBuf>');
      } else if (lowerTag == 'script') {
        final rawContent = tag.textContent ?? '';
        final safeContent = rawContent.replaceAll(
          RegExp(r'</script', caseSensitive: false),
          r'<\/script',
        );
        buf.writeln('  <script$attrBuf>$safeContent</script>');
      } else {
        buf.writeln(
          '  <$lowerTag$attrBuf>${_escape(tag.textContent ?? '')}</$lowerTag>',
        );
      }
    }

    buf.writeln('</head>');
    buf.writeln('<body>');

    // Render semantic body content
    if (bodyNodes.isNotEmpty) {
      for (final node in bodyNodes) {
        buf.writeln(node.toHtml());
      }
    }

    // Optionally include progressive Flutter Web enhancement bootstrap
    if (includeFlutterBootstrap) {
      buf.writeln('  <script src="$flutterBootstrapSrc" async></script>');
    }

    buf.writeln('</body>');
    buf.writeln('</html>');
    return buf.toString();
  }

  static String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _escapeAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
