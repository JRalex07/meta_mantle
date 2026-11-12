import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Caching & Concurrency Lock Tests', () {
    test('CacheEntry respects TTL, StaleWhileRevalidate, and Expired states', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);

      final entry = CacheEntry(
        html: '<h1>Hello</h1>',
        metadata: const WebMetadata(title: 'Hello'),
        createdAt: now,
        ttl: const Duration(minutes: 5),
        staleWhileRevalidate: const Duration(minutes: 10),
      );

      // At +2 min: completely fresh
      expect(entry.isFresh(now.add(const Duration(minutes: 2))), isTrue);
      expect(
        entry.isStaleWhileRevalidate(now.add(const Duration(minutes: 2))),
        isFalse,
      );
      expect(entry.isExpired(now.add(const Duration(minutes: 2))), isFalse);

      // At +8 min: stale, but within staleWhileRevalidate window (5 to 15 min)
      expect(entry.isFresh(now.add(const Duration(minutes: 8))), isFalse);
      expect(
        entry.isStaleWhileRevalidate(now.add(const Duration(minutes: 8))),
        isTrue,
      );
      expect(entry.isExpired(now.add(const Duration(minutes: 8))), isFalse);

      // At +20 min: completely expired
      expect(entry.isFresh(now.add(const Duration(minutes: 20))), isFalse);
      expect(
        entry.isStaleWhileRevalidate(now.add(const Duration(minutes: 20))),
        isFalse,
      );
      expect(entry.isExpired(now.add(const Duration(minutes: 20))), isTrue);
    });

    test(
      'MemoryCacheStore supports tag-based invalidation and tracks metrics',
      () async {
        final store = MemoryCacheStore();

        final entry1 = CacheEntry(
          html: '<p>Rice</p>',
          metadata: const WebMetadata(title: 'Rice'),
          createdAt: DateTime.now().toUtc(),
          ttl: const Duration(minutes: 10),
          tags: {'products', 'category:rice'},
        );

        final entry2 = CacheEntry(
          html: '<p>Milk</p>',
          metadata: const WebMetadata(title: 'Milk'),
          createdAt: DateTime.now().toUtc(),
          ttl: const Duration(minutes: 10),
          tags: {'products', 'category:dairy'},
        );

        await store.put('/products/rice', entry1);
        await store.put('/products/milk', entry2);

        expect(store.count, equals(2));

        // Hit rice
        final r1 = await store.get('/products/rice');
        expect(r1, isNotNull);
        expect(store.hits, equals(1));

        // Miss non-existent
        final r2 = await store.get('/products/unknown');
        expect(r2, isNull);
        expect(store.misses, equals(1));

        // Invalidate by specific tag 'category:rice'
        await store.deleteByTag('category:rice');
        expect(await store.get('/products/rice'), isNull);
        expect(await store.get('/products/milk'), isNotNull);

        // Invalidate remaining by global tag 'products'
        await store.deleteByTag('products');
        expect(await store.get('/products/milk'), isNull);
        expect(store.count, equals(0));
      },
    );

    test('SingleFlightCoordinator coalesces concurrent requests to a single execution', () async {
      final coordinator = SingleFlightCoordinator();
      var executionCount = 0;

      Future<String> expensiveDbOperation() async {
        executionCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 'data-result';
      }

      // Fire 25 concurrent invocations for the exact same key
      final futures = List.generate(
        25,
        (_) => coordinator.run('key:products:1', expensiveDbOperation),
      );

      final results = await Future.wait(futures);

      expect(results.length, equals(25));
      expect(results.every((r) => r == 'data-result'), isTrue);
      // Execution must happen strictly ONCE
      expect(executionCount, equals(1));
    });
  });
}
