import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

class _FailingLockProvider implements DistributedLockProvider {
  @override
  Future<String?> acquire(
    String resource, {
    Duration ttl = const Duration(seconds: 10),
  }) async {
    return null; // Always fails to acquire
  }

  @override
  Future<bool> release(String resource, String lockToken) async => true;
}

void main() {
  group('True LRU Cache & Distributed Locking Tests', () {
    test(
      'MemoryCacheStore implements true access-order LRU eviction',
      () async {
        final store = MemoryCacheStore(maxEntries: 3);

        final entryA = CacheEntry(
          html: '<html>A</html>',
          metadata: const WebMetadata(title: 'A'),
          createdAt: DateTime.now().toUtc(),
          ttl: const Duration(minutes: 5),
        );
        final entryB = CacheEntry(
          html: '<html>B</html>',
          metadata: const WebMetadata(title: 'B'),
          createdAt: DateTime.now().toUtc(),
          ttl: const Duration(minutes: 5),
        );
        final entryC = CacheEntry(
          html: '<html>C</html>',
          metadata: const WebMetadata(title: 'C'),
          createdAt: DateTime.now().toUtc(),
          ttl: const Duration(minutes: 5),
        );
        final entryD = CacheEntry(
          html: '<html>D</html>',
          metadata: const WebMetadata(title: 'D'),
          createdAt: DateTime.now().toUtc(),
          ttl: const Duration(minutes: 5),
        );

        // Insert A, B, C (Store full: [A, B, C])
        await store.put('keyA', entryA);
        await store.put('keyB', entryB);
        await store.put('keyC', entryC);

        // Access keyA! In True LRU, accessing A moves A to the tail ([B, C, A])
        final hitA = await store.get('keyA');
        expect(hitA, isNotNull);
        expect(hitA!.html, equals('<html>A</html>'));

        // Now insert D. If FIFO, A would be evicted. But in True LRU, B is the least recently used!
        await store.put('keyD', entryD);

        // B must be evicted
        expect(await store.get('keyB'), isNull);
        // A, C, D must still exist!
        expect(await store.get('keyA'), isNotNull);
        expect(await store.get('keyC'), isNotNull);
        expect(await store.get('keyD'), isNotNull);

        expect(store.evictions, equals(1));
        expect(store.hitRatio, greaterThan(0.0));
      },
    );

    test(
      'SingleFlightCoordinator throws DistributedLockException on lock failure',
      () async {
        final coordinator = SingleFlightCoordinator(
          distributedLock: _FailingLockProvider(),
        );

        expect(
          coordinator.run('test-resource', () async => 'success'),
          throwsA(isA<DistributedLockException>()),
        );
      },
    );

    test(
      'ServerEngine serves STALE-IF-ERROR fallback when origin re-render fails',
      () async {
        final cacheStore = MemoryCacheStore(maxEntries: 100);
        var failOrigin = false;

        final route = MetaRoute<String>(
          pattern: '/flaky-product',
          dataProvider: MockCallbackProvider<String>((ctx) async {
            if (failOrigin) {
              throw StateError('Database connection dropped!');
            }
            return DataProviderResult<String>.found(
              'Fresh Product Data',
              etag: 'w/"v1"',
            );
          }),
          metadataBuilder: (data, ctx) => WebMetadata(title: data),
          htmlBuilder: (data, ctx) => [H.h1(data)],
          cachePolicy: const CachePolicy(
            ttl: Duration(milliseconds: 40),
            staleWhileRevalidate: Duration(milliseconds: 60),
            staleIfError: Duration(hours: 1),
          ),
        );

        final engine = MetaMantleServerEngine(
          routes: [route],
          cacheStore: cacheStore,
        );

        final req = ServerRequest(
          method: 'GET',
          uri: Uri.parse('https://example.com/flaky-product'),
        );

        // 1. Initial fresh request (MISS)
        final res1 = await engine.handleRequest(req);
        expect(res1.statusCode, equals(200));
        expect(res1.headers['X-MetaMantle-Cache'], equals('MISS'));
        expect(res1.body, contains('<h1>Fresh Product Data</h1>'));

        // Wait for both TTL (40ms) and SWR (60ms) to expire (> 100ms)
        await Future<void>.delayed(const Duration(milliseconds: 130));

        // 2. Simulate origin failure
        failOrigin = true;

        // 3. Stale-If-Error request must gracefully serve stale content instead of 500 error!
        final res2 = await engine.handleRequest(req);
        expect(res2.statusCode, equals(200));
        expect(res2.headers['X-MetaMantle-Cache'], equals('STALE-IF-ERROR'));
        expect(res2.body, contains('<h1>Fresh Product Data</h1>'));
      },
    );

    test('ServerEngine isolates cache keys across tenants, hosts, and locales', () async {
      final cacheStore = MemoryCacheStore(maxEntries: 100);

      final route = MetaRoute<String>(
        pattern: '/localized-page',
        dataProvider: MockCallbackProvider<String>((ctx) async {
          final tenant = ctx.headers['x-tenant-id'] ?? 'public';
          final locale = ctx.headers['accept-language'] ?? 'en';
          return DataProviderResult<String>.found(
            'Rendered for $tenant in $locale',
          );
        }),
        metadataBuilder: (data, ctx) => WebMetadata(title: data),
        htmlBuilder: (data, ctx) => [H.h1(data)],
        cachePolicy: const CachePolicy(ttl: Duration(minutes: 10)),
      );

      final engine = MetaMantleServerEngine(
        routes: [route],
        cacheStore: cacheStore,
      );

      // Tenant 1 request
      final reqTenant1 = ServerRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com/localized-page'),
        headers: {'x-tenant-id': 'tenant-alpha', 'accept-language': 'en'},
      );
      final resTenant1 = await engine.handleRequest(reqTenant1);
      expect(resTenant1.body, contains('Rendered for tenant-alpha in en'));

      // Tenant 2 request on same URL path must NOT hit Tenant 1 cached response
      final reqTenant2 = ServerRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com/localized-page'),
        headers: {'x-tenant-id': 'tenant-beta', 'accept-language': 'fr'},
      );
      final resTenant2 = await engine.handleRequest(reqTenant2);
      expect(resTenant2.body, contains('Rendered for tenant-beta in fr'));
      expect(resTenant2.body, isNot(contains('tenant-alpha')));
    });
  });

  group('Unified SEO Policy Engine Tests', () {
    const resolver = SeoPolicyResolver();

    test('Resolves 7-tier hierarchy and tracks field provenance', () {
      const globalPolicy = SeoPolicy(
        tier: PolicyTier.global,
        name: 'Global',
        titleTemplate: '%s | Global Brand',
        defaultTitle: 'Default Brand Title',
        defaultDescription: 'Global brand description',
        canonicalBaseUrl: 'https://brand.com',
        enforceTrailingSlash: true,
        defaultRobots: RobotsDirective.indexFollow,
        defaultImage: 'https://brand.com/default.png',
      );

      const sectionPolicy = SeoPolicy(
        tier: PolicyTier.section,
        name: 'StoreSection',
        titleTemplate: '%s | Brand Store',
        defaultDescription: 'Shop our curated collection',
      );

      const pageMetadata = WebMetadata(title: 'Wireless Headphones');

      final resolved = resolver.resolve(
        global: globalPolicy,
        section: sectionPolicy,
        page: pageMetadata,
        currentPath: '/products/headphones',
      );

      final meta = resolved.metadata;
      final prov = resolved.provenance;

      // Page provides raw title, section template applies '%s | Brand Store'
      expect(meta.title, equals('Wireless Headphones | Brand Store'));
      expect(prov.originOf('title'), equals(PolicyTier.page));

      // Description falls back to Section default
      expect(meta.description, equals('Shop our curated collection'));
      expect(prov.originOf('description'), equals(PolicyTier.section));

      // Canonical inherited from Global base URL with trailing slash
      expect(meta.canonical, equals('https://brand.com/products/headphones/'));
      expect(prov.originOf('canonical'), equals(PolicyTier.global));

      // Social Image fallback to Global
      expect(meta.openGraph?.image, equals('https://brand.com/default.png'));
      expect(prov.originOf('openGraph.image'), equals(PolicyTier.global));
    });

    test('Ancestral forceNoindex propagates and reports conflict', () {
      const tenantPolicy = SeoPolicy(
        tier: PolicyTier.tenant,
        name: 'PrivateTenant',
        forceNoindex: true,
      );

      const pageMetadata = WebMetadata(
        title: 'Public Page',
        robots: RobotsDirective.indexFollow,
      );

      final resolved = resolver.resolve(
        tenant: tenantPolicy,
        page: pageMetadata,
      );

      expect(resolved.metadata.robots, contains('noindex'));
      expect(resolved.provenance.conflicts, isNotEmpty);
      expect(
        resolved.provenance.conflicts.first,
        contains('ancestor policy enforced forceNoindex=true'),
      );
    });
  });
}

class MockCallbackProvider<T> implements MetaMantleDataProvider<T> {
  const MockCallbackProvider(this.callback);
  final Future<DataProviderResult<T>> Function(RouteDataContext context)
  callback;

  @override
  Future<DataProviderResult<T>> load(RouteDataContext context) =>
      callback(context);
}
