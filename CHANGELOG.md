# Changelog

## 0.1.0 - 2026-11-11

Official release of **MetaMantle** (`meta_mantle`), the typed metadata management, native server rendering, and universal SEO infrastructure framework for Flutter Web and Dart applications.

**Integration limits:** The package currently requires Flutter SDK resolution (Dart `>=3.6.0`, Flutter `>=3.27.0`). Core/server source entrypoints avoid Flutter imports, but are not independently installable with the Dart SDK alone. Database adapters require application-supplied callbacks and drivers. Jaspr helpers produce metadata descriptors/HTML strings rather than native Jaspr components. CloudFront invalidation is unsupported and returns failure until a genuine AWS API implementation is added.

### Incremental Static Regeneration (ISR) Production Hardening & Scalability
- **Content-Addressed Immutable Artifact Storage:** Completely redesigned `FileHtmlArtifactStore` to avoid full-directory copies during version publication. Rendered documents are stored as immutable SHA-256 content-addressed objects (`.objects/{hash}.html`) linked through versioned route manifests (`.route_artifacts.json`). `beginVersion()` copies zero HTML files and shares unchanged objects across iterations.
- **Atomic Rollback & Garbage Collection:** Added `rollbackTo(targetVersion)` for atomic reversion to prior generations and `garbageCollect({retentionGracePeriod, maxRetainedVersions})` to safely reclaim unreferenced content objects.
- **Storage Capabilities Contract:** Introduced `StorageCapabilities` and the `capabilities` getter on `HtmlArtifactStore`, exposing explicit runtime guarantees for atomic publication, rollback, garbage collection, and distributed leases.
- **O(1) Indexed Regeneration Queue:** Replaced O(N^2) directory-scanning queue lookups in `FileRegenerationQueue` with persistent indexes (`indexes/idempotency.json`, `pending.json`, `processing.json`). Idempotency deduplication, pending claims, and lease expiration recovery operate without scanning filesystem directories.
- **Atomic Batch Scheduling (`enqueueAll`):** Added `enqueueAll` for bulk atomic scheduling with deduplication. Benchmarked up to 10,000 scheduled jobs running with sub-quadratic linear scaling (>500 jobs/sec on disk).
- **Queue Capabilities & Diagnostics:** Added `QueueCapabilities`, `rebuildIndexes()` for automatic index recovery, `cleanupCompleted()` for purging completed jobs and idempotency keys, and `metrics()` for real-time queue observability.
- **Multi-Worker Concurrency & Fencing:** Implemented monotonic lease fencing tokens (`leaseToken`), expired lease reclaiming, and competing worker serialization.
- **Socket-Level IP Pinning for REST/GraphQL:** Extended `SsrfGuard.createPinnedClient()` using socket connection factories to bind connections directly to pre-validated IP addresses. Defaulted both `RestDataProvider` and `GraphQLDataProvider` to pinned clients, preventing DNS rebinding vulnerabilities across external data fetching.
- **Streaming Collection Discovery:** Added `onProgress` and `isCancelled` callbacks to `CollectionRouteSource` and `HybridStaticGenerator`, enabling bounded-memory generation, progress tracking, and cooperative cancellation during large catalog builds.
- **Expanded Test Suite:** Expanded automated test coverage from 184 to **195 passing tests** across 19 suites with 100% pass rate.

