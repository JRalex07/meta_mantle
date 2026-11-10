/// Generator for `/llms.txt` and machine-readable AI documentation manifests.
class LlmsTxtGenerator {
  const LlmsTxtGenerator({
    required this.projectName,
    required this.projectSummary,
    this.documentationBaseUrl,
  });

  final String projectName;
  final String projectSummary;
  final String? documentationBaseUrl;

  /// Generates the standard `/llms.txt` content following the /llms.txt standard specification.
  String generate({
    required List<({String title, String path, String summary})> pages,
    List<({String title, String url})> optionalLinks = const [],
  }) {
    final buf = StringBuffer();
    buf.writeln('# $projectName');
    buf.writeln();
    buf.writeln('> $projectSummary');
    buf.writeln();
    buf.writeln('## Documentation');
    buf.writeln();

    final base = (documentationBaseUrl ?? '').replaceAll(RegExp(r'/+$'), '');
    for (final page in pages) {
      final fullUrl =
          '$base${page.path.startsWith('/') ? '' : '/'}${page.path}';
      buf.writeln('- [${page.title}]($fullUrl): ${page.summary}');
    }

    if (optionalLinks.isNotEmpty) {
      buf.writeln();
      buf.writeln('## Optional');
      buf.writeln();
      for (final link in optionalLinks) {
        buf.writeln('- [${link.title}](${link.url})');
      }
    }

    return buf.toString();
  }
}
