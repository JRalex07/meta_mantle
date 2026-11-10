# Research report and design rationale

**Research date:** 10 November 2026  
**Package status:** early implementation (`0.1.0`), not yet verified by a local Dart/Flutter toolchain.

## Executive summary

A Flutter package that only mutates `document.head` is straightforward, but it does not solve the initial-response metadata problem. Browser runtime injection occurs only after the Flutter application executes. Some crawlers and social-preview fetchers may not execute that application, so metadata must also be present in the HTML response when the server returns it.

This project therefore implements two delivery paths behind one metadata model:

1. **Runtime path:** a Flutter widget or imperative API resolves metadata and updates `document.head` in the browser.
2. **Static path:** a Dart CLI consumes an explicit JSON route manifest, reads Flutter's built `index.html`, and creates route-specific HTML entry documents with metadata already present.

The static generator does not execute Flutter widgets, inspect route definitions from Dart source, or render Flutter UI into semantic HTML. It is a static HTML shell generator. This is an intentional and documented scope boundary.

## Platform research

### Browser interoperability

Dart's official migration guidance identifies `package:web` as the long-term browser API binding and says it replaces `dart:html` and related SDK web libraries. It is built on static JS interop and supports JavaScript and WebAssembly compilation. The same guide recommends `dart.library.js_interop` for conditional web imports.

This package therefore uses `package:web` only in a conditional browser adapter and uses a stub on non-web platforms. The selected dependency constraint is `web: ^1.1.1` with Dart 3.6 as the minimum SDK. Pub selects `web` 1.1.1 on older compatible Dart SDKs; `web` 1.1.2 now requires Dart 3.13, so newer toolchains can select it while Dart 3.6–3.12 projects remain on a compatible release. Re-check package SDK constraints before release.

