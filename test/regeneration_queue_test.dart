import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  late Directory temp;
  late FileRegenerationQueue queue;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mm-jobs-');
    queue = FileRegenerationQueue(temp, maxProcessingJobs: 1);
  });
  tearDown(() async => temp.delete(recursive: true));

  Future<RegenerationJob> add(String key, {int maxAttempts = 3}) =>
      queue.enqueue(
        siteId: 'site-a',
        tenantId: 'tenant-a',
        path: '/products/$key',
        routeId: 'products',
        tags: ['catalog', 'product:$key'],
        idempotencyKey: key,
        maxAttempts: maxAttempts,
        now: DateTime.utc(2026, 1, 1),
      );

  test('persists jobs and coalesces duplicate idempotency keys', () async {
    final first = await add('item-1');
    expect((await add('item-1')).id, first.id);
    expect(
      (await FileRegenerationQueue(temp).list()).single.path,
      '/products/item-1',
    );
  });

  test('claims are path-serialized and bounded, then complete', () async {
    final first = await add('same');
    final second = await queue.enqueue(
      siteId: 'site-a',
      tenantId: 'tenant-a',
      path: first.path,
      routeId: 'products',
      tags: const [],
      idempotencyKey: 'second',
    );
    final claimed = await queue.claimNext(now: DateTime.utc(2026, 1, 1));
    expect(claimed!.id, first.id);
    expect(
      await queue.claimNext(
        now: claimed.leaseUntil!.subtract(const Duration(seconds: 1)),
      ),
      isNull,
    );
    await queue.complete(claimed.id, leaseToken: claimed.leaseToken!);
    expect((await queue.claimNext())!.id, second.id);
  });

  test('retries with backoff then fails at max attempts', () async {
    final job = await add('retry', maxAttempts: 2);
    final first = await queue.claimNext(now: DateTime.utc(2026, 1, 1));
    final retry = await queue.fail(
      first!.id,
      leaseToken: first.leaseToken!,
      errorCode: 'source_unavailable',
      now: DateTime.utc(2026, 1, 1),
    );
    expect(retry.status, RegenerationJobStatus.queued);
    expect(await queue.claimNext(now: DateTime.utc(2026, 1, 1)), isNull);
    final second = await queue.claimNext(now: retry.availableAt);
    final failed = await queue.fail(
      second!.id,
      leaseToken: second.leaseToken!,
      errorCode: 'source_unavailable',
      now: retry.availableAt,
    );
    expect(failed.status, RegenerationJobStatus.failed);
    expect(failed.attempts, 2);
    expect((await queue.list()).single.id, job.id);
  });

  test('expired lease is recovered after worker restart', () async {
    await add('lease');
    final time = DateTime.utc(2026, 1, 1);
    final claimed = await queue.claimNext(
      now: time,
      lease: const Duration(seconds: 1),
    );
    final recovered = await FileRegenerationQueue(temp)
        .claimNext(now: time.add(const Duration(seconds: 2)));
    expect(recovered!.id, claimed!.id);
    expect(recovered.attempts, 2);
  });

  test('rejects traversal and unsafe error details', () async {
    await expectLater(add('../escape'), throwsFormatException);
    await add('safe');
    final claimed = await queue.claimNext();
    await expectLater(
      queue.fail(
        claimed!.id,
        leaseToken: claimed.leaseToken!,
        errorCode: 'token=secret',
      ),
      throwsArgumentError,
    );
  });

  test('old lease token cannot complete a reclaimed job', () async {
    await add('fenced');
    final time = DateTime.utc(2026, 1, 1);
    final old = await queue.claimNext(
      now: time,
      lease: const Duration(seconds: 1),
    );
    final current = await queue.claimNext(
      now: time.add(const Duration(seconds: 2)),
    );
    expect(current!.leaseToken, isNot(old!.leaseToken));
    await expectLater(
      queue.complete(old.id, leaseToken: old.leaseToken!),
      throwsStateError,
    );
    await queue.complete(current.id, leaseToken: current.leaseToken!);
  });

  test('worker runs handler and records only a safe retry code', () async {
    await add('worker');
    var calls = 0;
    final worker = RegenerationWorker(
      queue: queue,
      handle: (_) async {
        calls++;
        throw StateError('secret-bearing source response');
      },
    );
    expect(
      await worker.processNext(now: DateTime.utc(2026, 1, 1)),
      RegenerationWorkerResult.retryScheduled,
    );
    final job = (await queue.list()).single;
    expect(job.errorCode, 'regeneration_failed');
    expect(job.toJson().toString(), isNot(contains('secret-bearing')));
    expect(calls, 1);
  });

  test(
    'explicit tag event queues only indexed paths and coalesces replay',
    () async {
      final store = FileHtmlArtifactStore(Directory('${temp.path}/artifacts'));
      final version = await store.beginVersion();
      for (final path in ['/products/1', '/products/2']) {
        await store.writeVersion(
          version,
          path,
          '<!doctype html><body>$path</body>',
        );
      }
      await store.saveVersionDependencies(version, {
        for (final path in ['/products/1', '/products/2'])
          path: RouteDependency(
            path: path,
            routeId: 'products',
            tags: path.endsWith('/1') ? const ['catalog'] : const ['other'],
            generatedAt: DateTime.utc(2026, 1, 1),
            sourceVersion: 'v1',
          ),
      });
      await store.publishVersion(version);
      final scheduler = HybridRevalidationScheduler(
        store: store,
        queue: queue,
        siteId: 'site-a',
        tenantId: 'tenant-a',
      );
      final first = await scheduler.revalidateTag(
        'catalog',
        eventId: 'event-1',
      );
      final replay = await scheduler.revalidateTag(
        'catalog',
        eventId: 'event-1',
      );
      expect(first.jobs, hasLength(1));
      expect(first.jobs.single.path, '/products/1');
      expect(first.jobs.single.sourceVersion, 'v1');
      expect(replay.jobIds, first.jobIds);

      final revalidator = HybridRevalidator(
        store: store,
        regenerate: (path, old) async => GeneratedRouteDocument(
          html: '<!doctype html><body>updated $path</body>',
          tags: old.tags,
          sourceVersion: 'v2',
        ),
      );
      final worker = RegenerationWorker(
        queue: queue,
        handle: (job) async {
          await revalidator.revalidatePath(job.path);
        },
      );
      expect(
        await worker.processNext(
          now: DateTime.now().toUtc().add(const Duration(seconds: 1)),
        ),
        RegenerationWorkerResult.completed,
      );
      expect(await store.read('/products/1'), contains('updated /products/1'));
      expect(await store.read('/products/2'), contains('/products/2'));
      expect(
        (await store.loadDependencies())['/products/1']!.sourceVersion,
        'v2',
      );

      final provider = MemoryDataProvider<Map<String, dynamic>>(
        lookupParam: 'slug',
      );
      final server = MetaMantleServerEngine(
        routes: [
          MetaRoute<Map<String, dynamic>>(
            pattern: '/products/:slug',
            dataProvider: provider,
            metadataBuilder: (_, __) => WebMetadata(title: 'Product'),
            htmlBuilder: (_, __) => [H.h1('Provider fallback')],
          ),
        ],
        artifactStore: store,
        artifactMaxAge: const Duration(days: 1),
      );
      final served = await server.handleRequest(
        ServerRequest(
          method: 'GET',
          uri: Uri.parse('https://example.com/products/1'),
        ),
      );
      expect(served.statusCode, 200);
      expect(served.body, contains('updated /products/1'));
      expect(served.body, isNot(contains('Provider fallback')));
    },
  );

  test('time-based scheduling queues only expired generated pages', () async {
    final store = FileHtmlArtifactStore(
      Directory('${temp.path}/timed-artifacts'),
    );
    final version = await store.beginVersion();
    await store.saveVersionDependencies(version, {
      '/products/old': RouteDependency(
        path: '/products/old',
        routeId: 'products',
        tags: const ['catalog'],
        generatedAt: DateTime.utc(2026, 1, 1),
      ),
      '/products/recent': RouteDependency(
        path: '/products/recent',
        routeId: 'products',
        tags: const ['catalog'],
        generatedAt: DateTime.utc(2026, 1, 1, 23),
      ),
      '/products/older': RouteDependency(
        path: '/products/older',
        routeId: 'products',
        tags: const ['catalog'],
        generatedAt: DateTime.utc(2025, 12, 31),
      ),
    });
    await store.publishVersion(version);
    final scheduler = HybridRevalidationScheduler(
      store: store,
      queue: queue,
      siteId: 'site-a',
      tenantId: 'tenant-a',
    );

    final report = await scheduler.revalidateExpired(
      maxAge: const Duration(days: 1),
      eventId: 'daily-scan-1',
      now: DateTime.utc(2026, 1, 2),
    );

    expect(report.jobs.map((job) => job.path), [
      '/products/old',
      '/products/older',
    ]);
    await expectLater(
      scheduler.revalidateExpired(
        maxAge: const Duration(days: 1),
        eventId: 'daily-scan-2',
        now: DateTime.utc(2026, 1, 2),
        maxJobs: 1,
      ),
      throwsStateError,
    );
  });
}
