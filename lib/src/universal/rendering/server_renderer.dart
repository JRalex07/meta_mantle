import '../../core/head_tag.dart';
import '../../html/html_document.dart';
import '../../html/html_node.dart';
import '../../models/metadata.dart';
import '../ir/mantle_node.dart';
import 'renderer_contract.dart';

/// Server-side semantic HTML renderer for [MantleNode] trees.
/// Produces standard, accessible HTML markup with zero client-side framework overhead.
class MantleServerRenderer implements MantleRenderer<HtmlNode> {
  const MantleServerRenderer({this.emitHydrationMarkers = true});

  final bool emitHydrationMarkers;

  @override
  HtmlNode render(MantleNode node) {
    return node
        .accept(_ServerVisitor(emitHydrationMarkers: emitHydrationMarkers));
  }

  /// Renders a [MantleNode] tree into a complete standalone HTML document with [metadata].
  String renderDocument(
    MantleNode node, {
    WebMetadata? metadata,
    String? currentUrl,
    List<String> scriptUrls = const [],
    List<String> stylesheetUrls = const [],
  }) {
    final bodyNode = render(node);
    final customTags = <HeadTag>[
      for (final s in stylesheetUrls)
        HeadTag(
          key: 'css-$s',
          tagName: 'link',
          attributes: {'rel': 'stylesheet', 'href': s},
        ),
      for (final s in scriptUrls)
        HeadTag(
          key: 'js-$s',
          tagName: 'script',
          attributes: {'src': s},
        ),
    ];

    final doc = HtmlDocument(
      metadata: metadata ?? const WebMetadata(),
      bodyNodes: [bodyNode],
      customHeadTags: customTags,
    );
    return doc.render(currentUrl: currentUrl);
  }
}

class _ServerVisitor implements MantleNodeVisitor<HtmlNode> {
  const _ServerVisitor({this.emitHydrationMarkers = true});

  final bool emitHydrationMarkers;

  @override
  HtmlNode visitElement(MantleElementNode node) {
    final attributes = <String, String?>{...node.attributes};

    if (node.id != null) attributes['id'] = node.id!;
    if (node.classes.isNotEmpty) {
      attributes['class'] = node.classes.join(' ');
    }

    if (emitHydrationMarkers) {
      attributes['data-mantle-node'] = node.tag;
      if (node.key != null) {
        attributes['data-mantle-key'] = node.key.toString();
      }
      if (node.events.isNotEmpty) {
        attributes['data-mantle-interactive'] = 'true';
      }
    }

    if (node.styles.isNotEmpty) {
      final styleBuffer = StringBuffer();
      for (final entry in node.styles.entries) {
        styleBuffer.write('${entry.key}: ${entry.value}; ');
      }
      attributes['style'] = styleBuffer.toString().trim();
    }

    // Determine self-closing tags
    final isSelfClosing = const {'img', 'input', 'hr', 'br'}.contains(node.tag);

    return ElementNode(
      node.tag,
      attributes: attributes,
      children: node.children.map((child) => child.accept(this)).toList(),
      isSelfClosing: isSelfClosing,
    );
  }

  @override
  HtmlNode visitText(MantleTextNode node) {
    if (node.style != null && node.style!.toCssProperties().isNotEmpty) {
      final styleBuffer = StringBuffer();
      for (final entry in node.style!.toCssProperties().entries) {
        styleBuffer.write('${entry.key}: ${entry.value}; ');
      }
      return ElementNode(
        node.tag,
        attributes: {'style': styleBuffer.toString().trim()},
        children: [TextNode(node.text)],
      );
    }
    return TextNode(node.text);
  }

  @override
  HtmlNode visitFragment(MantleFragment node) {
    return ElementNode(
      'div',
      attributes: const {'class': 'mantle-fragment'},
      children: node.children.map((child) => child.accept(this)).toList(),
    );
  }
}