Sources: [Dart: Migrate to package:web](https://dart.dev/interop/js-interop/package-web), [web 1.1.1](https://pub.dev/packages/web/versions/1.1.1), [web package](https://pub.dev/packages/web).

### Flutter bootstrap preservation

Flutter's web initialization documentation says `flutter build web` emits `flutter_bootstrap.js`. Custom initialization may include `{{flutter_js}}`, `{{flutter_build_config}}` and `{{flutter_bootstrap_js}}`; the loader also needs the `_flutter.loader.load()` call. Content-hashed builds place entrypoint and asset-manifest information into the build configuration. Hardcoding `main.dart.js` is therefore not a safe general strategy.

The builder parses and modifies the existing HTML document instead of replacing it with a new minimal page. It deliberately leaves the bootstrap script and Flutter-generated assets alone. It refuses to process a document without a recognizable Flutter bootstrap marker.

Source: [Flutter web app initialization](https://docs.flutter.dev/platform-integration/web/initialization).

### HTML parsing

The Dart `html` package provides an HTML5 parser and DOM-like tree API. Version 0.15.7 requires Dart 3.6 and includes parser and serializer security fixes. A structural parser is preferable to regex replacements when editing an HTML document because it can target the actual `<head>` tree and safely serialize text and attributes.

Sources: [html package](https://pub.dev/packages/html), [html 0.15.7 changelog](https://pub.dev/packages/html/changelog).

## SEO and crawler behavior

### Runtime injection versus initial HTML

Google documents a crawl, render and index pipeline for JavaScript pages and supports JavaScript-generated structured data. That does not make client-only metadata the safest cross-crawler strategy: the rendering phase is separate from the initial fetch, and non-Google preview systems do not necessarily execute the app. Initial HTML is the more reliable baseline for route metadata.

Sources: [Google JavaScript SEO basics](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics), [Google structured data introduction](https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data).

### Canonical and sitemap behavior

Google describes redirects and `rel=canonical` annotations as stronger canonicalization signals than sitemap inclusion, which is a weaker signal. Different canonicalization signals should agree. The generator therefore emits canonical tags per route and creates a sitemap from indexable same-origin canonical URLs. Routes marked `noindex` are excluded. This is a conservative implementation choice, not a guarantee that a search engine will select the declared canonical.

Source: [Google: consolidate duplicate URLs](https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls).

### JSON-LD

Google recommends JSON-LD in general because it is usually easier to implement and maintain, but requires required properties and accurate, complete data for eligibility. Valid structured data does not guarantee a rich result. The package's helpers are convenience constructors only; application owners remain responsible for truthful product price, stock, offers, reviews and other data.

Sources: [Google structured data introduction](https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data), [Schema.org](https://schema.org/).

## Competitive landscape and differentiation

The Flutter ecosystem already has SEO-related packages. The `seo` package documents a `Seo.head` API, semantic widget conversions and HTML document-tree approaches; `flutter_seo` documents imperative head tag helpers. Recreating the act of setting a title or meta description would not be meaningful differentiation.

This implementation instead focuses on: shared typed metadata resolution, lifecycle-aware runtime ownership and restoration, static per-route HTML files, JSON catalog expansion, same-origin canonical sitemap output, and explicit hosting/bootstrap documentation. The scope is complementary to semantic HTML/SSR approaches rather than a replacement for them. Recheck both projects' current APIs and maintenance status before making public competitor claims.

Sources: [seo on pub.dev](https://pub.dev/packages/seo), [flutter_seo on pub.dev](https://pub.dev/packages/flutter_seo).

## Architecture decisions

| Decision | Rationale | Trade-off |
|---|---|---|
| One package in v0.1.0 | Simpler initial API and release workflow | CLI/build dependencies are in the package dependency graph |
| Shared `WebMetadata` and renderer | Runtime and static output resolve the same fields | The static and runtime adapters still need parity tests |
| `package:web` conditional adapter | Modern interop and Wasm-compatible direction | Must test generated binding signatures on supported SDKs |
| DOM ownership keys | Avoids deleting unrelated tags | Existing semantic tags need snapshot/restore behavior |
| Explicit JSON route manifest | Deterministic and easy for CI | No automatic Dart route discovery |
| JSON data-file expansion | Simple product/catalog use case | Data is a build-time snapshot; requires rebuilds |
| HTML5 parser | Structured modification and serialization | Adds a dependency and can normalize source formatting |
| Static HTML shell, not SSR | Works with normal Flutter build output | Does not expose Flutter widget text as semantic HTML |

## Static generation algorithm

1. Read and validate `index.html`; require a `<head>` and recognizable Flutter bootstrap marker.
2. Validate input/output directory relationship.
3. Expand explicit routes and JSON-backed patterns.
4. Normalize routes, reject duplicate routes and path traversal, validate URL schemes and metadata tags.
5. In strict mode, stop before writing if required title/description warnings exist.
6. Copy the Flutter build only when output differs from input.
7. Parse the original HTML template separately for each route.
8. Replace or adopt matching head metadata while preserving unrelated tags and Flutter bootstrap code.
9. Write `/route/index.html`; generate a sitemap from unique same-origin canonical URLs excluding `noindex` routes.

The builder does not automatically delete obsolete files from a previous output directory. A clean output directory is recommended for repeatable deployments.

## Security and reliability boundaries

- Do not accept arbitrary raw HTML in metadata models.
- JSON-LD is JSON-encoded and dangerous HTML script delimiters are escaped.
- URLs are restricted to HTTP(S) when absolute; reject `javascript:` and other schemes.
- Route paths reject query, fragment, dot traversal and slash/backslash traversal.
- JSON data files must remain under the configuration directory.
- The runtime only prunes elements marked as package-owned; adopted originals are snapshotted and restored.
- Static builder should run on trusted build inputs in CI, not on arbitrary user-supplied directories.

## Why full SSR is not included

Flutter Web's visual output is not equivalent to a server-rendered HTML widget tree. A metadata shell can expose title, description, canonical, social cards and JSON-LD in the first response, but it cannot make the text drawn inside Flutter's rendering surface semantic HTML. Sites whose core requirement is indexable document text should evaluate HTML-first frameworks or a server-rendering framework.

## Release gates

Before `1.0.0`, run the included CI checks on the intended stable Flutter SDK, then add real browser tests for JavaScript and WebAssembly builds. Verify generated HTML from raw HTTP responses on each claimed hosting platform. Check browser back/forward, nested navigators, retained/offstage pages, custom bootstrap scripts, hashed Flutter builds, subdirectory hosting, multiple icons and restoration of pre-existing tags. Run `dart pub publish --dry-run` and confirm the package name and ownership.

## Current SDK compatibility snapshot

The `web` package version table currently lists `web` 1.1.2 with a Dart 3.13 minimum and `web` 1.1.1 with a Dart 3.4 minimum. The package keeps its own Dart floor at 3.6 and a `^1.1.1` dependency constraint so Pub can select a compatible binding version for the consumer SDK. The Flutter stable archive has a November 2026 release line; the checked-in CI deliberately uses the stable channel instead of pinning an outdated Flutter SDK.

Sources: [web package versions](https://pub.dev/packages/web/versions), [Flutter SDK archive](https://docs.flutter.dev/install/archive), [Dart SDK overview](https://dart.dev/tools/sdk).
