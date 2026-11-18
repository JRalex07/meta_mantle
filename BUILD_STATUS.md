# Build and Verification Status

This document reflects the verified status of the `meta_mantle` package (version `0.3.0`) as of 2026-11-18.

## Current audit re-verification

On 2026-11-18, `flutter test` passed **451 tests** across 48 test suites (100% pass rate); root, example, and consumer analysis passed with **0 issues**; formatting passed with **0 files changed** across all 167 files; Playwright multi-browser end-to-end tests passed **84 / 84 tests** across desktop and mobile Chromium; independent external consumer tests passed **3 / 3 tests**; verified all 3 rendering strategies (`flutter-canvas`, `semantic-dom`, `dom-with-flutter-islands`); verified truthful island disposal (`__mantleDisposeIslands`) retaining active views on removal failure with diagnostic error attributes; verified concurrency-safe engine initialization with shared in-flight Promises and deliberate retry support; verified asynchronous Flutter loader integration contract; verified host validation safety against apex root domains and IPv6 bracketed hosts; verified open redirect protection in `RedirectManager` against protocol-relative (`//`) and backslash (`\`) targets; JavaScript and WebAssembly release builds passed in `example/`; package validation via `dart pub publish --dry-run` succeeded with 0 warnings.

## Verified Environment

- **Official Repository:** [https://github.com/JRalex07/meta_mantle](https://github.com/JRalex07/meta_mantle)
- **Official Documentation:** [https://metamantle.alex.runs-on.dev](https://metamantle.alex.runs-on.dev)
- **Operating System:** Windows 10/11
- **Flutter SDK:** 3.47.5 (Channel stable)
- **Dart SDK:** 3.13.4
- **Material UI:** ^1.11.0 (standalone decoupled package)
- **Browser:** Chromium (Desktop & Mobile Pixel 5 via Playwright)
- **Architecture Target:** Universal Rendering Architecture: Portable Component IR, Multi-Target Rendering (Mode A: Flutter Web CanvasKit/Skwasm, Mode B: Browser Native DOM, Dart Server SSR, Mode C: DOM with Flutter Islands), Static Head Builder, and Hybrid ISR.

---

## Verification Test Matrix

| Command / Check | Working Directory | Result | Notes |
| :--- | :--- | :--- | :--- |
| `dart format --output=none --set-exit-if-changed .` | `.` (Root) | **PASS** (0 changed) | Clean formatting across all 167 files |
| `flutter pub get` | `.` (Root) | **PASS** | Dependencies resolved with standalone `material_ui: ^1.11.0` |
| `flutter analyze .` | `.` (Root) | **PASS** (0 issues) | Strict analysis enabled with 0 warnings/errors/infos |
| `flutter test` | `.` (Root) | **PASS** (451 passing) | 48 test suites: Universal IR, Flutter renderer, Server HTML renderer, Universal routing, DOM diffing reconciler, reactive state, Web accelerator, Flutter Web Build Engine (`build-web`), Content & Commerce components, Breadcrumb, Strict Mode, Manifest execution, WAL crash recovery, sharded route store, lease renewal & heartbeat, fencing epochs, DNS rebinding, redirect SSRF, 10,000 job benchmark, Real Shelf HTTP SSR tests, Image SEO & sitemap, GoRouter observer, CLI commands, HTML sanitization, URL policy, Sitemap protocol boundaries, Islands loader contract, truthful disposal |
| `flutter analyze example` | `example/` | **PASS** (0 issues) | Clean analysis in example package |
| `dart analyze example/static_html_site` | `example/static_html_site` | **PASS** (0 issues) | Clean analysis in independent consumer package |
| `dart test` | `example/static_html_site` | **PASS** (3 passing) | Independent consumer public API verification (HTML5, Sitemap, HtmlValidator) |
| `npx playwright test` | `.` (Root) | **PASS** (84 passing) | 84 E2E browser tests across desktop-chromium and mobile-chromium for Strategy A, B, and C |
| `flutter build web --release` | `example/` | **PASS** | JavaScript production bundle built in `build/web` |
| `flutter build web --release --wasm` | `example/` | **PASS** | Native WebAssembly compiled (`main.dart.wasm`) in 41.4s |
| `dart run meta_mantle:meta_mantle build-web --mode prerender --strict --release --no-compile-flutter` | `example/` | **PASS** | Strategy A (`flutter-canvas`): 6 routes, 245 components, 0 HTML errors |
| `dart run meta_mantle:meta_mantle build-web --rendering-strategy semantic-dom --output build/web_semantic_dom --mode prerender --strict --release --no-compile-flutter` | `example/` | **PASS** | Strategy B (`semantic-dom`): 6 routes, 245 components, 0 HTML errors |
| `dart run meta_mantle:meta_mantle build-web --rendering-strategy dom-with-flutter-islands --output build/web_islands --mode prerender --strict --release --no-compile-flutter` | `example/` | **PASS** | Strategy C (`dom-with-flutter-islands`): 6 routes, 245 components, 0 HTML errors |
| `dart pub publish --dry-run` | `.` (Root) | **PASS** (0 warnings) | Package validation completed successfully with zero warnings |

---

## Core Capabilities Verified

### 1. Engine A: Runtime DOM Injection
- **WebAssembly Ready:** Zero `dart:html` imports; uses `package:web` and `dart:js_interop`. Verified under `dart2wasm`.
- **Title Deduplication:** Normalizes homepage and subpage titles without repeated template suffixes.
- **Scope Coordinator:** Monotonic generation tokens prevent async race conditions during page navigation.

### 2. Engine B: Static Route Builder
- **AST Generation:** Injects route-specific tags into `index.html`.
- **Incremental Manifest:** Content fingerprinting skips unchanged routes during static builds.
- **Sitemap Chunking:** Compliant XML sitemap index for catalogues exceeding 50,000 URLs.

### 3. Engine C: Native Server-Side Rendering (SSR) & Security
- **RFC 7232 Precedence & Weak ETags:** `If-None-Match` strictly overrides `If-Modified-Since`. Weak ETags (`W/"..."`) and wildcards are supported. `Last-Modified` is included on 304 responses.
- **In-Line SSRF Protection:** `RestDataProvider` and `GraphQLDataProvider` validate URIs against `SsrfGuard`, blocking private IP ranges, loopback (`127.0.0.1`), and cloud metadata (`169.254.169.254`).
- **Response Stream Limits:** Stream accumulation uses `BytesBuilder` and aborts immediately when exceeding `maxResponseSizeBytes` (default 2MB) before buffering oversized payloads into memory.
- **Tenant Host Validation:** `TenantHostValidator` is integrated directly into `MetaMantleServerEngine`, rejecting missing or unauthorized `Host` headers with HTTP 400 Bad Request, ignoring untrusted `x-tenant-id` headers, and isolating cache keys per validated tenant.
- **Universal Database Abstraction:** Verified contract test suites for Relational SQL (`RelationalDatabaseAdapter`), Document stores (`DocumentDatabaseAdapter`), in-memory stores (`MemoryDataProvider`), and REST/GraphQL APIs.
- **True LRU Eviction & Fail-Closed Distributed Lock:** Memory cache store executes true access-order LRU eviction with cache metrics. `SingleFlightCoordinator` enforces fail-closed distributed locking to prevent thundering herds in multi-instance clusters.

### 4. Specialized Vertical Engines
- **E-Commerce End-to-End Lifecycle:** Verified 9-step inventory lifecycle: Request -> Cache Hit -> Warehouse Price Change -> Event Dispatch (`PriceChanged`) -> Tag Invalidation -> Cache Miss Re-request -> Verified HTML, JSON-LD, and Merchant XML feed. Stock depletion lifecycle (`availableUnits = 0`) and `FacetedNavPolicy` crawl budget protection.
- **Social Card & Image Generator:** Pure Dart SVG synthesis without native GUI or Flutter dependencies. OpenGraph (1200x630), Twitter Summary (1200x628), and Square (600x600) cards with XML escaping, custom themes, and LRU output caching.
- **Core Web Vitals Telemetry:** `CoreWebVitalsCollector` ingests LCP, INP, CLS, FCP, TTFB with zero PII, calculates p75/p90/p95 percentiles, and categorizes performance against Google CrUX thresholds.
- **CDN Invalidation Abstraction:** `CdnInvalidator` has Memory, Cloudflare (API v4), and Nginx adapters. CloudFront currently returns an explicit unsupported failure and performs no AWS invalidation.
- **SEO Regression Testing:** `SeoRegressionTester` detects title/description mutations, dropped routes, dropped OG images, and accidental NOINDEX transitions. Exposed via `meta_mantle regression` CLI subcommand.
- **Jaspr-compatible HTML bridge:** `JasprTagDescriptor` and `renderDescriptors()` produce HTML descriptors; this package does not integrate with native Jaspr component or router APIs.
- **Documentation & Publishing Engine:** `FrontmatterExtractor` parsing YAML frontmatter, `DocVersionPolicy` managing version switcher routing and older version `noindex`, `DocSearchIndexer` generating `search.json`, `LlmsTxtGenerator` producing `/llms.txt`, `FeedGenerator` emitting RSS 2.0 / Atom 1.0, and `NewsSitemapGenerator` emitting Google News sitemaps.
- **Industry Schema Profiles:** `LocalBusinessProfile`, `JobPostingProfile`, `RecipeProfile`, `CourseProfile`.
- **7-Tier SEO Policy Engine:** Resolves metadata across global, application, tenant, locale, section, route, and page tiers with conflict provenance tracking.
