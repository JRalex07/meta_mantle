import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';

void main() {
  late Directory temp;
  late FileHtmlArtifactStore store;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('metamantle-hybrid-');
    store = FileHtmlArtifactStore(Directory('${temp.path}/out'));
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('discovers pages incrementally, writes complete HTML and indexes tags', () async {
    var calls = 0;
    final source = CollectionRouteSource<int>(
      routeId: 'products',
      pathPattern: '/products/:key',
      pageSize: 2,
      discover: (cursor, limit) async {
        calls++;
        final start = int.tryParse(cursor ?? '') ?? 0;
        final items = List.generate(
          (5 - start).clamp(0, limit),
          (i) => start + i,
        );
        return RouteDiscoveryPage(
          records: items,
          nextCursor: start + items.length < 5
              ? '${start + items.length}'
              : null,
        );
      },
      keyOf: (n) => 'item-$n',
      tagsOf: (n) => ['catalog', 'product:$n'],
      versionOf: (n) => '$n',
      render: (n, path) async => GeneratedRouteDocument(
        html:
            '<!doctype html><html><head><title>$n</title></head><body><h1>$path</h1></body></html>',
      ),
    );
    final report = await HybridStaticGenerator(store: store).generate(source);
    expect((report.discovered, report.generated, calls), (5, 5, 3));
    expect(
      await store.read('/products/item-4'),
      contains('<h1>/products/item-4</h1>'),
    );
    final deps = await store.loadDependencies();
    expect(deps['/products/item-4']!.sourceVersion, '4');
    expect(deps['/products/item-4']!.tags, contains('product:4'));
    final active = await store.activeVersion;
    expect(
      await store.loadVersionTagPaths(active!, 'catalog'),
      contains('/products/item-4'),
    );
  });

  test(
    'fixed pages use versioned publication and remove obsolete route paths',
    () async {
      final generator = HybridStaticGenerator(store: store);
      await generator.generateFixedPages([
        FixedRouteSource(
          routeId: 'marketing',
          path: '/',
          render: () async => const GeneratedRouteDocument(
            html: '<!doctype html><body>Home</body>',
            tags: ['public'],
          ),
        ),
        FixedRouteSource(
          routeId: 'marketing',
          path: '/about',
          render: () async => const GeneratedRouteDocument(
            html: '<!doctype html><body>About</body>',
            tags: ['public'],
          ),
        ),
      ]);
      expect(await store.read('/'), contains('Home'));
      expect(await store.read('/about'), contains('About'));

      await generator.generateFixedPages([
        FixedRouteSource(
          routeId: 'marketing',
          path: '/',
          render: () async => const GeneratedRouteDocument(
            html: '<!doctype html><body>Home updated</body>',
          ),
        ),
      ]);
      expect(await store.read('/'), contains('Home updated'));
      expect(await store.read('/about'), isNull);
      expect((await store.loadDependencies()).keys, ['/']);
    },
  );

  test('collection initial policy supports selected and none', () async {
    final generator = HybridStaticGenerator(store: store);
    await expectLater(
      generator.generate<int>(
        CollectionRouteSource<int>(
          routeId: 'items',
          pathPattern: '/items/:key',
          initialGenerationPolicy: InitialGenerationPolicy.selected,
          discover: (_, __) async => const RouteDiscoveryPage(records: [1]),
          keyOf: (n) => '$n',
          render: (_, __) async => const GeneratedRouteDocument(
            html: '<!doctype html><body>x</body>',
          ),
        ),
      ),
      throwsArgumentError,
    );
    final selected = await generator.generate<int>(
      CollectionRouteSource<int>(
        routeId: 'items',
        pathPattern: '/items/:key',
        initialGenerationPolicy: InitialGenerationPolicy.selected,
        includeInInitialGeneration: (n) => n.isOdd,
        discover: (_, __) async => const RouteDiscoveryPage(records: [1, 2, 3]),
        keyOf: (n) => '$n',
        render: (n, _) async =>
            GeneratedRouteDocument(html: '<!doctype html><body>$n</body>'),
      ),
    );
    expect((selected.discovered, selected.generated), (3, 2));
    expect((await store.loadDependencies()).keys.toSet(), {
      '/items/1',
      '/items/3',
    });

    final none = await generator.generate<int>(
      CollectionRouteSource<int>(
        routeId: 'items',
        pathPattern: '/items/:key',
        initialGenerationPolicy: InitialGenerationPolicy.none,
        discover: (_, __) async => throw StateError('must not discover'),
        keyOf: (n) => '$n',
        render: (_, __) async =>
            const GeneratedRouteDocument(html: '<!doctype html><body/>'),
      ),
    );
    expect((none.discovered, none.generated), (0, 0));
    expect((await store.loadDependencies()).keys, isEmpty);
  });

  test(
    'sitemap follows indexability, revalidation, and route deletion',
    () async {
      final generator = HybridStaticGenerator(
        store: store,
        siteBaseUrl: 'https://shop.example/',
      );
      await generator.generateFixedPages([
        FixedRouteSource(
          routeId: 'pages',
          path: '/',
          render: () async => const GeneratedRouteDocument(
            html: '<!doctype html><body>Home</body>',
            lastModified: null,
          ),
        ),
        FixedRouteSource(
          routeId: 'pages',
          path: '/private',
          render: () async => const GeneratedRouteDocument(
            html: '<!doctype html><body>Private</body>',
            indexable: false,
          ),
        ),
      ]);
      var active = await store.activeVersion;
      var sitemap = await store.readVersionSitemap(active!);
      expect(sitemap, contains('<loc>https://shop.example/</loc>'));
      expect(sitemap, isNot(contains('/private')));

      final revalidator = HybridRevalidator(
        store: store,
        regenerate: (path, old) async => GeneratedRouteDocument(
          html: '<!doctype html><body>updated</body>',
          canonicalUrl: old.canonicalUrl,
          indexable: old.indexable,
        ),
      );
      await revalidator.revalidatePath('/');
      await revalidator.revalidatePath('/private');
      active = await store.activeVersion;
      sitemap = await store.readVersionSitemap(active!);
      expect(sitemap, contains('https://shop.example/'));
      expect(sitemap, isNot(contains('/private')));

      final publishedVersion = active;
      await expectLater(
        generator.generateFixedPages([
          FixedRouteSource(
            routeId: 'duplicate-canonical',
            path: '/one',
            render: () async => const GeneratedRouteDocument(
              html: '<!doctype html><body>One</body>',
              canonicalUrl: 'https://shop.example/shared',
            ),
          ),
          FixedRouteSource(
            routeId: 'duplicate-canonical',
            path: '/two',
            render: () async => const GeneratedRouteDocument(
              html: '<!doctype html><body>Two</body>',
              canonicalUrl: 'https://shop.example/shared',
            ),
          ),
        ]),
        throwsStateError,
      );
      expect(await store.activeVersion, publishedVersion);

      final staticOutput = Directory('${temp.path}/static-site');
      await store.exportActiveVersion(staticOutput);
      expect(
        await File('${staticOutput.path}/index.html').readAsString(),
        contains('updated'),
      );
      expect(await File('${staticOutput.path}/sitemap.xml').exists(), isTrue);
      final routeManifest = await File(
        '${staticOutput.path}/route-manifest.json',
      ).readAsString();
      expect(routeManifest, contains('https://shop.example/'));
      expect(routeManifest, contains('"path": "/"'));
      expect(
        await File('${staticOutput.path}/.meta_mantle_dependencies.json')
            .exists(),
        isFalse,
      );
      await expectLater(
        store.exportActiveVersion(
          Directory('${store.root.path}/nested-output'),
        ),
        throwsArgumentError,
      );

      await revalidator.deleteRoute('pages');
      active = await store.activeVersion;
      sitemap = await store.readVersionSitemap(active!);
      expect(sitemap, isNot(contains('https://shop.example/')));
    },
  );

  test(
    'rejects duplicate keys, invalid keys and non-HTML renderer results',
    () async {
      Future<HybridGenerationReport> run(List<String> keys, String html) =>
          HybridStaticGenerator(store: store).generate(
            CollectionRouteSource<String>(
              routeId: 'articles',
              pathPattern: '/articles/:key',
              pageSize: 10,
              discover: (_, __) async => RouteDiscoveryPage(records: keys),
              keyOf: (value) => value,
              render: (_, __) async => GeneratedRouteDocument(html: html),
            ),
          );
      await expectLater(
        run(['same', 'same'], '<!doctype html><body>x</body>'),
        throwsStateError,
      );
      await expectLater(
        run(['../escape'], '<!doctype html><body>x</body>'),
        throwsFormatException,
      );
      await expectLater(run(['ok'], '<body>partial</body>'), throwsStateError);
    },
  );

  test('rejects repeated pagination cursor', () async {
    final source = CollectionRouteSource<int>(
      routeId: 'r',
      pathPattern: '/r/:key',
      discover: (cursor, _) async =>
          RouteDiscoveryPage(records: const [], nextCursor: 'again'),
      keyOf: (n) => '$n',
      render: (_, __) async =>
          const GeneratedRouteDocument(html: '<!doctype html><body></body>'),
    );
    // First cursor is null, then a non-null cursor that must not repeat itself.
    await expectLater(
      HybridStaticGenerator(store: store).generate(source),
      throwsStateError,
    );
  });

  test('rejects traversal and only reads within the configured root', () async {
    await expectLater(store.read('/../secrets'), throwsFormatException);
    await expectLater(
      store.write('/a/../../secrets', 'x'),
      throwsFormatException,
    );
  });

  test('tag revalidation regenerates only associated paths', () async {
    final source = CollectionRouteSource<int>(
      routeId: 'items',
      pathPattern: '/items/:key',
      discover: (_, __) async => const RouteDiscoveryPage(records: [1, 2]),
      keyOf: (n) => '$n',
      tagsOf: (n) => n == 1 ? ['catalog'] : ['other'],
      render: (n, _) async => GeneratedRouteDocument(
        html: '<!doctype html><body>$n</body>',
        tags: const [],
      ),
    );
    await HybridStaticGenerator(store: store).generate(source);
    final regenerated = <String>[];
    final revalidator = HybridRevalidator(
      store: store,
      regenerate: (path, _) async {
        regenerated.add(path);
        return GeneratedRouteDocument(
          html: '<!doctype html><body>new $path</body>',
          tags: ['updated:$path'],
          sourceVersion: 'updated',
        );
      },
    );
    expect(await revalidator.revalidateTag('catalog'), ['/items/1']);
    expect(regenerated, ['/items/1']);
    expect(await store.read('/items/1'), contains('new /items/1'));
    expect(await store.read('/items/2'), contains('<body>2</body>'));
    expect((await store.loadDependencies())['/items/1']!.tags, [
      'updated:/items/1',
    ]);
    expect(await revalidator.revalidateTag('catalog'), isEmpty);
  });

  test('older source versions cannot replace a newer publication', () async {
    await HybridStaticGenerator(store: store).generate<int>(
      CollectionRouteSource<int>(
        routeId: 'products',
        pathPattern: '/products/:key',
        discover: (_, __) async => const RouteDiscoveryPage(records: [1]),
        keyOf: (n) => '$n',
        versionOf: (_) => '10',
        render: (_, __) async => const GeneratedRouteDocument(
          html: '<!doctype html><body>version 10</body>',
        ),
      ),
    );
    final publishedVersion = await store.activeVersion;
    final revalidator = HybridRevalidator(
      store: store,
      compareSourceVersions: (candidate, current) =>
          int.parse(candidate).compareTo(int.parse(current)),
      regenerate: (_, __) async => const GeneratedRouteDocument(
        html: '<!doctype html><body>version 9</body>',
        sourceVersion: '9',
      ),
    );

    await expectLater(
      revalidator.revalidatePath('/products/1'),
      throwsA(isA<StaleGeneratedDocumentException>()),
    );
    expect(await store.activeVersion, publishedVersion);
    expect(await store.read('/products/1'), contains('version 10'));
    expect(
      (await store.loadDependencies())['/products/1']!.sourceVersion,
      '10',
    );
  });

  test(
    'revalidation draft cannot publish after a concurrent newer update',
    () async {
      await HybridStaticGenerator(store: store).generate<int>(
        CollectionRouteSource<int>(
          routeId: 'products',
          pathPattern: '/products/:key',
          discover: (_, __) async => const RouteDiscoveryPage(records: [1]),
          keyOf: (n) => '$n',
          tagsOf: (_) => const ['product:1'],
          versionOf: (_) => '1',
          render: (_, __) async => const GeneratedRouteDocument(
            html: '<!doctype html><body>version 1</body>',
          ),
        ),
      );
      final enteredOldRender = Completer<void>();
      final releaseOldRender = Completer<void>();
      final olderRevalidation = HybridRevalidator(
        store: store,
        regenerate: (_, __) async {
          enteredOldRender.complete();
          await releaseOldRender.future;
          return const GeneratedRouteDocument(
            html: '<!doctype html><body>version 2</body>',
            sourceVersion: '2',
          );
        },
      );
      final olderResult = olderRevalidation.revalidateTag('product:1');
      await enteredOldRender.future;

      final newerRevalidation = HybridRevalidator(
        store: store,
        regenerate: (_, __) async => const GeneratedRouteDocument(
          html: '<!doctype html><body>version 3</body>',
          sourceVersion: '3',
        ),
      );
      await newerRevalidation.revalidatePath('/products/1');
      releaseOldRender.complete();

      await expectLater(
        olderResult,
        throwsA(isA<StaleArtifactVersionException>()),
      );
      expect(await store.read('/products/1'), contains('version 3'));
      expect(
        (await store.loadDependencies())['/products/1']!.sourceVersion,
        '3',
      );
    },
  );

  test('route revalidation is indexed and route deletion is atomic', () async {
    final generator = HybridStaticGenerator(store: store);
    await generator.generate<int>(
      CollectionRouteSource<int>(
        routeId: 'products',
        pathPattern: '/products/:key',
        discover: (_, __) async => const RouteDiscoveryPage(records: [1, 2]),
        keyOf: (n) => '$n',
        render: (n, _) async => GeneratedRouteDocument(
          html: '<!doctype html><body>product $n</body>',
        ),
      ),
    );
    await generator.generate<int>(
      CollectionRouteSource<int>(
        routeId: 'articles',
        pathPattern: '/articles/:key',
        discover: (_, __) async => const RouteDiscoveryPage(records: [3]),
        keyOf: (n) => '$n',
        render: (n, _) async => GeneratedRouteDocument(
          html: '<!doctype html><body>article $n</body>',
        ),
      ),
    );
    final active = await store.activeVersion;
    expect(await store.loadVersionRoutePaths(active!, 'products'), [
      '/products/1',
      '/products/2',
    ]);
    final refreshed = <String>[];
    final revalidator = HybridRevalidator(
      store: store,
      regenerate: (path, old) async {
        refreshed.add(path);
        return GeneratedRouteDocument(
          html: '<!doctype html><body>updated $path</body>',
          tags: old.tags,
        );
      },
    );
    expect(await revalidator.revalidateRoute('products'), [
      '/products/1',
      '/products/2',
    ]);
    expect(refreshed, ['/products/1', '/products/2']);
    expect(await revalidator.deleteRoute('products'), [
      '/products/1',
      '/products/2',
    ]);
    expect(await store.read('/products/1'), isNull);
    expect((await store.loadDependencies()).keys, ['/articles/3']);
  });

  test(
    'atomic replacement leaves the new complete document readable',
    () async {
      await store.write('/page', '<!doctype html><body>old</body>');
      await store.write('/page', '<!doctype html><body>new</body>');
      expect(await store.read('/page'), '<!doctype html><body>new</body>');
    },
  );

  test('failed generation keeps previous active artifact and index', () async {
    final generator = HybridStaticGenerator(store: store);
    await generator.generate<int>(
      CollectionRouteSource<int>(
        routeId: 'r',
        pathPattern: '/r/:key',
        discover: (_, __) async => const RouteDiscoveryPage(records: [1]),
        keyOf: (n) => '$n',
        render: (_, __) async => const GeneratedRouteDocument(
          html: '<!doctype html><body>old</body>',
        ),
      ),
    );
    final oldVersion = await store.activeVersion;
    await expectLater(
      generator.generate<int>(
        CollectionRouteSource<int>(
          routeId: 'r',
          pathPattern: '/r/:key',
          pageSize: 2,
          discover: (_, __) async => const RouteDiscoveryPage(records: [1, 2]),
          keyOf: (n) => '$n',
          render: (n, _) async {
            if (n == 2) throw StateError('render failed');
            return const GeneratedRouteDocument(
              html: '<!doctype html><body>new</body>',
            );
          },
        ),
      ),
      throwsStateError,
    );
    expect(await store.activeVersion, oldVersion);
    expect(await store.read('/r/1'), contains('old'));
    expect((await store.loadDependencies()).keys, ['/r/1']);
  });

  test(
    'active version can be atomically switched after a successful build',
    () async {
      final first = await store.beginVersion();
      await store.writeVersion(
        first,
        '/page',
        '<!doctype html><body>one</body>',
      );
      await store.publishVersion(first);
      final second = await store.beginVersion();
      await store.writeVersion(
        second,
        '/page',
        '<!doctype html><body>two</body>',
      );
      await store.publishVersion(second);
      expect(await store.activeVersion, second);
      expect(await store.read('/page'), contains('two'));
    },
  );

  test(
    'published HTML and dependency snapshot remain version-consistent',
    () async {
      final first = await store.beginVersion();
      await store.writeVersion(
        first,
        '/page',
        '<!doctype html><body>version one</body>',
      );
      await store.saveVersionDependencies(first, {
        '/page': RouteDependency(
          path: '/page',
          routeId: 'page',
          tags: const ['v1'],
          generatedAt: DateTime.utc(2026, 1, 1),
        ),
      });
      await store.publishVersion(first);
      final snapshot = await store.readPublished('/page');

      final second = await store.beginVersion();
      await store.writeVersion(
        second,
        '/page',
        '<!doctype html><body>version two</body>',
      );
      await store.saveVersionDependencies(second, {
        '/page': RouteDependency(
          path: '/page',
          routeId: 'page',
          tags: const ['v2'],
          generatedAt: DateTime.utc(2026, 1, 2),
        ),
      });
      await store.publishVersion(second);

      expect(snapshot!.html, contains('version one'));
      expect(snapshot.dependency.tags, ['v1']);
      expect(
        (await store.readPublished('/page'))!.html,
        contains('version two'),
      );
    },
  );

  test(
    'first versioned generation preserves legacy artifacts and index',
    () async {
      await store.write('/legacy', '<!doctype html><body>legacy</body>');
      await store.saveDependencies({
        '/legacy': RouteDependency(
          path: '/legacy',
          routeId: 'legacy-route',
          tags: const ['legacy-tag'],
          generatedAt: DateTime.utc(2026, 1, 1),
        ),
      });
      await HybridStaticGenerator(store: store).generate<int>(
        CollectionRouteSource<int>(
          routeId: 'new-route',
          pathPattern: '/new/:key',
          discover: (_, __) async => const RouteDiscoveryPage(records: [1]),
          keyOf: (n) => '$n',
          render: (_, __) async => const GeneratedRouteDocument(
            html: '<!doctype html><body>new</body>',
          ),
        ),
      );
      expect(await store.read('/legacy'), contains('legacy'));
      expect((await store.loadDependencies()).keys, contains('/legacy'));
      final active = await store.activeVersion;
      expect(await store.loadVersionTagPaths(active!, 'legacy-tag'), [
        '/legacy',
      ]);
    },
  );

  test('rejects an older draft after a newer draft publishes', () async {
    final older = await store.beginVersion();
    final newer = await store.beginVersion();
    await store.writeVersion(older, '/page', '<!doctype html><body>old</body>');
    await store.writeVersion(newer, '/page', '<!doctype html><body>new</body>');
    await store.publishVersion(newer);
    await expectLater(
      store.publishVersion(older),
      throwsA(isA<StaleArtifactVersionException>()),
    );
    expect(await store.read('/page'), contains('new'));
    await store.discardVersion(older);
  });
}
