import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Social Image Generator Tests', () {
    test('Renders valid SVG with exact dimensions and escaped text', () {
      final gen = SocialImageGenerator();
      final svg = gen.generateSvg(
        const SocialCardData(
          title:
              'How to Build Enterprise Flutter Web Applications <script>alert(1)</script>',
          subtitle:
              'A practical architecture guide for production SEO & metadata.',
          siteName: 'MetaMantle & Co',
          categoryBadge: 'Architecture',
          priceTag: '\$49.00',
        ),
        dimensions: SocialCardDimensions.openGraph,
      );

      expect(
          svg,
          contains(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630" width="1200" height="630">'));
      expect(svg, contains('width="1200"'));
      expect(svg, contains('height="630"'));
      expect(svg, contains('&lt;script&gt;alert(1)&lt;/script&gt;'),
          reason: 'Raw script tags must be safely XML-escaped');
      expect(svg, contains('MetaMantle &amp; Co'));
      expect(svg, contains('\$49.00'));
      expect(svg, isNot(contains('<script>alert(1)</script>')));
    });

    test('Output caching stores and returns cached SVGs', () {
      final gen = SocialImageGenerator(maxCachedImages: 2);
      final svg1 = gen.generateSvg(
        const SocialCardData(title: 'Page One'),
      );
      expect(gen.cachedCount, equals(1));

      // Same data returns identical cached string
      final svg1Cached = gen.generateSvg(
        const SocialCardData(title: 'Page One'),
      );
      expect(identical(svg1, svg1Cached), isTrue);

      gen.generateSvg(const SocialCardData(title: 'Page Two'));
      expect(gen.cachedCount, equals(2));

      // Over capacity triggers LRU eviction
      gen.generateSvg(const SocialCardData(title: 'Page Three'));
      expect(gen.cachedCount, equals(2));
    });

    test('toDataUri produces valid data URI for og:image', () {
      final gen = SocialImageGenerator();
      const rawSvg = '<svg width="100" height="100"><rect fill="#000"/></svg>';
      final uri = gen.toDataUri(rawSvg);
      expect(uri, startsWith('data:image/svg+xml;utf8,'));
      expect(uri, contains('%3Crect'));
    });
  });

  group('Core Web Vitals Collector Tests', () {
    test('Ingests metrics, sanitizes URLs, and calculates p75 CrUX ratings',
        () {
      final collector = CoreWebVitalsCollector();

      // Ingest LCP observations (in milliseconds)
      final lcpValues = [
        1200.0,
        1500.0,
        1800.0,
        2100.0,
        2400.0,
        2900.0,
        4200.0
      ];
      for (final val in lcpValues) {
        collector.record(
          name: WebVitalName.lcp,
          value: val,
          path:
              '/products/mug?token=secret123&user=42#reviews', // Contains PII/secrets
        );
      }

      final report = collector.summarize();
      final lcpSummary = report[WebVitalName.lcp]!;

      expect(lcpSummary.sampleCount, equals(7));
      expect(lcpSummary.min, equals(1200.0));
      expect(lcpSummary.max, equals(4200.0));
      // 75th percentile of 7 values is index 5 -> 2900.0
      expect(lcpSummary.p75, equals(2900.0));
      // 2900ms is between 2500ms and 4000ms -> needsImprovement
      expect(lcpSummary.rating, equals(MetricRating.needsImprovement));

      // Verify privacy: path query params and fragments must be completely stripped
      final jsonReport = collector.toJsonReport();
      expect(jsonReport, contains('LCP'));
      expect(jsonReport, isNot(contains('secret123')));
      expect(jsonReport, isNot(contains('#reviews')));
    });

    test('CrUX threshold rating evaluations', () {
      expect(CoreWebVitalsCollector.rate(WebVitalName.cls, 0.05),
          equals(MetricRating.good));
      expect(CoreWebVitalsCollector.rate(WebVitalName.cls, 0.15),
          equals(MetricRating.needsImprovement));
      expect(CoreWebVitalsCollector.rate(WebVitalName.cls, 0.35),
          equals(MetricRating.poor));

      expect(CoreWebVitalsCollector.rate(WebVitalName.inp, 150),
          equals(MetricRating.good));
      expect(CoreWebVitalsCollector.rate(WebVitalName.inp, 350),
          equals(MetricRating.needsImprovement));
      expect(CoreWebVitalsCollector.rate(WebVitalName.inp, 650),
          equals(MetricRating.poor));
    });
  });

  group('CDN Invalidation Subsystem Tests', () {
    test('MemoryCdnInvalidator tracks purged URLs and tags', () async {
      final cdn = MemoryCdnInvalidator();

      final res1 = await cdn.purgeUrls(['/products/mug', '/about']);
      expect(res1.success, isTrue);
      expect(res1.purgedCount, equals(2));
      expect(cdn.purgedUrls, contains('/products/mug'));
      expect(cdn.purgedUrls, contains('/about'));

      final res2 = await cdn.purgeTags(['catalog', 'products']);
      expect(res2.success, isTrue);
      expect(cdn.purgedTags, contains('catalog'));

      final res3 = await cdn.purgeAll();
      expect(res3.success, isTrue);
      expect(cdn.purgedAllCalled, isTrue);
    });

    test('CloudflareCdnInvalidator sends API v4 purge request', () async {
      final mockClient = MockClient((request) async {
        expect(
            request.url.toString(), contains('zones/zone-abc-123/purge_cache'));
        expect(
            request.headers['Authorization'], equals('Bearer test-token-xyz'));
        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['files'], contains('https://example.com/products/mug'));

        return http.Response(
          json.encode({
            'success': true,
            'result': {'id': 'cf-purge-001'}
          }),
          200,
        );
      });

      final cdn = CloudflareCdnInvalidator(
        zoneId: 'zone-abc-123',
        apiToken: 'test-token-xyz',
        httpClient: mockClient,
      );

      final res = await cdn.purgeUrls(['https://example.com/products/mug']);
      expect(res.success, isTrue);
      expect(res.invalidationId, equals('cf-purge-001'));
    });
  });

  group('SEO Regression Tester Tests', () {
    test(
        'Detects title changes, accidental noindex, and dropped JSON-LD schemas',
        () {
      const tester = SeoRegressionTester();

      final baseline = <String, PageSeoSnapshot>{
        'https://example.com/': const PageSeoSnapshot(
          url: 'https://example.com/',
          title: 'MetaMantle Store',
          description: 'Official store for daily essentials.',
          canonical: 'https://example.com/',
          robots: 'index, follow',
          ogImage: 'https://example.com/og.png',
          jsonLdTypes: ['WebSite', 'Organization'],
        ),
      };

      // Current build accidentally dropped description, changed title, and added noindex
      final current = <String, PageSeoSnapshot>{
        'https://example.com/': const PageSeoSnapshot(
          url: 'https://example.com/',
          title: 'MetaMantle - Home',
          description: null, // Dropped!
          canonical: 'https://example.com/',
          robots: 'noindex, follow', // Accidental noindex!
          ogImage: null, // Dropped!
          jsonLdTypes: ['WebSite'], // Dropped Organization!
        ),
      };

      final findings =
          tester.compareSnapshots(baseline: baseline, current: current);

      expect(findings.any((f) => f.field == 'title'), isTrue);
      expect(
          findings
              .any((f) => f.field == 'description' && f.severity == 'CRITICAL'),
          isTrue);
      expect(
          findings.any((f) => f.field == 'robots' && f.severity == 'CRITICAL'),
          isTrue);
      expect(
          findings
              .any((f) => f.field == 'og:image' && f.severity == 'CRITICAL'),
          isTrue);
      expect(
          findings.any(
              (f) => f.field == 'jsonLd' && f.baselineValue == 'Organization'),
          isTrue);
    });
  });
}
