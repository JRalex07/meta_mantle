import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Large Catalogue Performance Benchmarks', () {
    test('1,000 routes synthetic benchmark', () async {
      final store = MemoryCacheStore(maxEntries: 2000);
      final provider = MemoryDataProvider<String>(lookupParam: 'id');

      for (var i = 1; i <= 1000; i++) {
        provider.set(
          'item-$i',
          'Product Item #$i',
          lastModified: DateTime.utc(2026, 1, 1),
        );
      }

      final route = MetaRoute<String>(
        pattern: '/items/:id',
        dataProvider: provider,
        metadataBuilder: (data, ctx) => WebMetadata(
          title: data,
          description: 'Description for $data',
          canonical: 'https://example.com/items/${ctx.parameters["id"]}/',
        ),
        htmlBuilder: (data, ctx) => [
          H.h1(data),
          H.p('Detailed description for $data.'),
        ],
        cachePolicy: const CachePolicy(ttl: Duration(minutes: 10)),
      );

      final engine = MetaMantleServerEngine(
        routes: [route],
        cacheStore: store,
      );

      // Measure 1,000 sequential cache-miss renders
      final swMiss = Stopwatch()..start();
      for (var i = 1; i <= 1000; i++) {
        final req = ServerRequest(
          method: 'GET',
          uri: Uri.parse('https://example.com/items/item-$i'),
        );
        final res = await engine.handleRequest(req);
        expect(res.statusCode, equals(200));
      }
      swMiss.stop();

      // Measure 1,000 sequential cache-hit renders
      final swHit = Stopwatch()..start();
      for (var i = 1; i <= 1000; i++) {
        final req = ServerRequest(
          method: 'GET',
          uri: Uri.parse('https://example.com/items/item-$i'),
        );
        final res = await engine.handleRequest(req);
        expect(res.statusCode, equals(200));
      }
      swHit.stop();

      expect(store.hits, equals(1000));
      expect(store.misses, equals(1000));

      final missThroughput = 1000 / (swMiss.elapsedMilliseconds / 1000.0);
      final hitThroughput = 1000 / (swHit.elapsedMilliseconds / 1000.0);

      expect(missThroughput,
          greaterThan(100)); // At least 100 pages/sec on miss in debug mode
      expect(
          hitThroughput, greaterThan(2000)); // At least 2,000 pages/sec on hit
    });

    test('10,000 routes scaling & memory efficiency benchmark', () async {
      final entries = List.generate(
        10000,
        (i) => SitemapUrlEntry(
          loc: 'https://example.com/catalog/item-$i/',
          lastMod: DateTime.utc(2026, 1, 1),
          priority: 0.8,
        ),
      );

      const generator = SitemapGenerator(maxUrlsPerSitemap: 50000);
      final sw = Stopwatch()..start();
      final xml = generator.generateUrlset(entries);
      sw.stop();

      expect(xml.length, greaterThan(500000)); // over 500KB of valid XML
      expect(sw.elapsedMilliseconds, lessThan(1000)); // Generated in <1000ms
    });

    test('50,000 routes sitemap index generation benchmark', () async {
      final entries = List.generate(
        50000,
        (i) => SitemapUrlEntry(
          loc: 'https://example.com/p/$i/',
          lastMod: DateTime.utc(2026, 1, 1),
        ),
      );

      const generator = SitemapGenerator(maxUrlsPerSitemap: 10000);
      final sw = Stopwatch()..start();
      final files = generator.generateSitemapIndex(
        entries: entries,
        sitemapBaseUrl: 'https://example.com/sitemaps/',
      );
      sw.stop();

      // 50,000 entries chunked into 10,000 = 5 sitemaps + 1 index
      expect(files.length, equals(6));
      expect(files.containsKey('sitemap_index.xml'), isTrue);
      expect(sw.elapsedMilliseconds, lessThan(2000)); // under 2.0s
    });
  });
}
