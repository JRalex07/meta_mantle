# Engine C: Native Server-Side Rendering (SSR) & Dynamic SEO

MetaMantle's Server-Side Rendering (SSR) engine (`lib/meta_mantle_server.dart`) enables real-time, dynamic document rendering on the server.

---

## 1. Why Native SSR in Dart?

While Static Generation (Engine B) works well for marketing sites and predictable route trees, dynamic platforms (e.g. large catalogues, e-commerce, user-generated content, newsrooms) require:
- Rendering millions of dynamic items without pre-building every URL ahead of time.
- Fresh metadata, pricing, inventory, and JSON-LD structured data updated instantly from databases.
- Full semantic HTML bodies served immediately to search crawlers (Googlebot, Bingbot, Yandex) and social sharing user-agents (Twitterbot, WhatsApp, FacebookExternalHit).
- Complete RFC-compliant HTTP caching with `ETag`, `Last-Modified`, and `304 Not Modified`.
- Sub-5ms response times via tag-invalidated memory or distributed caching.

---

## 2. Server Pipeline Architecture

```
HTTP Request (GET /products/basmati-rice)
     │
     ▼
[ Redirect Manager ] ──► (Chain collapsed redirect / Loop detection)
     │
     ▼
[ Cache Store Lookup ]
  ├── Hit (Fresh) ───────► Return cached HTML (ETag / Last-Modified / 304 check)
  ├── Hit (Stale + SWR) ─► Return stale HTML immediately + Trigger background single-flight refresh
  └── Miss / Stale ──────► [ Single-Flight Coordinator ] (Prevents cache stampedes)
                               │
                               ▼
                       [ Route Matching ]
                               │
                               ▼
                     [ Data Provider Load ] ──► Relational DB / REST / GraphQL / Document DB
                               │
                               ├── Found: Build WebMetadata + HtmlNodes
                               ├── Deleted: Return 410 Gone
                               └── Not Found: Return 404 Not Found
                               │
                               ▼
                      [ HtmlDocument Render ]
                               │
                               ▼
                       [ Cache Store Put ] ──► Tagged with route, entity, and custom keys
                               │
                               ▼
                      HTTP 200 OK Response
```

---

## 3. Defining SSR Routes

```dart
final engine = MetaMantleServerEngine(
  routes: [
    MetaRoute<Product>(
      pattern: '/products/:slug',
      dataProvider: productDbProvider,
      metadataBuilder: (product, context) => WebMetadata(
        title: product.name,
        description: product.summary,
        canonical: 'https://example.com/products/${product.slug}/',
        openGraph: OpenGraph(
          title: product.name,
          image: product.imageUrl,
          type: OpenGraphType.product,
        ),
        jsonLd: [
          JsonLd.product(
            name: product.name,
            sku: product.sku,
            offers: JsonLd.offer(
              price: product.price.toStringAsFixed(2),
              priceCurrency: 'USD',
              availability: product.inStock ? 'InStock' : 'OutOfStock',
            ),
          ),
        ],
      ),
      htmlBuilder: (product, context) => [
        H.header([
          H.nav([
            H.a(href: '/', text: 'Home'),
            H.a(href: '/products', text: 'Products'),
          ]),
          H.h1(product.name),
        ]),
        H.article([
          H.img(src: product.imageUrl, alt: product.name),
          H.p(product.summary),
          H.p('Price: \$${product.price.toStringAsFixed(2)}'),
        ]),
      ],
      cachePolicy: const CachePolicy(
        ttl: Duration(minutes: 15),
        staleWhileRevalidate: Duration(hours: 1),
        tags: ['products'],
      ),
      includeFlutterBootstrap: true,
    ),
  ],
);
```

---

## 4. Serving Requests

MetaMantle SSR integrates with any Dart server framework or standalone Shelf server:

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:meta_mantle/meta_mantle_server.dart';

void main() async {
  final handler = metaMantleShelfHandler(engine: engine);
  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('SSR Server listening on port ${server.port}');
}
```

