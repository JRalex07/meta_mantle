# Routing and Hosting Guide

This guide explains routing strategies, router integration patterns, and hosting configurations for applications using `meta_mantle`.

---

## 1. Path URLs vs. Hash URLs

For clean URLs such as `/products/rice`, configure Flutter with a path URL strategy before calling `runApp`:

```dart
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy();
  runApp(const MyApp());
}
```

> [!NOTE]
> Static route HTML generation requires a path URL strategy. If an application uses Flutter's default hash URL strategy (`/#/route`), the web server cannot read the URL fragment and cannot serve route-specific static HTML.

---

## 2. Router Integration Strategy

### A. Flutter Navigator (`MaterialApp`)
`meta_mantle` includes `MetaMantleNavigatorObserver` to synchronize route names with `MetaMantle.setCurrentUrl()`:

```dart
MaterialApp(
  navigatorObservers: [MetaMantleNavigatorObserver()],
  // ...
);
```

### B. GoRouter Integration (Supported Manual Wrapping Pattern)
`meta_mantle` deliberately avoids adding a hard dependency on `go_router` to keep the core package lightweight and prevent dependency version conflicts.

The **officially supported pattern** for GoRouter is wrapping the page widget inside `builder` or `pageBuilder` with `MetaHead`:

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MetaHead(
        metadata: WebMetadata(
          title: 'Home',
          canonical: 'https://example.com/',
        ),
        child: HomeScreen(),
      ),
    ),
    GoRoute(
      path: '/products/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MetaHead(
          metadata: WebMetadata(
            title: 'Product $id',
            canonical: 'https://example.com/products/$id',
          ),
          child: ProductScreen(id: id),
        );
      },
    ),
  ],
);
```

> [!IMPORTANT]
> `meta_mantle` does **not** provide or claim automatic GoRouter route observation. Wrapping route targets with `MetaHead` gives developers complete control over route parameters, query strings, and custom canonical URLs.

---

## 3. General Deployment Workflow

1. Build the Flutter web application:
   ```bash
   flutter build web --release
   ```
2. Generate static route documents:
   ```bash
   dart run meta_mantle build --config meta_mantle.config.json --strict
   ```
3. Deploy the resulting `build/web` directory.
4. Verify using raw HTTP requests that deep routes (e.g. `/about/`) return HTTP 200 with the correct static `<head>` metadata.

---

## 4. Hosting Configurations

### GitHub Pages (Project Site: `/meta_mantle/`)
When deploying a project repository site to GitHub Pages (`https://<username>.github.io/<repo>/`), Flutter must be built with `--base-href`:

```bash
flutter build web --release --base-href /meta_mantle/
dart run meta_mantle build --config meta_mantle.config.json --strict
```

Key considerations for GitHub Pages:
- **Base href:** `--base-href /meta_mantle/` ensures scripts (`flutter_bootstrap.js`, `main.dart.js`, `main.dart.wasm`) and assets load from the correct subdirectory.
- **Canonical URLs:** Configure `baseUrl: "https://<username>.github.io/meta_mantle"` in `meta_mantle.config.json`.
- **HTTPS:** GitHub Pages enforces HTTPS automatically.
- **Relative assets:** Favicons and social images should use absolute URLs or resolve against the configured `baseUrl`.

### Firebase Hosting (`firebase.json`)
```json
{
  "hosting": {
    "public": "build/web",
    "cleanUrls": true,
    "trailingSlash": true,
    "rewrites": [
      { "source": "**", "destination": "/index.html" }
    ]
  }
}
```

### Netlify (`_redirects`)
Ensure existing static files take precedence before SPA fallback:
```text
/*    /index.html   200
```

### Vercel (`vercel.json`)
```json
{
  "cleanUrls": true,
  "trailingSlash": true,
  "routes": [
    { "handle": "filesystem" },
    { "src": "/(.*)", "dest": "/index.html" }
  ]
}
```

---

## 5. WebAssembly Hosting Requirements

When deploying a Flutter WebAssembly build, the hosting provider must send specific cross-origin isolation headers if threaded Wasm is enabled:
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: credentialless` (or `require-corp`)

Confirm that your hosting environment supports custom response headers before enabling threaded Wasm in production.
