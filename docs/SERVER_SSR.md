# MetaMantle Server-Side Rendering (SSR) & Shelf Integration

MetaMantle includes a production-grade Shelf middleware adapter that enables dynamic Server-Side Rendering (SSR) of Dart applications.

---

## 1. Shelf Adapter (`meta_mantle_server.dart`)

```dart
import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  final serverEngine = ServerEngine(
    routes: [
      ServerRoute(
        path: '/',
        render: (request) async => RenderResult(
          html: '<!DOCTYPE html><html><head><title>SSR Home</title></head><body><h1>Welcome</h1></body></html>',
          headers: {'cache-control': 'public, max-age=3600'},
        ),
      ),
    ],
  );

  final pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(serverEngine.middleware)
      .addHandler(serverEngine.fallbackHandler);

  final server = await io.serve(pipeline, '0.0.0.0', 8080);
  print('Server listening on port ${server.port}');
}
```

---

## 2. Dynamic Crawler Detection

MetaMantle's `CrawlerDetector` intercepts incoming HTTP requests, identifies search engine and social media crawlers (`Googlebot`, `bingbot`, `Twitterbot`, `facebookexternalhit`, `LinkedInBot`), and serves pre-rendered semantic HTML with complete Open Graph cards while directing standard interactive browser users to the Flutter Web SPA bundle.

---

## 3. Network Security & SSRF Protection

MetaMantle's server engine includes `SsrfGuard` and `CrawlerInspector`:
- Blocks DNS rebinding attacks with strict IP validation.
- Restricts internal network requests (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.1`, `::1`).
- Blocks cloud metadata endpoints (`169.254.169.254`).
