// ignore_for_file: avoid_print
import 'dart:io';
import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  // 1. Configure the Universal Data Provider for products
  final productDb = MemoryDataProvider<Map<String, dynamic>>(
    lookupParam: 'slug',
  );

  // Seed sample e-commerce catalogue
  productDb.set(
    'basmati-rice',
    {
      'id': 'PROD-101',
      'slug': 'basmati-rice',
      'name': 'Premium Himalayan Basmati Rice',
      'price': 24.99,
      'stock': 42,
      'description':
          'Naturally aged extra-long grain aromatic rice harvested from Himalayan foothills.',
      'image': 'https://metamantle.alex.runs-on.dev/assets/basmati-rice.png',
    },
    lastModified: DateTime.utc(2026, 1, 1),
    etag: 'w/"rice-v1"',
  );

  productDb.set(
    'whole-milk',
    {
      'id': 'PROD-102',
      'slug': 'whole-milk',
      'name': 'Organic Whole Milk',
      'price': 4.49,
      'stock': 18,
      'description':
          'Fresh pasture-raised whole milk enriched with essential vitamins and calcium.',
      'image': 'https://metamantle.alex.runs-on.dev/assets/whole-milk.png',
    },
    lastModified: DateTime.utc(2026, 1, 15),
    etag: 'w/"milk-v1"',
  );

  // 2. Configure SSR Routes
  final productRoute = MetaRoute<Map<String, dynamic>>(
    pattern: '/products/:slug',
    dataProvider: productDb,
    metadataBuilder: (product, context) => WebMetadata(
      title: product['name'] as String,
      description: product['description'] as String,
      canonical:
          'https://metamantle.alex.runs-on.dev/products/${product["slug"]}/',
      openGraph: OpenGraph(
        type: OpenGraphType.product,
        title: product['name'] as String,
        description: product['description'] as String,
        image: product['image'] as String,
      ),
      twitter: const TwitterCard(
        card: TwitterCardType.summaryLargeImage,
        site: '@MetaMantleStore',
      ),
      jsonLd: [
        JsonLd.product(
          name: product['name'] as String,
          description: product['description'] as String,
          image: product['image'] as String,
          sku: product['id'] as String,
          offers: JsonLd.offer(
            price: '${product["price"]}',
            priceCurrency: 'USD',
            availability: (product['stock'] as int) > 0
                ? 'https://schema.org/InStock'
                : 'https://schema.org/OutOfStock',
          ),
        ),
      ],
    ),
    htmlBuilder: (product, context) => [
      H.header([
        H.nav([
          H.a('/', 'Home'),
          H.a('/about', 'About Us'),
          H.a('/products/basmati-rice', 'Basmati Rice'),
          H.a('/products/whole-milk', 'Whole Milk'),
        ]),
      ]),
      H.main([
        H.article([
          H.h1(product['name'] as String),
          H.img(
            product['image'] as String,
            alt: product['name'] as String,
            width: 500,
            height: 500,
          ),
          H.p(product['description'] as String),
          H.p('Price: \$${product["price"]} | Stock: ${product["stock"]} units'),
          H.table(
            headers: ['Attribute', 'Details'],
            rows: [
              ['SKU', product['id'] as String],
              ['Delivery', 'Same-day delivery available'],
              [
                'Status',
                (product['stock'] as int) > 0 ? 'In Stock' : 'Sold Out'
              ],
            ],
          ),
        ]),
      ]),
      H.footer([
        H.p('© 2026 MetaMantle Store Inc. All rights reserved.'),
      ]),
    ],
    cachePolicy: const CachePolicy(
      ttl: Duration(minutes: 15),
      staleWhileRevalidate: Duration(hours: 1),
      tags: ['catalog', 'products'],
    ),
    includeFlutterBootstrap: true,
  );

  // 3. Initialize Server Engine with Cache Store and Global Config
  final cacheStore = MemoryCacheStore(maxEntries: 1000);

  final engine = MetaMantleServerEngine(
    routes: [productRoute],
    cacheStore: cacheStore,
    config: const MetaMantleConfig(
      siteName: 'MetaMantle Store',
      titleTemplate: '%s | MetaMantle Store',
      baseUrl: 'https://metamantle.alex.runs-on.dev',
      defaultRobots: RobotsDirective.indexFollow,
    ),
  );

  // 4. Mount Shelf Handler
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(metaMantleShelfHandler(engine));

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('========================================================');
  print(' MetaMantle SSR Production Server Running');
  print(' URL: http://localhost:${server.port}');
  print(' Try: http://localhost:${server.port}/products/basmati-rice');
  print(' Try: http://localhost:${server.port}/products/whole-milk');
  print('========================================================');
}
