# Engine A: Runtime SEO & Metadata Management

MetaMantle's Runtime Engine manages the HTML `<head>` directly from the client-side Flutter Web application during active user sessions.

---

## 1. Overview & Mechanics

When running in the browser, Flutter applications typically render via Canvas or WebAssembly inside a single `<canvas>` or `<flt-glass-pane>` element. However, search engine crawlers, social share preview bots, and browser tab titles rely on actual DOM tags inside `<head>`.

The Runtime Engine bridges Flutter's widget tree to the real browser DOM using:
1. `WebHead` widget: Scopes metadata to the widget lifecycle (`initState`, `didUpdateWidget`, `dispose`).
2. `MetaMantleCoordinator`: Maintains a stack of active metadata layers, cleanly resolving hierarchical overrides (e.g., App Default -> Layout -> Page -> Modal).
3. `DomAdapter`: Injects tags into `document.head` using standard web interop (`package:web` and `dart:js_interop`).
4. `MetaMantleNavigatorObserver`: Automatically syncs router transitions with metadata updates.

---

## 2. Using `WebHead`

Place `WebHead` at the top of your page's widget build method:

```dart
class ProductDetailPage extends StatelessWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return WebHead(
      metadata: WebMetadata(
        title: product.name,
        description: product.summary,
        canonical: 'https://example.com/products/${product.slug}/',
        openGraph: OpenGraph(
          title: product.name,
          type: OpenGraphType.product,
          image: product.imageUrl,
        ),
        jsonLd: [
          JsonLd.product(
            name: product.name,
            description: product.summary,
            sku: product.sku,
            offers: JsonLd.offer(
              price: product.price.toStringAsFixed(2),
              priceCurrency: 'USD',
              availability: 'InStock',
            ),
          ),
        ],
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(product.name)),
        body: ProductDetailView(product: product),
      ),
    );
  }
}
```

---

## 3. WebAssembly (Wasm) Compatibility

MetaMantle Runtime uses `package:web` and Dart's official modern JS interop (`dart:js_interop`). It strictly avoids legacy `dart:html` or `dart:js` imports.

### Verification:
```bash
flutter build web --wasm
```
MetaMantle compiles natively under `dart2wasm` without runtime warnings or interop crashes.

---

## 4. Lifecycle & Stack Coordination

When navigating between screens:
- **Push Screen B**: Screen B's `WebHead` metadata takes precedence and replaces title, description, and Open Graph tags.
- **Pop back to Screen A**: Screen B unmounts, calls `_remove`, and the coordinator restores Screen A's metadata.
- **Multiple Widgets**: If nested widgets both declare a `WebHead`, the deepest widget in the hierarchy overrides specific tags while inheriting unset values from parents.

