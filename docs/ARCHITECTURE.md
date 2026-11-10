# Architecture

## Overview & System Design

`meta_mantle` is a metadata management and static SEO framework designed for Flutter Web. It operates on a unified model architecture powering two complementary engines:

1. **Engine A (Runtime DOM Injection):** High-performance, reactive DOM reconciliation that dynamically modifies the browser's `document.head` during client-side Flutter navigation.
2. **Engine B (Static SEO Route Generator):** Build-time HTML AST processor that pre-populates initial static HTML files with route-specific metadata, Open Graph cards, structured JSON-LD data, and generates `sitemap.xml` and `robots.txt`.

Both engines share identical data models (`WebMetadata`), default inheritance logic, and rendering pipelines (`MetadataRenderer`), ensuring consistent output across both runtime execution and crawler indexing.

```
       ┌───────────────────────────────┐
       │ WebMetadata + MetaMantleConfig│
       └──────────────┬────────────────┘
                      │
                      ▼
       ┌───────────────────────────────┐
       │       MetadataRenderer        │
       └──────────────┬────────────────┘
                      │
         ┌────────────┴─────────────┐
         ▼                          ▼
┌──────────────────┐      ┌────────────────────┐
│ Runtime Engine A │      │   Static Engine B  │
│ (DOM Adapter Web)│      │(HTML AST Injector) │
└──────────────────┘      └────────────────────┘
```

---

## Core Components

### 1. Unified Models (`lib/src/models/metadata.dart`)
- **`WebMetadata`:** Immutable specification of page metadata (title, description, canonical, robots directives, OpenGraph, TwitterCard, JSON-LD, icons, resource hints, verification tags, custom tags).
- **`MetaMantleConfig`:** Global defaults (base URL, site name, title template, default sharing image, default robots). (Alias: `WebHeadConfig`).
- **`RobotsDirective`:** Typed flags (`index`, `noindex`, `follow`, `nofollow`, `noarchive`, `nosnippet`, `none`, etc.).
- **`JsonLd`:** Structured data schema factory providing 13 verified schema.org types with XSS-safe serialization.

### 2. Shared Tag Renderer (`lib/src/core/metadata_renderer.dart`)
Transforms a `WebMetadata` object and optional `MetaMantleConfig` into a deterministic list of `HeadTag` objects:
- Resolves title formatting via `titleTemplate` (`%s | Acme Store`).
- Merges default values without duplicating tags.
- Normalizes canonical URLs (enforcing absolute URLs and handling trailing slash rules).
- Performs single-identity validation for `<meta>` elements (with exceptions for repeated multi-value tags like `og:locale:alternate`).

### 3. Runtime Lifecycle Coordinator (`lib/src/runtime/`)
- **`RuntimeCoordinator`:** Centralized state and lifecycle engine:
  - Manages a stack of metadata scopes.
  - Generates a monotonic `generationToken` for every scope change.
  - Prevents race conditions from asynchronous metadata updates on unmounted or superseded routes.
  - Automatically restores the parent/previous scope when a route pops or disposes.
- **`MetaHead` Widget:** Pure declarative widget wrapper. Safely dispatches `activate`, `update`, and `remove` events in `initState()`, `didUpdateWidget()`, and `dispose()`. Does **zero** DOM mutations in `build()`. (Alias: `WebHead`).
- **`MetaMantle` Facade:** Imperative API (`setTitle`, `setDescription`, `setCanonical`, `update`, `reset`) for non-widget contexts. (Alias: `FlutterWebHead`).
- **`HeadAdapterWeb`:** Manipulates browser DOM using `package:web`. Tags elements with `data-mm-owner="meta_mantle"` and `data-mm-key`.
- **`HeadAdapterStub`:** Safe no-op adapter compiled on non-web platforms (Android, iOS, macOS, Windows, Linux) ensuring cross-platform stability.

### 4. Static Route Builder & CLI (`lib/src/builder/`, `bin/`)
- **HTML AST Engine:** Uses `package:html` to parse Flutter's `build/web/index.html` template.
- **Bootstrap Preservation:** Detects and preserves Flutter initialization scripts (`flutter_bootstrap.js` or `{{flutter_js}}` tokens).
- **Dynamic Route Expansion:** Generates static pages from parameterized routes (`/products/:slug`) and external JSON datasets.
- **Asset Generation:** Generates valid XML `sitemap.xml` (filtering out `noindex` and `none` routes) and `robots.txt`.
- **CLI Commands:**
  - `build`: Runs preflight validation and compiles static route documents.
  - `validate`: Verifies configuration syntax and data file paths.
  - `inspect`: Displays all expanded static routes and metadata.
  - `doctor`: Performs environment and template diagnostics.

---

## Security Model

1. **Context-Aware Escaping:** All HTML attribute values and tag bodies are escaped to prevent injection.
2. **Safe JSON-LD:** Structured data is serialized using Unicode escaping for `<`, `>`, `&`, and `"` to neutralize script breakout attacks.
3. **Traversal Prevention:** Route paths and data files are checked against path traversal (`..`) prior to reading or writing.
4. **Scheme Restrictions:** Rejects dangerous URL schemes (`javascript:`, `data:`) on canonical links and alternate tags.
