/// Parsed document payload containing extracted frontmatter attributes and raw markdown body.
class ParsedDocument {
  const ParsedDocument({
    required this.attributes,
    required this.body,
  });

  final Map<String, String> attributes;
  final String body;

  String? get title => attributes['title'];
  String? get description => attributes['description'];
  String? get canonical => attributes['canonical'];
  String? get author => attributes['author'];
  String? get publishedDate =>
      attributes['publishedDate'] ?? attributes['date'];
  String? get modifiedDate =>
      attributes['modifiedDate'] ?? attributes['updated'];
  String? get image => attributes['image'] ?? attributes['ogImage'];
  String? get tags => attributes['tags'];
  String? get category => attributes['category'];
  String? get version => attributes['version'];
}

/// Lightweight YAML frontmatter parser for documentation and blog markdown files.
class FrontmatterExtractor {
  const FrontmatterExtractor();

  /// Parses a markdown string, separating leading `---` frontmatter from the document body.
  ParsedDocument parse(String markdownContent) {
    final clean = markdownContent.replaceAll('\r\n', '\n');
    if (!clean.startsWith('---')) {
      return ParsedDocument(attributes: const {}, body: clean);
    }

    final secondDelimiterIndex = clean.indexOf('\n---', 3);
    if (secondDelimiterIndex == -1) {
      return ParsedDocument(attributes: const {}, body: clean);
    }

    final frontmatterBlock = clean.substring(3, secondDelimiterIndex).trim();
    final body = clean.substring(secondDelimiterIndex + 4).trimLeft();

    final attributes = <String, String>{};
    for (final line in frontmatterBlock.split('\n')) {
      final colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final key = line.substring(0, colonIndex).trim();
        var value = line.substring(colonIndex + 1).trim();
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.substring(1, value.length - 1);
        }
        attributes[key] = value;
      }
    }

    return ParsedDocument(attributes: attributes, body: body);
  }
}