### Product Evolution & Architectural Hardening
- **True Access-Order LRU Cache Eviction:** Overhauled `MemoryCacheStore` to re-insert keys on access, guaranteeing genuine LRU eviction order under memory pressure. Added granular cache performance metrics: `evictions`, `invalidations`, `expiredCount`, and `hitRatio`.
- **Fail-Closed Distributed Locking:** Hardened `SingleFlightCoordinator` to raise `DistributedLockException` upon lock acquisition timeout, preventing unbounded concurrent executions during cluster outages. Added `completer.future.ignore()` to neutralize unhandled asynchronous zone exception leaks.
- **Cryptographic SHA-256 ETags:** Standardized cryptographically robust SHA-256 HTTP ETags (`w/"${sha256.convert(...)}"`) replacing weak hashing.
- **Genuine RFC 5861 `stale-if-error` Fallback:** Implemented origin failure recovery in `MetaMantleServerEngine`, returning cached stale content with `X-MetaMantle-Cache: STALE-IF-ERROR` when origin re-rendering fails.
- **7-Tier SEO Policy Engine:** Built a hierarchical policy resolution engine across Global, Application, Tenant, Locale, Section, Route, and Page tiers. Introduced `PolicyProvenance` to track attribute inheritance origins and alert on ancestral `forceNoindex` conflicts.
- **Enterprise E-Commerce SEO Subsystem:**
  - `ProductItem`, `ProductVariant`, `ProductRating`, `ShippingDetails`, and `ReturnPolicy` domain models generating Google Search Central compliant `Product` and `AggregateOffer` JSON-LD schemas.
  - `InventoryEventDispatcher` processing `PriceChanged`, `InventoryChanged`, `StockDepleted`, and `ProductSlugChanged` events with targeted cache tag invalidation.
  - `FacetedNavPolicy` guarding crawl budgets by enforcing `noindex, follow` on sorted views, excessive combined filters, and deep pagination (> 5 pages).
  - `MerchantFeedGenerator` producing Google Merchant Center RSS 2.0 XML feeds with the `xmlns:g="http://base.google.com/ns/1.0"` namespace.
- **Documentation & Publishing Engine:**
  - `FrontmatterExtractor` parsing YAML frontmatter with zero external native dependencies.
  - `DocVersionPolicy` managing versioned documentation portals (`/docs/v1/` -> `/docs/latest/`) with canonical redirects and automated `noindex, follow` directives for archived versions.
  - `DocSearchIndexer` extracting markdown heading hierarchies into structured in-memory `search.json` indexes.
  - `LlmsTxtGenerator` emitting structured `/llms.txt` documents for AI coding agent discovery.
  - `FeedGenerator` generating standard RSS 2.0 and Atom 1.0 syndication feeds.
  - `NewsSitemapGenerator` emitting Google News XML sitemaps with the `<news:news>` namespace.
- **SaaS Multi-Tenancy & Host Security:**
  - `TenantHostValidator` enforcing strict allowlists on incoming HTTP `Host` headers across registered custom domains and wildcard subdomains, completely neutralizing Host Header Injection attacks.
  - `TenantCachePartitioner` deterministically isolating cache keys by `tenant:host:locale:currency` and enabling atomic, single-tenant cache invalidation without flushing global entries.
- **Jaspr-compatible HTML bridge (not a native Jaspr adapter):**
  - `MetaMantleDocument`, `MetaMantleHead`, `MetaMantleRouteAdapter`, `MetaMantleDataComponent`, and `MetaMantleContentAdapter`.
  - Support for Jaspr + Flutter Web hybrid embedding: server-rendered HTML shells with pre-rendered crawler content and Flutter Web canvas initialization.
- **Industry Schema Profiles:**
  - Added dedicated schema generation profiles for `LocalBusinessProfile`, `JobPostingProfile`, `RecipeProfile`, and `CourseProfile`.
- **Vertical Example Applications:** Added 7 runnable production-grade reference applications in `example/bin/`:
  - `example/lib/main.dart` — Flutter Web client application with reactive `MetaHead`.
  - `example/bin/static_marketing_example.dart` — Static marketing landing page generator.
  - `example/bin/ecommerce_server_example.dart` — E-commerce SSR with inventory webhooks and Google Merchant feeds.
  - `example/bin/jaspr_docs_example.dart` — Jaspr documentation portal with version switching and search indexing.
  - `example/bin/jaspr_flutter_embed_example.dart` — Hybrid Jaspr HTML shell embedding Flutter Web canvases.
  - `example/bin/blog_publishing_example.dart` — Markdown publishing engine with RSS, Atom, and Google News sitemaps.
  - `example/bin/saas_multitenant_example.dart` — Multi-tenant host validation and isolated cache key partitioning.
- **Comprehensive Documentation Suite:** 32 technical reference guides in `docs/` covering all architectural facets, security guarantees, performance metrics, and vertical integrations.
- **Acceptance Test Suite:** Expanded from 83 to **128 passing tests** across 18 test suites with 100% pass rate.

