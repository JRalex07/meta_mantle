# Quick Start Guide

This guide provides minimal, fully compilable examples for each of MetaMantle's three rendering modes.

---

## Mode 1: Reactive Flutter Web Client (Engine A)

Wrap your route widgets with `MetaHead` to dynamically synchronize `<head>` metadata, Open Graph cards, and JSON-LD structured data during client-side navigation.

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
    return const MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MetaHead(
      metadata: WebMetadata(
        title: 'Home Page',
        description: 'Discover high-performance metadata management with MetaMantle.',
        canonical: 'https://example.com/',
        openGraph: const OpenGraph(
          title: 'Home Page | MetaMantle',
          description: 'Discover high-performance metadata management with MetaMantle.',
          type: 'website',
          image: 'https://example.com/og-home.png',
        ),
        jsonLd: [
          WebSiteSchema(
            name: 'MetaMantle Store',
            url: 'https://example.com',
          ),
        ],
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('MetaMantle Home')),
        body: const Center(child: Text('Welcome to MetaMantle!')),
      ),
    );
  }
}
```

---

## Mode 2: Static Site Pre-Rendering (Engine B)

Inject route-specific metadata directly into Flutter's `build/web` output before deployment.

### 1. Create `meta_mantle.config.json`:
```json
{
  "baseUrl": "https://example.com",
  "titleTemplate": "%s | My Store",
  "sitemap": true,
  "robotsTxt": true,
  "routes": [
    {
      "path": "/",
      "metadata": {
        "title": "Home",
        "description": "Welcome to our store homepage."
      }
    },
    {
      "path": "/about",
      "metadata": {
        "title": "About Us",
        "description": "Learn about our company and mission."
      }
    }
  ]
}
```

### 2. Build the Static HTML Documents:
```bash
# Option A: Unified Flutter Web Static Build Engine (compiles Flutter + pre-renders semantic HTML)
dart run meta_mantle build-web --mode hybrid --release

# Option B: Two-step build on pre-compiled web output
flutter build web --release
dart run meta_mantle build --config meta_mantle.config.json --strict
```

The `build/web` directory now contains pre-rendered HTML files (`/index.html`, `/about/index.html`, `/sitemap.xml`, `/robots.txt`). In `--mode hybrid`, client-side Flutter coordination is managed automatically through `MetaMantle.markReady()`.

---

## Mode 3: Native Server-Side Rendering (Engine C)

Render complete, crawler-friendly HTML responses on the server using pure Dart without headless browsers.

```dart
import 'dart:io';
import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() async {
  // 1. Configure in-memory or database provider
  final productDb = MemoryDataProvider<Map<String, dynamic>>(lookupParam: 'id')
    ..set('mug-101', {
      'id': 'mug-101',
      'name': 'Artisan Stoneware Mug',
      'price': 24.99,
      'description': 'Handcrafted ceramic mug.',
    });

  // 2. Define dynamic SSR route
  final productRoute = MetaRoute<Map<String, dynamic>>(
    pattern: '/products/:id',
    dataProvider: productDb,
    metadataBuilder: (data, ctx) => WebMetadata(
      title: data['name'] as String,
      description: data['description'] as String,
      canonical: 'https://store.example.com/products/${data['id']}/',
    ),
    htmlBuilder: (data, ctx) => [
      H.h1(data['name'] as String),
      H.p('Price: \$${data['price']}'),
      H.p(data['description'] as String),
    ],
    cachePolicy: const CachePolicy(
      ttl: Duration(hours: 1),
      staleWhileRevalidate: Duration(hours: 4),
    ),
  );

  // 3. Initialize Server Engine
  final engine = MetaMantleServerEngine(routes: [productRoute]);

  // 4. Mount with Shelf
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(engine.toShelfHandler());

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server rendering on http://localhost:${server.port}');
}
```
