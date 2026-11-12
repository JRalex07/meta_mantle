/// A news article item formatted for Google News sitemaps.
class NewsArticleItem {
  const NewsArticleItem({
    required this.loc,
    required this.publicationName,
    required this.publicationLanguage,
    required this.publicationDate,
    required this.title,
    this.genres,
    this.keywords = const [],
    this.stockTickers = const [],
  });

  final String loc;
  final String publicationName;
  final String publicationLanguage;
  final DateTime publicationDate;
  final String title;
  final String? genres;
  final List<String> keywords;
  final List<String> stockTickers;
}

/// Generates Google News-compliant XML sitemaps using `<news:news>` namespace.
class NewsSitemapGenerator {
  const NewsSitemapGenerator();

  /// Emits Google News sitemap XML according to Google Search Central specifications.
  String generate(List<NewsArticleItem> articles) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"');
    buf.writeln(
      '        xmlns:news="http://www.google.com/schemas/sitemap-news/0.9">',
    );

    for (final article in articles) {
      buf.writeln('  <url>');
      buf.writeln('    <loc>${_escape(article.loc)}</loc>');
      buf.writeln('    <news:news>');
      buf.writeln('      <news:publication>');
      buf.writeln(
        '        <news:name>${_escape(article.publicationName)}</news:name>',
      );
      buf.writeln(
        '        <news:language>${_escape(article.publicationLanguage)}</news:language>',
      );
      buf.writeln('      </news:publication>');
      buf.writeln(
        '      <news:publication_date>${article.publicationDate.toUtc().toIso8601String()}</news:publication_date>',
      );
      buf.writeln('      <news:title>${_escape(article.title)}</news:title>');
      if (article.genres != null) {
        buf.writeln(
          '      <news:genres>${_escape(article.genres!)}</news:genres>',
        );
      }
      if (article.keywords.isNotEmpty) {
        buf.writeln(
          '      <news:keywords>${_escape(article.keywords.join(", "))}</news:keywords>',
        );
      }
      if (article.stockTickers.isNotEmpty) {
        buf.writeln(
          '      <news:stock_tickers>${_escape(article.stockTickers.join(", "))}</news:stock_tickers>',
        );
      }
      buf.writeln('    </news:news>');
      buf.writeln('  </url>');
    }

    buf.writeln('</urlset>');
    return buf.toString();
  }

  static String _escape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
