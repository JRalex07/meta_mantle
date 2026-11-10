# Research notes and design decisions

Research checked on **10 November 2026**. URLs below are primary or package-maintainer references; verify versions again before a public release.

## Dart browser interop

- `package:web` is Dart's modern generated browser API binding and is intended to replace deprecated `dart:html` APIs. It is designed around static JS interop and supports JavaScript and WebAssembly compilation. Reference: https://dart.dev/interop/js-interop/package-web
- `package:web` 1.1.1 is selected to retain a Dart 3.6-compatible floor; 1.1.2 requires Dart 3.13 according to its package version page at research time. Reference: https://pub.dev/packages/web/versions
- The `dart.library.js_interop` conditional import is the recommended modern platform split for browser interop. Reference: https://dart.dev/interop/js-interop/package-web

## Flutter bootstrap and routing

- Flutter's `flutter build web` output uses `flutter_bootstrap.js`; custom bootstrap flows use the `{{flutter_js}}`, `{{flutter_build_config}}` and `_flutter.loader.load()` flow. The builder must preserve these generated files and template-derived setup. Reference: https://docs.flutter.dev/platform-integration/web/initialization
- Flutter path URL strategy uses History API paths and requires server rewrite/deep-link configuration. Reference: https://docs.flutter.dev/ui/navigation/url-strategies

## HTML parsing and command line

- `html` 0.15.7 provides an HTML5 parser and DOM-like tree API; selected for safe structural changes instead of regular-expression injection. Reference: https://pub.dev/packages/html
- `args` provides Dart CLI argument parsing. Reference: https://pub.dev/packages/args

## Search and structured data

- Google describes JavaScript indexing as crawl, render and index phases; its guidance notes rendering delay and recommends server-side or pre-rendered HTML as useful for users and crawlers. Reference: https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics
- Google says JSON-LD is generally the easiest structured data format to implement and requires complete, accurate data for eligibility. Structured data does not guarantee enhanced display. Reference: https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data
- Google treats canonical URLs as signals, not absolute rules, and recommends consistent canonicalization signals. Reference: https://developers.google.com/search/docs/crawling-indexing/consolidate-duplicate-urls
- Open Graph protocol reference: https://ogp.me/

## Existing Flutter packages

- `seo` (pub.dev) provides `SeoController`, `Seo.head`, semantic widget conversions and HTML document-tree support. Its README describes `WidgetTree` and experimental `SemanticsTree`. Reference: https://pub.dev/packages/seo
- `flutter_seo` provides imperative head tag helpers. Reference: https://pub.dev/packages/flutter_seo

## Product differentiation

The target differentiation is not merely dynamic meta insertion. It is:

1. shared typed metadata models and resolver;
2. scope-based runtime ownership and cleanup;
3. deterministic static route HTML generation;
4. JSON data expansion for dynamic product routes;
5. sitemap output and deployment verification guidance.

## Release caution

The environment used to create this archive did not have Flutter or Dart installed. Source files and tests are included, but this archive has not passed `dart format`, `flutter analyze`, `flutter test`, browser integration tests, `dart pub publish --dry-run`, or a live hosting test. These are required before publishing as stable.
