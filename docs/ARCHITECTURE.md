# MetaMantle Architecture & System Design

MetaMantle is an enterprise-grade metadata management, static pre-rendering, and dynamic server-side rendering (SSR) framework for Flutter Web and the Dart ecosystem.

---

## 1. Tripartite System Architecture

MetaMantle operates on a unified model architecture powering three complementary engines:

1. **Engine A (Runtime DOM Injection):** High-performance, reactive DOM reconciliation that dynamically modifies the browser's `document.head` during client-side Flutter navigation (`lib/meta_mantle.dart`).
2. **Engine B (Static SEO Route Generator):** Build-time HTML AST processor that pre-populates initial static HTML files with route-specific metadata, Open Graph cards, structured JSON-LD data, sitemaps, and robots.txt (`lib/meta_mantle_builder.dart`).
3. **Engine C (Native Server-Side Rendering):** Real-time, dynamic request rendering pipeline executing in pure Dart on the server, featuring database abstraction, semantic HTML body generation, RFC 5861 HTTP caching, and single-flight stampede protection (`lib/meta_mantle_server.dart`).

```
                    ┌───────────────────────────────┐
                    │  WebMetadata + MetadataRenderer│
                    └──────────────┬────────────────┘
                                   │
       ┌───────────────────────────┼───────────────────────────┐
       ▼                           ▼                           ▼
┌──────────────┐           ┌──────────────┐           ┌──────────────┐
│   Engine A   │           │   Engine B   │           │   Engine C   │
│ Client-Side  │           │  Build-Time  │           │ Native Dart  │
│  DOM Interop │           │ Static Pre-  │           │ Server-Side  │
│ (Wasm Ready) │           │  Rendering   │           │  Rendering   │
└──────────────┘           └──────────────┘           └──────────────┘
```

---

## 2. Subsystem Architecture

### 1. Pure Dart Core (`lib/meta_mantle_core.dart`)
- **Zero Dependencies**: Zero dependencies on `flutter` and zero dependencies on `dart:io`.
- **`WebMetadata`**: Strongly typed model for page title, description, canonical, robots, Open Graph, Twitter cards, and JSON-LD structured data.
- **`MetadataRenderer`**: Deterministic serialization of metadata objects into standards-compliant HTML tags.
- **`H` & `HtmlDocument`**: Semantic HTML DSL producing accessible HTML5 documents without browser dependencies.
- **`HtmlSanitizer`**: Strict allowlist-based sanitizer stripping malicious tags and dangerous URL schemes.

### 2. Runtime Engine A (`lib/src/runtime/`)
- **`WebHead` Widget**: Declarative widget mounting metadata into the active widget tree.
- **`RuntimeCoordinator`**: Stack-based scope manager generating monotonic tokens to prevent race conditions during page transitions.
- **`DomAdapter`**: Browser DOM adapter using modern `package:web` and `dart:js_interop` (100% WebAssembly compatible).

### 3. Static Builder Engine B & Flutter Web Build Engine (`lib/src/builder/`, `lib/src/static/`)
- **`StaticHeadBuilder`**: Injects route-specific tags into Flutter's `build/web/index.html` template.
- **`FlutterWebBuildEngine`**: Full-pipeline Flutter Web build orchestrator (`dart run meta_mantle build-web`) managing Flutter compilation, route expansion, semantic HTML pre-rendering, and asset generation.
- **`BootstrapAdapter`**: Injects metadata, CSS styles, semantic content containers, and client startup handshake (`window.__mantleClientReady`) into the Flutter bootstrap lifecycle without modifying framework internals.
- **Build Modes**:
  - **Mode A (Metadata):** Enriches HTML `<head>` while preserving standard client-side Flutter Web rendering.
  - **Mode B (Prerender):** Injects semantic HTML snapshots (`<article>`, `<form>`, `<details>`, `<table>`, lists, headings, products) alongside Flutter bootstrap.
  - **Mode C (Hybrid):** Combines static snapshots with client-side synchronization (`MetaMantle.markReady()`) for seamless, flicker-free hydration.
- **`BuildManifest`**: SHA-256 content fingerprinting enabling sub-second incremental builds.
- **Sitemaps & Robots**: Automated XML sitemap generation with chunking and reciprocal hreflang validation.

### 4. Dynamic SSR Engine C (`lib/src/server/`)
- **`MetaMantleServerEngine`**: Framework-agnostic request handler executing route matching, database querying, caching, and document rendering.
- **`MetaMantleDataProvider<T>`**: Universal data abstraction with pre-built adapters for Relational SQL databases, Document/NoSQL databases, in-memory stores, and REST/GraphQL APIs.
- **`MetaMantleCacheStore`**: LRU memory caching with tag invalidation, RFC 5861 Stale-While-Revalidate, and Stale-If-Error.
- **`SingleFlightCoordinator`**: Concurrency coordinator eliminating cache stampedes / thundering herds.
- **`RedirectManager`**: Redirect pipeline with automated chain collapsing (A -> B -> C becomes A -> C), loop detection, and open-redirect validation.

---

## 3. Security Design

1. **Context-Aware Escaping**: All HTML attribute values and tag bodies are escaped to prevent DOM injection.
2. **Safe JSON-LD**: Structured data is serialized using Unicode escaping for `<`, `>`, `&`, and `"` to neutralize script breakout attacks.
3. **SSRF Guard (`SsrfGuard`)**: Comprehensive protection against Server-Side Request Forgery by blocking requests to loopback addresses, private networks, link-local addresses, and cloud instance metadata services (`169.254.169.254`).
4. **HTML Sanitization**: Removes all `<script>`, `<iframe>`, and `on*` event handlers from rich text payloads.
5. **Open Redirect Defense**: Rejects external redirects unless explicitly permitted by security policies.
