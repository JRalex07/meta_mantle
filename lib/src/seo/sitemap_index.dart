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
    if (url.isEmpty) {
      throw ArgumentError.value(url, context, '$context must not be empty.');
    }

    // Check for forbidden control characters ([\x00-\x1F\x7F-\x9F]) and invalid XML characters.
    if (url.contains(RegExp(r'[\x00-\x1F\x7F-\x9F]'))) {
      throw ArgumentError.value(
        url,
        context,
        '$context contains forbidden control characters.',
      );
    }

    // Reject unencoded whitespace.
    if (url.contains(RegExp(r'\s'))) {
      throw ArgumentError.value(
        url,
        context,
        '$context must not contain whitespace: "$url".',
      );
    }

    // Validate percent-encoding: '%' must be followed by two hexadecimal digits.
    final invalidPercent = RegExp(r'%([^0-9a-fA-F]|[0-9a-fA-F][^0-9a-fA-F]|$)');
    if (invalidPercent.hasMatch(url)) {
      throw ArgumentError.value(
        url,
        context,
        '$context contains invalid percent-encoding: "$url".',
      );
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute) {
      throw ArgumentError.value(
        url,
        context,
        '$context must be an absolute URL, got: "$url".',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw ArgumentError.value(
        url,
        context,
        '$context must use http or https scheme, got "$scheme" in: "$url".',
      );
    }

    if (uri.host.isEmpty) {
      throw ArgumentError.value(
        url,
        context,
        '$context must include a valid host, got: "$url".',
      );
    }

    if (uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        url,
        context,
        '$context must not contain credentials/userinfo: "$url".',
      );
    }

    if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) {
      throw ArgumentError.value(
        url,
        context,
        '$context contains an invalid port: "$url".',
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
      if (entry.loc.trim().isEmpty) {
        throw ArgumentError.value(
          entry.loc,
          'entry.loc',
          'SitemapUrlEntry loc must not be empty or whitespace-only.',
        );
      }
      final loc = entry.loc;

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
        if (!validChangeFrequencies.contains(freq)) {
          throw ArgumentError.value(
            entry.changeFreq,
            'changeFreq',
            'Invalid changefreq "${entry.changeFreq}". Valid values are: ${validChangeFrequencies.join(', ')}.',
          );
        }
        buf.writeln('    <changefreq>$freq</changefreq>');
      }

      if (entry.priority != null) {
        final p = entry.priority!;
        if (p.isNaN || p.isInfinite || p < 0.0 || p > 1.0) {
          throw ArgumentError.value(
            p,
            'priority',
            'Priority must be a finite number between 0.0 and 1.0, got: $p.',
          );
        }
        buf.writeln('    <priority>${p.toStringAsFixed(1)}</priority>');
      }

      for (final alt in entry.alternates) {
        // Validate alternate language and URL.
        _assertValidLanguage(alt.language);
        if (alt.url.trim().isEmpty) {
          throw ArgumentError.value(
            alt.url,
            'alternate href',
            'Alternate href must not be empty or whitespace-only.',
          );
        }
        _assertAbsoluteHttpUrl(alt.url, 'alternate href');
        buf.writeln(
          '    <xhtml:link rel="alternate" hreflang="${_escape(alt.language)}" href="${_escape(alt.url)}" />',
        );
      }

      for (final img in entry.images) {
        if (img.trim().isEmpty) {
          throw ArgumentError.value(
            img,
            'image loc',
            'Image loc must not be empty or whitespace-only.',
          );
        }
        _assertAbsoluteHttpUrl(img, 'image loc');
        buf.writeln('    <image:image>');
        buf.writeln('      <image:loc>${_escape(img)}</image:loc>');
        buf.writeln('    </image:image>');
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
    final baseUri = Uri.parse(sitemapBaseUrl);
    if (baseUri.hasQuery) {
      throw ArgumentError.value(
        sitemapBaseUrl,
        'sitemapBaseUrl',
        'sitemapBaseUrl must not contain query parameters.',
      );
    }
    if (baseUri.hasFragment) {
      throw ArgumentError.value(
        sitemapBaseUrl,
        'sitemapBaseUrl',
        'sitemapBaseUrl must not contain fragment.',
      );
    }

    if (entries.length <= maxUrlsPerSitemap) {
      return {'sitemap.xml': generateUrlset(entries)};
    }

    final sitemapCount = (entries.length / maxUrlsPerSitemap).ceil();
    if (sitemapCount > 50000) {
      throw ArgumentError.value(
        entries.length,
        'entries',
        'Dataset requires $sitemapCount sitemaps, which exceeds the sitemaps.org protocol limit of 50,000 sitemaps per sitemap index.',
      );
    }

    final result = <String, String>{};
    final indexBuf = StringBuffer();

    indexBuf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    indexBuf.writeln(
      '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    );

    final normalizedBase = sitemapBaseUrl.endsWith('/')
        ? sitemapBaseUrl.substring(0, sitemapBaseUrl.length - 1)
        : sitemapBaseUrl;

    for (var i = 0; i < sitemapCount; i++) {
      final startIndex = i * maxUrlsPerSitemap;
      final endIndex = (startIndex + maxUrlsPerSitemap < entries.length)
          ? startIndex + maxUrlsPerSitemap
          : entries.length;

      final chunk = entries.sublist(startIndex, endIndex);
      final filename = 'sitemap-${i + 1}.xml';
      result[filename] = generateUrlset(chunk);

      final fullUrl = '$normalizedBase/$filename';

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
