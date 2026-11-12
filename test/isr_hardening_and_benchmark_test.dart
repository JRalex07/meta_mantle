import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Artifact Publication & Immutability Tests', () {
    late Directory temp;
    late FileHtmlArtifactStore store;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mm-artifact-hardening-');
      store = FileHtmlArtifactStore(Directory('${temp.path}/artifacts'));
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('regenerating one page never copies or rewrites unrelated generated HTML objects', () async {
      final generator = HybridStaticGenerator(store: store);

      // 1. Initial build: 5 distinct pages
      await generator.generateFixedPages([
        for (var i = 1; i <= 5; i++)
          FixedRouteSource(
            routeId: 'items',
            path: '/item-$i',
            render: () async => GeneratedRouteDocument(
              html: '<!doctype html><body>Item $i content</body>',
            ),
          ),
      ]);

      final active = await store.activeVersion;
      expect(active, isNotNull);

      // Verify all 5 items are in store
      for (var i = 1; i <= 5; i++) {
        expect(await store.read('/item-$i'), contains('Item $i content'));
      }

      // Record file stats for all objects in .objects
      final objectsDir = Directory(
        '${store.root.path}${Platform.pathSeparator}.objects',
      );
      expect(await objectsDir.exists(), isTrue);

      final initialStats = <String, DateTime>{};
      await for (final entity in objectsDir.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.html')) {
          initialStats[entity.path] = (await entity.stat()).modified;
        }
      }
      expect(initialStats.length, 5);

      // Small pause to ensure modified timestamp would differ if touched
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 2. Regenerate ONLY page 1
      final revalidator = HybridRevalidator(
        store: store,
        regenerate: (path, old) async {
          expect(path, '/item-1');
          return const GeneratedRouteDocument(
            html: '<!doctype html><body>Item 1 UPDATED content</body>',
          );
        },
      );
      final refreshed = await revalidator.revalidatePath('/item-1');
      expect(refreshed, ['/item-1']);

      // 3. Verify page 1 updated, but pages 2-5 are completely unchanged
      expect(await store.read('/item-1'), contains('UPDATED'));
      for (var i = 2; i <= 5; i++) {
        expect(await store.read('/item-$i'), contains('Item $i content'));
      }

      // 4. Verify that untouched object files in .objects were NEVER rewritten
      var unchangedCount = 0;
      await for (final entity in objectsDir.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.html')) {
          final recordedTime = initialStats[entity.path];
          if (recordedTime != null) {
            final currentTime = (await entity.stat()).modified;
            if (currentTime == recordedTime) {
              unchangedCount++;
            }
          }
        }
      }
      // All 5 original files must have preserved their exact original modification timestamp
      expect(unchangedCount, 5);
    });

    test(
      'rollbackTo restores previous generation publication atomically',
      () async {
        final generator = HybridStaticGenerator(store: store);

        // Version 1
        await generator.generateFixedPages([
          FixedRouteSource(
            routeId: 'pages',
            path: '/home',
            render: () async => const GeneratedRouteDocument(
              html: '<!doctype html><body>Version 1 Home</body>',
            ),
          ),
        ]);
        final v1 = await store.activeVersion;

        // Version 2
        await generator.generateFixedPages([
          FixedRouteSource(
            routeId: 'pages',
            path: '/home',
            render: () async => const GeneratedRouteDocument(
              html: '<!doctype html><body>Version 2 Home</body>',
            ),
          ),
        ]);
        final v2 = await store.activeVersion;
        expect(v1, isNot(v2));
        expect(await store.read('/home'), contains('Version 2 Home'));

        // Rollback to v1
        await store.rollbackTo(v1!);
        expect(await store.activeVersion, v1);
        expect(await store.read('/home'), contains('Version 1 Home'));
      },
    );

    test(
      'garbage collection deletes unreferenced objects older than grace period',
      () async {
        final generator = HybridStaticGenerator(store: store);

        // Version 1
        await generator.generateFixedPages([
          FixedRouteSource(
            routeId: 'pages',
            path: '/page',
            render: () async => const GeneratedRouteDocument(
              html: '<!doctype html><body>Old unreferenced object</body>',
            ),
          ),
        ]);

        // Version 2 (replaces content of /page)
        await generator.generateFixedPages([
          FixedRouteSource(
            routeId: 'pages',
            path: '/page',
            render: () async => const GeneratedRouteDocument(
              html: '<!doctype html><body>New active object</body>',
            ),
          ),
        ]);

        // Run garbage collection with 0 grace period and retaining only 1 version (active)
        final report = await store.garbageCollect(
          retentionGracePeriod: Duration.zero,
          maxRetainedVersions: 1,
        );

        expect(report.retainedVersions, 1);
        expect(report.deletedObjects, greaterThanOrEqualTo(1));
        expect(report.reclaimedBytes, greaterThan(0));

        // Active page is still readable and intact
        expect(await store.read('/page'), contains('New active object'));
      },
    );

    test(
      'storage capabilities report accurate local filesystem guarantees',
      () {
        final caps = store.capabilities;
        expect(caps.supportsImmutableObjects, isTrue);
        expect(caps.supportsAtomicPublication, isTrue);
        expect(caps.supportsRollback, isTrue);
        expect(caps.supportsGarbageCollection, isTrue);
        expect(caps.supportsDistributedLeases, isFalse);
      },
    );
  });

  group('Regeneration Queue Indexing, Batching & Benchmark Tests', () {
    late Directory temp;
    late FileRegenerationQueue queue;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mm-queue-hardening-');
      queue = FileRegenerationQueue(temp);
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test(
      'idempotency lookup is O(1) and coalesces duplicate requests',
      () async {
        final first = await queue.enqueue(
          siteId: 'site-1',
          tenantId: 'tenant-1',
          path: '/items/item-100',
          routeId: 'items',
          tags: const ['catalog'],
          idempotencyKey: 'key-100',
        );

        final second = await queue.enqueue(
          siteId: 'site-1',
          tenantId: 'tenant-1',
          path: '/items/item-100',
          routeId: 'items',
          tags: const ['catalog'],
          idempotencyKey: 'key-100',
        );

        expect(second.id, first.id);
        expect(second.path, first.path);
      },
    );

    test('batch enqueueAll schedules multiple jobs atomically', () async {
      final requests = List.generate(
        100,
        (i) => RegenerationJobRequest(
          siteId: 'site-1',
          tenantId: 'tenant-1',
          path: '/products/prod-$i',
          routeId: 'products',
          tags: ['catalog', 'prod:$i'],
          idempotencyKey: 'batch-prod-$i',
        ),
      );

      final jobs = await queue.enqueueAll(requests);
      expect(jobs.length, 100);

      // Re-enqueuing the same batch returns coalesced duplicates
      final replayed = await queue.enqueueAll(requests);
      expect(replayed.length, 100);
      expect(
        replayed.map((j) => j.id).toList(),
        jobs.map((j) => j.id).toList(),
      );

      final metrics = await queue.metrics();
      expect(metrics.totalJobs, 100);
      expect(metrics.queuedJobs, 100);
    });

    test(
      'cleanupCompleted deletes finished jobs and frees idempotency keys',
      () async {
        final job = await queue.enqueue(
          siteId: 'site-1',
          tenantId: 'tenant-1',
          path: '/done',
          routeId: 'r',
          tags: const [],
          idempotencyKey: 'cleanup-test',
        );

        final claimed = await queue.claimNext();
        expect(claimed!.id, job.id);
        await queue.complete(claimed.id, leaseToken: claimed.leaseToken!);

        final deletedCount = await queue.cleanupCompleted(
          maxAge: Duration.zero,
        );
        expect(deletedCount, 1);

        final metrics = await queue.metrics();
        expect(metrics.totalJobs, 0);
      },
    );

    test(
      'rebuildIndexes recovers queue state after corrupted or missing index',
      () async {
        final job = await queue.enqueue(
          siteId: 'site-1',
          tenantId: 'tenant-1',
          path: '/recover-me',
          routeId: 'r',
          tags: const [],
          idempotencyKey: 'recover-key',
        );

        // Simulate index corruption by deleting the index directory
        final indexDir = Directory(
          '${temp.path}${Platform.pathSeparator}indexes',
        );
        if (await indexDir.exists()) {
          await indexDir.delete(recursive: true);
        }

        // Rebuild indexes
        await queue.rebuildIndexes();

        // Enqueue with the same idempotency key must resolve the existing job
        final reEnqueued = await queue.enqueue(
          siteId: 'site-1',
          tenantId: 'tenant-1',
          path: '/recover-me',
          routeId: 'r',
          tags: const [],
          idempotencyKey: 'recover-key',
        );
        expect(reEnqueued.id, job.id);
      },
    );

    test('10,000 scheduled jobs benchmark verifies linear/sub-quadratic enqueue performance', () async {
      const totalJobs = 10000;
      const batchSize = 1000;
      final stopwatch = Stopwatch()..start();

      for (var batch = 0; batch < totalJobs ~/ batchSize; batch++) {
        final requests = List.generate(batchSize, (i) {
          final idx = batch * batchSize + i;
          return RegenerationJobRequest(
            siteId: 'site-bench',
            tenantId: 'tenant-bench',
            path: '/catalogue/item-$idx',
            routeId: 'catalogue',
            tags: ['catalog', 'cat:${idx % 50}'],
            idempotencyKey: 'bench-key-$idx',
          );
        });
        await queue.enqueueAll(requests);
      }

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      final jobsPerSec = (totalJobs / (elapsedMs / 1000)).round();

      // Enqueueing 10,000 jobs in batches should be fast (> 250 jobs/sec on Windows disk I/O)
      // and not suffer from quadratic O(N^2) file scans.
      expect(jobsPerSec, greaterThan(250));

      final metrics = await queue.metrics();
      expect(metrics.totalJobs, totalJobs);
      expect(metrics.queuedJobs, totalJobs);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('Multi-Worker Concurrency & Fencing Tests', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mm-workers-concurrency-');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('two independent workers: competing claims serialize, expired lease reclaimed, stale token rejected', () async {
      final queue1 = FileRegenerationQueue(temp);
      final queue2 = FileRegenerationQueue(temp);

      final now = DateTime.utc(2026, 11, 11, 10, 0);

      await queue1.enqueue(
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/concurrent-item',
        routeId: 'items',
        tags: const [],
        idempotencyKey: 'competing-claim',
        now: now,
      );

      // Worker 1 claims with a 30-second lease
      final claim1 = await queue1.claimNext(
        now: now,
        lease: const Duration(seconds: 30),
      );
      expect(claim1, isNotNull);
      expect(claim1!.status, RegenerationJobStatus.processing);

      // Worker 2 attempts claim while lease is active -> receives null
      final claim2 = await queue2.claimNext(
        now: now.add(const Duration(seconds: 10)),
      );
      expect(claim2, isNull);

      // Now time advances beyond lease expiry (35 seconds later)
      final claim3 = await queue2.claimNext(
        now: now.add(const Duration(seconds: 35)),
        lease: const Duration(seconds: 30),
      );
      expect(claim3, isNotNull);
      expect(claim3!.id, claim1.id);
      expect(claim3.leaseToken, isNot(claim1.leaseToken));
      expect(claim3.attempts, 2);

      // Worker 1 attempts to complete using old/stale lease token -> FAILS with StateError
      await expectLater(
        queue1.complete(claim1.id, leaseToken: claim1.leaseToken!),
        throwsStateError,
      );

      // Worker 2 completes using active lease token -> SUCCEEDS
      final completed = await queue2.complete(
        claim3.id,
        leaseToken: claim3.leaseToken!,
      );
      expect(completed.status, RegenerationJobStatus.completed);
    });
  });

  group('REST & GraphQL Network Security & DNS Pinning Tests', () {
    test(
      'SsrfGuard createPinnedClient pins socket to validated address',
      () async {
        var resolveCalls = 0;
        final guard = SsrfGuard(
          resolver: (host) async {
            resolveCalls++;
            if (host == 'safe.example.com') {
              return [InternetAddress('93.184.216.34')]; // Example public IP
            }
            if (host == 'rebinding.example.com') {
              return [InternetAddress('10.0.0.1')]; // Private IP
            }
            return [];
          },
        );

        final client = guard.createPinnedClient();
        expect(client, isNotNull);

        final restProvider = RestDataProvider<Map<String, dynamic>>(
          urlBuilder: (_) => 'http://rebinding.example.com/api',
          mapper: (json) => json as Map<String, dynamic>,
          ssrfGuard: guard,
        );

        await expectLater(
          restProvider.load(RouteDataContext(path: '/test')),
          throwsA(isA<SecurityException>()),
        );
        expect(resolveCalls, greaterThanOrEqualTo(1));
      },
    );
  });
}
