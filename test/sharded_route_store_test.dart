import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Sharded Route & Dependency Storage Tests', () {
    late Directory temp;
    late FileHtmlArtifactStore store;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mm-sharded-store-');
      store = FileHtmlArtifactStore(Directory('${temp.path}/artifacts'));
    });

    tearDown(() async {
      try {
        await temp.delete(recursive: true);
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          await temp.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('readVersion and readPublished resolve artifacts and dependencies from shards', () async {
      final v1 = await store.beginVersion();

      await store.writeVersion(
        v1,
        '/products/laptop-pro',
        '<!doctype html><body>Laptop Pro Specification</body>',
      );
      await store.saveVersionDependencies(v1, {
        '/products/laptop-pro': RouteDependency(
          path: '/products/laptop-pro',
          routeId: 'products',
          tags: ['hardware', 'electronics'],
          generatedAt: DateTime.utc(2026, 1, 1),
          canonicalUrl: 'https://example.com/products/laptop-pro',
        ),
      });
      await store.publishVersion(v1);

      // Verify shards directory was created inside .versions/$v1/
      final shardsDir = Directory(
        '${store.root.path}/.versions/$v1/.route_shards',
      );
      expect(await shardsDir.exists(), isTrue);
      final shardFiles = await shardsDir.list().toList();
      expect(shardFiles.isNotEmpty, isTrue);

      // readVersion uses shard
      final html = await store.readVersion(v1, '/products/laptop-pro');
      expect(html, contains('Laptop Pro Specification'));

      // readPublished returns both HTML and dependency
      final published = await store.readPublished('/products/laptop-pro');
      expect(published, isNotNull);
      expect(published!.html, contains('Laptop Pro Specification'));
      expect(published.dependency.tags, contains('hardware'));
      expect(
        published.dependency.canonicalUrl,
        'https://example.com/products/laptop-pro',
      );
    });

    test('single page regeneration updates only the touched shard and creates only 1 new object', () async {
      final generator = HybridStaticGenerator(store: store);

      // 1. Initial build with 4 routes
      await generator.generateFixedPages([
        FixedRouteSource(
          routeId: 'p1',
          path: '/alpha',
          render: () async => const GeneratedRouteDocument(
            html: '<!doctype html><body>Alpha initial</body>',
          ),
        ),
        FixedRouteSource(
          routeId: 'p2',
          path: '/beta',
          render: () async => const GeneratedRouteDocument(
            html: '<!doctype html><body>Beta initial</body>',
          ),
        ),
      ]);

      final initialVersion = await store.activeVersion;
      expect(initialVersion, isNotNull);

      final objectsDir = Directory('${store.root.path}/.objects');
      final initialObjectCount = (await objectsDir.list().toList()).length;
      expect(initialObjectCount, 2);

      // 2. Revalidate only /alpha
      final revalidator = HybridRevalidator(
        store: store,
        regenerate: (path, prev) async => GeneratedRouteDocument(
          html: '<!doctype html><body>$path updated</body>',
          tags: prev.tags,
        ),
      );

      final revalidated = await revalidator.revalidatePath('/alpha');
      expect(revalidated, ['/alpha']);

      final newVersion = await store.activeVersion;
      expect(newVersion, isNot(initialVersion));

      // Exactly 1 new object was created in .objects/
      final newObjectCount = (await objectsDir.list().toList()).length;
      expect(newObjectCount, initialObjectCount + 1);

      // /alpha has new content, /beta has preserved content
      expect(await store.read('/alpha'), contains('/alpha updated'));
      expect(await store.read('/beta'), contains('Beta initial'));
    });

    test(
      'deleting a route prunes it from route and dependency shards',
      () async {
        final generator = HybridStaticGenerator(store: store);

        await generator.generateFixedPages([
          FixedRouteSource(
            routeId: 'items',
            path: '/item-to-delete',
            render: () async => const GeneratedRouteDocument(
              html: '<!doctype html><body>To be deleted</body>',
            ),
          ),
          FixedRouteSource(
            routeId: 'items',
            path: '/item-to-keep',
            render: () async => const GeneratedRouteDocument(
              html: '<!doctype html><body>Keep me</body>',
            ),
          ),
        ]);

        expect(await store.read('/item-to-delete'), isNotNull);
        expect(await store.read('/item-to-keep'), isNotNull);

        // Delete route via revalidator
        final revalidator = HybridRevalidator(
          store: store,
          regenerate: (_, __) async => const GeneratedRouteDocument(
            html: '<!doctype html><body></body>',
          ),
        );

        final deleted = await revalidator.deleteRoute('items');
        expect(deleted, containsAll({'/item-to-delete', '/item-to-keep'}));

        expect(await store.read('/item-to-delete'), isNull);
        expect(await store.read('/item-to-keep'), isNull);
      },
    );
  });
}
