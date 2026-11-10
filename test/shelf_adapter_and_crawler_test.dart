import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  group('Real Shelf HTTP Server & Raw Crawler Response Tests (Zero JavaScript)',
      () {
    late HttpServer server;
    late String serverBaseUrl;
    late MemoryDataProvider<Map<String, dynamic>> productProvider;

    setUpAll(() async {
      productProvider =
          MemoryDataProvider<Map<String, dynamic>>(lookupParam: 'slug');

      productProvider.set(
        'basmati-rice',
        {
          'id': 'PROD-101',
          'slug': 'basmati-rice',
          'name': 'Premium Basmati Rice',
          'description':
              'Aged long-grain aromatic rice sourced directly from Himalayan organic farms.',
          'price': 24.99,
          'image':
              'https://metamantle.alex.runs-on.dev/assets/basmati-rice.png',
        },
        lastModified: DateTime.utc(2026, 2, 1),
        etag: 'w/"shelf-rice-101"',
      );

      final route = MetaRoute<Map<String, dynamic>>(
        pattern: '/products/:slug',
        dataProvider: productProvider,
        metadataBuilder: (data, ctx) => WebMetadata(
          title: data['name'] as String,
          description: data['description'] as String,
          canonical:
              'https://metamantle.alex.runs-on.dev/products/${data["slug"]}/',
          openGraph: OpenGraph(
            type: OpenGraphType.product,
            title: data['name'] as String,
            description: data['description'] as String,
            image: data['image'] as String,
          ),
          jsonLd: [
            JsonLd.product(
              name: data['name'] as String,
              description: data['description'] as String,
              image: data['image'] as String,
              sku: data['id'] as String,
              offers: {
                '@type': 'Offer',
                'price': '${data["price"]}',
                'priceCurrency': 'USD',
                'availability': 'https://schema.org/InStock',
              },
            ),
          ],
        ),
        htmlBuilder: (data, ctx) => [
          H.header([
            H.nav([
              H.a('/', 'Home'),
              H.a('/about', 'About Us'),
            ]),
          ]),
          H.main([
            H.article([
              H.h1(data['name'] as String),
              H.img(
                data['image'] as String,
                alt: '${data["name"]} package',
                width: 600,
                height: 600,
              ),
              H.p(data['description'] as String),
              H.p('Price: \$${data["price"]} — In Stock'),
              H.table(
                headers: ['Attribute', 'Specification'],
                rows: [
                  ['SKU', data['id'] as String],
                  ['Weight', '5 kg'],
                  ['Origin', 'Himalayan Foothills'],
                ],
              ),
            ]),
          ]),
          H.footer([
            H.p('© 2026 MetaMantle Store Inc. All rights reserved.'),
          ]),
        ],
        cachePolicy: const CachePolicy(
          ttl: Duration(minutes: 10),
          staleWhileRevalidate: Duration(minutes: 20),
        ),
      );

      final engine = MetaMantleServerEngine(
        routes: [route],
        config: const MetaMantleConfig(
          siteName: 'MetaMantle Store',
          titleTemplate: '%s | MetaMantle Store',
          baseUrl: 'https://metamantle.alex.runs-on.dev',
        ),
      );

      final handler = metaMantleShelfHandler(engine);
      // Bind to an ephemeral port on loopback
      server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
      serverBaseUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    test(
        'raw HTTP crawler receives full semantic HTML before JavaScript executes',
        () async {
      final client = http.Client();
      try {
        final res = await client.get(
          Uri.parse('$serverBaseUrl/products/basmati-rice'),
          headers: {
            'User-Agent': 'Googlebot/2.1 (+http://www.google.com/bot.html)',
            'Accept': 'text/html',
          },
        );

        expect(res.statusCode, equals(200));
        expect(res.headers['content-type'], contains('text/html'));
        expect(res.headers['etag'], equals('w/"shelf-rice-101"'));

        final body = res.body;

        // 1. Title verification
        expect(body,
            contains('<title>Premium Basmati Rice | MetaMantle Store</title>'));

        // 2. Meta description
        expect(
          body,
          contains(
              'name="description" content="Aged long-grain aromatic rice sourced directly from Himalayan organic farms."'),
        );

        // 3. Canonical URL
        expect(
          body,
          contains(
              '<link rel="canonical" href="https://metamantle.alex.runs-on.dev/products/basmati-rice/"'),
        );

        // 4. Open Graph protocol
        expect(
            body,
            contains(
                '<meta property="og:title" content="Premium Basmati Rice"'));
        expect(
            body,
            contains(
                '<meta property="og:image" content="https://metamantle.alex.runs-on.dev/assets/basmati-rice.png"'));
        expect(body, contains('<meta property="og:type" content="product"'));

        // 5. JSON-LD Structured Data
        expect(body, contains('<script type="application/ld+json"'));
        expect(body, contains(r'"@type":"Product"'));
        expect(body, contains(r'"name":"Premium Basmati Rice"'));
        expect(body, contains(r'"sku":"PROD-101"'));

        // 6. Semantic Body Markup
        expect(body, contains('<h1>Premium Basmati Rice</h1>'));
        expect(
            body,
            contains(
                '<img src="https://metamantle.alex.runs-on.dev/assets/basmati-rice.png" alt="Premium Basmati Rice package" width="600" height="600" />'));
        expect(body, contains('<p>Price: \$24.99 — In Stock</p>'));
        expect(body, contains('<th>Attribute</th>'));
        expect(body, contains('<td>Himalayan Foothills</td>'));

        // 7. Verify zero requirement for JavaScript execution
        expect(body, startsWith('<!DOCTYPE html>'));
        expect(body, endsWith('</html>\n'));
      } finally {
        client.close();
      }
    });

    test('raw HTTP crawler receives 404 for missing items', () async {
      final client = http.Client();
      try {
        final res =
            await client.get(Uri.parse('$serverBaseUrl/products/unknown-item'));
        expect(res.statusCode, equals(404));
        expect(res.body, contains('404'));
      } finally {
        client.close();
      }
    });
  });
}
