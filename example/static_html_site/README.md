# MetaMantle Independent Consumer Example: Static HTML Site

An independent, standalone consumer application demonstrating the official public API of **MetaMantle** for pure Dart static HTML generation, semantic DOM node composition, SEO metadata, JSON-LD structured data, sitemap generation, and HTML5 validation.

## Architecture

This project is an **external consumer**:
- Imports **only** documented public entrypoints (`package:meta_mantle/meta_mantle_core.dart` and `package:meta_mantle/meta_mantle_builder.dart`).
- Contains zero imports from `package:meta_mantle/src/...`.
- Never relies on internal implementation details.

## Features Demonstrated

1. **Semantic HTML Construction**: Building valid HTML5 documents with `<header>`, `<nav>`, `<main>`, `<article>`, `<section>`, `<h1>`-`<h6>`, `<p>`, `<a>`, `<ul>`, `<li>`, `<table>`, and `<footer>` via `H` element factories.
2. **Type-Safe Metadata**: Page titles, meta descriptions, canonical URLs, robots directives, OpenGraph tags, and Twitter Card tags via `WebMetadata` and `MetaMantleConfig`.
3. **Structured Data (JSON-LD)**: Rich snippet schema generation using `JsonLd.organization`, `JsonLd.webSite`, and `JsonLd.webPage`.
4. **Sitemap Generation**: Standard-compliant XML sitemaps with `<loc>`, `<lastmod>`, `<changefreq>`, and `<priority>` using `SitemapGenerator`.
5. **Strict HTML5 Validation**: Automated document structure and quality checks using `HtmlValidator`.

## Getting Started

### 1. Resolve Dependencies
```bash
flutter pub get
```

### 2. Generate the Static Site
```bash
dart run bin/generate_site.dart
```

This compiles semantic HTML documents, sitemap.xml, and robots.txt into `build/site/`:
- `build/site/index.html` (Home)
- `build/site/about/index.html` (About)
- `build/site/contact/index.html` (Contact)
- `build/site/sitemap.xml`
- `build/site/robots.txt`

### 3. Verify Output with Tests
```bash
flutter test
```
