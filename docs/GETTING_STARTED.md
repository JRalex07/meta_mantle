# Getting Started with MetaMantle

MetaMantle is an SEO and document rendering infrastructure framework for Dart and Flutter. It bridges the gap between single-page application (SPA) client rendering and modern search engine requirements.

---

## 1. What MetaMantle Does (and What It Does Not)

### What MetaMantle Does:
- **Client-Side Reactive Metadata (Engine A):** Dynamically synchronizes document `<head>` metadata, Open Graph cards, and JSON-LD structured data in Flutter Web as users navigate between screens.
- **Static Pre-Rendering (Engine B):** Injects route-specific metadata and semantic HTML into Flutter's `build/web` output before deployment so crawlers receive complete metadata in the initial HTTP payload.
- **Native Request-Time SSR (Engine C):** Renders complete HTML documents and metadata on the server in pure Dart without browser overhead, returning instant semantic HTML to crawlers.
- **Enterprise SEO Tooling:** Generates Google-compliant XML sitemaps, robots.txt, Google Merchant feeds, Google News sitemaps, and `/llms.txt`.
- **Security & Performance:** Built-in SSRF protection, host header validation, RFC 7232 conditional requests, and true access-order LRU caching.

### What MetaMantle Does Not Do:
- MetaMantle does **not** convert arbitrary Flutter widget trees into server-rendered HTML. Flutter widgets render on a canvas via Skia/Impeller in WebAssembly or JavaScript.
- MetaMantle does **not** replace backend application servers or database ORMs; it provides standard data provider adapters to connect your existing databases to SSR routes.

---

## 2. Choosing the Right Engine

| Use Case | Recommended Engine | How It Works |
| :--- | :--- | :--- |
| **Flutter Web SPA (Internal Tool / Portal)** | **Engine A: Runtime (`MetaHead`)** | Metadata updates in the browser DOM as routes change. Zero build pipeline changes. |
| **Public Marketing / Documentation Site** | **Engine B: Static Builder** | `meta_mantle build` expands route templates into static HTML files in `build/web`. Crawlers get instant metadata. |
| **Dynamic E-Commerce / CMS / High-Scale SSR** | **Engine C: Native SSR Engine** | `MetaMantleServerEngine` renders pages on demand from database queries with caching, ETags, and zero JS. |
| **Hybrid Shell + Canvas App** | **Jaspr Adapter (`MetaMantleDocument`)** | Server-rendered HTML shell with pre-rendered crawler content that embeds and bootstraps Flutter Web. |

---

## 3. Recommended Developer Path

1. **Install the package:** Follow the [Installation Guide](INSTALLATION.md) to add `meta_mantle` as a dependency.
2. **Try the Quick Start:** Walk through the minimal examples in the [Quick Start Guide](QUICK_START.md).
3. **Explore Architecture:** Read the [Architecture Guide](ARCHITECTURE.md) to understand how the tripartite engines operate.
4. **Inspect Examples:** Review runnable sample applications in [`example/bin/`](../example/bin/).

