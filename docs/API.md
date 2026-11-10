# API Reference — `meta_mantle`

Comprehensive documentation for all public APIs, configuration classes, metadata models, structured data helpers, and router integrations in MetaMantle.

---

## 1. Global Configuration — `MetaMantleConfig`

Configure global defaults once before `runApp`. (Legacy alias `WebHeadConfig` is also supported).

```dart
MetaMantle.initialize(
  config: const MetaMantleConfig(
    siteName: 'Example Store',
    baseUrl: 'https://example.com',
    defaultTitle: 'Example Store | Fresh Groceries',
    titleTemplate: '%s | Example Store',
    defaultDescription: 'Online grocery delivery in 30 minutes.',
    defaultImage: 'https://example.com/assets/social-card.png',
    defaultRobots: RobotsDirective.indexFollow,
    themeColor: '#0066cc',
    colorScheme: 'light dark',
    language: 'en',
    trailingSlash: true,
    includeCurrentUrlAsCanonical: true,
    debug: false,
  ),
);
```

### Parameters:
- `siteName` (`String?`): Name of the website/brand used across Open Graph tags.
- `baseUrl` (`String?`): Base origin (e.g. `'https://example.com'`) used to resolve relative URLs.
- `defaultTitle` (`String?`): Title used when a page does not supply one.
- `titleTemplate` (`String?`): Formatter for titles where `%s` is replaced by page title.
- `defaultDescription` (`String?`): Default meta description.
- `defaultImage` (`String?`): Fallback social card image.
- `defaultRobots` (`String?`): Default robots meta directive (default: `'index, follow'`).
- `themeColor` (`String?`): Hex color or named browser toolbar color.
- `colorScheme` (`String?`): Browser supported color schemes (e.g. `'light dark'`).
- `language` (`String?`): Default document language for `<html lang="...">`.
- `includeCurrentUrlAsCanonical` (`bool`): If true, uses the router's URL when canonical is unset.
- `trailingSlash` (`bool?`): When true, forces canonical URLs to end with a slash `/`.
- `debug` (`bool`): Enables debug messages during development.

---

## 2. Declarative Page Metadata — `MetaHead`

Primary widget for managing document head metadata. (Legacy alias `WebHead` is also supported).

```dart
MetaHead(
  active: true,
  metadata: WebMetadata(
    title: 'Organic Basmati Rice',
    description: 'Long-grain aged organic basmati rice.',
    canonical: 'https://example.com/products/basmati-rice/',
    keywords: 'rice, organic, basmati',
    author: 'Farm Direct',
    openGraph: const OpenGraph(
      type: OpenGraphType.product,
      image: 'https://example.com/assets/rice.png',
      imageWidth: 800,
      imageHeight: 800,
      imageAlt: 'Pack of basmati rice',
    ),
    twitter: const TwitterCard(
      card: TwitterCardType.summaryLargeImage,
      site: '@ExampleStore',
    ),
    jsonLd: [
      JsonLd.product(
        name: 'Organic Basmati Rice',
        image: 'https://example.com/assets/rice.png',
        sku: 'RICE-001',
      ),
    ],
  ),
  child: const ProductDetailsScreen(),
)
```

### Properties:
- `metadata` (`WebMetadata`): Metadata configuration for the page.
- `child` (`Widget`): Underlying page widget.
- `active` (`bool`): Whether this widget owns the active scope (default: `true`). Set to `false` for inactive/offstage tabs.

---

## 3. Imperative API — `MetaMantle`

Manage metadata programmatically from controllers or services outside the widget tree: (Legacy alias `FlutterWebHead` is also supported).

```dart
// Set specific metadata fields imperatively:
MetaMantle.setTitle('New Page Title');
MetaMantle.setDescription('Updated description.');
MetaMantle.setCanonical('https://example.com/custom');

// Update entire metadata scope:
MetaMantle.update(const WebMetadata(
  title: 'Maintenance Mode',
  robots: RobotsDirective.noindexNofollow,
));

// Clear imperative scope and restore active MetaHead widget:
MetaMantle.clearUpdate();

// Reset all package-managed tags:
MetaMantle.reset();

// Inspection properties:
WebMetadata? active = MetaMantle.activeMetadata;
int token = MetaMantle.generationToken;
bool supported = MetaMantle.isSupported;
```

---

## 4. Robots Directives — `RobotsDirective`

Convenience presets and custom builders for search engine crawler directives:

