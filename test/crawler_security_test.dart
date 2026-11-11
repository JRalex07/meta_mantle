import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('CrawlerInspector security', () {
    test('denies loopback, private, link-local, special, and metadata targets',
        () async {
      final blocked = <(String, String)>[
        ('http://localhost/', '127.0.0.1'),
        ('http://127.0.0.1/', '127.0.0.1'),
        ('http://2130706433/', '127.0.0.1'),
        ('http://[::1]/', '::1'),
        ('http://10.0.0.1/', '10.0.0.1'),
        ('http://172.16.0.1/', '172.16.0.1'),
        ('http://192.168.0.1/', '192.168.0.1'),
        ('http://192.0.2.1/', '192.0.2.1'),
        ('http://[fc00::1]/', 'fc00::1'),
        ('http://[fe80::1]/', 'fe80::1'),
        ('http://0.0.0.0/', '0.0.0.0'),
        ('http://224.0.0.1/', '224.0.0.1'),
        ('http://169.254.169.254/latest/', '169.254.169.254'),
      ];
      for (final (url, address) in blocked) {
        final guard = SsrfGuard(
          resolver: (_) async => [InternetAddress(address)],
        );
        await expectLater(guard.validateUri(Uri.parse(url)),
            throwsA(isA<SecurityException>()),
            reason: 'should reject $url');
      }
      await expectLater(
        const SsrfGuard()
            .validateUri(Uri.parse('http://metadata.google.internal/')),
        throwsA(isA<SecurityException>()),
      );
    });

    test('rejects localhost by default before contacting the client', () async {
      var requests = 0;
      final crawler = CrawlerInspector(
        client: MockClient((_) async {
          requests++;
          return http.Response('<title>ok</title>', 200);
        }),
        ssrfGuard: SsrfGuard(
          resolver: (_) async => [InternetAddress.loopbackIPv4],
        ),
      );

      await expectLater(
        crawler.inspectUrl('http://example.test/'),
        throwsA(isA<SecurityException>()),
      );
      expect(requests, 0);
    });

    test(
        'localhost requires explicit opt in and other private ranges stay blocked',
        () async {
      var requests = 0;
      final crawler = CrawlerInspector(
        client: MockClient((_) async {
          requests++;
          return http.Response('<html><title>ok</title></html>', 200);
        }),
        ssrfGuard: SsrfGuard(
          allowLocalhostInDev: true,
          resolver: (_) async => [InternetAddress.loopbackIPv4],
        ),
      );
      await crawler.inspectUrl('http://example.test/');
      expect(requests, 1);

      final privateGuard = SsrfGuard(
        allowLocalhostInDev: true,
        resolver: (_) async => [InternetAddress('10.0.0.1')],
      );
      await expectLater(
        privateGuard.validateUri(Uri.parse('http://private.example/')),
        throwsA(isA<SecurityException>()),
      );
    });

    test('mixed public and private DNS answers fail closed', () async {
      final guard = SsrfGuard(
        resolver: (_) async => [
          InternetAddress('8.8.8.8'),
          InternetAddress('10.0.0.7'),
        ],
      );
      await expectLater(
        guard.validateUri(Uri.parse('https://mixed.example/')),
        throwsA(isA<SecurityException>()),
      );
    });

    test('DNS answer changing to private is blocked by the pinned transport',
        () async {
      var lookups = 0;
      final crawler = CrawlerInspector(
        ssrfGuard: SsrfGuard(resolver: (_) async {
          lookups++;
          return [InternetAddress(lookups == 1 ? '8.8.8.8' : '10.0.0.9')];
        }),
        timeout: const Duration(seconds: 2),
      );
      await expectLater(
        crawler.inspectUrl('http://rebinding.example/'),
        throwsA(isA<SecurityException>()),
      );
      expect(lookups, 2,
          reason:
              'The socket factory must resolve and validate immediately before connect.');
    });

    test('redirect to loopback is rejected before second request', () async {
      var requests = 0;
      final crawler = CrawlerInspector(
        client: MockClient((request) async {
          requests++;
          return http.Response('', 302,
              headers: {'location': 'http://127.0.0.1/admin'});
        }),
        ssrfGuard: SsrfGuard(
          resolver: (_) async => [InternetAddress('8.8.8.8')],
        ),
      );
      await expectLater(
        crawler.inspectUrl('https://public.example/'),
        throwsA(isA<SecurityException>()),
      );
      expect(requests, 1);
    });

    test('redirect loop and HTTPS downgrade are rejected', () async {
      var requests = 0;
      final loop = CrawlerInspector(
        client: MockClient((request) async {
          requests++;
          return http.Response('', 302, headers: {'location': '/'});
        }),
        ssrfGuard:
            SsrfGuard(resolver: (_) async => [InternetAddress('8.8.8.8')]),
      );
      await expectLater(loop.inspectUrl('https://loop.example/'),
          throwsA(isA<CrawlerException>()));
      expect(requests, 1);

      final downgrade = CrawlerInspector(
        client: MockClient((_) async => http.Response('', 302,
            headers: {'location': 'http://public.example/'})),
        ssrfGuard:
            SsrfGuard(resolver: (_) async => [InternetAddress('8.8.8.8')]),
      );
      await expectLater(downgrade.inspectUrl('https://public.example/'),
          throwsA(isA<CrawlerException>()));
    });

    test('redirect count is bounded before a sixth redirect request', () async {
      var requests = 0;
      final crawler = CrawlerInspector(
        client: MockClient((_) async {
          requests++;
          return http.Response('', 302,
              headers: {'location': '/next?hop=$requests'});
        }),
        ssrfGuard:
            SsrfGuard(resolver: (_) async => [InternetAddress('8.8.8.8')]),
      );
      await expectLater(crawler.inspectUrl('https://count.example/start'),
          throwsA(isA<CrawlerException>()));
      expect(requests, 6);
    });

    test('stalled response headers and body time out', () async {
      final guard =
          SsrfGuard(resolver: (_) async => [InternetAddress('8.8.8.8')]);
      final stalledHeaders = CrawlerInspector(
        client: MockClient((_) => Future<http.Response>.delayed(
            const Duration(seconds: 1), () => http.Response('', 200))),
        ssrfGuard: guard,
        timeout: const Duration(milliseconds: 40),
        totalTimeout: const Duration(milliseconds: 100),
      );
      await expectLater(
        stalledHeaders.inspectUrl('https://slow.example/'),
        throwsA(isA<TimeoutException>()),
      );

      final stalledBody = CrawlerInspector(
        client: MockClient.streaming((_, __) async => http.StreamedResponse(
            Stream<void>.periodic(const Duration(seconds: 1)).map((_) => [65]),
            200)),
        ssrfGuard: guard,
        timeout: const Duration(milliseconds: 40),
        totalTimeout: const Duration(milliseconds: 100),
      );
      await expectLater(
        stalledBody.inspectUrl('https://slow.example/'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('oversized streamed response is cancelled immediately', () async {
      var cancelled = false;
      final stream = Stream<List<int>>.multi((controller) {
        controller.onCancel = () => cancelled = true;
        controller.add(List.filled(9, 65));
      });
      final crawler = CrawlerInspector(
        client: MockClient.streaming(
            (_, __) async => http.StreamedResponse(stream, 200)),
        ssrfGuard:
            SsrfGuard(resolver: (_) async => [InternetAddress('8.8.8.8')]),
        maxResponseSizeBytes: 8,
      );
      await expectLater(
        crawler.inspectUrl('https://large.example/'),
        throwsA(isA<CrawlerResponseTooLargeException>()),
      );
      expect(cancelled, isTrue);
    });

    test('streamed body size is bounded and exact limit is accepted', () async {
      final exact = CrawlerInspector(
        client: MockClient((_) async => http.Response('<title>x</title>', 200,
            headers: {'content-type': 'text/html'})),
        ssrfGuard:
            SsrfGuard(resolver: (_) async => [InternetAddress('8.8.8.8')]),
        maxResponseSizeBytes: '<title>x</title>'.length,
      );
      final report = await exact.inspectUrl('https://public.example/');
      expect(report.title, 'x');

      final largeBytes = utf8.encode('<title>too big</title>');
      final tooSmall = CrawlerInspector(
        client: MockClient.streaming((_, __) async =>
            http.StreamedResponse(Stream.value(largeBytes), 200)),
        ssrfGuard:
            SsrfGuard(resolver: (_) async => [InternetAddress('8.8.8.8')]),
        maxResponseSizeBytes: 4,
      );
      await expectLater(
        tooSmall.inspectUrl('https://public.example/'),
        throwsA(isA<CrawlerResponseTooLargeException>()),
      );
    });
  });
}
