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


0.1.0-prerelease.7 - 2026-11-06
Pre-release 7: Static SEO Builder Refactor & CLI Enhancements
Fixes

CLI Build Logic: Reimplemented the static build pipeline in meta_mantle_cli to use the core generate() function, ensuring the CLI and library produce identical output.

Duplicate canonical tag generation eliminated.

Build failure on strict mode with missing descriptions resolved.

JSON-LD Escaping: Added comprehensive XSS sanitization for all JSON-LD helper functions (13 total) to ensure Unicode characters are correctly escaped as \uXXXX.

Platform Safety: Reinforced the MetaHead widget with a build guard to prevent runtime crashes on non-web platforms (iOS, Android, etc.).

Breaking changes

The titleTemplate field is deprecated. Please migrate to titlePatterns in your JSON configuration.

Compatibility

Requires Dart 3.10+ and Flutter 3.30+.

0.1.0-prerelease.6 - 2026-11-06
Pre-release 6: Documentation Site & Custom Domain Setup
Bug fixes

Duplicate canonical tag generation eliminated.

Added iOS 18/visionOS 30px safe area meta tags.

Fixed JSON-LD escaping for UTF-8 and special characters (.\u2122.).

Enhanced preflight validation and URL sanitization.

Breaking changes

The titleTemplate field is deprecated. Please migrate to titlePatterns in your JSON configuration.

Compatibility

Requires Dart 3.10+ and Flutter 3.30+.

0.1.0-prerelease.5 - 2026-11-06
Pre-release 5: JSON-LD Schema Helpers & Enhanced CLI
Breaking changes

The titleTemplate field is deprecated. Please migrate to titlePatterns in your JSON configuration.

Compatibility

Requires Dart 3.10+ and Flutter 3.30+.

0.1.0-prerelease.4 - 2026-11-05
Pre-release 4: Static JSON Metadata Generation & CLI
Breaking changes

The titleTemplate field is deprecated. Please migrate to titlePatterns in your JSON configuration.

Compatibility

Requires Dart 3.10+ and Flutter 3.30+.

0.1.0-prerelease.3 - 2026-11-04
Pre-release 3: Navigator Observer Integration
Breaking changes

The titleTemplate field is deprecated. Please migrate to titlePatterns in your JSON configuration.

Compatibility

Requires Dart 3.10+ and Flutter 3.30+.

0.1.0-prerelease.2 - 2026-11-03
Pre-release 2: WebHead Aliasing and Widgets
Breaking changes

The titleTemplate field is deprecated. Please migrate to titlePatterns in your JSON configuration.

Compatibility

Requires Dart 3.10+ and Flutter 3.30+.

0.1.0-prerelease.1 - 2026-11-02
Pre-release 1: Initial Package Publication
Breaking changes

The titleTemplate field is deprecated. Please migrate to titlePatterns in your JSON configuration.

Compatibility

Requires Dart 3.10+ and Flutter 3.30+.