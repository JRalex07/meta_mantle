# MetaMantle Quick Start Guide

This step-by-step tutorial walks you through creating, configuring, building, and deploying a universal Dart application with MetaMantle.

---

## 1. Requirements & Prerequisites

- **Dart SDK**: `>=3.6.0 <4.0.0`
- **Flutter SDK**: `>=3.27.0`
- Supported target platforms: Web (CanvasKit, Skwasm, WasmGC, or lightweight DOM), iOS, Android, macOS, Linux, Windows, and Server (Shelf).

Check your local environment:
```bash
flutter doctor -v
dart --version
```

---

## 2. Installation

Add `meta_mantle` to your `pubspec.yaml`:

```yaml
dependencies:
  meta_mantle: ^0.2.0
  flutter:
    sdk: flutter

dev_dependencies:
  meta_mantle_builder: ^0.2.0
  flutter_test:
    sdk: flutter
```

Run `flutter pub get` to fetch dependencies.

---

## 3. Application Entrypoint

In your `lib/main.dart`, initialize your app using `MetaMantleApp` and attach the `MetaMantleGoRouterObserver` (or navigator observer) so route updates seamlessly synchronize with browser `<head>` tags:

```dart
import 'package:flutter/material.dart';
import 'package:meta_mantle/meta_mantle.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MetaMantle Universal App',
      navigatorObservers: [
        MetaMantleGoRouterObserver(
          markReadyOnFirstFrame: true,
          onRouteChanged: (path) => debugPrint('Navigated to: $path'),
        ),
      ],
      routes: {
        '/': (context) => const HomeScreen(),
        '/about': (context) => const AboutScreen(),
      },
    );
  }
}
```

---

## 4. Universal Components

MetaMantle enables writing UI components once that can render to:
1. Native Flutter widgets on mobile and desktop
2. Semantic HTML elements on the web and during SSR
3. Direct browser DOM nodes with zero CanvasKit overhead

```dart
import 'package:meta_mantle/meta_mantle_universal.dart';

class ProductCard extends MantleComponent {
  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.onAddToCart,
  });

  final String name;
  final double price;
  final VoidCallback onAddToCart;

  @override
  MantleNode build(MantleContext context) {
    return MantleArticle(
      className: 'product-card',
      children: [
        MantleHeading(2, name),
        MantleText('Price: \$${price.toStringAsFixed(2)}'),
        MantleButton(
          label: 'Add to Cart',
          onPressed: onAddToCart,
        ),
      ],
    );
  }
}
```

---

## 5. Route Manifest

Declare your static pages and metadata in `lib/meta_mantle_routes.dart`:

```dart
import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

final metaMantleRoutes = StaticRouteManifest(
  routes: [
    StaticPageRoute(
      path: '/',
      metadata: const WebMetadata(
        title: 'Home | Ultra-Fast Universal Flutter Web',
        description: 'Blazing-fast pre-rendered Flutter Web applications with pure HTML SEO.',
        canonical: 'https://example.com/',
        openGraph: OpenGraph(
          title: 'Home | Ultra-Fast Universal Flutter Web',
          description: 'Blazing-fast pre-rendered Flutter Web applications with pure HTML SEO.',
          image: 'https://example.com/og-home.jpg',
        ),
      ),
      componentBuilder: (ctx) => const MantleColumn(
        children: [
          MantleHeading(1, 'Welcome to MetaMantle'),
          MantleText('Rendered universally to Flutter widgets and semantic HTML.'),
        ],
      ),
    ),
    StaticPageRoute(
      path: '/about',
      metadata: const WebMetadata(
        title: 'About Us | MetaMantle',
        description: 'Learn about our engineering philosophy and architecture.',
        canonical: 'https://example.com/about',
      ),
      componentBuilder: (ctx) => const MantleColumn(
        children: [
          MantleHeading(1, 'About Us'),
          MantleText('Universal Dart application framework.'),
        ],
      ),
    ),
  ],
);

void main(List<String> args) => runStaticManifest(metaMantleRoutes, args);
```

---

## 6. Build Configuration

Create `meta_mantle.yaml` in your project root:

```yaml
baseUrl: https://example.com
titleTemplate: "%s | MetaMantle"
sitemap:
  enabled: true
  changefreq: weekly
  priority: 0.8
robots:
  enabled: true
  allow:
    - /
  disallow:
    - /admin
```

---

## 7. Executing the Production Build

Run the universal Flutter Web Build Engine:

```bash
dart run meta_mantle build-web --mode=hybrid --strict
```

The build engine executes:
1. `flutter build web --release`
2. Generates semantic HTML trees for all routes
3. Injects canonical tags, Open Graph cards, and JSON-LD schemas
4. Sets up the smooth client-side transition handshake
5. Emits `sitemap.xml` and `robots.txt` into `build/web`

---

## 8. Inspecting the Generated Artifacts

Verify generated HTML files:

```bash
dart run meta_mantle html inspect --file build/web/index.html
```

Inspect metadata tags, headings, Open Graph image URLs, and JSON-LD script blocks.

---

## 9. Running the Local Preview Server

Start the built-in HTTP server to test pre-rendered routes and client transitions:

```bash
dart run meta_mantle preview --dir build/web --port 8080
```

Open `http://localhost:8080` in your browser. Notice the instantaneous first contentful paint (FCP), followed by seamless hydration.

---

## 10. Deployment

### Firebase Hosting
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### Vercel / Cloudflare Pages / Netlify
Point the deployment directory to `build/web`. All pre-rendered route directories (`/about/index.html`) will be served statically by CDN edge nodes with optimal caching.

---

## 11. Verifying SEO & Core Web Vitals

Audit your production bundle before deploying:

```bash
dart run meta_mantle validate --dir build/web --strict
dart run meta_mantle report --dir build/web
```

Confirm that:
- Cumulative Layout Shift (CLS) is prevented with explicit image dimensions
- Alt text coverage is 100%
- Canonical URLs match your production domain
- First Contentful Paint (FCP) and Largest Contentful Paint (LCP) achieve 95+ Lighthouse scores.