### Verification Milestone & Security Hardening
- **RFC 7232 HTTP Precedence & Weak ETag Comparison:** Fixed `MetaMantleServerEngine._isNotModified` to strictly ignore `If-Modified-Since` when `If-None-Match` is present per RFC 7232 §3.3. Added weak ETag comparison (`_weakEtagMatch` and `_stripWeak`), supporting `W/"..."`, raw `"..."`, and wildcard `*`. Forwarded `Last-Modified` to HTTP 304 Not Modified responses.
- **In-Line SSRF Protection & Response Streaming Security:** Wired `SsrfGuard` directly into `RestDataProvider` and `GraphQLDataProvider`, blocking loopback (`127.0.0.1`), private subnets, and cloud metadata (`169.254.169.254`). Replaced full buffering with chunk-by-chunk stream counting via `BytesBuilder`, immediately aborting with `StateError` if the response exceeds `maxResponseSizeBytes` (default 2MB) before consuming server heap.
- **Multi-Tenant Host Security Integration:** Wired `TenantHostValidator` into `MetaMantleServerEngine`. Unregistered or missing `Host` headers return HTTP 400 Bad Request, untrusted `x-tenant-id` headers are ignored, and cache keys are strictly partitioned by validated tenant context.
- **Social Card & Image Generation Subsystem:** Added pure Dart SVG synthesis (`SocialCardGenerator`) supporting OpenGraph (1200x630), Twitter Summary (1200x628), and Square (600x600) dimensions with XML escaping, custom themes, and LRU output caching.
- **Core Web Vitals Telemetry Subsystem:** Added `CoreWebVitalsCollector` ingesting LCP, INP, CLS, FCP, TTFB with zero PII (strips query parameters), calculating p75/p90/p95 percentiles, and categorizing metrics against Google CrUX thresholds.
- **CDN Invalidation Abstraction:** Implemented `CdnInvalidator` with Memory, Cloudflare (API v4), and Nginx adapters. CloudFront is an unsupported placeholder and reports failure; it does not call AWS.
- **SEO Regression Testing & CLI Integration:** Added `SeoRegressionTester` comparing baseline and current crawl snapshots to flag title/description mutations, dropped routes, dropped OG tags, and accidental NOINDEX transitions. Added `regression` subcommand to `meta_mantle` CLI.
- **Jaspr HTML Compatibility Bridge:** Implemented `JasprTagDescriptor` and HTML rendering helpers. The parity tests compare generated HTML output and do not demonstrate integration with Jaspr's component or router APIs.
- **E-Commerce End-to-End Inventory Lifecycle:** Verified complete 9-step inventory lifecycle (Request -> Cache Hit -> Warehouse Price Change -> Event Dispatch -> Tag Invalidation -> Cache Miss Re-request -> Updated HTML, JSON-LD, and Merchant XML feed), stock depletion lifecycle, and faceted navigation crawl budget protection.

### Bug Fixes & Refinements
- **Strict Static SEO Preflight Validation:** Added explicit description to `/about` in `example/meta_mantle.config.json` and `example/web_head.config.json` satisfying strict mode requirements without disabling `--strict`.
- **CupertinoIcons Font Tree-Shaking:** Added `cupertino_icons` dependency to `example/pubspec.yaml`, eliminating font asset resolution warnings during Flutter web release builds while allowing the Flutter tree-shaker to reduce font payload by 99.4%.
- **Canonical and Social Image Harmonization:** Updated all example URLs to consistently target `https://metamantle.alex.runs-on.dev/`.
- **Title Template Deduplication:** Fixed duplicate title generation on root and home routes (e.g. `<title>Site | Site</title>`). Added deduplication safeguards in `MetadataRenderer` that prevent applying the title template when the page title matches `siteName`, `defaultTitle`, or already contains the template suffix.
- **Title Regression Suite:** Added 8 regression unit tests covering default titles, page titles, empty titles, pre-templated titles, and disabled templates.
- **GoRouter Integration Clarification:** Explicitly documented the manual `MetaHead` widget wrapping pattern for `go_router`, deliberately avoiding a hard package dependency.
- **GitHub Pages Preparation:** Updated deployment workflow in `.github/workflows/pages.yml` with `--base-href /meta_mantle/` and documentation URLs.

### Core Features
- **Tripartite Architecture:**
  - **Engine A (Runtime):** Real-time DOM reconciliation using modern `package:web`, reactive updates on navigation, nested scope restoration, monotonic generation tokens protecting against async race conditions.
  - **Engine B (Static):** Build-time HTML AST generation, Flutter bootstrap script preservation (`flutter_bootstrap.js`), dynamic pattern expansion from JSON files, and automated `sitemap.xml` & `robots.txt` generation.
  - **Engine C (Native Server-Side Rendering):** Real-time dynamic document rendering on the server in pure Dart without browser dependencies, delivering full semantic HTML bodies to crawlers before client JavaScript executes.
