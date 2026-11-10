# Schema.org Structured Data (JSON-LD)

MetaMantle features type-safe constructors for Schema.org JSON-LD structured data.

---

## 1. Supported Schema Models

All JSON-LD schemas are emitted within `<script type="application/ld+json">` tags in the `<head>` of static HTML and SSR responses:

### 1. Product & AggregateOffer
```dart
JsonLd.product(
  name: 'Organic Basmati Rice',
  description: 'Pure aged long-grain rice.',
  sku: 'RICE-01',
  offers: JsonLd.offer(
    price: '24.99',
    priceCurrency: 'USD',
    availability: 'InStock',
  ),
);
```
Or for multi-seller marketplaces:
```dart
JsonLd.aggregateOffer(
  lowPrice: '19.99',
  highPrice: '29.99',
  priceCurrency: 'USD',
  offerCount: 5,
);
```

### 2. Articles, News, and Blog Posts
- `JsonLd.article(...)`
- `JsonLd.blogPosting(...)`
- `JsonLd.newsArticle(...)`

### 3. Media Objects
- `JsonLd.videoObject(...)`: Includes `duration`, `thumbnailUrl`, `uploadDate`.
- `JsonLd.imageObject(...)`: Includes `contentUrl`, `caption`, `license`.

### 4. Site Structure & Navigation
- `JsonLd.organization(...)`: Site name, logo, contact points, social links.
- `JsonLd.breadcrumbList(...)`: Breadcrumb trail displayed in Google search results.
- `JsonLd.webSite(...)`: Enables Google Sitelinks Search Box.

