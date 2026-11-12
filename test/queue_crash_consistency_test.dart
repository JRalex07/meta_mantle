import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Queue Crash-Consistency & Fault Injection Tests', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mm-queue-crash-');
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

    test('recovers safely from corrupted journal tail (partial write)',
        () async {
      final queueDir = Directory('${temp.path}/queue');
      final queue1 = FileRegenerationQueue(queueDir);

      await queue1.enqueue(
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/page-1',
        routeId: 'pages',
        tags: const [],
        idempotencyKey: 'page-1',
        now: DateTime.utc(2026, 1, 1),
      );
      await queue1.enqueue(
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/page-2',
        routeId: 'pages',
        tags: const [],
        idempotencyKey: 'page-2',
        now: DateTime.utc(2026, 1, 1),
      );

      // Simulate a crash during append: append a corrupted, incomplete JSON line
      final journalFile = File('${queueDir.path}/.queue.journal');
      expect(await journalFile.exists(), isTrue);
      await journalFile.writeAsString(
        '{"op":"enqueue","id":"corrupted-job","job":{"id":"corrupted', // truncated JSON
        mode: FileMode.append,
        flush: true,
      );

      // Now create a new queue instance pointing to the same directory
      final queue2 = FileRegenerationQueue(queueDir);
      final report = await queue2.recover();

      expect(report.corruptedEntriesDiscarded, greaterThanOrEqualTo(1));
      expect(report.activePendingCount, 2);

      // Ensure the uncorrupted jobs are claimable and ordered
      final claim1 = await queue2.claimNext(
        now: DateTime.utc(2026, 1, 1),
        lease: const Duration(minutes: 5),
      );
      expect(claim1, isNotNull);
      expect(claim1!.path, '/page-1');

      final claim2 = await queue2.claimNext(
        now: DateTime.utc(2026, 1, 1),
        lease: const Duration(minutes: 5),
      );
      expect(claim2, isNotNull);
      expect(claim2!.path, '/page-2');
    });

    test('discovers and reconciles unindexed job files on disk', () async {
      final queueDir = Directory('${temp.path}/queue');
      final queue1 = FileRegenerationQueue(queueDir);

      await queue1.enqueue(
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/indexed',
        routeId: 'pages',
        tags: const [],
        idempotencyKey: 'indexed-key',
        now: DateTime.utc(2026, 1, 1),
      );
      await queue1.checkpoint();

      // Simulate a crash where a job file was written to disk in jobs/
      // but process crashed before the journal write or checkpoint could complete
      final jobsDir = Directory('${queueDir.path}/jobs');
      await jobsDir.create(recursive: true);
      final orphanJob = RegenerationJob(
        id: 'orphan-1',
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/orphan',
        routeId: 'pages',
        tags: const [],
        idempotencyKey: 'orphan-key',
        status: RegenerationJobStatus.queued,
        attempts: 0,
        maxAttempts: 5,
        createdAt: DateTime.utc(2026, 1, 1),
        availableAt: DateTime.utc(2026, 1, 1),
      );
      final orphanFile = File('${jobsDir.path}/orphan-1.job.json');
      await orphanFile.writeAsString(jsonEncode(orphanJob.toJson()),
          flush: true);

      // Re-open queue and run recovery
      final queue2 = FileRegenerationQueue(queueDir);
      final report = await queue2.recover();

      expect(report.recoveredJobs, greaterThanOrEqualTo(1));
      expect(report.activePendingCount, 2);

      // Verify both jobs are claimable
      final claim1 = await queue2.claimNext(
        now: DateTime.utc(2026, 1, 1),
        lease: const Duration(minutes: 5),
      );
      final claim2 = await queue2.claimNext(
        now: DateTime.utc(2026, 1, 1),
        lease: const Duration(minutes: 5),
      );

      final claimedPaths = {claim1?.path, claim2?.path};
      expect(claimedPaths, containsAll({'/indexed', '/orphan'}));
    });

    test('snapshot compaction recovery: survives partial temporary snapshot',
        () async {
      final queueDir = Directory('${temp.path}/queue');
      final queue = FileRegenerationQueue(queueDir);

      await queue.enqueue(
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/snap',
        routeId: 'pages',
        tags: const [],
        idempotencyKey: 'snap-key',
        now: DateTime.utc(2026, 1, 1),
      );

      // Run a valid checkpoint
      await queue.checkpoint();
      final snapFile = File('${queueDir.path}/indexes/snapshot.json');
      expect(await snapFile.exists(), isTrue);

      // Simulate an interrupted checkpoint by leaving an incomplete .tmp file
      final tempSnap =
          File('${queueDir.path}/indexes/snapshot.json.partial.tmp');
      await tempSnap.writeAsString('{"invalid": true,', flush: true);

      // Reopen queue and verify valid snapshot was read unaffected by temp file
      final queue2 = FileRegenerationQueue(queueDir);
      final claim = await queue2.claimNext(
        now: DateTime.utc(2026, 1, 1),
        lease: const Duration(minutes: 5),
      );
      expect(claim, isNotNull);
      expect(claim!.path, '/snap');
    });
  });
}
