# MetaMantle E-Commerce SEO Architecture

MetaMantle provides an enterprise-grade SEO and structured data engine specifically engineered for high-scale e-commerce catalogs on Dart and Flutter Web.

---

## 1. Google Merchant & Product Rich Snippets

Google Search enforces strict schema requirements for product eligibility in rich search snippets, image carousels, and merchant listings.

MetaMantle's `ProductItem` model generates schema.org compliant JSON-LD with:
- **`Product` / `ProductGroup`**: Canonical entity naming, description, SKU, GTIN/EAN barcodes, brand, and category classification.
- **`AggregateOffer`**: Variant price range (`lowPrice`, `highPrice`), item availability (`InStock`, `OutOfStock`, `PreOrder`), and currency codes.
- **`OfferShippingDetails`**: Flat or tiered shipping rates, transit time quantitative bounds, and destination country codes.
- **`MerchantReturnPolicy`**: Finite return windows, return shipping fees, and merchant policy links.
- **`AggregateRating`**: Verified customer review aggregates and score boundaries.

```dart
final product = ProductItem(
  id: 'PROD-101',
  slug: 'artisan-mug',
  name: 'Handcrafted Ceramic Mug',
  description: 'Stoneware coffee mug crafted by master artisans.',
  brand: 'Terracotta',
  price: 28.00,
  currency: 'USD',
  sku: 'MUG-01',
  gtin: '01234567890123',
  images: ['https://store.example.com/assets/mug.jpg'],
  variants: [
    ProductVariant(
      name: 'Sandstone 12oz',
      sku: 'MUG-01-S',
      price: 28.00,
      availability: ItemAvailability.inStock,
    ),
  ],
  rating: ProductRating(ratingValue: 4.8, reviewCount: 95),
  shipping: ShippingDetails(shippingRate: 4.99, currency: 'USD'),
  returnPolicy: ReturnPolicy(merchantReturnDays: 30),
);

// Generates Google-compliant JSON-LD
final jsonLd = product.toJsonLd(baseUrl: 'https://store.example.com');
```

---

## 2. Event-Driven Inventory Cache Invalidation

E-commerce catalogs encounter frequent stock and price changes. Stale cached pricing or out-of-stock items can harm search rankings and violate Google Merchant Center accuracy policies.

MetaMantle implements `InventoryEventDispatcher` with atomic tag invalidation:

| Event Type | Affected Cache Tags | Target Routes |
| :--- | :--- | :--- |
| `PriceChanged` | `product:$id`, `product:$slug`, `prices`, `category:$slug` | `/products/$slug`, `/categories/$slug` |
| `InventoryChanged` | `product:$id`, `product:$slug`, `inventory` | `/products/$slug` |
| `StockDepleted` | `product:$id`, `product:$slug`, `catalog`, `out-of-stock` | `/products/$slug`, `/catalog` |
| `ProductSlugChanged` | `product:$id`, `product:$slug`, `product:$newSlug`, `catalog` | 301 Redirect old -> new, purge both |

```dart
final dispatcher = InventoryEventDispatcher(cacheStore);

// When inventory depletes in warehouse:
await dispatcher.dispatch(
  InventoryChanged(
    productId: 'PROD-101',
    slug: 'artisan-mug',
    availableUnits: 0,
  ),
);
```

---

## 3. Crawl Budget Protection for Faceted Navigation

Faceted filters (color, size, price, sorting, pagination) create exponential URL combinations, leading to duplicate content penalties and crawl budget exhaustion.

`FacetedNavPolicy` provides automated crawl governance:
- **Indexable Filters**: Only whitelisted singular attributes (e.g. `category`, `brand`) remain indexable.
- **Parameter Explosion Guard**: Query parameters exceeding `maxFilterParameters` (default 2) receive `noindex, follow`.
- **Sorting Parameters**: Filters containing `sort`, `order`, or `dir` are automatically marked `noindex, follow` and canonicalized to the unsorted root category.
- **Deep Pagination Guard**: Pages exceeding threshold (default page 5) receive `noindex, follow` to prevent bot traps.

```dart
const facetedPolicy = FacetedNavPolicy(
  baseCategoryUrl: 'https://store.example.com/categories/kitchen',
  allowedIndexableParams: {'brand', 'category'},
  maxFilterParameters: 2,
  noindexPaginationAfterPage: 5,
);

final decision = facetedPolicy.evaluate(request.url.queryParameters);
// Returns canonicalUrl and strict robots directive ('index, follow' vs 'noindex, follow')
```

---

## 4. Automated Google Merchant XML Feeds

`MerchantFeedGenerator` emits standard Google Merchant Center RSS 2.0 XML with the `xmlns:g="http://base.google.com/ns/1.0"` namespace:

```dart
const generator = MerchantFeedGenerator(
  storeName: 'MetaMantle Store',
  storeUrl: 'https://store.example.com',
  storeDescription: 'Handcrafted Goods & Homeware',
);

final xmlFeed = generator.generateXmlFeed(products);
// Produces <g:id>, <g:title>, <g:price>, <g:availability>, <g:condition>, and <g:shipping>
```

