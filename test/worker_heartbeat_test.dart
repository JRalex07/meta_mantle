import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Worker Lease Renewal & Heartbeat Tests', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mm-heartbeat-');
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

    test('renewLease explicitly extends lease deadline on claimed job',
        () async {
      final queueDir = Directory('${temp.path}/queue');
      final queue = FileRegenerationQueue(queueDir);

      var currentTime = DateTime.utc(2026, 1, 1, 12, 0, 0);

      await queue.enqueue(
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/renew',
        routeId: 'pages',
        tags: const [],
        idempotencyKey: 'key-renew',
        now: currentTime,
      );

      // Claim job with 60 second lease
      final claimed = await queue.claimNext(
        now: currentTime,
        lease: const Duration(seconds: 60),
      );
      expect(claimed, isNotNull);
      expect(claimed!.leaseUntil, currentTime.add(const Duration(seconds: 60)));

      // 40 seconds pass, renew lease for another 60 seconds
      currentTime = currentTime.add(const Duration(seconds: 40));
      final renewed = await queue.renewLease(
        claimed.id,
        leaseToken: claimed.leaseToken!,
        extension: const Duration(seconds: 60),
        now: currentTime,
      );

      expect(renewed.leaseUntil, currentTime.add(const Duration(seconds: 60)));
      expect(renewed.leaseUntil!.isAfter(claimed.leaseUntil!), isTrue);
    });

    test(
        'renewLease throws StateError if lease was reclaimed by another worker',
        () async {
      final queueDir = Directory('${temp.path}/queue');
      final queue = FileRegenerationQueue(queueDir);

      var currentTime = DateTime.utc(2026, 1, 1, 12, 0, 0);

      await queue.enqueue(
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/steal',
        routeId: 'pages',
        tags: const [],
        idempotencyKey: 'key-steal',
        now: currentTime,
      );

      // Worker 1 claims job
      final worker1Claim = await queue.claimNext(
        now: currentTime,
        lease: const Duration(seconds: 30),
      );
      expect(worker1Claim, isNotNull);

      // 35 seconds pass - lease expires!
      currentTime = currentTime.add(const Duration(seconds: 35));

      // Worker 2 claims the expired job
      final worker2Claim = await queue.claimNext(
        now: currentTime,
        lease: const Duration(seconds: 30),
      );
      expect(worker2Claim, isNotNull);
      expect(worker2Claim!.id, worker1Claim!.id);
      expect(worker2Claim.leaseToken, isNot(worker1Claim.leaseToken));

      // Worker 1 tries to renew its stale lease -> must be rejected
      expect(
        () => queue.renewLease(
          worker1Claim.id,
          leaseToken: worker1Claim.leaseToken!,
          extension: const Duration(seconds: 30),
          now: currentTime,
        ),
        throwsStateError,
      );
    });

    test(
        'RegenerationWorker heartbeat periodically renews lease during long job',
        () async {
      final queueDir = Directory('${temp.path}/queue');
      final queue = FileRegenerationQueue(queueDir);

      await queue.enqueue(
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/long',
        routeId: 'pages',
        tags: const [],
        idempotencyKey: 'key-long',
      );

      var heartbeatCount = 0;
      final worker = RegenerationWorker(
        queue: queue,
        // Short lease of 300ms, heartbeat interval of 80ms
        leaseDuration: const Duration(milliseconds: 300),
        heartbeatInterval: const Duration(milliseconds: 80),
        handle: (job) async {
          // Simulate handler taking 500ms (longer than the initial 300ms lease)
          for (var i = 0; i < 5; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            heartbeatCount++;
          }
        },
      );

      final result = await worker.processNext();
      expect(result, RegenerationWorkerResult.completed);
      expect(heartbeatCount, 5);

      // Verify job is completed in queue
      final next = await queue.claimNext();
      expect(next, isNull);
    });

    test(
        'RegenerationWorker returns leaseLost when heartbeat fails due to lease theft',
        () async {
      final queueDir = Directory('${temp.path}/queue');
      final queue = FileRegenerationQueue(queueDir);

      var now = DateTime.utc(2026, 1, 1, 10, 0, 0);

      await queue.enqueue(
        siteId: 'site-1',
        tenantId: 'tenant-1',
        path: '/stolen',
        routeId: 'pages',
        tags: const [],
        idempotencyKey: 'key-stolen',
        now: now,
      );

      final worker = RegenerationWorker(
        queue: queue,
        leaseDuration: const Duration(milliseconds: 100),
        heartbeatInterval: const Duration(milliseconds: 40),
        clock: () => now,
        handle: (job) async {
          // Simulate sudden clock jump where another worker reclaims the lease
          now = now.add(const Duration(seconds: 10));
          // Steal the lease with another worker call
          await queue.claimNext(now: now, lease: const Duration(seconds: 60));
          // Wait for heartbeat to attempt renewal and fail
          await Future<void>.delayed(const Duration(milliseconds: 90));
        },
      );

      final result = await worker.processNext(now: now);
      expect(result, RegenerationWorkerResult.leaseLost);
    });
  });
}
