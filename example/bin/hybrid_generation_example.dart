// ignore_for_file: avoid_print
import 'dart:io';

import 'package:meta_mantle/meta_mantle_builder.dart';

class ProductRecord {
  const ProductRecord({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.price,
  });

  final String id;
  final String slug;
  final String name;
  final String description;
  final double price;
}

/// Demonstrates paginated source discovery and complete product documents.
/// Pass a record count as the first argument; defaults to 10,000.
Future<void> main(List<String> arguments) async {
  final keepOutput = arguments.contains('--keep');
  final positional = arguments.where((arg) => arg != '--keep').toList();
  final recordCount = positional.isEmpty ? 10000 : int.parse(positional.first);
  if (recordCount < 1 || recordCount > 100000) {
    throw ArgumentError('record count must be between 1 and 100000');
  }
  final output = await Directory.systemTemp.createTemp('metamantle-hybrid-');
  final records = List.generate(
    recordCount,
    (index) => ProductRecord(
      id: 'product-$index',
      slug: 'product-$index',
      name: 'Example product $index',
      description: 'Semantic product page generated from record $index.',
      price: 10 + index / 100,
    ),
    growable: false,
  );
  final store = FileHtmlArtifactStore(output);
  final generator = HybridStaticGenerator(
    store: store,
    siteBaseUrl: 'https://shop.example/',
  );

  try {
    await generator.generateFixedPages([
      FixedRouteSource(
        routeId: 'marketing',
        path: '/',
        render: () async => GeneratedRouteDocument(
          html: HtmlDocument(
            metadata: const WebMetadata(
              title: 'Example shop',
              description: 'A sample fixed marketing page.',
              canonical: 'https://shop.example/',
            ),
            bodyNodes: [
              H.h1('Example shop'),
              H.p('Browse a catalogue of generated product pages.'),
            ],
          ).render(currentUrl: 'https://shop.example/'),
          tags: const ['public'],
        ),
      ),
    ]);
    final stopwatch = Stopwatch()..start();
    final report = await generator.generate<ProductRecord>(
      CollectionRouteSource<ProductRecord>(
        routeId: 'products',
        pathPattern: '/products/:key',
        pageSize: 250,
        concurrency: 8,
        maxRecords: recordCount,
        discover: (cursor, limit) async {
          final start = int.tryParse(cursor ?? '0') ?? 0;
          final end = (start + limit).clamp(0, records.length);
          return RouteDiscoveryPage<ProductRecord>(
            records: records.sublist(start, end),
            nextCursor: end < records.length ? '$end' : null,
          );
        },
        keyOf: (product) => product.slug,
        tagsOf: (product) => ['catalog', 'product:${product.id}'],
        versionOf: (product) => product.id,
        render: (product, path) async {
          final canonical = 'https://shop.example$path';
          final document = HtmlDocument(
            metadata: WebMetadata(
              title: product.name,
              description: product.description,
              canonical: canonical,
              jsonLd: [
                JsonLd.product(
                  name: product.name,
                  image: 'https://shop.example/images/${product.slug}.jpg',
                  description: product.description,
                  sku: product.id,
                  brand: 'Example brand',
                  url: canonical,
                  offers: {
                    '@type': 'Offer',
                    'priceCurrency': 'USD',
                    'price': product.price.toStringAsFixed(2),
                    'availability': 'https://schema.org/InStock',
                  },
                ),
              ],
            ),
            bodyNodes: [
              H.h1(product.name),
              H.tag('img',
                  attributes: {
                    'src': 'https://shop.example/images/${product.slug}.jpg',
                    'alt': product.name,
                    'loading': 'lazy',
                  },
                  isSelfClosing: true),
              H.p(product.description),
              H.p('Price: \$${product.price.toStringAsFixed(2)}'),
              H.a('/products', 'Browse products'),
            ],
          );
          return GeneratedRouteDocument(
            html: document.render(currentUrl: canonical),
            tags: ['category:example'],
            sourceVersion: product.id,
            canonicalUrl: canonical,
          );
        },
      ),
    );
    stopwatch.stop();
    final exportStopwatch = Stopwatch()..start();
    final staticOutput = Directory('${output.path}-site');
    await store.exportActiveVersion(staticOutput);
    exportStopwatch.stop();
    final sitemap = await store.readVersionSitemap(
      (await store.activeVersion)!,
    );
    print('Generated ${report.generated} of ${report.discovered} products');
    print('Generation: ${stopwatch.elapsedMilliseconds} ms');
    print('Static export: ${exportStopwatch.elapsedMilliseconds} ms');
    print('Artifact directory: ${output.path}');
    print('Sitemap entries: ${RegExp('<url>').allMatches(sitemap!).length}');
    print('Static output directory: ${staticOutput.path}');
    print('First page: ${staticOutput.path}/products/product-0/index.html');
    if (!keepOutput) print('Pass --keep to retain the generated directory.');
  } finally {
    if (!keepOutput) {
      await output.delete(recursive: true);
      if (await Directory('${output.path}-site').exists()) {
        await Directory('${output.path}-site').delete(recursive: true);
      }
    }
  }
}
