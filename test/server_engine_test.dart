import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('MetaMantleServerEngine Tests', () {
    late MetaMantleServerEngine engine;
    late MemoryDataProvider<Map<String, dynamic>> productProvider;

    setUp(() {
      productProvider =
          MemoryDataProvider<Map<String, dynamic>>(lookupParam: 'slug');

      productProvider.set(
          'basmati-rice',
          {
            'id': '101',
            'name': 'Premium Basmati Rice',
            'description': 'Aged aromatic long-grain rice.',
            'price': 24.99,
          },
          lastModified: DateTime.utc(2026, 1, 1),
          etag: 'w/"product-101"');

      productProvider.markGone('discontinued-item');

      final redirectManager = RedirectManager(
        rules: const [
          RedirectRule(
              fromPath: '/old-rice',
              toPath: '/products/basmati-rice',
              statusCode: 301),
          RedirectRule(
              fromPath: '/legacy-hop-1',
              toPath: '/legacy-hop-2',
              statusCode: 301),
          RedirectRule(
              fromPath: '/legacy-hop-2',
              toPath: '/products/basmati-rice',
              statusCode: 301),
        ],
      );

      final route = MetaRoute<Map<String, dynamic>>(
        pattern: '/products/:slug',
        dataProvider: productProvider,
        metadataBuilder: (data, ctx) => WebMetadata(
          title: data['name'] as String,
          description: data['description'] as String,
          canonical: 'https://example.com/products/${data["id"]}/',
        ),
        htmlBuilder: (data, ctx) => [
          H.h1(data['name'] as String),
          H.p('Price: \$${data["price"]}'),
        ],
        cachePolicy: const CachePolicy(
          ttl: Duration(minutes: 10),
          staleWhileRevalidate: Duration(minutes: 20),
        ),
      );

      engine = MetaMantleServerEngine(
        routes: [route],
        redirectManager: redirectManager,
        config: const MetaMantleConfig(
          siteName: 'MetaMantle Store',
          titleTemplate: '%s | MetaMantle Store',
        ),
      );
    });

    test('serves 200 OK with complete semantic HTML on valid product route',
        () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com/products/basmati-rice'),
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(200));
      expect(res.header('content-type'), contains('text/html'));
      expect(res.header('etag'), equals('w/"product-101"'));
      expect(res.header('cache-control'), contains('public, max-age=600'));
      expect(res.body,
          contains('<title>Premium Basmati Rice | MetaMantle Store</title>'));
      expect(
          res.body,
          contains(
              '<meta name="description" content="Aged aromatic long-grain rice."'));
      expect(res.body, contains('<h1>Premium Basmati Rice</h1>'));
      expect(res.body, contains('<p>Price: \$24.99</p>'));
    });

    test('returns 304 Not Modified when client provides matching ETag',
        () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com/products/basmati-rice'),
        headers: {'If-None-Match': 'w/"product-101"'},
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(304));
      expect(res.body, isEmpty);
      expect(res.header('etag'), equals('w/"product-101"'));
    });

    test('returns 404 Not Found for missing product', () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com/products/unknown-item'),
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(404));
      expect(res.body, contains('404'));
    });

    test('returns 410 Gone for permanently removed product', () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com/products/discontinued-item'),
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(410));
      expect(res.body, contains('permanently removed'));
    });

    test('returns HEAD response with correct headers but empty body', () async {
      final req = ServerRequest(
        method: 'HEAD',
        uri: Uri.parse('https://example.com/products/basmati-rice'),
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(200));
      expect(res.header('content-type'), contains('text/html'));
      expect(res.header('etag'), equals('w/"product-101"'));
      expect(res.body, isEmpty);
    });

    test('resolves redirects and collapses redirect chains to 301', () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com/legacy-hop-1'),
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(301));
      expect(res.header('location'), equals('/products/basmati-rice'));
    });

    test('RedirectManager detects cycles and prevents infinite loops', () {
      final mgr = RedirectManager(
        rules: const [
          RedirectRule(fromPath: '/cycle-a', toPath: '/cycle-b'),
          RedirectRule(fromPath: '/cycle-b', toPath: '/cycle-a'),
        ],
      );

      expect(() => mgr.resolve('/cycle-a'), throwsA(isA<StateError>()));
    });
  });
}