- `RobotsDirective.indexFollow`: `'index, follow'`
- `RobotsDirective.noindexFollow`: `'noindex, follow'`
- `RobotsDirective.indexNofollow`: `'index, nofollow'`
- `RobotsDirective.noindexNofollow`: `'noindex, nofollow'`
- `RobotsDirective.noarchive`: `'noarchive'`
- `RobotsDirective.nosnippet`: `'nosnippet'`
- `RobotsDirective.noimageindex`: `'noimageindex'`
- `RobotsDirective.none`: `'none'`
- `RobotsDirective.custom(...)`: Generates fine-grained directives (e.g. `max-snippet:160`, `max-image-preview:large`).

---

## 5. Open Graph — `OpenGraph` / `OpenGraphMetadata`

```dart
OpenGraph(
  type: OpenGraphType.website,
  title: 'Summer Sale',
  description: 'Huge discounts across all categories.',
  url: 'https://example.com/sale',
  image: 'https://example.com/assets/sale.png',
  imageAlt: 'Summer sale banner',
  imageWidth: 1200,
  imageHeight: 630,
  imageType: 'image/png',
  locale: 'en_US',
  alternateLocales: ['hi_IN', 'es_ES'],
  video: 'https://example.com/promo.mp4',
  audio: 'https://example.com/jingle.mp3',
  siteName: 'Example Store',
)
```

### Supported Types (`OpenGraphType`):
`website`, `article`, `product`, `profile`, `book`, `musicSong`, `musicAlbum`, `videoMovie`.

---

## 6. X/Twitter Cards — `TwitterCard` / `TwitterCardMetadata`

```dart
TwitterCard(
  card: TwitterCardType.summaryLargeImage,
  title: 'Summer Sale',
  description: 'Huge discounts.',
  image: 'https://example.com/assets/sale.png',
  imageAlt: 'Summer sale banner',
  site: '@ExampleStore',
  creator: '@JohnDoe',
)
```

### Supported Card Types (`TwitterCardType`):
`summary`, `summaryLargeImage`, `player`, `app`.

---

## 7. JSON-LD Structured Data — `JsonLd`

Rich schema helpers supporting schema.org:

- `JsonLd.organization({name, url, logo, sameAs, telephone, email})`
- `JsonLd.website({name, url, description, language})`
- `JsonLd.webPage({name, url, description, inLanguage})`
- `JsonLd.product({name, image, description, sku, brand, url, offers})`
- `JsonLd.article({headline, image, datePublished, dateModified, author, publisher, url, description})`
- `JsonLd.breadcrumb(items)`
- `JsonLd.localBusiness({name, address, telephone, image, url, priceRange})`
- `JsonLd.faqPage(questions)`
- `JsonLd.person({name, url, jobTitle, image})`
- `JsonLd.softwareApplication({name, operatingSystem, applicationCategory, offers, aggregateRating})`
- `JsonLd.event({name, startDate, endDate, locationName, description, url})`
- `JsonLd.offer({price, priceCurrency, availability, url})`
- `JsonLd.custom(Map<String, Object?> data)`

All JSON-LD scripts are serialized with `<` and `>` Unicode-escaped to prevent script injection.

---

## 8. Resource Hints — `ResourceHint`

Warm up network connections and preload critical assets:

```dart
resourceHints: [
  ResourceHint.preconnect('https://fonts.googleapis.com'),
  ResourceHint.dnsPrefetch('https://api.example.com'),
  ResourceHint.preload('https://example.com/font.woff2', asType: 'font', type: 'font/woff2', crossOrigin: 'anonymous'),
  ResourceHint.modulePreload('https://example.com/bundle.js'),
]
```

---

## 9. Router Integration

### Standard Flutter Navigator (`MetaMantleNavigatorObserver`)
Synchronizes the browser URL with `MetaMantle` on every route transition:

```dart
MaterialApp(
  navigatorObservers: [MetaMantleNavigatorObserver()],
  // ...
)
```

### GoRouter Integration (Manual Wrapping)
MetaMantle intentionally avoids coupling to `go_router`. Wrap individual routes or route shells with `MetaHead`:

```dart
GoRoute(
  path: '/about',
  builder: (context, state) => const MetaHead(
    metadata: WebMetadata(title: 'About Us'),
    child: AboutScreen(),
  ),
);
```

---

## 10. CLI Reference

```bash
# Diagnose environment and build readiness
dart run meta_mantle doctor --config meta_mantle.config.json

# Validate configuration syntax and dynamic data patterns
dart run meta_mantle validate --config meta_mantle.config.json

# Inspect all resolved routes and metadata without writing files
dart run meta_mantle inspect --config meta_mantle.config.json

# Generate route-specific HTML, sitemap.xml and robots.txt
dart run meta_mantle build \
  --config meta_mantle.config.json \
  --input build/web \
  --output build/web \
  --strict \
  --verbose
```
