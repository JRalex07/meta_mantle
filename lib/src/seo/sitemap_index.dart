import '../models/metadata.dart';

/// Single URL entry for sitemap generation.
class SitemapUrlEntry {
  const SitemapUrlEntry({
    required this.loc,
    this.lastMod,
    this.changeFreq,
    this.priority,
    this.images = const [],
    this.alternates = const [],
  });

  final String loc;
  final DateTime? lastMod;
  final String? changeFreq;
  final double? priority;
  final List<String> images;
  final List<AlternateUrl> alternates;
}

/// Generates XML sitemaps and sitemap indexes according to the sitemaps.org protocol.
class SitemapGenerator {
  const SitemapGenerator({
    this.maxUrlsPerSitemap = 50000,
  });

  final int maxUrlsPerSitemap;

  /// Generates a single `<urlset>` XML document string for [entries].
  String generateUrlset(List<SitemapUrlEntry> entries) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"');
    buf.writeln(
        '        xmlns:image="http://www.google.com/schemas/sitemap-image/1.1"');
    buf.writeln('        xmlns:xhtml="http://www.w3.org/1999/xhtml">');

    for (final entry in entries) {
      buf.writeln('  <url>');
      buf.writeln('    <loc>${_escape(entry.loc)}</loc>');

      if (entry.lastMod != null) {
        final iso = entry.lastMod!.toUtc().toIso8601String().split('T').first;
        buf.writeln('    <lastmod>$iso</lastmod>');
      }

      if (entry.changeFreq != null) {
        buf.writeln('    <changefreq>${entry.changeFreq}</changefreq>');
      }

      if (entry.priority != null) {
        buf.writeln(
            '    <priority>${entry.priority!.toStringAsFixed(1)}</priority>');
      }

      for (final alt in entry.alternates) {
        buf.writeln(
          '    <xhtml:link rel="alternate" hreflang="${alt.language}" href="${_escape(alt.url)}" />',
        );
      }

      for (final img in entry.images) {
        buf.writeln('    <image:image>');
        buf.writeln('      <image:loc>${_escape(img)}</image:loc>');
        buf.writeln('    </image:image>');
      }

      buf.writeln('  </url>');
    }

    buf.writeln('</urlset>');
    return buf.toString();
  }

  /// Splits [entries] into chunks of at most [maxUrlsPerSitemap] and generates
  /// individual sitemaps plus a `sitemap_index.xml`.
  Map<String, String> generateSitemapIndex({
    required List<SitemapUrlEntry> entries,
    required String sitemapBaseUrl,
  }) {
    if (entries.length <= maxUrlsPerSitemap) {
      return {'sitemap.xml': generateUrlset(entries)};
    }

    final result = <String, String>{};
    final sitemapCount = (entries.length / maxUrlsPerSitemap).ceil();
    final indexBuf = StringBuffer();

    indexBuf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    indexBuf.writeln(
        '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');

    for (var i = 0; i < sitemapCount; i++) {
      final startIndex = i * maxUrlsPerSitemap;
      final endIndex = (startIndex + maxUrlsPerSitemap < entries.length)
          ? startIndex + maxUrlsPerSitemap
          : entries.length;

      final chunk = entries.sublist(startIndex, endIndex);
      final filename = 'sitemap-${i + 1}.xml';
      result[filename] = generateUrlset(chunk);

      final fullUrl = sitemapBaseUrl.endsWith('/')
          ? '$sitemapBaseUrl$filename'
          : '$sitemapBaseUrl/$filename';

      indexBuf.writeln('  <sitemap>');
      indexBuf.writeln('    <loc>${_escape(fullUrl)}</loc>');
      final latestMod = _findLatestMod(chunk);
      if (latestMod != null) {
        final iso = latestMod.toUtc().toIso8601String().split('T').first;
        indexBuf.writeln('    <lastmod>$iso</lastmod>');
      }
      indexBuf.writeln('  </sitemap>');
    }

    indexBuf.writeln('</sitemapindex>');
    result['sitemap_index.xml'] = indexBuf.toString();

    return result;
  }

  DateTime? _findLatestMod(List<SitemapUrlEntry> entries) {
    DateTime? latest;
    for (final e in entries) {
      if (e.lastMod != null) {
        if (latest == null || e.lastMod!.isAfter(latest)) {
          latest = e.lastMod;
        }
      }
    }
    return latest;
  }

  String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
