# Static Route HTML Generation

## Overview

Flutter Web applications run client-side by default. While search engine crawlers like Googlebot can execute JavaScript, many social sharing crawlers (Twitter/X, Facebook, WhatsApp, LinkedIn, Discord, Slack) and lightweight scrapers do not run client-side code.

Static generation solves this by pre-compiling route-specific HTML documents into your Flutter Web build before deployment.

---

## 1. Build the Flutter Web Application

Compile your application with Flutter Web release tooling:

```bash
flutter build web --release
```

The output in `build/web` includes `index.html`, `flutter_bootstrap.js`, compiled JavaScript/Wasm bundles, and static assets.

---

## 2. Configuration (`meta_mantle.config.json`)

Define your static routing configuration:

```json
{
  "baseUrl": "https://example.com",
  "siteName": "Acme Store",
  "titleTemplate": "%s | Acme Store",
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
        "title": "Home",
        "description": "Premium groceries delivered to your door."
      }
    },
    {
      "path": "/about",
      "metadata": {
        "title": "About Us",
        "description": "Learn about our farm-to-table mission."
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
        "canonical": "https://example.com/products/{{slug}}/",
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

---

## 3. Dynamic Route Data Expansion

For catalog or blog items, dynamic routes expand a local JSON file (`products.json`):

```json
[
  {
    "slug": "basmati-rice",
    "name": "Premium Basmati Rice",
    "description": "Authentic long-grain aromatic rice.",
    "image": "https://example.com/assets/rice.png"
  },
  {
    "slug": "whole-milk",
    "name": "Farm Fresh Whole Milk",
    "description": "Pasteurized whole milk from local dairies.",
    "image": "https://example.com/assets/milk.png"
  }
]
```

Placeholders like `{{name}}` or nested `{{brand.name}}` are replaced automatically for each entry.

---

## 4. CLI Execution & Verification

### Diagnostics (`doctor`)

Check your configuration, input template, and environment:

```bash
dart run meta_mantle doctor --config meta_mantle.config.json
```

### Route Inspection (`inspect`)

Preview all generated routes and metadata without writing files:

```bash
dart run meta_mantle inspect --config meta_mantle.config.json
```

### Build Static Pages (`build`)

Generate static route files:

```bash
dart run meta_mantle build \
  --config meta_mantle.config.json \
  --input build/web \
  --output build/web \
  --strict
```

#### Strict Mode Preflight Validation (`--strict`)

When `--strict` is enabled, the builder performs preflight validation across all resolved routes before writing any files:
- **Title Validation:** Every route must resolve a non-empty `title`.
- **Description Validation:** Every route must resolve a non-empty `description` (either specified per-route or inherited from `"defaults"`).
- **URL & Scheme Sanitization:** Absolute URLs must use valid `http` or `https` schemes; canonical URLs cannot contain query parameters or hash fragments.
- **Atomic Execution:** If any route fails strict validation, the build halts with an exit code of 1, leaving the output directory intact.

---

## 5. Unified Flutter Web Build Engine (`build-web`)

MetaMantle provides an all-in-one Flutter Web Build Engine that compiles Flutter Web, parses route configurations and data sources, generates semantic HTML snapshots from your universal `MantleComponent` trees, coordinates Flutter client hydration/bootstrap, and outputs SEO assets in a single command.

```bash
dart run meta_mantle build-web \
  --mode hybrid \
  --release \
  --output build/web \
  --verbose
```

### Build Modes

| Mode | Flag | Description |
| :--- | :--- | :--- |
| **Mode A: Metadata** | `--mode metadata` | Injects route-specific SEO tags, Open Graph, Twitter Cards, and JSON-LD schemas into route-specific `index.html` copies while retaining standard client-side Flutter rendering. |
| **Mode B: Prerender** | `--mode prerender` | Generates semantic HTML snapshots (`<article>`, `<form>`, `<details>`, `<table>`, lists, headings, links, products) into `#mantle-prerender-root` alongside Flutter bootstrap. |
| **Mode C: Hybrid** | `--mode hybrid` *(default)* | Generates static semantic snapshots and coordinates client startup via `window.__mantleClientReady` and `MetaMantle.markReady()`. Once the first Flutter frame is painted, the static snapshot fades out smoothly with zero content flashing or duplication. |

### CLI Options

| Flag | Default | Description |
| :--- | :--- | :--- |
| `--mode` | `hybrid` | Operating mode: `metadata`, `prerender`, or `hybrid` |
| `--release / --no-release` | `true` | Compile Flutter Web with release optimizations (`--release`) |
| `--debug` | `false` | Compile in debug mode |
| `--output` | `build/web` | Target output directory for build artifacts |
| `--base-href` | `/` | Base href for Flutter Web application |
| `--wasm` | `false` | Enable Flutter WebAssembly compilation (`--wasm`) |
| `--dry-run` | `false` | Resolve routes and simulate generation without running Flutter build or writing files |
| `--clean` | `false` | Run `flutter clean` prior to compilation |
| `--strict` | `false` | Fail the build if any route is missing critical metadata |
| `--verbose` | `false` | Print detailed step-by-step progress logging |

### Client Startup Coordination (`MetaMantle.markReady()`)

In Mode C (`hybrid`), the generated HTML includes `#mantle-prerender-root` and an inline coordination script. When running the Flutter client application, MetaMantle automatically invokes:

```dart
// Handled automatically by runMantleApp(), or manually in your custom App:
WidgetsBinding.instance.addPostFrameCallback((_) {
  MetaMantle.markReady();
});
```

When called, `window.__mantleClientReady()` adds `.mantle-fade-out` to the pre-rendered content and removes it from the DOM after 250ms, ensuring a seamless visual handover.

### Build Artifacts Produced

```text
build/web/
├── index.html                   (Root route HTML with Home metadata & semantic snapshot)
├── about/
│   └── index.html               (About route HTML)
├── products/
│   ├── basmati-rice/
│   │   └── index.html           (Product route HTML with Schema.org Microdata)
│   └── whole-milk/
│       └── index.html           (Product route HTML)
├── sitemap.xml                  (Generated XML sitemap)
├── robots.txt                   (Generated robots.txt)
├── flutter_bootstrap.js         (Preserved Flutter bootstrap script)
├── meta_mantle_report.json      (Machine-readable build metrics & route summary)
└── ...other Flutter build assets
```

---

## 6. Web Server Configuration

To serve static routes with client-side SPA fallback:

- Configure your web server (Firebase, Netlify, Vercel, Nginx, Apache) to serve `<route>/index.html` if it exists.
- If a path has no static HTML file, fall back to `/index.html` to allow Flutter's client-side router to handle the route.
- See [Routing and Hosting Guide](ROUTING_AND_HOSTING.md) for provider-specific configuration files.
