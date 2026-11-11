import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('HTTP Conditional Requests & RFC 7232 Precedence Tests', () {
    late MetaMantleServerEngine engine;
    final fixedDate = DateTime.utc(2026, 3, 1, 10, 0);

    setUp(() {
      final db = MemoryDataProvider<Map<String, dynamic>>(lookupParam: 'slug');
      db.set(
        'item',
        {'name': 'Test Item', 'price': 100},
        etag: 'w/"etag-12345"',
        lastModified: fixedDate,
      );

      final route = MetaRoute<Map<String, dynamic>>(
        pattern: '/items/:slug',
        dataProvider: db,
        metadataBuilder: (data, ctx) =>
            WebMetadata(title: data['name'] as String),
        htmlBuilder: (data, ctx) => [H.h1(data['name'] as String)],
        cachePolicy: const CachePolicy(
          ttl: Duration(minutes: 10),
          staleWhileRevalidate: Duration(minutes: 30),
        ),
      );

      engine = MetaMantleServerEngine(routes: [route]);
    });

    test(
        'Matching If-None-Match returns 304 with ETag, Last-Modified, and Cache-Control',
        () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://example.com/items/item'),
        headers: {'if-none-match': 'w/"etag-12345"'},
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(304));
      expect(res.body, isEmpty);
      expect(res.headers['ETag'], contains('etag-12345'));
      expect(res.headers['Last-Modified'], isNotNull);
      expect(res.headers['Cache-Control'], contains('max-age=600'));
    });

    test('Weak ETag comparison matches regardless of W/ prefix or case',
        () async {
      // Client sends without W/ prefix -> should still match weak tag on server
      final req1 = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://example.com/items/item'),
        headers: {'if-none-match': '"etag-12345"'},
      );
      final res1 = await engine.handleRequest(req1);
      expect(res1.statusCode, equals(304));

      // Client sends W/ uppercase -> should match
      final req2 = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://example.com/items/item'),
        headers: {'if-none-match': 'W/"etag-12345"'},
      );
      final res2 = await engine.handleRequest(req2);
      expect(res2.statusCode, equals(304));

      // Client sends wildcard * -> matches
      final req3 = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://example.com/items/item'),
        headers: {'if-none-match': '*'},
      );
      final res3 = await engine.handleRequest(req3);
      expect(res3.statusCode, equals(304));
    });

    test(
        'RFC 7232 Precedence: If-None-Match present and non-matching MUST ignore If-Modified-Since',
        () async {
      // ETag is different ("wrong-etag"), but If-Modified-Since is in the future.
      // Under RFC 7232, the request MUST NOT return 304; it MUST return 200 with fresh body!
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://example.com/items/item'),
        headers: {
          'if-none-match': '"different-etag"',
          'if-modified-since': 'Sun, 01 Mar 2026 12:00:00 GMT',
        },
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(200),
          reason: 'Non-matching If-None-Match must ignore If-Modified-Since');
      expect(res.body, contains('Test Item'));
    });

    test('If-Modified-Since without If-None-Match returns 304 when unmodified',
        () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://example.com/items/item'),
        headers: {
          'if-modified-since': fixedDate.toIso8601String(),
        },
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(304));
      expect(res.body, isEmpty);
    });

    test('HEAD request returns 200 with headers but empty body', () async {
      final req = ServerRequest(
        method: 'HEAD',
        uri: Uri.parse('http://example.com/items/item'),
      );

      final res = await engine.handleRequest(req);
      expect(res.statusCode, equals(200));
      expect(res.body, isEmpty);
      expect(res.headers['Content-Type'], contains('text/html'));
      expect(res.headers['ETag'], isNotNull);
    });
  });

  group('SSRF Protection & Response Streaming Security Tests', () {
    test(
        'RestDataProvider blocks loopback addresses before making network requests',
        () async {
      final provider = RestDataProvider<Map<String, dynamic>>(
        urlBuilder: (ctx) => 'http://127.0.0.1:8080/internal-api',
        mapper: (json) => json as Map<String, dynamic>,
      );

      expect(
        () => provider.load(RouteDataContext(path: '/test')),
        throwsA(isA<SecurityException>().having(
          (e) => e.message,
          'message',
          contains('loopback address'),
        )),
      );
    });

    test('RestDataProvider blocks cloud metadata endpoints (169.254.169.254)',
        () async {
      final provider = RestDataProvider<Map<String, dynamic>>(
        urlBuilder: (ctx) => 'http://169.254.169.254/latest/meta-data/',
        mapper: (json) => json as Map<String, dynamic>,
      );

      expect(
        () => provider.load(RouteDataContext(path: '/test')),
        throwsA(isA<SecurityException>().having(
          (e) => e.message,
          'message',
          contains('cloud metadata'),
        )),
      );
    });

    test(
        'RestDataProvider stream limit aborts before buffering oversized payload',
        () async {
      // Mock client that emits oversized chunks
      final mockClient = MockClient.streaming((request, stream) async {
        final bigChunk = List.filled(1024 * 1024, 65); // 1MB chunks
        final controller = StreamController<List<int>>();
        // Send 10 chunks (10MB total)
        for (var i = 0; i < 10; i++) {
          controller.add(bigChunk);
        }
        controller.close();
        return http.StreamedResponse(
          controller.stream,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = RestDataProvider<Map<String, dynamic>>(
        urlBuilder: (ctx) => 'http://localhost:8080/data',
        mapper: (json) => json as Map<String, dynamic>,
        client: mockClient,
        maxResponseSizeBytes: 2 * 1024 * 1024, // 2MB limit
        ssrfGuard: const SsrfGuard(
          allowLocalhostInDev: true,
        ),
      );

      expect(
        () => provider.load(RouteDataContext(path: '/test')),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('exceeded maximum allowed size'),
        )),
      );
    });
  });

  group('Multi-Tenant Host Security Integration Tests', () {
    late MetaMantleServerEngine multiTenantEngine;

    setUp(() {
      const tenantAcme = TenantContext(
        tenantId: 'acme-corp',
        name: 'Acme Corp',
        primaryDomain: 'acme.portal.dev',
        customDomains: ['portal.acme.com'],
      );
      const tenantGlobex = TenantContext(
        tenantId: 'globex-inc',
        name: 'Globex Inc',
        primaryDomain: 'globex.portal.dev',
      );

      const validator = TenantHostValidator(
        tenants: [tenantAcme, tenantGlobex],
        allowedRootDomains: ['portal.dev'],
      );

      final route = MetaRoute<String>(
        pattern: '/dashboard',
        dataProvider: MemoryDataProvider<String>()
          ..set('/dashboard', 'Dashboard Content'),
        metadataBuilder: (data, ctx) => WebMetadata(title: 'Dashboard'),
        htmlBuilder: (data, ctx) => [H.h1(data)],
        cachePolicy: const CachePolicy(ttl: Duration(hours: 1)),
      );

      multiTenantEngine = MetaMantleServerEngine(
        routes: [route],
        tenantHostValidator: validator,
      );
    });

    test('Rejects missing Host header with HTTP 400 Bad Request', () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('/dashboard'),
        headers: {}, // No host header
      );

      final res = await multiTenantEngine.handleRequest(req);
      expect(res.statusCode, equals(400));
      expect(res.body, contains('Missing Host header'));
    });

    test('Rejects unauthorized/spoofed Host header with HTTP 400 Bad Request',
        () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://attacker.com/dashboard'),
        headers: {'host': 'attacker-controlled.com'},
      );

      final res = await multiTenantEngine.handleRequest(req);
      expect(res.statusCode, equals(400));
      expect(res.body, contains('Unauthorized or unregistered Host header'));
    });

    test('Valid host resolves tenant and ignores untrusted x-tenant-id header',
        () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://acme.portal.dev/dashboard'),
        headers: {
          'host': 'acme.portal.dev',
          'x-tenant-id': 'globex-inc', // Attacker trying to spoof globex
        },
      );

      final res = await multiTenantEngine.handleRequest(req);
      expect(res.statusCode, equals(200));
      expect(res.headers['X-MetaMantle-Cache'], equals('MISS'));

      // Verify that cache key was created under acme-corp, not spoofed globex-inc
      final acmeKey = multiTenantEngine.cache;
      final cachedEntry = await acmeKey.get(
        '[acme-corp|acme.portal.dev|en|USD]:/dashboard:/dashboard?',
      );
      expect(cachedEntry, isNotNull,
          reason:
              'Cache key must be partitioned by validated host tenant, not spoofed header');
    });
  });
}
