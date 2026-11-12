import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:shelf/shelf.dart' as shelf;

void main() {
  late Directory temp;
  late List<int> secret;
  late DateTime now;
  late FileRegenerationQueue queue;
  late RevalidationWebhookHandler handler;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mm-webhook-');
    secret = List<int>.generate(32, (i) => i + 1);
    now = DateTime.utc(2026, 11, 11, 12);
    queue = FileRegenerationQueue(Directory('${temp.path}/queue'));
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
      '/products/1': RouteDependency(
        path: '/products/1',
        routeId: 'products',
        tags: const ['catalog'],
        generatedAt: now,
      ),
      '/products/2': RouteDependency(
        path: '/products/2',
        routeId: 'products',
        tags: const ['other'],
        generatedAt: now,
      ),
    });
    await store.publishVersion(version);
    handler = RevalidationWebhookHandler(
      scheduler: HybridRevalidationScheduler(
        store: store,
        queue: queue,
        siteId: 'site-a',
        tenantId: 'tenant-a',
      ),
      replayStore: FileWebhookReplayStore(Directory('${temp.path}/replays')),
      tenantId: 'tenant-a',
      secret: secret,
      clock: () => now,
    );
  });

  tearDown(() async => temp.delete(recursive: true));

  ServerRequest request({
    required String body,
    String eventId = 'event-1',
    DateTime? signedAt,
    String? signatureOverride,
    String method = 'POST',
  }) {
    final seconds = ((signedAt ?? now).millisecondsSinceEpoch ~/ 1000)
        .toString();
    final canonical = '$seconds\n$eventId\ntenant-a\n$body';
    final signature =
        signatureOverride ??
        Hmac(sha256, secret).convert(utf8.encode(canonical)).toString();
    return ServerRequest(
      method: method,
      uri: Uri.parse('https://example.test/_meta/revalidate'),
      headers: {
        'x-metamantle-timestamp': seconds,
        'x-metamantle-event-id': eventId,
        'x-metamantle-signature': 'sha256=$signature',
      },
      bodyBytes: utf8.encode(body),
    );
  }

  test(
    'valid signed tag event enqueues only matching page and rejects replay',
    () async {
      const body = '{"tenantId":"tenant-a","tag":"catalog"}';
      final first = await handler.handle(request(body: body));
      expect(first.statusCode, 202);
      expect(jsonDecode(first.body)['scheduled'], 1);
      expect((await queue.list()).single.path, '/products/1');

      final replay = await handler.handle(request(body: body));
      expect(replay.statusCode, 409);
      expect(jsonDecode(replay.body)['error'], 'replayed_event');
      expect((await queue.list()).length, 1);
    },
  );

  test(
    'rejects invalid signature, expired timestamp, and tenant mismatch',
    () async {
      const body = '{"tenantId":"tenant-a","tag":"catalog"}';
      final badSignature = await handler.handle(
        request(body: body, signatureOverride: List.filled(64, '0').join()),
      );
      expect(badSignature.statusCode, 401);
      final expired = await handler.handle(
        request(
          body: body,
          eventId: 'old-event',
          signedAt: now.subtract(const Duration(minutes: 6)),
        ),
      );
      expect(expired.statusCode, 401);
      const otherTenant = '{"tenantId":"tenant-b","tag":"catalog"}';
      final mismatchedTenant = await handler.handle(request(body: otherTenant));
      expect(mismatchedTenant.statusCode, 403);
      expect(await queue.list(), isEmpty);
    },
  );

  test('valid signature with invalid selector returns 400', () async {
    const body = '{"tenantId":"tenant-a","path":"/products/1","tag":"catalog"}';
    final response = await handler.handle(request(body: body));
    expect(response.statusCode, 400);
  });

  test(
    'Shelf handler rejects oversized streamed bodies before buffering',
    () async {
      final limited = RevalidationWebhookHandler(
        scheduler: handler.scheduler,
        replayStore: MemoryWebhookReplayStore(),
        tenantId: 'tenant-a',
        secret: secret,
        clock: () => now,
        maxBodyBytes: 8,
      );
      final response = await limited.createShelfHandler()(
        shelf.Request(
          'POST',
          Uri.parse('https://example.test/_meta/revalidate'),
          body: Stream<List<int>>.value(List<int>.filled(9, 65)),
        ),
      );
      expect(response.statusCode, 413);
    },
  );

  test(
    'file replay protection persists across handler store instances',
    () async {
      final replayDirectory = Directory('${temp.path}/durable-replays');
      final first = FileWebhookReplayStore(replayDirectory);
      expect(
        await first.claim('event-a', now.add(const Duration(minutes: 5)), now),
        isTrue,
      );
      final restarted = FileWebhookReplayStore(replayDirectory);
      expect(
        await restarted.claim(
          'event-a',
          now.add(const Duration(minutes: 5)),
          now,
        ),
        isFalse,
      );
      await restarted.release('event-a');
      expect(
        await restarted.claim(
          'event-a',
          now.add(const Duration(minutes: 5)),
          now,
        ),
        isTrue,
      );
    },
  );
}
