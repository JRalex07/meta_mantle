# MetaMantle

[![CI](https://github.com/JRalex07/meta_mantle/actions/workflows/ci.yml/badge.svg)](https://github.com/JRalex07/meta_mantle/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/docs-metamantle.alex.runs--on.dev-blue.svg)](https://metamantle.alex.runs-on.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Typed metadata management and static SEO framework for Flutter Web, offering runtime DOM updates and static route HTML generation.**

MetaMantle brings Next.js Metadata and React Helmet capabilities to Flutter Web. Define your SEO and document metadata once in typed Dart, and apply it seamlessly both at runtime in the browser and ahead-of-time during static deployment builds.

- **Official Repository:** [https://github.com/JRalex07/meta_mantle](https://github.com/JRalex07/meta_mantle)
- **Official Documentation:** [https://metamantle.alex.runs-on.dev](https://metamantle.alex.runs-on.dev)

---

## Key Features

- **Dual Engine Architecture:**
  - **Engine A (Runtime DOM Injection):** High-performance DOM reconciliation using modern `package:web` (zero legacy `dart:html`). Updates `<title>`, `<meta>`, `<link>`, and `<script type="application/ld+json">` during client-side navigation.
  - **Engine B (Static Route Generator):** Injects route-specific metadata into Flutter's `build/web` output before deployment so search engine crawlers (Googlebot, Bingbot) and social bots (Twitterbot, Facebook, Slack, Discord) receive rich SEO metadata in the initial HTML response.
- **Unified Metadata Models:**
  - Full Open Graph (title, type, image with dimensions, video, audio, multiple locale alternates).
  - Twitter / X Cards (summary, summary large image, app, player).
  - 13 JSON-LD Structured Data builders (Organization, WebSite, Product, Article, Breadcrumb, LocalBusiness, FAQPage, Event, etc.) with XSS escaping.
  - Basic SEO: canonical URLs, robots directives, keywords, authors, publishers, theme color, color scheme, search verification tags.
  - Icons and Manifests: Favicons (PNG, SVG, ICO), Apple Touch Icons, Web App Manifests.
  - Resource Hints: `dns-prefetch`, `preconnect`, `prefetch`, `preload`, and `prerender`.
  - Custom Meta & Link tags.
- **Deterministic Runtime Lifecycle:**
  - Nested scope stacking and automatic parent scope restoration on page pop/dispose.
  - Safe against asynchronous route transitions via monotonic generation tokens.
  - Zero DOM mutations inside widget `build()` methods.
  - Safe non-web compilation: safe no-op stubs on Android, iOS, Windows, macOS, and Linux.
- **Production CLI Tooling:**
  - Complete CLI suite: `build`, `validate`, `inspect`, and `doctor`.
  - Dynamic route expansion from JSON data files with dot-notation templating (`{{brand.name}}`).
  - Automatic `sitemap.xml` and `robots.txt` generation.
  - `--strict`, `--dry-run`, and `--verbose` modes.

---

## Installation

### GitHub Git Dependency (Recommended)

Add `meta_mantle` directly from the official GitHub repository:

```yaml
dependencies:
  meta_mantle:
    git:
      url: https://github.com/JRalex07/meta_mantle.git
      ref: main # or a release tag such as v0.1.0
```

### Local Path Dependency

For local development or monorepos:

```yaml
dependencies:
  meta_mantle:
    path: ../meta_mantle
```

---

## Quick Start

### 1. Global Initialization (Optional)

Configure site-wide defaults in your application entrypoint:

```dart
import 'package:flutter/material.dart';
import 'package:meta_mantle/meta_mantle.dart';

void main() {
  MetaMantle.initialize(
    config: const MetaMantleConfig(
      siteName: 'MetaMantle Store',
      baseUrl: 'https://metamantle.alex.runs-on.dev',
      defaultTitle: 'MetaMantle Store',
      defaultDescription: 'Shop our catalog of high quality daily essentials.',
      titleTemplate: '%s | MetaMantle Store',
      defaultImage: 'https://metamantle.alex.runs-on.dev/assets/social-card.png',
      defaultRobots: RobotsDirective.indexFollow,
      themeColor: '#0066cc',
      colorScheme: 'light dark',
      language: 'en',
    ),
  );

  runApp(const MyApp());
}
```

### 2. Declarative Route Metadata with `MetaHead`

Wrap any screen with `MetaHead` (or legacy alias `WebHead`):

```dart
class ProductDetailPage extends StatelessWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return MetaHead(
      metadata: WebMetadata(
        title: product.name,
        description: product.summary,
        canonical: 'https://metamantle.alex.runs-on.dev/products/${product.slug}',
        robots: RobotsDirective.indexFollow,
        keywords: ['groceries', 'organic', product.category],
        author: 'MetaMantle Team',
        openGraph: OpenGraph(
          title: product.name,
          description: product.summary,
          type: OpenGraphType.product,
          image: product.imageUrl,
          imageAlt: product.name,
          imageWidth: 1200,
          imageHeight: 630,
        ),
        twitterCard: TwitterCard(
          card: TwitterCardType.summaryLargeImage,
          title: product.name,
          description: product.summary,
          image: product.imageUrl,
          site: '@metamantle',
        ),
        jsonLd: [
          JsonLd.product(
            name: product.name,
            description: product.summary,
            image: product.imageUrl,
            sku: product.sku,
            brand: 'MetaMantle',
            offers: JsonLd.offer(
              price: product.price,
              priceCurrency: 'USD',
              availability: 'https://schema.org/InStock',
            ),
          ),
          JsonLd.breadcrumb([
            BreadcrumbItem(name: 'Home', url: 'https://metamantle.alex.runs-on.dev'),
            BreadcrumbItem(name: 'Products', url: 'https://metamantle.alex.runs-on.dev/products'),
            BreadcrumbItem(name: product.name, url: 'https://metamantle.alex.runs-on.dev/products/${product.slug}'),
          ]),
        ],
        resourceHints: const [
          ResourceHint.preconnect('https://images.example.com', crossorigin: true),
        ],
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(product.name)),
        body: ProductView(product: product),
      ),
    );
  }
}
```

### 3. Navigator & Router Integration

#### Standard Navigator
Automatically track route changes with `MetaMantleNavigatorObserver`:

```dart
MaterialApp(
  navigatorObservers: [
    MetaMantleNavigatorObserver(),
  ],
  // ...
);
```

#### GoRouter Integration
To maintain a clean dependency tree without version locking, MetaMantle integrates with GoRouter via manual widget wrapping:

```dart
GoRoute(
  path: '/products/:id',
  builder: (context, state) => MetaHead(
    metadata: WebMetadata(
      title: 'Product ${state.pathParameters['id']}',
      canonical: 'https://metamantle.alex.runs-on.dev/products/${state.pathParameters['id']}',
    ),
    child: ProductScreen(id: state.pathParameters['id']!),
  ),
);
```

---

## Static Route Generation (CLI)

Ensure search engine crawlers and social share scrapers see rich metadata on the initial HTTP response without executing JavaScript.

### 1. Build your Flutter Web application

```bash
flutter build web --release
```

### 2. Configure `meta_mantle.config.json`

```json
{
  "baseUrl": "https://metamantle.alex.runs-on.dev",
  "siteName": "MetaMantle",
  "titleTemplate": "%s | MetaMantle",
  "trailingSlash": true,
  "defaults": {
    "robots": "index, follow",
    "language": "en",
    "themeColor": "#0066cc"
  },
  "robotsTxt": {
    "enabled": true,
    "rules": [
      {
        "userAgent": "*",
        "allow": ["/"],
        "disallow": ["/admin", "/checkout"]
      }
    ]
  },
  "routes": [
    {
      "path": "/",
      "metadata": {
        "title": "MetaMantle",
        "description": "Typed metadata management and static SEO framework for Flutter Web."
      }
    },
    {
      "path": "/about",
      "metadata": {
        "title": "About Us",
        "description": "Learn more about MetaMantle."
      }
    }
  ],
  "patterns": [
    {
      "pathPattern": "/products/:slug",
      "dataFile": "products.json",
      "slugField": "slug",
      "metadataTemplate": {
        "title": "{{name}}",
        "description": "{{description}}",
        "canonical": "https://metamantle.alex.runs-on.dev/products/{{slug}}/",
        "openGraph": {
          "type": "product",
          "title": "{{name}}",
          "description": "{{description}}",
          "image": "{{image}}"
        }
      }
    }
  ]
}
```

### 3. Generate Route HTML & SEO Assets

```bash
# Validate your configuration
dart run meta_mantle doctor --config meta_mantle.config.json

# Inspect expanded routes
dart run meta_mantle inspect --config meta_mantle.config.json

# Build static HTML, sitemap.xml, and robots.txt
dart run meta_mantle build --config meta_mantle.config.json --strict
```

---

## Documentation Website & Custom Domain Setup

The official documentation website is hosted via GitHub Pages at:
[https://metamantle.alex.runs-on.dev](https://metamantle.alex.runs-on.dev)

### DNS Configuration Instructions for Repository Owner:
To point `metamantle.alex.runs-on.dev` to GitHub Pages:
1. **Add CNAME Record in DNS:**
   - Type: `CNAME`
   - Host/Name: `metamantle` (under domain `alex.runs-on.dev`)
   - Target/Value: `jralex07.github.io`
2. **Configure in GitHub Repository:**
   - Go to **Settings > Pages**.
   - Under **Custom domain**, enter `metamantle.alex.runs-on.dev` and click **Save**.
   - Once DNS propagation is verified, check **Enforce HTTPS**.

---

## Security Architecture

- **Context-Aware Escaping:** `MetadataRenderer` escapes all HTML attributes and tag bodies.
- **XSS-Safe JSON-LD:** Structured data is serialized with Unicode character escaping for `<`, `>`, `&`, and `"` to prevent script tag breakout attacks (`</script><script>...`).
- **URL Sanitization:** `javascript:` and `data:` schemes are strictly rejected for canonical and alternate URLs.
- **Directory Traversal Protection:** Static file paths and route strings are validated against path traversal (`..`) prior to file writing.
- **Strict DOM Ownership:** Elements injected by the package are tagged with `data-mm-owner="meta_mantle"` and `data-mm-key`. Third-party tags and analytics scripts in `document.head` are strictly preserved.

---

## Documentation

- [Online Documentation](https://metamantle.alex.runs-on.dev)
- [API Reference](docs/API.md)
- [Architecture Guide](docs/ARCHITECTURE.md)
- [Security Architecture](docs/SECURITY.md)
- [Static Generation Guide](docs/STATIC_GENERATION.md)
- [Routing and Hosting Guide](docs/ROUTING_AND_HOSTING.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [SEO Limitations](docs/SEO_LIMITATIONS.md)
- [Build and Verification Status](BUILD_STATUS.md)

---

## License

MIT License. See [LICENSE](LICENSE) for details.
