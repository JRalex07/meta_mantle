# MetaMantle Core Architecture

`meta_mantle_core.dart` is the pure-Dart, platform-agnostic source entrypoint. It has **zero imports of `package:flutter` and `dart:io`**. However, the root `meta_mantle` package manifest requires Flutter for dependency resolution, so this entrypoint is not currently distributed as a Dart-SDK-only package.

---

## 1. Core Modules & Responsibilities

The core library (`lib/meta_mantle_core.dart`) provides:

1. **Metadata Modeling (`WebMetadata`, `OpenGraph`, `TwitterCard`, `RobotsDirective`, `JsonLd`)**:
   Immutable, strongly typed representations of all web document head metadata.
2. **Metadata Rendering (`MetadataRenderer`)**:
   Deterministic serialization of metadata objects into standards-compliant HTML `<head>` tags.
3. **HTML Semantic Node Engine (`HtmlNode`, `H`, `HtmlDocument`)**:
   Type-safe HTML representation capable of emitting semantic document bodies and full HTML5 documents without requiring a web browser or virtual DOM.
4. **HTML Security & Sanitization (`HtmlSanitizer`)**:
   Strict allowlist-based sanitizer stripping malicious tags (`<script>`, `<iframe>`, `<object>`) and dangerous attributes (`onclick`, `javascript:` URLs).

---

## 2. Typed Metadata Primitives

### WebMetadata
The root container for page metadata:
```dart
const metadata = WebMetadata(
  title: 'Organic Basmati Rice',
  description: 'Aromatic long-grain basmati rice harvested sustainably.',
  canonical: 'https://example.com/products/basmati-rice/',
  keywords: 'rice, organic, basmati, pantry',
  robots: RobotsDirective.indexFollow,
  openGraph: OpenGraph(
    title: 'Organic Basmati Rice',
    type: OpenGraphType.product,
    image: 'https://example.com/images/rice.jpg',
  ),
  twitter: TwitterCard(
    card: TwitterCardType.summaryLargeImage,
    site: '@MetaMantle',
  ),
  jsonLd: [
    JsonLd.product(
      name: 'Organic Basmati Rice',
      description: 'Aromatic long-grain basmati rice.',
      sku: 'RICE-001',
      offers: JsonLd.offer(
        price: '24.99',
        priceCurrency: 'USD',
        availability: 'InStock',
      ),
    ),
  ],
);
```

### JSON-LD Structured Data
MetaMantle Core supports high-fidelity Schema.org schemas:
- `JsonLd.product(...)` & `JsonLd.aggregateOffer(...)`
- `JsonLd.article(...)`, `JsonLd.blogPosting(...)`, `JsonLd.newsArticle(...)`
- `JsonLd.videoObject(...)`, `JsonLd.imageObject(...)`
- `JsonLd.organization(...)`, `JsonLd.breadcrumbList(...)`

---

## 3. Semantic HTML Builder (`H`)

The core library contains a DSL for creating semantic HTML trees:
```dart
final nodes = [
  H.header([
    H.h1('Fresh Produce'),
    H.p('Directly from certified local farmers.'),
  ]),
  H.article([
    H.h2('Farm-Fresh Apples'),
    H.img(src: '/images/apple.jpg', alt: 'Crisp red apple'),
    H.p('Picked this morning with care.'),
    H.a(href: '/order/apple', text: 'Order Now'),
  ]),
];
```

The tree is rendered through `HtmlDocument`:
```dart
final doc = HtmlDocument(
  metadata: metadata,
  bodyNodes: nodes,
  includeFlutterBootstrap: true,
);

final fullHtml = doc.render(currentUrl: '/products/apples/');
```

---

## 4. Portability & Compatibility Guarantees

- **No Flutter Dependency**: Does not import `flutter`, `dart:ui`, or Flutter widget trees.
- **No Dart IO Dependency**: Does not import `dart:io`, ensuring total compatibility with Dart Web, Node/Wasm, and edge runtimes.
- **Deterministic Output**: Tag ordering, attribute escaping, and template evaluation produce byte-for-byte identical output on every platform.

