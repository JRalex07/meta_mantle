import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Publication Fencing & Monotonic Epoch Tests', () {
    late Directory temp;
    late FileHtmlArtifactStore store;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mm-fencing-test-');
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

    test(
        'rejects publication from stale worker when a higher epoch has already published',
        () async {
      // 1. Worker A begins draft A with fencing epoch 43
      final versionA = await store.beginVersion();
      await store.writeVersion(
        versionA,
        '/blog/post-1',
        '<!doctype html><body>Post 1 from Worker A (epoch 43)</body>',
      );
      await store.saveVersionDependencies(versionA, {
        '/blog/post-1': RouteDependency(
          path: '/blog/post-1',
          routeId: 'blog',
          tags: ['blog'],
          generatedAt: DateTime.utc(2026, 1, 1),
        ),
      });

      // 2. Worker B begins draft B with fencing epoch 44
      final versionB = await store.beginVersion();
      await store.writeVersion(
        versionB,
        '/blog/post-1',
        '<!doctype html><body>Post 1 from Worker B (epoch 44)</body>',
      );
      await store.saveVersionDependencies(versionB, {
        '/blog/post-1': RouteDependency(
          path: '/blog/post-1',
          routeId: 'blog',
          tags: ['blog'],
          generatedAt: DateTime.utc(2026, 1, 1, 0, 1),
        ),
      });

      // 3. Worker B publishes successfully with epoch 44
      await store.publishVersion(
        versionB,
        fencingEpoch: 44,
        routePath: '/blog/post-1',
      );

      expect(await store.activeVersion, versionB);
      expect(
        await store.read('/blog/post-1'),
        contains('Worker B (epoch 44)'),
      );

      // 4. Worker A wakes up and attempts to publish with stale epoch 43
      expect(
        () => store.publishVersion(
          versionA,
          fencingEpoch: 43,
          routePath: '/blog/post-1',
        ),
        throwsA(isA<StaleFencingEpochException>()
            .having(
              (e) => e.candidateEpoch,
              'candidateEpoch',
              43,
            )
            .having(
              (e) => e.currentEpoch,
              'currentEpoch',
              44,
            )),
      );

      // 5. Version B remains the active published version intact
      expect(await store.activeVersion, versionB);
      expect(
        await store.read('/blog/post-1'),
        contains('Worker B (epoch 44)'),
      );
    });

    test('monotonic epoch sequence succeeds when epochs increase', () async {
      // Epoch 10
      final v1 = await store.beginVersion();
      await store.writeVersion(v1, '/page', '<!doctype html><body>v1</body>');
      await store.saveVersionDependencies(v1, {
        '/page': RouteDependency(
          path: '/page',
          routeId: 'p',
          tags: [],
          generatedAt: DateTime.utc(2026, 1, 1),
        ),
      });
      await store.publishVersion(v1, fencingEpoch: 10, routePath: '/page');
      expect(await store.activeVersion, v1);

      // Epoch 11
      final v2 = await store.beginVersion();
      await store.writeVersion(v2, '/page', '<!doctype html><body>v2</body>');
      await store.saveVersionDependencies(v2, {
        '/page': RouteDependency(
          path: '/page',
          routeId: 'p',
          tags: [],
          generatedAt: DateTime.utc(2026, 1, 1, 1),
        ),
      });
      await store.publishVersion(v2, fencingEpoch: 11, routePath: '/page');
      expect(await store.activeVersion, v2);

      // Trying equal epoch 11 again is rejected (must be strictly monotonic or newer)
      final v3 = await store.beginVersion();
      await store.writeVersion(v3, '/page', '<!doctype html><body>v3</body>');
      await store.saveVersionDependencies(v3, {
        '/page': RouteDependency(
          path: '/page',
          routeId: 'p',
          tags: [],
          generatedAt: DateTime.utc(2026, 1, 1, 2),
        ),
      });
      // fencingEpoch < currentEpoch: 10 < 11 throws
      expect(
        () => store.publishVersion(v3, fencingEpoch: 10, routePath: '/page'),
        throwsA(isA<StaleFencingEpochException>()),
      );
    });
  });
}