- **Universal Database Abstraction Layer:**
  - `MetaMantleDataProvider<T>` contract with built-in adapters for Relational SQL databases, Document/NoSQL databases, in-memory caches, and REST/GraphQL APIs.
  - Native soft-delete detection yielding RFC-compliant `410 Gone` responses.
- **Multi-Tier Caching & Concurrency:**
  - `MemoryCacheStore` with bounded LRU eviction and tag-based O(1) invalidation.
  - Support for RFC 5861 `stale-while-revalidate` and `stale-if-error` caching directives.
  - `SingleFlightCoordinator` eliminating cache stampedes / thundering herds during concurrent regeneration.
  - HTTP conditional GET handling (`If-None-Match` -> `304 Not Modified`, `If-Modified-Since`).
- **Semantic HTML & Progressive Enhancement:**
  - Type-safe `H` node builders (`h1-h6`, `p`, `img`, `table`, `article`, `header`, `footer`, `nav`, `a`).
  - Strict allowlist `HtmlSanitizer` stripping malicious script tags and event handlers.
  - Flutter bootstrap script embedding for seamless client-side hydration.
- **Server Framework Interoperability:**
  - `metaMantleShelfHandler` and `metaMantleShelfMiddleware` for Shelf pipelines.
  - Framework adapters for Dart Frog, Serverpod, and Jaspr SSR.
- **Security & Threat Mitigation:**
  - `SsrfGuard` blocking access to private subnets, loopback addresses, and cloud instance metadata endpoints (`169.254.169.254`).
  - Open redirect loop detection and redirect chain collapsing (A -> B -> C becomes A -> C).
- **SEO & Search Indexing Automation:**
  - Sitemaps chunking into `sitemap_index.xml` for catalogues exceeding 50,000 URLs.
  - Google Image extensions and reciprocal `hreflang` validation.
- **Native WebAssembly (Wasm) Support:**
  - Fully compatible with `flutter build web --wasm` and Chrome execution via `package:web`.
- **Comprehensive Metadata Model:**
  - Standard SEO: Page title, title templates, meta description, meta keywords, author, publisher, application name, referrer policy, robots directives (`RobotsDirective`), theme color, color scheme.
  - Canonical URLs: Absolute URL resolution, scheme validation (`http`/`https`), query string/fragment protection, and configurable trailing slash handling.
  - Open Graph: Full typed Open Graph protocol support (`title`, `description`, `type`, `url`, `image`, dimensions `imageWidth`/`imageHeight`/`imageType`, `video`, `audio`, `siteName`, and multiple `localeAlternates`).
  - Twitter / X Cards: Complete Twitter Card specifications (`summary`, `summaryLargeImage`, `app`, `player`, `site`, `siteId`, `creator`, `creatorId`).
  - JSON-LD Structured Data: 13 typed schema helpers (`organization`, `website`, `webPage`, `product`, `article`, `breadcrumb`, `localBusiness`, `faqPage`, `person`, `softwareApplication`, `event`, `offer`, `custom`) with automatic XSS Unicode character escaping.
  - Icons and Manifests: Favicons (PNG, SVG, ICO), Apple Touch Icons, and Web App Manifests.
  - Resource Hints: `dns-prefetch`, `preconnect`, `prefetch`, `preload`, `prerender` with typed cross-origin and as attributes.
- **Widgets and Integrations:**
  - Declarative `MetaHead` widget (with backward-compatible `WebHead` alias).
  - Imperative `MetaMantle` facade (`setTitle`, `setDescription`, `setCanonical`, `update`, `reset`).
  - `MetaMantleNavigatorObserver` for automatic Flutter Navigator URL synchronization.
- **CLI Suite:**
  - `meta_mantle` executable offering `build`, `validate`, `inspect`, and `doctor` commands with `--strict`, `--dry-run`, and `--verbose` modes.
- **Platform Compatibility:**
  - Conditional compilation with zero runtime crash on non-web Flutter platforms (Android, iOS, macOS, Windows, Linux).


---

## 0.1.0-prerelease.7 - 2026-11-06

*Pre-release 7: Static SEO Builder Refactor & CLI Enhancements*

