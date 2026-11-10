/// Represents a publishable article or blog item for RSS/Atom syndication.
class FeedItem {
  const FeedItem({
    required this.id,
    required this.title,
    required this.url,
    required this.summary,
    required this.publishedAt,
    this.author,
    this.contentHtml,
    this.categories = const [],
  });

  final String id;
  final String title;
  final String url;
  final String summary;
  final DateTime publishedAt;
  final String? author;
  final String? contentHtml;
  final List<String> categories;
}

/// Generates compliant RSS 2.0 and Atom 1.0 syndication feeds.
class FeedGenerator {
  const FeedGenerator({
    required this.feedTitle,
    required this.feedUrl,
    required this.feedDescription,
    this.authorEmail,
    this.authorName,
  });

  final String feedTitle;
  final String feedUrl;
  final String feedDescription;
  final String? authorEmail;
  final String? authorName;

  /// Generates RSS 2.0 XML feed.
  String generateRss2(List<FeedItem> items) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">');
    buf.writeln('  <channel>');
    buf.writeln('    <title>${_escape(feedTitle)}</title>');
    buf.writeln('    <link>${_escape(feedUrl)}</link>');
    buf.writeln('    <description>${_escape(feedDescription)}</description>');
    buf.writeln(
        '    <atom:link href="${_escape(feedUrl)}/rss.xml" rel="self" type="application/rss+xml" />');

    for (final item in items) {
      buf.writeln('    <item>');
      buf.writeln('      <guid isPermaLink="true">${_escape(item.url)}</guid>');
      buf.writeln('      <title>${_escape(item.title)}</title>');
      buf.writeln('      <link>${_escape(item.url)}</link>');
      buf.writeln('      <description>${_escape(item.summary)}</description>');
      buf.writeln('      <pubDate>${_toRfc822(item.publishedAt)}</pubDate>');
      if (item.author != null || authorName != null) {
        buf.writeln(
            '      <author>${_escape(authorEmail ?? "noreply@example.com")} (${_escape(item.author ?? authorName!)})</author>');
      }
      for (final cat in item.categories) {
        buf.writeln('      <category>${_escape(cat)}</category>');
      }
      buf.writeln('    </item>');
    }

    buf.writeln('  </channel>');
    buf.writeln('</rss>');
    return buf.toString();
  }

  /// Generates Atom 1.0 XML feed.
  String generateAtom(List<FeedItem> items) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<feed xmlns="http://www.w3.org/2005/Atom">');
    buf.writeln('  <title>${_escape(feedTitle)}</title>');
    buf.writeln('  <id>${_escape(feedUrl)}</id>');
    buf.writeln('  <link href="${_escape(feedUrl)}" />');
    buf.writeln('  <link rel="self" href="${_escape(feedUrl)}/atom.xml" />');
    buf.writeln('  <subtitle>${_escape(feedDescription)}</subtitle>');
    buf.writeln(
        '  <updated>${DateTime.now().toUtc().toIso8601String()}</updated>');

    for (final item in items) {
      buf.writeln('  <entry>');
      buf.writeln('    <id>${_escape(item.url)}</id>');
      buf.writeln('    <title>${_escape(item.title)}</title>');
      buf.writeln('    <link href="${_escape(item.url)}" />');
      buf.writeln('    <summary>${_escape(item.summary)}</summary>');
      buf.writeln(
          '    <updated>${item.publishedAt.toUtc().toIso8601String()}</updated>');
      if (item.author != null || authorName != null) {
        buf.writeln(
            '    <author><name>${_escape(item.author ?? authorName!)}</name></author>');
      }
      buf.writeln('  </entry>');
    }

    buf.writeln('</feed>');
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

  static String _toRfc822(DateTime dt) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final u = dt.toUtc();
    final dName = days[u.weekday - 1];
    final mName = months[u.month - 1];
    final day = u.day.toString().padLeft(2, '0');
    final year = u.year;
    final hour = u.hour.toString().padLeft(2, '0');
    final min = u.minute.toString().padLeft(2, '0');
    final sec = u.second.toString().padLeft(2, '0');
    return '$dName, $day $mName $year $hour:$min:$sec GMT';
  }
}
