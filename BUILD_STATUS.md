# Build and Verification Status

This document reflects the verified status of the `meta_mantle` package (version `0.1.0`) as of 2026-11-11.

## Current audit re-verification

On 2026-11-11, `flutter test` passed **137 tests**; root and example analysis passed with **0 issues**; formatting passed with **0 files changed**; JavaScript and WebAssembly example builds passed; CLI `doctor` and strict `build` passed. `dart pub publish --dry-run` completed package validation with **1 warning** because the working tree is modified. Gitleaks v8.30.1 history and checkout scans are configured in CI but were not run locally because Docker/Gitleaks are unavailable. CloudFront invalidation is unsupported; Jaspr support is an HTML compatibility bridge; package dependency resolution requires Flutter.

## Verified Environment

- **Official Repository:** [https://github.com/JRalex07/meta_mantle](https://github.com/JRalex07/meta_mantle)
- **Official Documentation:** [https://metamantle.alex.runs-on.dev](https://metamantle.alex.runs-on.dev)
- **Operating System:** Windows 10/11
- **Flutter SDK:** 3.47.5 (Channel stable)
- **Dart SDK:** 3.13.4
- **Browser:** Google Chrome 156.0.7118.0
- **Architecture Target:** Tripartite Architecture: Web (Runtime Wasm/JS), Static Pre-rendering, and Native Dart SSR with Universal Vertical Engines.

---

## Verification Test Matrix

| Command / Check | Working Directory | Result | Notes |
| :--- | :--- | :--- | :--- |
| `dart format --output=none --set-exit-if-changed .` | `.` (Root) | **PASS** (0 changed) | Clean formatting across all 91 files |
| `flutter pub get` | `.` (Root) | **PASS** | Dependencies resolved |
| `flutter analyze` | `.` (Root) | **PASS** (0 issues) | Strict analysis enabled across core, server, and example |
| `flutter test` | `.` (Root) | **PASS** (137 passing) | Re-run during the 2026-11-11 audit; includes redirect, SQL identifier, IPv4-mapped IPv6, Cloudflare status, and unsupported CloudFront regressions |
| `flutter pub get` | `example/` | **PASS** | Dependencies resolved |
| `flutter analyze` | `example/` | **PASS** (0 issues) | 7 runnable vertical examples clean |
| `dart run example/bin/blog_publishing_example.dart` | `.` (Root) | **PASS** | RSS 2.0, Atom 1.0, Google News Sitemap |
| `dart run example/bin/jaspr_docs_example.dart` | `.` (Root) | **PASS** | Version switcher, search index, llms.txt |
| `dart run example/bin/jaspr_flutter_embed_example.dart` | `.` (Root) | **PASS** | Hybrid HTML shell + Flutter bootstrap embedding |
| `dart run example/bin/saas_multitenant_example.dart` | `.` (Root) | **PASS** | Host injection protection, tenant cache partitioner |
| `dart run example/bin/static_marketing_example.dart` | `.` (Root) | **PASS** | Static head builder generating HTML, sitemap, robots |
| `flutter build web --release` | `example/` | **PASS** | JavaScript bundle built in `build/web` |
| `flutter build web --wasm` | `example/` | **PASS** | Native WebAssembly compiled (`main.dart.wasm`) |
| `dart run meta_mantle doctor` | `example/` | **PASS** | Preflight checks passed |
| `dart run meta_mantle inspect` | `example/` | **PASS** | 4 static routes resolved |
| `dart run meta_mantle build` | `example/` | **PASS** | Generated static files for routes |
| `dart run meta_mantle regression --help` | `.` (Root) | **PASS** | SEO snapshot regression tester |
| `dart pub publish --dry-run` | `.` (Root) | **WARN** (1 warning) | Package validation completed; warned that 14 checked-in files are modified, so release should use a clean checkout |

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
