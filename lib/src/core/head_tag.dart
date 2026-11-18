import '../html/url_policy.dart';

/// A normalized, platform-neutral representation of one head element.
class HeadTag {
  const HeadTag({
    required this.key,
    required this.tagName,
    this.attributes = const {},
    this.textContent,
    this.isTrustedContent = false,
  });

  /// Creates an explicitly trusted inline script head tag.
  factory HeadTag.trustedScript({
    required String key,
    Map<String, String> attributes = const {},
    String? content,
  }) => HeadTag(
    key: key,
    tagName: 'script',
    attributes: attributes,
    textContent: content,
    isTrustedContent: true,
  );

  /// Creates an explicitly trusted inline stylesheet head tag.
  factory HeadTag.trustedStyle({
    required String key,
    Map<String, String> attributes = const {},
    required String css,
  }) => HeadTag(
    key: key,
    tagName: 'style',
    attributes: attributes,
    textContent: css,
    isTrustedContent: true,
  );

  /// Creates a structured JSON-LD data script head tag.
  factory HeadTag.jsonLd({
    required String key,
    required String jsonLdContent,
  }) => HeadTag(
    key: key,
    tagName: 'script',
    attributes: const {'type': 'application/ld+json'},
    textContent: jsonLdContent,
    isTrustedContent: true,
  );

  static final RegExp _tagRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9-]*$');
  static final RegExp _attrKeyRegex = RegExp(r'^[a-zA-Z_:][a-zA-Z0-9_.:-]*$');
  static const Set<String> _voidHeadTags = {'meta', 'link', 'base'};

  /// Permitted HTML5 head elements. Elements like `<div>`, `<span>`, `<html>`, `<body>` are prohibited.
  static const Set<String> allowedHeadTags = {
    'title',
    'base',
    'link',
    'style',
    'meta',
    'script',
    'noscript',
    'template',
  };

  final String key;
  final String tagName;
  final Map<String, String> attributes;
  final String? textContent;
  final bool isTrustedContent;

  /// Serializes this head tag to an HTML string.
  String toHtml() {
    if (!_tagRegex.hasMatch(tagName)) {
      throw ArgumentError.value(tagName, 'tagName', 'Invalid head tag name');
    }
    final lowerTag = tagName.toLowerCase();
    if (!allowedHeadTags.contains(lowerTag)) {
      throw ArgumentError.value(
        tagName,
        'tagName',
        'Invalid head element "$tagName". Only HTML5 head elements '
            '(title, base, link, style, meta, script, noscript, template) are permitted in head tags.',
      );
    }
    for (final entry in attributes.entries) {
      if (!_attrKeyRegex.hasMatch(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'attribute',
          'Invalid attribute name',
        );
      }
      final lowerKey = entry.key.toLowerCase();
      if (lowerKey.startsWith('on')) {
        throw ArgumentError.value(
          entry.key,
          'attribute',
          'Event handler attributes (on*) are prohibited in head tags',
        );
      }
      if (lowerKey == 'href' ||
          lowerKey == 'src' ||
          lowerKey == 'action' ||
          lowerKey == 'formaction' ||
          lowerKey == 'cite' ||
          lowerKey == 'poster' ||
          lowerKey == 'data') {
        UrlPolicy.assertSafe(entry.value, entry.key);
      }
    }

    final attrs = attributes.entries
        .map((e) => '${e.key}="${_escapeAttr(e.value)}"')
        .join(' ');
    final attrString = attrs.isEmpty ? '' : ' $attrs';

    if (_voidHeadTags.contains(lowerTag)) {
      return '<$tagName$attrString>';
    }

    if (lowerTag == 'script') {
      final isJsonLd =
          attributes['type']?.toLowerCase() == 'application/ld+json';
      if (textContent != null && textContent!.isNotEmpty) {
        if (!isJsonLd && !isTrustedContent) {
          throw ArgumentError.value(
            textContent,
            'textContent',
            'Inline script execution requires explicit trusted content (isTrustedContent: true). '
                'Ordinary text is never interpreted as executable script.',
          );
        }
      }
      final safeContent = (textContent ?? '')
          .replaceAll(RegExp(r'</script', caseSensitive: false), r'<\/script')
          .replaceAll('\u2028', r'\u2028')
          .replaceAll('\u2029', r'\u2029');
      return '<script$attrString>$safeContent</script>';
    }

    if (lowerTag == 'style') {
      if (textContent != null && textContent!.isNotEmpty && !isTrustedContent) {
        throw ArgumentError.value(
          textContent,
          'textContent',
          'Inline style content requires explicit trusted content (isTrustedContent: true). '
              'Ordinary text is never interpreted as executable style.',
        );
      }
      final safeCss = (textContent ?? '').replaceAll(
        RegExp(r'</style', caseSensitive: false),
        r'<\/style',
      );
      return '<style$attrString>$safeCss</style>';
    }

    if (lowerTag == 'title') {
      final safeTitle = _escapeText(textContent ?? '');
      return '<title$attrString>$safeTitle</title>';
    }

    if (textContent != null) {
      final safeText = _escapeText(textContent!);
      return '<$tagName$attrString>$safeText</$tagName>';
    }

    return '<$tagName$attrString></$tagName>';
  }

  static String _escapeAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _escapeText(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
