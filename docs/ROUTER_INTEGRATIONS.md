# MetaMantle Router Integrations & Lifecycle

Synchronizing browser `<head>` metadata, Open Graph preview tags, and the static pre-render transition lifecycle during client-side navigation requires integration with your Flutter router.

---

## 1. Official GoRouter Observer (`MetaMantleGoRouterObserver`)

MetaMantle provides an out-of-the-box `NavigatorObserver` designed for `go_router`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_mantle/meta_mantle.dart';

final router = GoRouter(
  observers: [
    MetaMantleGoRouterObserver(
      markReadyOnFirstFrame: true,
      onRouteChanged: (path) => debugPrint('Route changed: $path'),
      metadataProvider: (route, path) {
        if (path == '/products') {
          return const WebMetadata(
            title: 'Browse Products | Store',
            description: 'Explore our catalog of premium electronics.',
          );
        }
        return null;
      },
    ),
  ],
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsScreen(),
    ),
  ],
);
```

### Observer Features:
1. **Dynamic URL Synchronization**: Updates `window.location` and canonical tags during `didPush`, `didPop`, and `didReplace`.
2. **First-Frame Transition Coordination**: Automatically calls `MetaMantle.markReady()` after the first Flutter frame is painted, fading out the static HTML pre-render snapshot.
3. **Dynamic Metadata Resolution**: Computes metadata dynamically from route parameters and passes it to `MetaMantle.update(metadata)`.

---

## 2. Standard Navigator & AutoRoute Integration

For applications using standard `Navigator` or third-party routers:

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [
        MetaMantleNavigatorObserver(),
      ],
      routes: {
        '/': (_) => const HomeScreen(),
      },
    );
  }
}
```

Or manually wrap individual route widgets with `MetaHead`:

```dart
@override
Widget build(BuildContext context) {
  return MetaHead(
    metadata: WebMetadata(
      title: 'Dynamic Product Title',
      description: 'Dynamic Description',
    ),
    child: Scaffold(
      body: ...,
    ),
  );
}
```
