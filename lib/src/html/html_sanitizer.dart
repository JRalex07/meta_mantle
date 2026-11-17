import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'url_policy.dart';

/// Allowlist-based HTML sanitizer for rich text content.
///
/// Strips executable elements (`script`, `iframe`, `object`, `embed`), event
/// handlers (`onload`, `onclick`), and unsafe URL schemes (`javascript:`, `data:`).
class HtmlSanitizer {
  const HtmlSanitizer({
    this.allowedTags = defaultAllowedTags,
    this.allowedAttributes = defaultAllowedAttributes,
    this.allowedSchemes = defaultAllowedSchemes,
    this.allowProtocolRelative = false,
  });

  /// Default safe tags permitted for semantic rich text.
  static const Set<String> defaultAllowedTags = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'span',
    'strong',
    'em',
    'b',
    'i',
    'u',
    's',
    'ul',
    'ol',
    'li',
    'blockquote',
    'pre',
    'code',
    'a',
    'img',
    'table',
    'thead',
    'tbody',
    'tr',
    'th',
    'td',
    'br',
    'hr',
    'article',
    'section',
    'nav',
    'header',
    'footer',
    'main',
    'figure',
    'figcaption',
    'time',
    'div',
    'button',
    'label',
    'input',
    'aside',
    'mark',
    'small',
    'sub',
    'sup',
    'details',
    'summary',
    'abbr',
  };

  /// Default safe attributes allowed on elements.
  static const Set<String> defaultAllowedAttributes = {
    'href',
    'src',
    'alt',
    'title',
    'width',
    'height',
    'class',
    'id',
    'target',
    'rel',
    'aria-label',
    'aria-hidden',
    'aria-describedby',
    'role',
    'datetime',
  };

  /// Permitted URL schemes for links and images.
  static const Set<String> defaultAllowedSchemes = {
    'http',
    'https',
    'mailto',
    'tel',
  };

  final Set<String> allowedTags;
  final Set<String> allowedAttributes;
  final Set<String> allowedSchemes;
  final bool allowProtocolRelative;

  /// Sanitizes [rawHtml] and returns safe HTML markup.
  String sanitize(String rawHtml) {
    if (rawHtml.trim().isEmpty) return '';

    final fragment = html_parser.parseFragment(rawHtml);
    _cleanNode(fragment);
    return fragment.outerHtml;
  }

  void _cleanNode(dom.Node node) {
    final children = List<dom.Node>.from(node.nodes);
    for (final child in children) {
      if (child is dom.Element) {
        final tagName = child.localName?.toLowerCase() ?? '';
        if (!allowedTags.contains(tagName)) {
          // If tag is not allowed, remove the node or replace with text if safe
          child.remove();
          continue;
        }

        // Clean attributes
        final attrs = Map<dynamic, String>.from(child.attributes);
        for (final entry in attrs.entries) {
          final attrKey = entry.key.toString().toLowerCase();
          final attrVal = entry.value;

          // Strip event handlers (e.g. onclick, onload, onmouseover)
          if (attrKey.startsWith('on')) {
            child.attributes.remove(entry.key);
            continue;
          }

          // Allow standard attributes or safe aria-* / data-* attributes
          final isAria =
              attrKey.startsWith('aria-') &&
              RegExp(r'^aria-[a-z0-9_-]+$').hasMatch(attrKey);
          final isData =
              attrKey.startsWith('data-') &&
              RegExp(r'^data-[a-z0-9_-]+$').hasMatch(attrKey);
          if (!allowedAttributes.contains(attrKey) && !isAria && !isData) {
            child.attributes.remove(entry.key);
            continue;
          }

          // Validate URL schemes for href, src, and action
          if (attrKey == 'href' || attrKey == 'src' || attrKey == 'action') {
            if (!isValidUrl(attrVal)) {
              child.attributes.remove(entry.key);
              continue;
            }
          }
        }

        // Enforce rel="noopener noreferrer" on external links with target="_blank"
        if (tagName == 'a' && child.attributes['target'] == '_blank') {
          child.attributes['rel'] = 'noopener noreferrer';
        }

        // Recurse into children
        _cleanNode(child);
      }
    }
  }

  bool isValidUrl(String url) {
    return UrlPolicy.isSafe(url);
  }
}