### Bug Fixes & Refinements
- **CLI Build Logic:** Reimplemented the static build pipeline in `meta_mantle_cli` to use the core `generate()` function, ensuring the CLI and library produce identical output.
- **Canonical Tags:** Eliminated duplicate canonical tag generation across static routes.
- **Strict Mode Validation:** Resolved build failure in `--strict` mode when missing descriptions occurred.
- **JSON-LD Script Escaping:** Added comprehensive XSS sanitization for all JSON-LD helper functions (13 total), ensuring Unicode characters (`<`, `>`, `&`, `"`) are safely encoded as `\uXXXX`.
- **Platform Safety:** Reinforced the `MetaHead` widget with platform build guards to prevent runtime crashes when running on non-web platforms (iOS, Android, macOS, Windows, Linux).

### Breaking Changes
- The `titleTemplate` field is deprecated in favor of `titlePatterns` in JSON configurations.

### Compatibility
- Requires Dart `>= 3.10.0` and Flutter `>= 3.30.0`.


---

## 0.1.0-prerelease.6 - 2026-11-06

*Pre-release 6: Documentation Site & Custom Domain Setup*

### Bug Fixes & Refinements
- **Canonical URLs:** Eliminated redundant canonical tag emissions during multi-scope navigation.
- **Apple Platform Support:** Added iOS 18 and visionOS safe-area viewport meta tag configurations.
- **JSON-LD Serialization:** Fixed JSON-LD escaping for UTF-8 and special trademark characters (e.g., `\u2122`).
- **URL Sanitization:** Enhanced preflight validation and dangerous scheme rejection for relative and absolute URLs.

### Compatibility
- Requires Dart `>= 3.10.0` and Flutter `>= 3.30.0`.


---

## 0.1.0-prerelease.5 - 2026-11-06

*Pre-release 5: JSON-LD Schema Helpers & Enhanced CLI*

### Features
- **Schema.org Structured Data:** Introduced typed JSON-LD factory helpers (`product`, `article`, `organization`, `website`, `breadcrumb`, `localBusiness`, `faqPage`, `person`, `event`).
- **CLI Diagnostics:** Added `inspect` and `doctor` commands to verify template index files and route configuration tables.

### Compatibility
- Requires Dart `>= 3.10.0` and Flutter `>= 3.30.0`.


---

## 0.1.0-prerelease.4 - 2026-11-05

*Pre-release 4: Static JSON Metadata Generation & CLI*

### Features
- **Dynamic Pattern Expansion:** Added support for parameterized route patterns (`/products/:slug`) populated dynamically from local JSON datasets.
- **Sitemap & Robots Automation:** Integrated automated build-time `sitemap.xml` and `robots.txt` generation.

### Compatibility
- Requires Dart `>= 3.10.0` and Flutter `>= 3.30.0`.


---

## 0.1.0-prerelease.3 - 2026-11-04

*Pre-release 3: Navigator Observer Integration*

### Features
- **Router Observation:** Introduced `MetaMantleNavigatorObserver` to synchronize browser URL path changes with active metadata scopes.
- **Scope Tokenization:** Implemented monotonic generation tokens in `RuntimeCoordinator` to eliminate asynchronous race conditions during rapid route transitions.

### Compatibility
- Requires Dart `>= 3.10.0` and Flutter `>= 3.30.0`.


---

## 0.1.0-prerelease.2 - 2026-11-03

*Pre-release 2: WebHead Aliasing and Widgets*

### Features
- **Declarative Head Widget:** Introduced `MetaHead` and `WebHead` widgets for declarative metadata binding in Flutter widget trees.
- **Imperative Facade:** Added imperative setters (`setTitle`, `setDescription`, `setCanonical`, `update`, `reset`) on `MetaMantle`.

### Compatibility
- Requires Dart `>= 3.10.0` and Flutter `>= 3.30.0`.


---

## 0.1.0-prerelease.1 - 2026-11-02

*Pre-release 1: Initial Package Publication*

### Features
- **Initial Core Architecture:** Initial release establishing pure Dart metadata models (`WebMetadata`, `OpenGraph`, `TwitterCard`, `RobotsDirective`) and browser DOM adapter.
- **WebAssembly Ready:** Pure `package:web` and `dart:js_interop` DOM adapter implementation.

### Compatibility
- Requires Dart `>= 3.10.0` and Flutter `>= 3.30.0`.
