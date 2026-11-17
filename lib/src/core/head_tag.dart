/// A normalized, platform-neutral representation of one head element.
class HeadTag {
  const HeadTag({
    required this.key,
    required this.tagName,
    this.attributes = const {},
    this.textContent,
  });

  static final RegExp _tagRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9-]*$');
  static final RegExp _attrKeyRegex = RegExp(r'^[a-zA-Z_:][a-zA-Z0-9_.:-]*$');
  static const Set<String> _voidHeadTags = {'meta', 'link', 'base'};

  final String key;
  final String tagName;
  final Map<String, String> attributes;
  final String? textContent;

  /// Serializes this head tag to an HTML string.
  String toHtml() {
    if (!_tagRegex.hasMatch(tagName)) {
      throw ArgumentError.value(tagName, 'tagName', 'Invalid head tag name');
    }
    for (final entry in attributes.entries) {
      if (!_attrKeyRegex.hasMatch(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'attribute',
          'Invalid attribute name',
        );
      }
      if (entry.key.toLowerCase().startsWith('on')) {
        throw ArgumentError.value(
          entry.key,
          'attribute',
          'Event handler attributes (on*) are prohibited in head tags',
        );
      }
    }

    final lowerTag = tagName.toLowerCase();
    final attrs = attributes.entries
        .map((e) => '${e.key}="${_escapeAttr(e.value)}"')
        .join(' ');
    final attrString = attrs.isEmpty ? '' : ' $attrs';

    if (_voidHeadTags.contains(lowerTag)) {
      return '<$tagName$attrString>';
    }

    if (lowerTag == 'script') {
      final safeContent = (textContent ?? '').replaceAll(
        RegExp(r'</script', caseSensitive: false),
        r'<\/script',
      );
      return '<script$attrString>$safeContent</script>';
    }

    if (textContent != null) {
      final safeText = lowerTag == 'style'
          ? textContent!
          : _escapeText(textContent!);
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
