import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:meta_mantle/meta_mantle_server.dart';

class SampleProduct {
  const SampleProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.price,
  });

  final String id;
  final String slug;
  final String name;
  final double price;
}

void main() {
  test('rejects unsafe SQL identifiers before invoking the query callback',
      () async {
    var called = false;
    final provider = RelationalDatabaseAdapter<String>(
      tableName: 'products; DROP TABLE users',
      queryRunner: (sql, parameters) async {
        called = true;
        return null;
      },
      rowMapper: (row) => '',
    );

    await expectLater(
      provider.load(RouteDataContext(
        path: '/products/item',
        parameters: {'slug': 'item'},
      )),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });

  group('Universal Database Provider Contract Tests', () {
    void runStandardProviderContractTests({
      required String providerName,
      required MetaMantleDataProvider<SampleProduct> Function() providerFactory,
      required Future<void> Function() seedData,
      required Future<void> Function() markDeleted,
    }) {
      group('Contract: $providerName', () {
        late MetaMantleDataProvider<SampleProduct> provider;

        setUp(() async {
          provider = providerFactory();
          await seedData();
        });

        test('returns found result for existing record', () async {
          final ctx = RouteDataContext(
            path: '/products/basmati-rice',
            parameters: {'slug': 'basmati-rice'},
          );
          final res = await provider.load(ctx);
          expect(res.isFound, isTrue);
          expect(res.isDeleted, isFalse);
          expect(res.data, isNotNull);
          expect(res.data!.slug, equals('basmati-rice'));
          expect(res.data!.name, equals('Premium Basmati Rice'));
          expect(res.lastModified, isNotNull);
          expect(res.etag, isNotNull);
        });

        test('returns notFound for missing record', () async {
          final ctx = RouteDataContext(
            path: '/products/non-existent',
            parameters: {'slug': 'non-existent'},
          );
          final res = await provider.load(ctx);
          expect(res.isFound, isFalse);
          expect(res.isDeleted, isFalse);
          expect(res.data, isNull);
        });

        test('returns gone for permanently removed record', () async {
          await markDeleted();
          final ctx = RouteDataContext(
            path: '/products/basmati-rice',
            parameters: {'slug': 'basmati-rice'},
          );
          final res = await provider.load(ctx);
          expect(res.isDeleted, isTrue);
          expect(res.data, isNull);
        });
      });
    }

    // 1. MemoryDataProvider Contract Verification
    final memStore = MemoryDataProvider<SampleProduct>();
    runStandardProviderContractTests(
      providerName: 'MemoryDataProvider',
      providerFactory: () => memStore,
      seedData: () async {
        memStore.set(
          'basmati-rice',
          const SampleProduct(
            id: '1',
            slug: 'basmati-rice',
            name: 'Premium Basmati Rice',
            price: 24.99,
          ),
          lastModified: DateTime.utc(2026, 1, 1),
          etag: 'w/"v1"',
        );
      },
      markDeleted: () async {
        memStore.markGone('basmati-rice');
      },
    );

    // 2. RelationalDatabaseAdapter Contract Verification
    final dbRows = <String, Map<String, dynamic>>{};
    final relationalAdapter = RelationalDatabaseAdapter<SampleProduct>(
      tableName: 'products',
      queryRunner: (sql, params) async {
        final key = params.first as String;
        return dbRows[key];
      },
      rowMapper: (row) => SampleProduct(
        id: row['id'] as String,
        slug: row['slug'] as String,
        name: row['name'] as String,
        price: (row['price'] as num).toDouble(),
      ),
    );

    runStandardProviderContractTests(
      providerName: 'RelationalDatabaseAdapter',
      providerFactory: () => relationalAdapter,
      seedData: () async {
        dbRows['basmati-rice'] = {
          'id': '1',
          'slug': 'basmati-rice',
          'name': 'Premium Basmati Rice',
          'price': 24.99,
          'updated_at': '2026-01-01T00:00:00.000Z',
          'version': '1',
        };
      },
      markDeleted: () async {
        dbRows['basmati-rice'] = {
          'id': '1',
          'slug': 'basmati-rice',
          'name': 'Premium Basmati Rice',
          'price': 24.99,
          'is_deleted': true,
        };
      },
    );

    // 3. DocumentDatabaseAdapter Contract Verification
    final docStore = <String, Map<String, dynamic>>{};
    final documentAdapter = DocumentDatabaseAdapter<SampleProduct>(
      collection: 'products',
      fetcher: (col, docId) async => docStore[docId],
      mapper: (id, data) => SampleProduct(
        id: id,
        slug: data['slug'] as String,
        name: data['name'] as String,
        price: (data['price'] as num).toDouble(),
      ),
    );

    runStandardProviderContractTests(
      providerName: 'DocumentDatabaseAdapter',
      providerFactory: () => documentAdapter,
      seedData: () async {
        docStore['basmati-rice'] = {
          'slug': 'basmati-rice',
          'name': 'Premium Basmati Rice',
          'price': 24.99,
          'updated_at': '2026-01-01T00:00:00.000Z',
          'version': 'v1',
          'is_deleted': false,
        };
      },
      markDeleted: () async {
        docStore['basmati-rice'] = {
          'is_deleted': true,
        };
      },
    );

    // 4. REST Data Provider Contract Verification
    test(
        'RestDataProvider parses JSON response and handles 404/410 status codes',
        () async {
      final mockClient = http_testing.MockClient((req) async {
        if (req.url.path.endsWith('/basmati-rice')) {
          return http.Response(
            json.encode({
              'id': '1',
              'slug': 'basmati-rice',
              'name': 'Premium Basmati Rice',
              'price': 24.99,
            }),
            200,
            headers: {
              'Content-Type': 'application/json',
              'ETag': 'w/"rest-1"',
            },
          );
        } else if (req.url.path.endsWith('/missing')) {
          return http.Response('Not Found', 404);
        } else if (req.url.path.endsWith('/deleted')) {
          return http.Response('Gone', 410);
        }
        return http.Response('Error', 500);
      });

      final restProvider = RestDataProvider<SampleProduct>(
        client: mockClient,
        urlBuilder: (ctx) =>
            'http://localhost:8080/items/${ctx.parameters['slug']}',
        ssrfGuard: const SsrfGuard(allowLocalhostInDev: true),
        mapper: (json) => SampleProduct(
          id: json['id'] as String,
          slug: json['slug'] as String,
          name: json['name'] as String,
          price: (json['price'] as num).toDouble(),
        ),
      );

      final found = await restProvider.load(RouteDataContext(
        path: '/items/basmati-rice',
        parameters: {'slug': 'basmati-rice'},
      ));
      expect(found.isFound, isTrue);
      expect(found.data!.name, equals('Premium Basmati Rice'));
      expect(found.etag, equals('w/"rest-1"'));

      final missing = await restProvider.load(RouteDataContext(
        path: '/items/missing',
        parameters: {'slug': 'missing'},
      ));
      expect(missing.isFound, isFalse);
      expect(missing.isDeleted, isFalse);

      final deleted = await restProvider.load(RouteDataContext(
        path: '/items/deleted',
        parameters: {'slug': 'deleted'},
      ));
      expect(deleted.isDeleted, isTrue);
    });
  });
}
