/// A normalized, platform-neutral representation of one head element.
class HeadTag {
  const HeadTag({
    required this.key,
    required this.tagName,
    this.attributes = const {},
    this.textContent,
  });

  final String key;
  final String tagName;
  final Map<String, String> attributes;
  final String? textContent;

  /// Serializes this head tag to an HTML string.
  String toHtml() {
    final attrs = attributes.entries
        .map((e) => '${e.key}="${e.value}"')
        .join(' ');
    final attrString = attrs.isEmpty ? '' : ' $attrs';
    if (textContent != null) {
      return '<$tagName$attrString>$textContent</$tagName>';
    }
    if (tagName == 'meta' || tagName == 'link') {
      return '<$tagName$attrString />';
    }
    return '<$tagName$attrString></$tagName>';
  }
}
