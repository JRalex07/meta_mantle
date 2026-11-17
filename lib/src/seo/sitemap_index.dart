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
  const SitemapGenerator({this.maxUrlsPerSitemap = 50000})
    : assert(
        maxUrlsPerSitemap > 0 && maxUrlsPerSitemap <= 50000,
        'maxUrlsPerSitemap must be between 1 and 50,000 per sitemaps.org protocol',
      );

  final int maxUrlsPerSitemap;

  static const Set<String> validChangeFrequencies = {
    'always',
    'hourly',
    'daily',
    'weekly',
    'monthly',
    'yearly',
    'never',
  };

  // RFC 5646 language tag pattern (e.g. 'en', 'en-US', 'zh-Hant-TW') or 'x-default'.
  static final RegExp _langTagPattern = RegExp(
    r'^[a-zA-Z]{1,8}(-[a-zA-Z0-9]{1,8})*$',
  );

  /// Validates that [url] is a non-empty, absolute HTTP or HTTPS URL with valid host.
  /// Throws [ArgumentError] if the URL fails validation.
  /// [context] is a human-readable label used in the error message.
  void _assertAbsoluteHttpUrl(String url, String context) {
    // Strip control characters and trim whitespace.
    final cleaned = url.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();

    if (cleaned.isEmpty) {
      throw ArgumentError.value(url, context, '$context must not be empty.');
    }

    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.isAbsolute) {
      throw ArgumentError.value(
        url,
        context,
        '$context must be an absolute URL, got: "$cleaned".',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw ArgumentError.value(
        url,
        context,
        '$context must use http or https scheme, got "$scheme" in: "$cleaned".',
      );
    }

    if (uri.host.isEmpty) {
      throw ArgumentError.value(
        url,
        context,
        '$context must include a valid host, got: "$cleaned".',
      );
    }

    if (uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        url,
        context,
        '$context must not contain credentials/userinfo: "$cleaned".',
      );
    }
  }

  /// Validates [language] is a valid BCP-47 language tag or `x-default`.
  void _assertValidLanguage(String language) {
    if (language == 'x-default') return;
    if (!_langTagPattern.hasMatch(language)) {
      throw ArgumentError.value(
        language,
        'language',
        'alternate language "$language" is not a valid BCP-47 language tag. '
            'Must match ^[a-zA-Z]{1,8}(-[a-zA-Z0-9]{1,8})*\$ or be "x-default".',
      );
    }
  }

  /// Generates a single `<urlset>` XML document string for [entries].
  ///
  /// **Contract:** [entries.length] must not exceed [maxUrlsPerSitemap] (configured
  /// protocol limit between 1 and 50,000 URLs).
  ///
  /// If [entries.length] exceeds [maxUrlsPerSitemap], this method throws an [ArgumentError].
  /// Oversized inputs must use [generateSitemapIndex] to produce chunked sitemaps and
  /// a master `sitemap_index.xml`.
  String generateUrlset(List<SitemapUrlEntry> entries) {
    if (maxUrlsPerSitemap <= 0 || maxUrlsPerSitemap > 50000) {
      throw ArgumentError.value(
        maxUrlsPerSitemap,
        'maxUrlsPerSitemap',
        'Must be between 1 and 50,000 per sitemaps.org protocol',
      );
    }

    if (entries.length > maxUrlsPerSitemap) {
      throw ArgumentError.value(
        entries.length,
        'entries',
        'Too many entries: ${entries.length} exceeds maxUrlsPerSitemap '
            '($maxUrlsPerSitemap). Use generateSitemapIndex() for datasets exceeding protocol limits.',
      );
    }

    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"');
    buf.writeln(
      '        xmlns:image="http://www.google.com/schemas/sitemap-image/1.1"',
    );
    buf.writeln('        xmlns:xhtml="http://www.w3.org/1999/xhtml">');

    for (final entry in entries) {
      final loc = entry.loc.trim();
      if (loc.isEmpty) continue;

      // Validate loc as an absolute HTTP(S) URL.
      _assertAbsoluteHttpUrl(loc, 'loc');

      buf.writeln('  <url>');
      buf.writeln('    <loc>${_escape(loc)}</loc>');

      if (entry.lastMod != null) {
        final iso = entry.lastMod!.toUtc().toIso8601String().split('T').first;
        buf.writeln('    <lastmod>$iso</lastmod>');
      }

      if (entry.changeFreq != null) {
        final freq = entry.changeFreq!.trim().toLowerCase();
        final safeFreq = validChangeFrequencies.contains(freq)
            ? freq
            : 'weekly';
        buf.writeln('    <changefreq>${_escape(safeFreq)}</changefreq>');
      }

      if (entry.priority != null) {
        final p = entry.priority!;
        if (p.isNaN || p.isInfinite) {
          throw ArgumentError.value(
            p,
            'priority',
            'Priority must be a finite number between 0.0 and 1.0',
          );
        }
        final clampedPriority = p.clamp(0.0, 1.0);
        buf.writeln(
          '    <priority>${clampedPriority.toStringAsFixed(1)}</priority>',
        );
      }

      for (final alt in entry.alternates) {
        // Validate alternate language and URL.
        _assertValidLanguage(alt.language);
        _assertAbsoluteHttpUrl(alt.url, 'alternate href');
        buf.writeln(
          '    <xhtml:link rel="alternate" hreflang="${_escape(alt.language)}" href="${_escape(alt.url)}" />',
        );
      }

      for (final img in entry.images) {
        final imgUrl = img.trim();
        if (imgUrl.isNotEmpty) {
          _assertAbsoluteHttpUrl(imgUrl, 'image loc');
          buf.writeln('    <image:image>');
          buf.writeln('      <image:loc>${_escape(imgUrl)}</image:loc>');
          buf.writeln('    </image:image>');
        }
      }

      buf.writeln('  </url>');
    }

    buf.writeln('</urlset>');
    return buf.toString();
  }

  /// Splits [entries] into compliant chunks of at most [maxUrlsPerSitemap] (maximum
  /// 50,000 URLs per file per sitemaps.org protocol) and generates individual sitemaps
  /// plus a master `sitemap_index.xml`.
  ///
  /// **Contract:**
  /// - If [entries.length] is within [maxUrlsPerSitemap], returns `{'sitemap.xml': xmlContent}`.
  /// - If [entries.length] exceeds [maxUrlsPerSitemap], returns `sitemap_index.xml` referencing
  ///   `sitemap-1.xml`, `sitemap-2.xml`, etc., each containing at most [maxUrlsPerSitemap] URLs.
  /// - [sitemapBaseUrl] must be a non-empty, absolute HTTP(S) URL.
  Map<String, String> generateSitemapIndex({
    required List<SitemapUrlEntry> entries,
    required String sitemapBaseUrl,
  }) {
    if (maxUrlsPerSitemap <= 0 || maxUrlsPerSitemap > 50000) {
      throw ArgumentError.value(
        maxUrlsPerSitemap,
        'maxUrlsPerSitemap',
        'Must be between 1 and 50,000 per sitemaps.org protocol',
      );
    }

    // Validate sitemapBaseUrl.
    _assertAbsoluteHttpUrl(sitemapBaseUrl, 'sitemapBaseUrl');

    if (entries.length <= maxUrlsPerSitemap) {
      return {'sitemap.xml': generateUrlset(entries)};
    }

    final result = <String, String>{};
    final sitemapCount = (entries.length / maxUrlsPerSitemap).ceil();
    final indexBuf = StringBuffer();

    indexBuf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    indexBuf.writeln(
      '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    );

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
