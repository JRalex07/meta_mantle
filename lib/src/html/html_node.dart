import 'dart:convert';
import 'html_sanitizer.dart';

/// Base class for all HTML DOM nodes rendered by MetaMantle SSR.
abstract class HtmlNode {
  const HtmlNode();

  /// Renders this node to safe HTML string.
  String toHtml();
}

/// A node representing escaped plain text.
class TextNode extends HtmlNode {
  const TextNode(this.text);

  final String text;

  @override
  String toHtml() => const HtmlEscape(HtmlEscapeMode.element).convert(text);
}

/// A node representing explicitly validated or sanitized raw HTML markup.
class RawSafeHtmlNode extends HtmlNode {
  const RawSafeHtmlNode._(this.html);

  /// Creates a safe HTML node from pre-sanitized or explicitly trusted markup.
  factory RawSafeHtmlNode.trusted(String html) => RawSafeHtmlNode._(html);

  /// Creates a safe HTML node by running untrusted HTML through [HtmlSanitizer].
  factory RawSafeHtmlNode.sanitize(
    String untrustedHtml, {
    HtmlSanitizer sanitizer = const HtmlSanitizer(),
  }) {
    return RawSafeHtmlNode._(sanitizer.sanitize(untrustedHtml));
  }

  final String html;

  @override
  String toHtml() => html;
}

/// A semantic HTML element node with attributes and child nodes.
class ElementNode extends HtmlNode {
  const ElementNode(
    this.tag, {
    this.attributes = const {},
    this.children = const [],
    this.isSelfClosing = false,
  });

  final String tag;
  final Map<String, String?> attributes;
  final List<HtmlNode> children;
  final bool isSelfClosing;

  @override
  String toHtml() {
    final buf = StringBuffer('<$tag');
    for (final entry in attributes.entries) {
      if (entry.value != null) {
        final escapedVal =
            const HtmlEscape(HtmlEscapeMode.attribute).convert(entry.value!);
        buf.write(' ${entry.key}="$escapedVal"');
      }
    }

    if (isSelfClosing) {
      buf.write(' />');
      return buf.toString();
    }

    buf.write('>');
    for (final child in children) {
      buf.write(child.toHtml());
    }
    buf.write('</$tag>');
    return buf.toString();
  }
}

/// Factory functions for common semantic HTML tags.
class H {
  const H._();

  static ElementNode tag(
    String name, {
    Map<String, String?> attributes = const {},
    List<HtmlNode> children = const [],
    bool isSelfClosing = false,
  }) =>
      ElementNode(
        name,
        attributes: attributes,
        children: children,
        isSelfClosing: isSelfClosing,
      );

  static TextNode text(String text) => TextNode(text);

  static RawSafeHtmlNode raw(String trustedHtml) =>
      RawSafeHtmlNode.trusted(trustedHtml);

  static RawSafeHtmlNode sanitize(String untrustedHtml) =>
      RawSafeHtmlNode.sanitize(untrustedHtml);

  static ElementNode h1(String text, {Map<String, String?> attrs = const {}}) =>
      ElementNode('h1', attributes: attrs, children: [TextNode(text)]);

  static ElementNode h2(String text, {Map<String, String?> attrs = const {}}) =>
      ElementNode('h2', attributes: attrs, children: [TextNode(text)]);

  static ElementNode h3(String text, {Map<String, String?> attrs = const {}}) =>
      ElementNode('h3', attributes: attrs, children: [TextNode(text)]);

  static ElementNode p(String text, {Map<String, String?> attrs = const {}}) =>
      ElementNode('p', attributes: attrs, children: [TextNode(text)]);

  static ElementNode pNodes(
    List<HtmlNode> children, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('p', attributes: attrs, children: children);

  static ElementNode a(
    String href,
    String text, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('a',
          attributes: {'href': href, ...attrs}, children: [TextNode(text)]);

  static ElementNode img(
    String src, {
    required String alt,
    int? width,
    int? height,
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode(
        'img',
        attributes: {
          'src': src,
          'alt': alt,
          if (width != null) 'width': '$width',
          if (height != null) 'height': '$height',
          ...attrs,
        },
        isSelfClosing: true,
      );

  static ElementNode div(
    List<HtmlNode> children, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('div', attributes: attrs, children: children);

  static ElementNode span(String text,
          {Map<String, String?> attrs = const {}}) =>
      ElementNode('span', attributes: attrs, children: [TextNode(text)]);

  static ElementNode header(
    List<HtmlNode> children, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('header', attributes: attrs, children: children);

  static ElementNode footer(
    List<HtmlNode> children, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('footer', attributes: attrs, children: children);

  static ElementNode nav(
    List<HtmlNode> children, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('nav', attributes: attrs, children: children);

  static ElementNode main(
    List<HtmlNode> children, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('main', attributes: attrs, children: children);

  static ElementNode article(
    List<HtmlNode> children, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('article', attributes: attrs, children: children);

  static ElementNode section(
    List<HtmlNode> children, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('section', attributes: attrs, children: children);

  static ElementNode ul(
    List<ElementNode> items, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('ul', attributes: attrs, children: items);

  static ElementNode ol(
    List<ElementNode> items, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('ol', attributes: attrs, children: items);

  static ElementNode li(String text, {Map<String, String?> attrs = const {}}) =>
      ElementNode('li', attributes: attrs, children: [TextNode(text)]);

  static ElementNode liNodes(
    List<HtmlNode> children, {
    Map<String, String?> attrs = const {},
  }) =>
      ElementNode('li', attributes: attrs, children: children);

  static ElementNode table({
    List<String>? headers,
    required List<List<String>> rows,
    Map<String, String?> attrs = const {},
  }) {
    final children = <HtmlNode>[];
    if (headers != null && headers.isNotEmpty) {
      children.add(ElementNode('thead', children: [
        ElementNode('tr',
            children: headers
                .map((h) => ElementNode('th', children: [TextNode(h)]))
                .toList()),
      ]));
    }
    children.add(ElementNode('tbody',
        children: rows
            .map((row) => ElementNode('tr',
                children: row
                    .map(
                        (cell) => ElementNode('td', children: [TextNode(cell)]))
                    .toList()))
            .toList()));
    return ElementNode('table', attributes: attrs, children: children);
  }
}
