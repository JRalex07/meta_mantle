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


### Build Artifacts Produced

```text
build/web/
├── index.html                   (Root route HTML with Home metadata)
├── about/
│   └── index.html               (About route HTML)
├── products/
│   ├── basmati-rice/
│   │   └── index.html           (Product route HTML)
│   └── whole-milk/
│       └── index.html           (Product route HTML)
├── sitemap.xml                  (Generated XML sitemap)
├── robots.txt                   (Generated robots.txt)
├── flutter_bootstrap.js         (Preserved Flutter bootstrap script)
└── ...other Flutter build assets
```

---

## 5. Web Server Configuration

To serve static routes with client-side SPA fallback:

- Configure your web server (Firebase, Netlify, Vercel, Nginx, Apache) to serve `<route>/index.html` if it exists.
- If a path has no static HTML file, fall back to `/index.html` to allow Flutter's client-side router to handle the route.
- See [Routing and Hosting Guide](ROUTING_AND_HOSTING.md) for provider-specific configuration files.
