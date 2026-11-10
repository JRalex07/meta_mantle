# Changelog

## 0.1.0 - 2026-11-10

Official initial release of **MetaMantle** (`meta_mantle`), the typed metadata management and static SEO framework for Flutter Web.

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
