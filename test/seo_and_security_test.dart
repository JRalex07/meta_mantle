import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Advanced SEO & Security Guard Tests', () {
    test('SitemapGenerator produces valid XML with images and alternates', () {
      const generator = SitemapGenerator();
      final entries = [
        const SitemapUrlEntry(
          loc: 'https://example.com/products/rice/',
          lastMod: null,
          changeFreq: 'daily',
          priority: 0.9,
          images: ['https://example.com/assets/rice.png'],
          alternates: [
            AlternateUrl(
                language: 'es', url: 'https://example.com/es/products/rice/'),
          ],
        ),
      ];

      final xml = generator.generateUrlset(entries);
      expect(xml, contains('<loc>https://example.com/products/rice/</loc>'));
      expect(xml, contains('<changefreq>daily</changefreq>'));
      expect(xml, contains('<priority>0.9</priority>'));
      expect(
          xml,
          contains(
              '<image:loc>https://example.com/assets/rice.png</image:loc>'));
      expect(xml, contains('hreflang="es"'));
    });

    test(
        'SitemapGenerator splits into sitemap index when entries exceed maxUrlsPerSitemap',
        () {
      const generator = SitemapGenerator(maxUrlsPerSitemap: 5);
      final entries = List.generate(
        12,
        (i) => SitemapUrlEntry(
          loc: 'https://example.com/items/$i/',
          lastMod: DateTime.utc(2026, 1, 1),
        ),
      );

      final result = generator.generateSitemapIndex(
        entries: entries,
        sitemapBaseUrl: 'https://example.com/sitemaps/',
      );

      // 12 entries with max 5 per file yields: sitemap-1.xml, sitemap-2.xml, sitemap-3.xml, and sitemap_index.xml
      expect(result.containsKey('sitemap-1.xml'), isTrue);
      expect(result.containsKey('sitemap-2.xml'), isTrue);
      expect(result.containsKey('sitemap-3.xml'), isTrue);
      expect(result.containsKey('sitemap_index.xml'), isTrue);

      final indexXml = result['sitemap_index.xml']!;
      expect(indexXml, contains('<sitemapindex'));
      expect(indexXml,
          contains('<loc>https://example.com/sitemaps/sitemap-1.xml</loc>'));
      expect(indexXml,
          contains('<loc>https://example.com/sitemaps/sitemap-2.xml</loc>'));
      expect(indexXml,
          contains('<loc>https://example.com/sitemaps/sitemap-3.xml</loc>'));
    });

    test('HreflangValidator catches missing reciprocal alternate links', () {
      const validator = HreflangValidator();

      // Page A links to Page B, but Page B does NOT link back to Page A
      final catalog = {
        'https://example.com/en/about': [
          const AlternateUrl(
              language: 'es', url: 'https://example.com/es/about'),
        ],
        'https://example.com/es/about': <AlternateUrl>[],
      };

      final findings = validator.validate(catalog);
      expect(findings.any((f) => f.isError && f.message.contains('reciprocal')),
          isTrue);
    });

    test('SsrfGuard blocks cloud metadata and private network addresses',
        () async {
      const guard = SsrfGuard(allowLocalhostInDev: false);

      // Cloud metadata IP
      expect(
        () => guard
            .validateUri(Uri.parse('http://169.254.169.254/latest/meta-data')),
        throwsA(isA<SecurityException>()),
      );

      // Cloud metadata DNS name
      expect(
        () => guard.validateUri(
            Uri.parse('http://metadata.google.internal/computeMetadata/v1/')),
        throwsA(isA<SecurityException>()),
      );

      // Disallowed scheme
      expect(
        () => guard.validateUri(Uri.parse('file:///etc/passwd')),
        throwsA(isA<SecurityException>()),
      );

      // Loopback IP
      expect(
        () => guard.validateUri(Uri.parse('http://127.0.0.1:8080/admin')),
        throwsA(isA<SecurityException>()),
      );
    });

    test('IncrementalManifest fingerprints and detects route modifications',
        () {
      final manifest = IncrementalManifest();

      const route = '/products/basmati-rice/';
      final hashV1 =
          IncrementalManifest.computeFingerprint('<h1>Version 1</h1>');
      manifest.record(route, hashV1, 'products/basmati-rice/index.html');

      // Unchanged check
      expect(manifest.hasChanged(route, hashV1), isFalse);

      // Changed check
      final hashV2 =
          IncrementalManifest.computeFingerprint('<h1>Version 2 Modified</h1>');
      expect(manifest.hasChanged(route, hashV2), isTrue);

      // Obsolete route detection
      final obsolete = manifest.findObsoleteRoutes({'/about/'});
      expect(obsolete, contains(route));
    });
  });
}
