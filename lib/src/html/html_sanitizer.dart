import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'url_policy.dart';

/// Allowlist-based HTML sanitizer for rich text content.
///
/// Strips executable elements (`script`, `iframe`, `object`, `embed`), event
/// handlers (`onload`, `onclick`), and unsafe URL schemes (`javascript:`, `data:`).
///
/// ### Security Considerations
/// - **Dangerous schemes:** Schemes such as `javascript:`, `data:`, `vbscript:`,
///   `blob:`, and `file:` are categorically prohibited and cannot be allowlisted.
///   Attempting to pass them in [allowedSchemes] throws an [ArgumentError].
/// - **Protocol-relative URLs:** By default, [allowProtocolRelative] is `false` to
///   prevent protocol-hijacking attacks. Enabling this option should only be done
///   when integrating with legacy CDN infrastructures.
/// - **Executable elements:** Tags like `<script>`, `<iframe>`, `<object>`, and `<embed>`
///   cannot be included in [allowedTags] and will throw an [ArgumentError].
/// - **Event handlers:** Attributes starting with `on*` (e.g. `onclick`) cannot be
///   included in [allowedAttributes] and will throw an [ArgumentError].
class HtmlSanitizer {
  factory HtmlSanitizer({
    Set<String> allowedTags = defaultAllowedTags,
    Set<String> allowedAttributes = defaultAllowedAttributes,
    Set<String> allowedSchemes = defaultAllowedSchemes,
    bool allowProtocolRelative = false,
  }) {
    _validateConfiguration(allowedTags, allowedAttributes, allowedSchemes);
    return HtmlSanitizer._(
      allowedTags: Set.unmodifiable(allowedTags.map((t) => t.toLowerCase())),
      allowedAttributes: Set.unmodifiable(
        allowedAttributes.map((a) => a.toLowerCase()),
      ),
      allowedSchemes: Set.unmodifiable(
        allowedSchemes.map((s) => s.toLowerCase()),
      ),
      allowProtocolRelative: allowProtocolRelative,
    );
  }

  const HtmlSanitizer._({
    this.allowedTags = defaultAllowedTags,
    this.allowedAttributes = defaultAllowedAttributes,
    this.allowedSchemes = defaultAllowedSchemes,
    this.allowProtocolRelative = false,
  });

  /// Compile-time constant sanitizer with default security settings.
  const HtmlSanitizer.defaults()
    : this._(
        allowedTags: defaultAllowedTags,
        allowedAttributes: defaultAllowedAttributes,
        allowedSchemes: defaultAllowedSchemes,
        allowProtocolRelative: false,
      );

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

  static void _validateConfiguration(
    Set<String> allowedTags,
    Set<String> allowedAttributes,
    Set<String> allowedSchemes,
  ) {
    for (final scheme in allowedSchemes) {
      final lowerScheme = scheme.toLowerCase();
      if (UrlPolicy.prohibitedSchemes.contains(lowerScheme)) {
        throw ArgumentError.value(
          scheme,
          'allowedSchemes',
          'Dangerous scheme "$scheme" is prohibited by security policy and cannot be allowlisted.',
        );
      }
      if (!UrlPolicy.isValidSchemeName(lowerScheme)) {
        throw ArgumentError.value(
          scheme,
          'allowedSchemes',
          'Invalid scheme format "$scheme". Scheme must start with a letter and contain only alphanumeric, "+", "-", or "." characters.',
        );
      }
    }

    for (final tag in allowedTags) {
      final lowerTag = tag.toLowerCase();
      if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9-]*$').hasMatch(lowerTag)) {
        throw ArgumentError.value(
          tag,
          'allowedTags',
          'Invalid tag name "$tag".',
        );
      }
      if (const {
        'script',
        'iframe',
        'object',
        'embed',
        'applet',
      }.contains(lowerTag)) {
        throw ArgumentError.value(
          tag,
          'allowedTags',
          'Potentially executable or sandbox-escaping tag "$tag" is prohibited in HtmlSanitizer.',
        );
      }
    }

    for (final attr in allowedAttributes) {
      final lowerAttr = attr.toLowerCase();
      if (!RegExp(r'^[a-zA-Z_:][a-zA-Z0-9_.:-]*$').hasMatch(lowerAttr)) {
        throw ArgumentError.value(
          attr,
          'allowedAttributes',
          'Invalid attribute name "$attr".',
        );
      }
      if (lowerAttr.startsWith('on')) {
        throw ArgumentError.value(
          attr,
          'allowedAttributes',
          'Event handler attribute "$attr" is prohibited in HtmlSanitizer.',
        );
      }
    }
  }

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

          // Validate URL schemes for href, src, action, formaction, poster, cite, and data
          if (attrKey == 'href' ||
              attrKey == 'src' ||
              attrKey == 'action' ||
              attrKey == 'formaction' ||
              attrKey == 'poster' ||
              attrKey == 'cite' ||
              attrKey == 'data') {
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

  /// Validates whether [url] complies with this sanitizer's URL policy.
  bool isValidUrl(String url) {
    return UrlPolicy.isSafe(
      url,
      allowedSchemes: allowedSchemes,
      allowProtocolRelative: allowProtocolRelative,
    );
  }
}
