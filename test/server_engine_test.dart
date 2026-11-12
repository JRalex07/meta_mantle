import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('MetaMantleServerEngine Tests', () {
    late MetaMantleServerEngine engine;
    late MemoryDataProvider<Map<String, dynamic>> productProvider;

    setUp(() {
      productProvider = MemoryDataProvider<Map<String, dynamic>>(
        lookupParam: 'slug',
      );

      productProvider.set(
        'basmati-rice',
        {
          'id': '101',
          'name': 'Premium Basmati Rice',
          'description': 'Aged aromatic long-grain rice.',
          'price': 24.99,
        },
        lastModified: DateTime.utc(2026, 1, 1),
        etag: 'w/"product-101"',
      );

      productProvider.markGone('discontinued-item');

      final redirectManager = RedirectManager(
        rules: const [
          RedirectRule(
            fromPath: '/old-rice',
            toPath: '/products/basmati-rice',
            statusCode: 301,
          ),
          RedirectRule(
            fromPath: '/legacy-hop-1',
            toPath: '/legacy-hop-2',
            statusCode: 301,
          ),
          RedirectRule(
            fromPath: '/legacy-hop-2',
            toPath: '/products/basmati-rice',
            statusCode: 301,
          ),
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

    test(
      'serves 200 OK with complete semantic HTML on valid product route',
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
        expect(
          res.body,
          contains('<title>Premium Basmati Rice | MetaMantle Store</title>'),
        );
        expect(
          res.body,
          contains(
            '<meta name="description" content="Aged aromatic long-grain rice."',
          ),
        );
        expect(res.body, contains('<h1>Premium Basmati Rice</h1>'));
        expect(res.body, contains('<p>Price: \$24.99</p>'));
      },
    );

    test('serves a fresh generated artifact before invoking the data provider', () async {
      final directory = await Directory.systemTemp.createTemp('mm-artifact-');
      try {
        final store = FileHtmlArtifactStore(directory);
        final version = await store.beginVersion();
        const path = '/products/basmati-rice';
        const html =
            '<!doctype html><html><head><title>Static item</title></head><body><h1>Built artifact</h1></body></html>';
        await store.writeVersion(version, path, html);
        await store.saveVersionDependencies(version, {
          path: RouteDependency(
            path: path,
            routeId: 'products',
            tags: const ['catalog'],
            generatedAt: DateTime.now().toUtc(),
          ),
        });
        await store.publishVersion(version);
        final artifactEngine = MetaMantleServerEngine(
          routes: engine.routes,
          artifactStore: store,
          artifactMaxAge: const Duration(minutes: 5),
        );
        final response = await artifactEngine.handleRequest(
          ServerRequest(
            method: 'GET',
            uri: Uri.parse('https://example.com$path'),
          ),
        );
        expect(response.statusCode, 200);
        expect(response.body, contains('Built artifact'));
        expect(response.header('x-metamantle-cache'), 'ARTIFACT');
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('serves stale artifact and requests background regeneration', () async {
      final directory = await Directory.systemTemp.createTemp('mm-isr-');
      try {
        final store = FileHtmlArtifactStore(directory);
        const path = '/products/basmati-rice';
        final version = await store.beginVersion();
        await store.writeVersion(
          version,
          path,
          '<!doctype html><html><head></head><body>Stale product</body></html>',
        );
        final dependency = RouteDependency(
          path: path,
          routeId: 'products',
          tags: const ['catalog'],
          generatedAt: DateTime.utc(2020),
        );
        await store.saveVersionDependencies(version, {path: dependency});
        await store.publishVersion(version);
        RouteDependency? enqueued;
        final artifactEngine = MetaMantleServerEngine(
          routes: engine.routes,
          artifactStore: store,
          artifactMaxAge: const Duration(seconds: 1),
          onStaleArtifact: (requestedPath, current) async {
            expect(requestedPath, path);
            enqueued = current;
          },
        );
        final response = await artifactEngine.handleRequest(
          ServerRequest(
            method: 'GET',
            uri: Uri.parse('https://example.com$path'),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(response.statusCode, 200);
        expect(response.body, contains('Stale product'));
        expect(response.header('x-metamantle-cache'), 'STALE-ARTIFACT');
        expect(enqueued?.path, dependency.path);
        expect(enqueued?.tags, dependency.tags);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test(
      'publishes a safe artifact on an explicit route miss policy',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'mm-on-demand-artifact-',
        );
        try {
          final store = FileHtmlArtifactStore(directory);
          final route = MetaRoute<Map<String, dynamic>>(
            pattern: '/products/:slug',
            dataProvider: productProvider,
            metadataBuilder: (data, _) => WebMetadata(
              title: data['name'] as String,
              canonical: 'https://example.com/products/${data['id']}',
            ),
            htmlBuilder: (data, _) => [H.h1(data['name'] as String)],
            cachePolicy: const CachePolicy(tags: ['products']),
            artifactRouteId: 'product-pages',
            artifactMissPolicy: ArtifactMissPolicy.renderAndPublish,
          );
          final artifactEngine = MetaMantleServerEngine(
            routes: [route],
            artifactStore: store,
            artifactMaxAge: const Duration(minutes: 5),
          );

          final first = await artifactEngine.handleRequest(
            ServerRequest(
              method: 'GET',
              uri: Uri.parse('https://example.com/products/basmati-rice'),
            ),
          );
          expect(first.statusCode, 200);
          expect(first.header('x-metamantle-cache'), 'MISS-PUBLISHED');
          final dependency = (await store
              .loadDependencies())['/products/basmati-rice'];
          expect(dependency?.routeId, 'product-pages');
          expect(
            dependency?.tags,
            containsAll(['products', '/products/basmati-rice']),
          );

          productProvider.set('basmati-rice', {
            'id': '101',
            'name': 'Changed in provider',
            'description': 'Changed.',
            'price': 30,
          });
          final second = await artifactEngine.handleRequest(
            ServerRequest(
              method: 'GET',
              uri: Uri.parse('https://example.com/products/basmati-rice'),
            ),
          );
          expect(second.header('x-metamantle-cache'), 'ARTIFACT');
          expect(second.body, contains('Premium Basmati Rice'));
          expect(second.body, isNot(contains('Changed in provider')));

          final unsafe = await artifactEngine.handleRequest(
            ServerRequest(
              method: 'GET',
              uri: Uri.parse(
                'https://example.com/products/basmati-rice?preview=1',
              ),
            ),
          );
          expect(unsafe.body, contains('Changed in provider'));
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );

    test('can require a generated artifact before serving a route', () async {
      final directory = await Directory.systemTemp.createTemp(
        'mm-artifact-not-found-',
      );
      try {
        final route = MetaRoute<Map<String, dynamic>>(
          pattern: '/products/:slug',
          dataProvider: productProvider,
          metadataBuilder: (_, __) => WebMetadata(title: 'Product'),
          htmlBuilder: (_, __) => [H.h1('Provider should not run')],
          artifactMissPolicy: ArtifactMissPolicy.notFound,
        );
        final artifactEngine = MetaMantleServerEngine(
          routes: [route],
          artifactStore: FileHtmlArtifactStore(directory),
          artifactMaxAge: const Duration(minutes: 5),
        );
        final response = await artifactEngine.handleRequest(
          ServerRequest(
            method: 'GET',
            uri: Uri.parse('https://example.com/products/basmati-rice'),
          ),
        );
        expect(response.statusCode, 404);
        expect(response.body, contains('No generated artifact exists'));
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('uses an isolated artifact store for the validated tenant', () async {
      final directory = await Directory.systemTemp.createTemp(
        'mm-tenant-artifacts-',
      );
      try {
        const alpha = TenantContext(
          tenantId: 'alpha',
          name: 'Alpha',
          primaryDomain: 'alpha.example.com',
        );
        const beta = TenantContext(
          tenantId: 'beta',
          name: 'Beta',
          primaryDomain: 'beta.example.com',
        );
        const validator = TenantHostValidator(tenants: [alpha, beta]);
        final alphaStore = FileHtmlArtifactStore.forTenant(directory, 'alpha');
        final version = await alphaStore.beginVersion();
        await alphaStore.writeVersion(
          version,
          '/products/basmati-rice',
          '<!doctype html><html><body>Alpha private artifact</body></html>',
        );
        await alphaStore.saveVersionDependencies(version, {
          '/products/basmati-rice': RouteDependency(
            path: '/products/basmati-rice',
            routeId: 'products',
            tags: const ['alpha-catalog'],
            generatedAt: DateTime.now().toUtc(),
          ),
        });
        await alphaStore.publishVersion(version);

        final tenantEngine = MetaMantleServerEngine(
          routes: engine.routes,
          tenantHostValidator: validator,
          artifactStoreForTenant: (tenant) =>
              FileHtmlArtifactStore.forTenant(directory, tenant.tenantId),
          artifactMaxAge: const Duration(minutes: 5),
        );
        final alphaResponse = await tenantEngine.handleRequest(
          ServerRequest(
            method: 'GET',
            uri: Uri.parse('https://alpha.example.com/products/basmati-rice'),
            headers: const {'Host': 'alpha.example.com'},
          ),
        );
        expect(alphaResponse.header('x-metamantle-cache'), 'ARTIFACT');
        expect(alphaResponse.body, contains('Alpha private artifact'));

        final betaResponse = await tenantEngine.handleRequest(
          ServerRequest(
            method: 'GET',
            uri: Uri.parse('https://beta.example.com/products/basmati-rice'),
            headers: const {'Host': 'beta.example.com'},
          ),
        );
        expect(betaResponse.header('x-metamantle-cache'), 'MISS');
        expect(betaResponse.body, isNot(contains('Alpha private artifact')));
        expect(
          await FileHtmlArtifactStore.forTenant(
            directory,
            'beta',
          ).read('/products/basmati-rice'),
          isNull,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test(
      'returns 304 Not Modified when client provides matching ETag',
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
      },
    );

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
