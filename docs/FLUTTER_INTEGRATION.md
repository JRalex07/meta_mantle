# MetaMantle Flutter Web Runtime Integration

MetaMantle's runtime engine allows Flutter developers to manage browser `<head>` metadata, Open Graph cards, search engine directives, and structured JSON-LD directly from Flutter widget trees.

---

## 1. The `WebHead` Widget

The `WebHead` widget dynamically pushes metadata changes into the browser DOM during widget mounting and lifecycle updates.

```dart
import 'package:material_ui/material_ui.dart';
import 'package:meta_mantle/meta_mantle.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return WebHead(
      metadata: WebMetadata(
        title: product.name,
        description: product.description,
        canonical: 'https://store.example.com/products/${product.slug}/',
        openGraph: OpenGraph(
          type: OpenGraphType.product,
          title: product.name,
          description: product.description,
          image: product.imageUrl,
        ),
        twitter: const TwitterCard(
          card: TwitterCardType.summaryLargeImage,
        ),
        jsonLd: [
          JsonLd.product(
            name: product.name,
            description: product.description,
            image: product.imageUrl,
            sku: product.sku,
            offers: JsonLd.offer(
              price: product.price.toStringAsFixed(2),
              priceCurrency: 'USD',
            ),
          ),
        ],
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(product.name)),
        body: Center(child: Text(product.description)),
      ),
    );
  }
}
```

---

## 2. Navigation & Router Integration

When navigating between routes via Flutter's Navigator or routers (GoRouter, Beamer, AutoRoute), MetaMantle maintains a metadata stack:
- When a new route pushes, its `WebHead` metadata takes precedence and updates the browser `<head>`.
- When the route pops, MetaMantle cleanly cleans up page-specific tags and restores the previous route's metadata.

To synchronize route names automatically:

```dart
MaterialApp(
  navigatorObservers: [
    WebHeadNavigatorObserver(),
  ],
  // ...
);
```

---

## 3. WebAssembly (Wasm) Compatibility

Flutter 3.27+ supports compiling web applications to WebAssembly (`dart2wasm`).

MetaMantle's runtime engine uses standard `package:web` interop with zero legacy `dart:html` imports, making it 100% compatible with WebAssembly builds:

```bash
flutter build web --wasm --release
```

