// ignore_for_file: avoid_print
import 'dart:io';
import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8081;

  final cacheStore = MemoryCacheStore(maxEntries: 5000);
  final inventoryDispatcher = InventoryEventDispatcher(cacheStore);

  // E-commerce product catalog using new domain models
  final catalog = <String, ProductItem>{
    'artisan-ceramic-mug': const ProductItem(
      id: 'PROD-MUG-001',
      slug: 'artisan-ceramic-mug',
      name: 'Handmade Ceramic Coffee Mug',
      description:
          'Stoneware matte ceramic coffee mug crafted by master potters.',
      brand: 'Terracotta Living',
      price: 28.00,
      currency: 'USD',
      sku: 'MUG-EARTHEN-01',
      gtin: '01234567890123',
      images: ['https://store.metamantle.dev/assets/mug.jpg'],
      variants: [
        ProductVariant(
          name: '12oz Sandstone',
          sku: 'MUG-SAN-12',
          price: 28.00,
          availability: ItemAvailability.inStock,
          attributes: {'capacity': '12oz', 'color': 'Sandstone'},
        ),
        ProductVariant(
          name: '16oz Charcoal',
          sku: 'MUG-CHA-16',
          price: 34.00,
          availability: ItemAvailability.outOfStock,
          attributes: {'capacity': '16oz', 'color': 'Charcoal'},
        ),
      ],
      rating: ProductRating(
        ratingValue: 4.8,
        reviewCount: 124,
        bestRating: 5.0,
      ),
      shipping: ShippingDetails(
        shippingRate: 4.99,
        currency: 'USD',
        shippingDestination: 'US',
        deliveryTimeDays: 3,
      ),
      returnPolicy: ReturnPolicy(
        returnPolicyCategory:
            'https://schema.org/MerchantReturnFiniteReturnWindow',
        merchantReturnDays: 30,
        returnFees: 'https://schema.org/FreeReturn',
      ),
      category: 'Home & Kitchen > Tableware > Drinkware > Mugs',
      tags: ['ceramic', 'kitchen', 'artisan'],
    ),
  };

  // Faceted navigation policy protecting crawl budget
  const facetedPolicy = FacetedNavPolicy(
    baseCategoryUrl: 'https://store.metamantle.dev/products',
    allowedIndexableParams: {'category', 'brand'},
  );

  // Merchant feed generator for Google Shopping
  const merchantGenerator = MerchantFeedGenerator(
    storeName: 'MetaMantle Artisan Store Catalog',
    storeUrl: 'https://store.metamantle.dev',
    storeDescription:
        'High quality handcrafted goods with structured merchant feeds',
  );
  final merchantFeed =
      merchantGenerator.generateXmlFeed(catalog.values.toList());

  // SSR Route for E-Commerce Product
  final productDb = MemoryDataProvider<ProductItem>(lookupParam: 'slug');
  for (final entry in catalog.entries) {
    productDb.set(
      entry.key,
      entry.value,
      etag: 'w/"${entry.value.sku}-v1"',
    );
  }

  final productRoute = MetaRoute<ProductItem>(
    pattern: '/products/:slug',
    dataProvider: productDb,
    metadataBuilder: (product, context) => WebMetadata(
      title: product.name,
      description: product.description,
      canonical: 'https://store.metamantle.dev/products/${product.slug}/',
      openGraph: OpenGraph(
        type: OpenGraphType.product,
        title: product.name,
        description: product.description,
        image: product.images.isNotEmpty ? product.images.first : null,
      ),
      jsonLd: [product.toJsonLd(baseUrl: 'https://store.metamantle.dev')],
    ),
    htmlBuilder: (product, context) => [
      H.header([
        H.nav([
          H.a('/', 'Store Home'),
          H.a('/merchant/feed.xml', 'Google Merchant Feed'),
        ]),
      ]),
      H.main([
        H.article([
          H.h1(product.name),
          if (product.images.isNotEmpty)
            H.img(product.images.first,
                alt: product.name, width: 400, height: 400),
          H.p(product.description),
          H.p('Brand: ${product.brand} | Rating: ${product.rating?.ratingValue} / 5 (${product.rating?.reviewCount} reviews)'),
          H.h2('Available Options'),
          H.ul(
            product.variants
                .map((v) => H.li(
                    '${v.name} - \$${v.price} (${v.availability == ItemAvailability.inStock ? "In Stock" : "Sold Out"})'))
                .toList(),
          ),
        ]),
      ]),
    ],
    cachePolicy: const CachePolicy(
      ttl: Duration(minutes: 30),
      staleWhileRevalidate: Duration(hours: 2),
      tags: ['catalog', 'products'],
    ),
  );

  final engine = MetaMantleServerEngine(
    routes: [productRoute],
    cacheStore: cacheStore,
    config: const MetaMantleConfig(
      siteName: 'MetaMantle Artisan Store',
      titleTemplate: '%s | MetaMantle Artisan Store',
      baseUrl: 'https://store.metamantle.dev',
    ),
  );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) async {
    if (request.url.path == 'merchant/feed.xml') {
      return Response.ok(merchantFeed, headers: {
        'Content-Type': 'application/xml; charset=utf-8',
      });
    }
    if (request.url.path == 'catalog') {
      final decision = facetedPolicy.evaluate(request.url.queryParameters);
      return Response.ok(
        'Faceted Decision: robots=${decision.robots}, canonical=${decision.canonicalUrl}',
        headers: {'Content-Type': 'text/plain'},
      );
    }
    // Admin webhook test for inventory update
    if (request.url.path == 'webhooks/inventory' && request.method == 'POST') {
      final tags = await inventoryDispatcher.dispatch(
        const InventoryChanged(
          productId: 'PROD-MUG-001',
          slug: 'artisan-ceramic-mug',
          availableUnits: 0,
        ),
      );
      return Response.ok(
          'Invalidated ${tags.length} cache tags ($tags) for depleted stock.\n');
    }
    return metaMantleShelfHandler(engine)(request);
  });

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('========================================================');
  print(' MetaMantle E-Commerce Production Example Running');
  print(' URL: http://localhost:${server.port}');
  print(
      ' Product page: http://localhost:${server.port}/products/artisan-ceramic-mug');
  print(' Merchant XML: http://localhost:${server.port}/merchant/feed.xml');
  print(
      ' Faceted Nav:  http://localhost:${server.port}/catalog?category=kitchen&page=4&sort=price');
  print(
      ' Webhook Invalidation: POST http://localhost:${server.port}/webhooks/inventory');
  print('========================================================');
}
