import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Allowlist-based HTML sanitizer for rich text content.
///
/// Strips executable elements (`script`, `iframe`, `object`, `embed`), event
/// handlers (`onload`, `onclick`), and unsafe URL schemes (`javascript:`, `data:`).
class HtmlSanitizer {
  const HtmlSanitizer({
    this.allowedTags = defaultAllowedTags,
    this.allowedAttributes = defaultAllowedAttributes,
    this.allowedSchemes = defaultAllowedSchemes,
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
  static const Set<String> defaultAllowedSchemes = {'http', 'https', 'mailto'};

  final Set<String> allowedTags;
  final Set<String> allowedAttributes;
  final Set<String> allowedSchemes;

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

          // Strip event handlers (e.g. onclick, onload)
          if (attrKey.startsWith('on') ||
              !allowedAttributes.contains(attrKey)) {
            child.attributes.remove(entry.key);
            continue;
          }

          // Validate URL schemes for href and src
          if (attrKey == 'href' || attrKey == 'src') {
            if (!_isValidUrl(attrVal)) {
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

  bool _isValidUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('/') || trimmed.startsWith('#')) return true;

    try {
      final uri = Uri.parse(trimmed);
      if (!uri.hasScheme) return true; // Relative URL
      return allowedSchemes.contains(uri.scheme.toLowerCase());
    } catch (_) {
      return false;
    }
  }
}
