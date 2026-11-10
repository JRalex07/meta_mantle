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
}
