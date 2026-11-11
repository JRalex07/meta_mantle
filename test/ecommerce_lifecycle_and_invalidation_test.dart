import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('E-Commerce End-to-End Inventory & Invalidation Lifecycle Tests', () {
    late MemoryCacheStore cacheStore;
    late InventoryEventDispatcher inventoryDispatcher;
    late MemoryDataProvider<ProductItem> productDb;
    late MetaMantleServerEngine engine;

    // Initial product state
    var currentProduct = const ProductItem(
      id: 'PROD-101',
      slug: 'artisan-mug',
      name: 'Handcrafted Ceramic Mug',
      description: 'Stoneware coffee mug crafted by master artisans.',
      brand: 'Terracotta',
      price: 28.00,
      currency: 'USD',
      sku: 'MUG-01',
      category: 'Kitchen',
      tags: ['ceramic', 'kitchen'],
      availability: ItemAvailability.inStock,
      variants: [
        ProductVariant(
          sku: 'MUG-01-S',
          name: 'Sandstone 12oz',
          price: 28.00,
          availability: ItemAvailability.inStock,
        ),
      ],
      shipping: ShippingDetails(
        shippingRate: 4.99,
        currency: 'USD',
        shippingDestination: 'US',
      ),
    );

    setUp(() {
      cacheStore = MemoryCacheStore();
      inventoryDispatcher = InventoryEventDispatcher(cacheStore);
      productDb = MemoryDataProvider<ProductItem>(lookupParam: 'slug');

      productDb.set(
        currentProduct.slug,
        currentProduct,
        etag: 'w/"mug-v1"',
        cacheTags: ['product:PROD-101', 'product:artisan-mug', 'prices'],
      );

      final productRoute = MetaRoute<ProductItem>(
        pattern: '/products/:slug',
        dataProvider: productDb,
        metadataBuilder: (p, ctx) => WebMetadata(
          title: p.name,
          description: p.description,
          canonical: 'https://store.example.com/products/${p.slug}/',
          jsonLd: [p.toJsonLd(baseUrl: 'https://store.example.com')],
        ),
        htmlBuilder: (p, ctx) => [
          H.h1(p.name),
          H.p('Price: \$${p.price.toStringAsFixed(2)}'),
          H.span(p.availability == ItemAvailability.inStock
              ? 'In Stock'
              : 'Sold Out'),
        ],
        cachePolicy: const CachePolicy(
          ttl: Duration(hours: 1),
          staleWhileRevalidate: Duration(hours: 4),
          tags: ['catalog', 'products'],
        ),
      );

      engine = MetaMantleServerEngine(
        routes: [productRoute],
        cacheStore: cacheStore,
      );
    });

    test(
        'Complete 9-Step Inventory Lifecycle: Request -> Cache -> Price Change -> Invalidate -> Verify New Render & Feed',
        () async {
      // 1. Initial Request
      final req1 = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://store.example.com/products/artisan-mug'),
      );
      final res1 = await engine.handleRequest(req1);
      expect(res1.statusCode, equals(200));
      expect(res1.headers['X-MetaMantle-Cache'], equals('MISS'));
      expect(res1.body, contains('Price: \$28.00'));
      expect(res1.body, contains('In Stock'));
      final etag1 = res1.headers['ETag']!;

      // 2. Cache Hit Verification
      final res2 = await engine.handleRequest(req1);
      expect(res2.statusCode, equals(200));
      expect(res2.headers['X-MetaMantle-Cache'], equals('HIT'));
      expect(res2.headers['ETag'], equals(etag1));

      // 3. Simulate Warehouse Price Update: $28.00 -> $21.99
      currentProduct = const ProductItem(
        id: 'PROD-101',
        slug: 'artisan-mug',
        name: 'Handcrafted Ceramic Mug',
        description: 'Stoneware coffee mug crafted by master artisans.',
        brand: 'Terracotta',
        price: 21.99,
        currency: 'USD',
        sku: 'MUG-01',
        category: 'Kitchen',
        tags: ['ceramic', 'kitchen'],
        availability: ItemAvailability.inStock,
      );

      productDb.set(
        currentProduct.slug,
        currentProduct,
        etag: 'w/"mug-v2"',
        cacheTags: ['product:PROD-101', 'product:artisan-mug', 'prices'],
      );

      // 4. Dispatch PriceChanged Event
      final invalidatedTags = await inventoryDispatcher.dispatch(
        const PriceChanged(
          productId: 'PROD-101',
          slug: 'artisan-mug',
          categorySlug: 'kitchen',
          oldPrice: 28.00,
          newPrice: 21.99,
        ),
      );
      expect(invalidatedTags, contains('product:PROD-101'));
      expect(invalidatedTags, contains('product:artisan-mug'));
      expect(invalidatedTags, contains('prices'));

      // 5. Re-request product route -> Must be cache MISS and render new price!
      final res3 = await engine.handleRequest(req1);
      expect(res3.statusCode, equals(200));
      expect(res3.headers['X-MetaMantle-Cache'], equals('MISS'));
      expect(res3.body, contains('Price: \$21.99'));
      expect(res3.headers['ETag'], isNot(equals(etag1)));

      // 6. Verify Structured Data contains new price
      final jsonLd =
          currentProduct.toJsonLd(baseUrl: 'https://store.example.com');
      final jsonStr = json.encode(jsonLd.data);
      expect(jsonStr, contains('21.99'));

      // 7. Verify Google Merchant XML Feed reflects updated price
      const merchantGen = MerchantFeedGenerator(
        storeName: 'Test Store',
        storeUrl: 'https://store.example.com',
        storeDescription: 'Test Catalog',
      );
      final merchantXml = merchantGen.generateXmlFeed([currentProduct]);
      expect(merchantXml, contains('<g:price>21.99 USD</g:price>'));
      expect(
          merchantXml, contains('<g:availability>in_stock</g:availability>'));
    });

    test(
        'Stock Depletion Lifecycle: availableUnits = 0 invalidates cache and marks Out of Stock',
        () async {
      final req = ServerRequest(
        method: 'GET',
        uri: Uri.parse('http://store.example.com/products/artisan-mug'),
      );

      // Prime cache
      await engine.handleRequest(req);

      // Warehouse stock depletes to 0
      currentProduct = const ProductItem(
        id: 'PROD-101',
        slug: 'artisan-mug',
        name: 'Handcrafted Ceramic Mug',
        description: 'Stoneware coffee mug crafted by master artisans.',
        brand: 'Terracotta',
        price: 28.00,
        currency: 'USD',
        sku: 'MUG-01',
        availability: ItemAvailability.outOfStock,
      );
      productDb.set(
        'artisan-mug',
        currentProduct,
        cacheTags: ['product:PROD-101', 'product:artisan-mug', 'inventory'],
      );

      // Dispatch inventory changed
      await inventoryDispatcher.dispatch(
        const InventoryChanged(
          productId: 'PROD-101',
          slug: 'artisan-mug',
          availableUnits: 0,
        ),
      );

      // Re-request must show Sold Out
      final res = await engine.handleRequest(req);
      expect(res.body, contains('Sold Out'));

      // Check Merchant Feed availability
      const merchantGen = MerchantFeedGenerator(
        storeName: 'Test Store',
        storeUrl: 'https://store.example.com',
        storeDescription: 'Test Catalog',
      );
      final xml = merchantGen.generateXmlFeed([currentProduct]);
      expect(xml, contains('<g:availability>out_of_stock</g:availability>'));
    });

    test(
        'Faceted Navigation Policy protects crawl budget and normalizes canonical URLs',
        () {
      const policy = FacetedNavPolicy(
        baseCategoryUrl: 'https://store.example.com/categories/kitchen',
        allowedIndexableParams: {'brand', 'color'},
        canonicalizeToCategory: false,
        maxFilterParameters: 2,
        noindexPaginationAfterPage: 5,
      );

      // 1. Clean category page
      final d1 = policy.evaluate({});
      expect(d1.shouldIndex, isTrue);
      expect(d1.canonicalUrl,
          equals('https://store.example.com/categories/kitchen/'));
      expect(d1.robots, contains('index, follow'));

      // 2. Allowed indexable filters (<= 2)
      final d2 = policy.evaluate({'brand': 'terracotta'});
      expect(d2.shouldIndex, isTrue);

      // 3. Sorting parameter -> Noindex & canonical resets to unsorted category
      final d3 = policy.evaluate({'sort': 'price_desc'});
      expect(d3.shouldIndex, isFalse);
      expect(d3.robots, contains('noindex, follow'));
      expect(d3.canonicalUrl,
          equals('https://store.example.com/categories/kitchen/'));

      // 4. Excessive filter combinations (> 2) -> Noindex
      final d4 = policy
          .evaluate({'brand': 'terracotta', 'color': 'sand', 'size': 'large'});
      expect(d4.shouldIndex, isFalse);
      expect(d4.robots, contains('noindex, follow'));

      // 5. Deep pagination (> 5) -> Noindex
      final d5 = policy.evaluate({'page': '6'});
      expect(d5.shouldIndex, isFalse);
      expect(d5.robots, contains('noindex, follow'));
    });
  });
}
