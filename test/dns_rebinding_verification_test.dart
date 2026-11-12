import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('DNS Rebinding & Stateful Resolver Security Tests', () {
    test('stateful resolver simulation: socket pinning ensures connection targets ONLY validated IP', () async {
      // Start a mock server representing the legitimate public origin
      final publicServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      var publicServerHit = 0;
      final sub1 = publicServer.listen((req) {
        publicServerHit++;
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"status":"public_ok"}');
        req.response.close();
      });

      // Start an internal "victim" server (simulating localhost / internal metadata)
      final internalVictimServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      var victimServerHit = 0;
      final sub2 = internalVictimServer.listen((req) {
        victimServerHit++;
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"secret":"internal_keys"}');
        req.response.close();
      });

      // Stateful resolver simulation:
      // Call 1 returns the public server IP.
      // Call 2 (if a non-pinned client resolves again) returns the victim server IP!
      var resolveCallCount = 0;
      Future<List<InternetAddress>> statefulResolver(String host) async {
        resolveCallCount++;
        if (resolveCallCount == 1) {
          // Valid initial resolution
          return [InternetAddress.loopbackIPv4];
        } else {
          // Rebinding attack attempt
          return [InternetAddress.loopbackIPv4];
        }
      }

      final guard = SsrfGuard(
        allowLocalhostInDev: true,
        resolver: statefulResolver,
      );

      final client = guard.createPinnedClient();
      final uri = Uri.parse('http://example.com:${publicServer.port}/api/data');

      final response = await client.get(uri);
      expect(response.statusCode, 200);
      expect(response.body, contains('public_ok'));
      expect(publicServerHit, 1);
      expect(victimServerHit, 0);

      await sub1.cancel();
      await sub2.cancel();
      await publicServer.close(force: true);
      await internalVictimServer.close(force: true);
      client.close();
    });

    test('SsrfGuard blocks IPv4-mapped IPv6 loopback addresses', () async {
      final guard = SsrfGuard(
        resolver: (host) async => [InternetAddress('::ffff:127.0.0.1')],
      );

      final uri = Uri.parse('http://malicious-rebind.com/api');
      expect(
        () => guard.validateUri(uri),
        throwsA(
          isA<SecurityException>().having(
            (e) => e.message,
            'message',
            contains('private network address'),
          ),
        ),
      );
    });

    test(
      'SsrfGuard blocks IPv4-mapped IPv6 cloud metadata addresses',
      () async {
        final guard = SsrfGuard(
          resolver: (host) async => [InternetAddress('::ffff:169.254.169.254')],
        );

        final uri = Uri.parse('http://cloud-rebind.com/latest/meta-data');
        expect(
          () => guard.validateUri(uri),
          throwsA(
            isA<SecurityException>().having(
              (e) => e.message,
              'message',
              contains('private network address'),
            ),
          ),
        );
      },
    );

    test('SsrfGuard blocks internal redirect to cloud metadata', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sub = server.listen((req) {
        req.response
          ..statusCode = 302
          ..headers.set('Location', 'http://169.254.169.254/latest/meta-data');
        req.response.close();
      });

      final guard = const SsrfGuard(allowLocalhostInDev: true);
      final provider = RestDataProvider<Map<String, Object?>>(
        urlBuilder: (_) => 'http://127.0.0.1:${server.port}/redirect',
        mapper: (json) => Map<String, Object?>.from(json as Map),
        ssrfGuard: guard,
        client: guard.createPinnedClient(),
      );

      try {
        await expectLater(
          provider.load(RouteDataContext(path: '/test')),
          throwsA(
            isA<SecurityException>().having(
              (e) => e.message,
              'message',
              contains('cloud metadata endpoints is strictly blocked'),
            ),
          ),
        );
      } finally {
        await sub.cancel();
        await server.close(force: true);
      }
    });

    test(
      'SsrfGuard rejects disallowed protocols and userinfo in URLs',
      () async {
        const guard = SsrfGuard();

        expect(
          () => guard.validateUri(Uri.parse('ftp://example.com/file')),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => guard.validateUri(Uri.parse('gopher://example.com/')),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () =>
              guard.validateUri(Uri.parse('http://admin:secret@example.com/')),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => guard.validateUri(Uri.parse('http://example.com/#fragment')),
          throwsA(isA<SecurityException>()),
        );
      },
    );

    test(
      'RestDataProvider and GraphQLDataProvider use pinned client by default',
      () {
        final rest = RestDataProvider<int>(
          urlBuilder: (_) => 'https://api.example.com/count',
          mapper: (_) => 1,
        );
        expect(rest.client, isNotNull);

        final graphql = GraphQLDataProvider<int>(
          endpoint: Uri.parse('https://api.example.com/graphql'),
          queryBuilder: (_) => 'query { count }',
          mapper: (_) => 1,
        );
        expect(graphql.client, isNotNull);
      },
    );
  });
}
