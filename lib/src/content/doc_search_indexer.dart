import 'dart:convert';

/// A search index entry representing an indexed document section.
class SearchIndexEntry {
  const SearchIndexEntry({
    required this.title,
    required this.url,
    required this.section,
    required this.content,
    this.hierarchy = const [],
    this.tags = const [],
  });

  final String title;
  final String url;
  final String section;
  final String content;
  final List<String> hierarchy;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'section': section,
    'content': content,
    'hierarchy': hierarchy,
    if (tags.isNotEmpty) 'tags': tags,
  };
}

/// Generates client-side and full-text search indexes (`search.json`).
class DocSearchIndexer {
  const DocSearchIndexer();

  /// Extracts headings (`#`, `##`, `###`) and paragraphs from markdown into search entries.
  List<SearchIndexEntry> extractEntries({
    required String pageTitle,
    required String pageUrl,
    required String markdownContent,
    List<String> tags = const [],
  }) {
    final entries = <SearchIndexEntry>[];
    final lines = markdownContent.split('\n');

    String currentHeading = pageTitle;
    String currentAnchor = '';
    final currentHierarchy = <String>[pageTitle];
    final currentSectionText = StringBuffer();

    void flushSection() {
      final text = currentSectionText.toString().trim();
      if (text.isNotEmpty) {
        final anchorSuffix = currentAnchor.isNotEmpty ? '#$currentAnchor' : '';
        entries.add(
          SearchIndexEntry(
            title: pageTitle,
            url: '$pageUrl$anchorSuffix',
            section: currentHeading,
            content: text,
            hierarchy: List.from(currentHierarchy),
            tags: tags,
          ),
        );
        currentSectionText.clear();
      }
    }

    final headingRegex = RegExp(r'^(#{1,4})\s+(.+)$');
    for (final line in lines) {
      final match = headingRegex.firstMatch(line.trim());
      if (match != null) {
        flushSection();
        final level = match.group(1)!.length;
        final headingText = match.group(2)!.trim();
        currentHeading = headingText;
        currentAnchor = headingText
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-');

        while (currentHierarchy.length >= level) {
          currentHierarchy.removeLast();
        }
        currentHierarchy.add(headingText);
      } else {
        final cleanLine = line.replaceAll(RegExp(r'[*_`#\[\]]'), '').trim();
        if (cleanLine.isNotEmpty) {
          currentSectionText.writeln(cleanLine);
        }
      }
    }
    flushSection();

    return entries;
  }

  /// Serializes a list of search entries into a compact JSON index document.
  String generateJsonIndex(List<SearchIndexEntry> entries) {
    return const JsonEncoder.withIndent('  ')
        .convert(entries.map((e) => e.toJson()).toList());
  }
}
