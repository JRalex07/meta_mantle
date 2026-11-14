import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  group('Real Shelf HTTP SSR Integration Tests', () {
    late HttpServer server;
    late String serverUrl;
    late MemoryDataProvider<Map<String, dynamic>> staticProvider;
    late MemoryDataProvider<Map<String, dynamic>> productProvider;

    setUpAll(() async {
      staticProvider = MemoryDataProvider<Map<String, dynamic>>();
      staticProvider.set('/', {'title': 'Home'});
      staticProvider.set('/about', {'title': 'About'});
      staticProvider.set('/failing-route', {'title': 'Fail'});

      productProvider = MemoryDataProvider<Map<String, dynamic>>(
        lookupParam: 'slug',
      );

      productProvider.set('example', {
        'slug': 'example',
        'title': 'Example Product',
        'description': 'A fantastic product for testing real SSR.',
        'price': 49.99,
      });

      final homeRoute = MetaRoute<Map<String, dynamic>>(
        pattern: '/',
        dataProvider: staticProvider,
        metadataBuilder: (_, __) => const WebMetadata(
          title: 'Home Page',
          description: 'Welcome to our SSR site.',
          canonical: 'http://localhost/home',
        ),
        htmlBuilder: (_, __) => [
          H.h1('Welcome to MetaMantle SSR'),
          H.p('Server-side rendered home page.'),
        ],
      );

      final aboutRoute = MetaRoute<Map<String, dynamic>>(
        pattern: '/about',
        dataProvider: staticProvider,
        metadataBuilder: (_, __) => const WebMetadata(
          title: 'About Us',
          description: 'Learn all about MetaMantle.',
        ),
        htmlBuilder: (_, __) => [
          H.h1('About Us'),
          H.p('We build universal Dart rendering architecture.'),
        ],
      );

      final productRoute = MetaRoute<Map<String, dynamic>>(
        pattern: '/products/:slug',
        dataProvider: productProvider,
        metadataBuilder: (data, _) => WebMetadata(
          title: data['title'] as String,
          description: data['description'] as String,
          openGraph: OpenGraph(
            title: data['title'] as String,
            description: data['description'] as String,
          ),
        ),
        htmlBuilder: (data, _) => [
          H.article([
            H.h1(data['title'] as String),
            H.p(data['description'] as String),
            H.p('Price: \$${data["price"]}'),
          ]),
        ],
      );

      final failingRoute = MetaRoute<Map<String, dynamic>>(
        pattern: '/failing-route',
        dataProvider: staticProvider,
        metadataBuilder: (_, __) => const WebMetadata(title: 'Fail'),
        htmlBuilder: (_, __) {
          throw Exception('Intentional server error for testing');
        },
      );

      final engine = MetaMantleServerEngine(
        routes: [homeRoute, aboutRoute, productRoute, failingRoute],
        config: const MetaMantleConfig(
          siteName: 'SSR Test Site',
          baseUrl: 'http://localhost',
        ),
      );

      final handler = metaMantleShelfHandler(engine);
      server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    test('GET / returns 200 with home metadata and semantic HTML', () async {
      final res = await http.get(Uri.parse('$serverUrl/'));
      expect(res.statusCode, equals(200));
      expect(res.headers['content-type'], contains('text/html'));
      expect(res.body, contains('<title>Home Page</title>'));
      expect(res.body, contains('<h1>Welcome to MetaMantle SSR</h1>'));
    });

    test(
      'GET /about returns 200 with about metadata and semantic HTML',
      () async {
        final res = await http.get(Uri.parse('$serverUrl/about'));
        expect(res.statusCode, equals(200));
        expect(res.body, contains('<title>About Us</title>'));
        expect(res.body, contains('<h1>About Us</h1>'));
        expect(
          res.body,
          contains('We build universal Dart rendering architecture.'),
        );
      },
    );

    test('GET /products/example resolves dynamic parameter, returns 200 and product HTML', () async {
      final res = await http.get(Uri.parse('$serverUrl/products/example'));
      expect(res.statusCode, equals(200));
      expect(res.body, contains('<title>Example Product</title>'));
      expect(res.body, contains('<h1>Example Product</h1>'));
      expect(res.body, contains('Price: \$49.99'));
    });

    test(
      'GET /products/nonexistent returns 404 for missing dynamic entity',
      () async {
        final res = await http.get(
          Uri.parse('$serverUrl/products/nonexistent'),
        );
        expect(res.statusCode, equals(404));
      },
    );

    test('GET /unknown-route returns 404 for unregistered path', () async {
      final res = await http.get(Uri.parse('$serverUrl/unknown-route'));
      expect(res.statusCode, equals(404));
    });

    test(
      'GET /failing-route returns 500 without leaking sensitive error stack',
      () async {
        final res = await http.get(Uri.parse('$serverUrl/failing-route'));
        expect(res.statusCode, equals(500));
        expect(
          res.body,
          isNot(contains('Exception: Intentional server error')),
        );
      },
    );

    test('HEAD / returns 200 with headers and empty body', () async {
      final client = http.Client();
      try {
        final req = http.Request('HEAD', Uri.parse('$serverUrl/'));
        final streamed = await client.send(req);
        final res = await http.Response.fromStream(streamed);
        expect(res.statusCode, equals(200));
        expect(res.headers['content-type'], contains('text/html'));
        expect(res.headers['etag'], isNotNull);
        expect(res.body, isEmpty);
      } finally {
        client.close();
      }
    });

    test(
      'Response headers verify ETag, Cache-Control, and Cache Hit behavior',
      () async {
        // First request (Cache MISS)
        final res1 = await http.get(Uri.parse('$serverUrl/about'));
        expect(res1.statusCode, equals(200));
        expect(res1.headers['etag'], isNotNull);
        expect(res1.headers['cache-control'], contains('public'));
        expect(res1.headers['cache-control'], contains('max-age='));
        final etag = res1.headers['etag']!;

        // Second request (Cache HIT)
        final res2 = await http.get(Uri.parse('$serverUrl/about'));
        expect(res2.statusCode, equals(200));
        expect(res2.headers['etag'], equals(etag));
        expect(res2.headers['x-metamantle-cache'], equals('HIT'));
      },
    );

    test(
      'Conditional GET with matching If-None-Match returns 304 Not Modified',
      () async {
        // Fetch initial response to get ETag
        final res1 = await http.get(Uri.parse('$serverUrl/about'));
        expect(res1.statusCode, equals(200));
        final etag = res1.headers['etag'];
        expect(etag, isNotNull);

        // Send conditional GET with exact ETag
        final res304 = await http.get(
          Uri.parse('$serverUrl/about'),
          headers: {'if-none-match': etag!},
        );
        expect(res304.statusCode, equals(304));
        expect(res304.body, isEmpty);
        expect(res304.headers['etag'], equals(etag));

        // Send conditional GET with uppercase weak ETag format W/"..."
        final rawEtag = etag.toLowerCase().startsWith('w/')
            ? etag.substring(2)
            : etag;
        final resWeak304 = await http.get(
          Uri.parse('$serverUrl/about'),
          headers: {'if-none-match': 'W/$rawEtag'},
        );
        expect(resWeak304.statusCode, equals(304));
        expect(resWeak304.body, isEmpty);
      },
    );

    test(
      'Conditional GET with mismatched If-None-Match returns 200 with content',
      () async {
        final res = await http.get(
          Uri.parse('$serverUrl/about'),
          headers: {'if-none-match': '"mismatched-nonexistent-etag"'},
        );
        expect(res.statusCode, equals(200));
        expect(res.body, contains('<h1>About Us</h1>'));
      },
    );

    test('Conditional GET with If-Modified-Since returns 304 when content is fresh', () async {
      final futureDate = HttpDate.format(
        DateTime.now().add(const Duration(days: 1)),
      );
      final res = await http.get(
        Uri.parse('$serverUrl/about'),
        headers: {'if-modified-since': futureDate},
      );
      expect(res.statusCode, equals(304));
      expect(res.body, isEmpty);
    });
  });
}
