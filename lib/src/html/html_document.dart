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

    final lang = metadata.language ?? config.language ?? 'en';
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="$lang">');
    buf.writeln('<head>');
    buf.writeln('  <meta charset="UTF-8">');
    buf.writeln(
      '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',
    );
    buf.writeln('  <base href="$baseHref">');

    // Render title first if present
    for (final tag in headTags) {
      if (tag.tagName == 'title') {
        buf.writeln('  <title>${_escape(tag.textContent ?? '')}</title>');
        break;
      }
    }

    // Render other head tags
    for (final tag in headTags) {
      if (tag.tagName == 'title') continue; // already emitted

      final attrBuf = StringBuffer();
      for (final attr in tag.attributes.entries) {
        attrBuf.write(' ${attr.key}="${_escapeAttr(attr.value)}"');
      }

      if (tag.textContent != null) {
        buf.writeln(
          '  <${tag.tagName}$attrBuf>${tag.textContent}</${tag.tagName}>',
        );
      } else {
        buf.writeln('  <${tag.tagName}$attrBuf>');
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

  String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  String _escapeAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
