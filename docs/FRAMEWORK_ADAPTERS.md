# Framework Adapters: Shelf, Dart Frog, Serverpod & Jaspr

MetaMantle's server architecture is framework-agnostic. Pre-built adapters (`lib/src/adapters/`) connect `MetaMantleServerEngine` to Dart's most popular server frameworks.

---

## 1. Shelf Integration

### As a standalone Handler:
```dart
import 'package:shelf/shelf_io.dart' as io;
import 'package:meta_mantle/meta_mantle_server.dart';

void main() async {
  final handler = metaMantleShelfHandler(engine: engine);
  await io.serve(handler, '0.0.0.0', 8080);
}
```

### As Middleware (with static file fallback):
```dart
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

final staticFallback = createStaticHandler('build/web', defaultDocument: 'index.html');

final pipeline = const Pipeline()
    .addMiddleware(metaMantleShelfMiddleware(engine: engine))
    .addHandler(staticFallback);
```
If a request matches an SSR route, MetaMantle intercepts and renders it dynamically. Otherwise, the request falls through to serve static assets (`flutter.js`, images, wasm bundles).

---

## 2. Dart Frog Adapter (`dartFrogMiddleware`)

In Dart Frog routes:
```dart
// routes/_middleware.dart
import 'package:dart_frog/dart_frog.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

Handler middleware(Handler handler) {
  return dartFrogMetaMantleMiddleware(engine: serverEngine)(handler);
}
```

---

## 3. Serverpod Adapter (`metaMantleServerpodHandler`)

In a Serverpod web server:
```dart
// server.dart
import 'package:serverpod/serverpod.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void run(List<String> args) async {
  final pod = Serverpod(args);
  pod.webServer.addRoute(
    Route(
      path: '/products/*',
      handler: (session, request) => metaMantleServerpodHandler(engine, session, request),
    ),
  );
  await pod.start();
}
```

---

## 4. Jaspr SSR Adapter (`jasprSsrHandler`)

For full-stack hybrid web applications using Jaspr:
```dart
final handler = jasprSsrHandler(engine: engine);
```
Allows using MetaMantle's typed metadata engine alongside Jaspr SSR components.

