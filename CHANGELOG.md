# Changelog

## 0.1.0 - 2026-11-10

Official initial release of **MetaMantle** (`meta_mantle`), the typed metadata management and static SEO framework for Flutter Web.

### Bug Fixes & Refinements
- **Title Template Deduplication:** Fixed duplicate title generation on root and home routes (e.g. `<title>Site | Site</title>`). Added deduplication safeguards in `MetadataRenderer` that prevent applying the title template when the page title matches `siteName`, `defaultTitle`, or already contains the template suffix.
- **Title Regression Suite:** Added 8 regression unit tests covering default titles, page titles, empty titles, pre-templated titles, and disabled templates.
- **GoRouter Integration Clarification:** Explicitly documented the manual `MetaHead` widget wrapping pattern for `go_router`, deliberately avoiding a hard package dependency.
- **GitHub Pages Preparation:** Updated deployment workflow in `.github/workflows/pages.yml` with `--base-href /meta_mantle/` and documentation URLs.

### Core Features
- **Dual-Engine Architecture:**
  - **Engine A (Runtime):** Real-time DOM reconciliation using modern `package:web`, reactive updates on navigation, nested scope restoration, monotonic generation tokens protecting against async race conditions.
  - **Engine B (Static):** Build-time HTML AST generation, Flutter bootstrap script preservation (`flutter_bootstrap.js`), dynamic pattern expansion from JSON files, and automated `sitemap.xml` & `robots.txt` generation.
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
