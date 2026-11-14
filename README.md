# MetaMantle

[![CI](https://github.com/JRalex07/meta_mantle/actions/workflows/ci.yml/badge.svg)](https://github.com/JRalex07/meta_mantle/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Dart SDK](https://img.shields.io/badge/Dart-3.13%2B-blue.svg)](https://dart.dev)
[![Flutter SDK](https://img.shields.io/badge/Flutter-3.47%2B-blue.svg)](https://flutter.dev)
[![WebAssembly](https://img.shields.io/badge/Wasm-Ready-green.svg)](docs/FLUTTER_INTEGRATION.md)

**MetaMantle** is a universal typed metadata management, native server rendering (SSR), and automated SEO infrastructure framework for Flutter Web and Dart applications.

- **Official Repository:** [https://github.com/JRalex07/meta_mantle](https://github.com/JRalex07/meta_mantle)
- **Official Documentation Portal:** [https://metamantle.alex.runs-on.dev](https://metamantle.alex.runs-on.dev)
- **Package Version:** `0.3.0`

---

## 1. What is MetaMantle?

Single-page applications (SPAs) built with Flutter Web compile to WebAssembly or JavaScript that renders on an HTML5 canvas. Traditional search engine crawlers (Googlebot, Bingbot) and social platform scrapers (Twitterbot, Facebook, Slack, Discord, LinkedIn) often inspect raw HTTP responses without waiting for client-side JavaScript execution or canvas hydration.

MetaMantle solves this problem by providing a unified SEO and document infrastructure that works across the entire application lifecycle: from client-side reactive browser `<head>` updates, to pre-deployment static HTML generation, to high-performance dynamic server-side rendering (SSR) in pure Dart.

---

## 2. Why MetaMantle?

MetaMantle is built on three complementary rendering paradigms:

1. **Engine A — Runtime Web DOM Engine (`MetaHead`):** Dynamically synchronizes document `<head>` metadata, Open Graph cards, and JSON-LD structured data in Flutter Web as users navigate between screens. Built with modern `package:web` and `dart:js_interop` with full WebAssembly (`dart2wasm`) compatibility.
2. **Engine B — Static Pre-Rendering Builder & Flutter Web Build Engine (`meta_mantle build`, `meta_mantle build-web`):** Compiles Flutter Web and injects route-specific metadata and semantic HTML into Flutter's `build/web` output before deployment so crawlers receive rich SEO tags in the initial HTML payload. Supports Mode A (metadata), Mode B (prerender), and Mode C (hybrid) with client startup handshake (`window.__mantleClientReady` & `MetaMantle.markReady()`). Generates XML sitemaps, `robots.txt`, and build reports automatically.
3. **Engine C — Native Request-Time SSR Engine (`MetaMantleServerEngine`):** Executes on the backend in pure Dart without browser overhead, returning complete semantic HTML documents, cryptographic SHA-256 ETags, and sub-50ms responses directly to search engine bots.

Beyond rendering, MetaMantle includes a universal database abstraction layer, true access-order LRU caching, in-line SSRF protection, multi-tenant host security, and vertical SEO engines for e-commerce, publishing, documentation, and SaaS.

---

## 3. Key Capabilities

### Implemented & Verified Capabilities:
- **Declarative & Imperative Metadata:** Set title, description, canonical URLs, robots directives, keywords, authors, publishers, theme color, icons, and resource hints.
- **Social Media Cards:** Complete Open Graph (with image dimensions, video, audio, multiple alternate locales) and Twitter / X Summary and Summary Large Image cards.
- **13 Schema.org JSON-LD Builders:** Strongly typed builders for Organization, WebSite, Product, AggregateOffer, Article, BreadcrumbList, LocalBusiness, FAQPage, Event, JobPosting, Recipe, and Course schemas with Unicode character escaping against XSS.
- **Native Dart SSR Engine:** Real-time dynamic document rendering on the server in pure Dart VM with zero headless browser dependencies.
- **Database Provider Contracts:** In-memory storage, callback-based SQL/document adapters, and REST/GraphQL clients. Database drivers and connection management are supplied by your application.
- **Enterprise Caching & Concurrency:** True access-order LRU cache eviction, cryptographic SHA-256 ETags, RFC 7232 conditional GET evaluation, RFC 5861 `stale-while-revalidate` and `stale-if-error` origin recovery, and single-flight distributed lock coordination.
- **Security & Multi-Tenancy:** In-line SSRF validation (`SsrfGuard`), a pinned-address default crawler transport, bounded crawler response streaming, and Host Header Injection defense with tenant-isolated caching (`TenantHostValidator`). The crawler blocks localhost by default; see [Security Architecture](docs/SECURITY.md) for its explicit development opt-in and transport limitations.
- **E-Commerce SEO Subsystem:** Product models, Google Merchant Center RSS 2.0 XML feeds, inventory webhook event invalidation (`InventoryEventDispatcher`), and faceted navigation crawl budget protection (`FacetedNavPolicy`).
- **Documentation & Publishing Engines:** YAML frontmatter extraction, documentation version canonicalization, hierarchical in-memory search index generation (`search.json`), `/llms.txt` generation for AI coding agents, RSS 2.0 / Atom 1.0 feeds, and Google News sitemaps.
- **Social SVG Image Generator:** Pure Dart SVG card generation with custom themes, Open Graph dimensions, and LRU output caching.
- **Core Web Vitals Telemetry:** Telemetry engine ingesting LCP, INP, CLS, FCP, TTFB with zero PII and p75 Google CrUX rating classification.
- **CLI & Testing Tooling:** Command-line suite (`build`, `validate`, `inspect`, `doctor`, `inspect-url`, `crawl`, `regression`) and snapshot-based SEO regression testing.
- **Experimental Hybrid Rendering:** Paginated dynamic-route document generation, versioned filesystem artifacts, dependency indexes, and direct revalidation. A single-host durable queue, fenced worker runner, and optional stale-artifact callback provide ISR building blocks, but production multi-instance ISR and post-deployment static-site mutation are not provided; see [Hybrid Rendering](docs/HYBRID_RENDERING.md).

### Decoupled Framework Adapters:
- **Shelf Adapter:** Verified adapter for Dart Shelf servers (`engine.toShelfHandler()`).
- **Jaspr-compatible HTML bridge:** Metadata descriptors and document-shell HTML helpers. This package does not currently integrate with Jaspr component or routing APIs.

---

## 4. Architecture Overview

```
                               +-------------------------------------+
                               |     meta_mantle_core (Pure Dart)    |
                               |  - WebMetadata & Unified Models     |
                               |  - 13 Schema.org JSON-LD Builders   |
                               |  - 7-Tier SEO Policy Engine         |
                               |  - HtmlDocument & HtmlSanitizer     |
                               +-------------------------------------+
                                                  |
                 +--------------------------------+-------------------------------+
                 |                                                                |
                 v                                                                v
+-----------------------------------+                           +-----------------------------------+
|     meta_mantle (Flutter Web)     |                           |  meta_mantle_server (Pure Dart)   |
|  - MetaHead / WebHead Widgets     |                           |  - MetaMantleServerEngine         |
|  - Reactive DOM Reconciler        |                           |  - Universal Database Providers   |
|  - Wasm-Ready (package:web)       |                           |  - True LRU Caching & Lock Safety |
|  - Monotonic Race Token Guards    |                           |  - RFC 7232 ETags & SWR / SIE     |
|  - Safe Non-Web Compilation Stubs |                           |  - SSRF Guard & Host Validator    |
+-----------------------------------+                           +-----------------------------------+
                 |                                                                |
                 v                                                                v
+-----------------------------------+                           +-----------------------------------+
|  meta_mantle_builder (Static CLI) |                           |        Framework Adapters         |
|  - StaticHeadBuilder              |                           |  - Shelf HTTP Adapter             |
|  - Dynamic Pattern Expansion      |                           |  - Jaspr-compatible HTML Bridge   |
|  - Sitemap & Robots.txt Generator |                           |  - CDN Invalidation (Cloudflare)  |
+-----------------------------------+                           +-----------------------------------+
```

---

## 5. Installation

### GitHub Git Dependency (Recommended)
Add `meta_mantle` directly from the official GitHub repository in your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  meta_mantle:
    git:
      url: https://github.com/JRalex07/meta_mantle.git
      ref: main # Or pin to a specific release tag such as v0.1.0
```

> **Flutter SDK Requirement**: Because `meta_mantle` declares `flutter: sdk: flutter` and `package:material_ui` in its root package manifest (`pubspec.yaml`), resolving dependencies (`flutter pub get` or `dart pub get`) requires the Flutter SDK to be installed in your environment. Pure-Dart entrypoints (`meta_mantle_core.dart` and `meta_mantle_server.dart`) contain no Flutter imports at runtime, but the package manifest requires the Flutter SDK on the host during dependency resolution.

### Local Path Dependency
For monorepos or local package development:
```yaml
dependencies:
  meta_mantle:
    path: ../meta_mantle
```

Run `flutter pub get` (or `dart pub get`) to resolve dependencies.

---

## 6. Quick Start

### Flutter Web Client Example

```dart
import 'package:material_ui/material_ui.dart';
import 'package:meta_mantle/meta_mantle.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MetaHead(
      metadata: WebMetadata(
        title: 'Home',
        titleTemplate: '%s | MetaMantle Store',
        description: 'Explore high-performance Flutter Web SEO.',
        canonical: 'https://store.example.com/',
        openGraph: const OpenGraph(
          title: 'MetaMantle Store',
          description: 'Explore high-performance Flutter Web SEO.',
          type: 'website',
          image: 'https://store.example.com/og-banner.png',
        ),
        jsonLd: [
          WebSiteSchema(
            name: 'MetaMantle Store',
            url: 'https://store.example.com',
          ),
        ],
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('MetaMantle Store')),
        body: const Center(child: Text('Welcome to MetaMantle!')),
      ),
    );
  }
}
```

---

## 7. Choosing an Engine

| Requirement | Recommended Engine | Documentation Guide |
| :--- | :--- | :--- |
| Single-page Flutter Web apps where browser `<head>` updates are sufficient | **Engine A: Runtime (`MetaHead`)** | [Flutter Web Integration](docs/FLUTTER_INTEGRATION.md) |
| Pre-rendering static marketing pages, blogs, or documentation for crawlers | **Engine B: Static Builder (`meta_mantle build`)** | [Static Generation Guide](docs/STATIC_GENERATION.md) |
| Dynamic databases, real-time inventory, sub-50ms crawler responses, and zero-JS payloads | **Engine C: Native SSR Engine (`MetaMantleServerEngine`)** | [Server Rendering Guide](docs/SERVER_RENDERING.md) |
| Hybrid server-rendered HTML document shell that embeds and bootstraps Flutter Web | **Jaspr Adapter (`MetaMantleDocument`)** | [Jaspr Web Integration](docs/JASPR_INTEGRATION.md) |

> [!NOTE]
> Client-side metadata injection alone is **not** server-side rendering. For search engines that do not execute JavaScript or for ultra-fast crawler discovery, use **Engine B (Static Pre-Rendering)** or **Engine C (Native SSR)**.

---

## 8. Working Examples

The repository includes runnable, production-grade reference implementations in [`example/bin/`](example/bin/):

- **[`example/lib/main.dart`](example/lib/main.dart):** Complete Flutter Web client application with reactive `MetaHead` widgets and Navigator observers.
- **[`example/bin/static_marketing_example.dart`](example/bin/static_marketing_example.dart):** Static marketing site generator emitting HTML, `sitemap.xml`, and `robots.txt`.
- **[`example/bin/ecommerce_server_example.dart`](example/bin/ecommerce_server_example.dart):** E-commerce SSR server with product variants, inventory cache invalidation, and Google Merchant Center feeds.
- **[`example/bin/jaspr_docs_example.dart`](example/bin/jaspr_docs_example.dart):** Documentation portal with version switching, search indexing, and `/llms.txt`.
- **[`example/bin/jaspr_flutter_embed_example.dart`](example/bin/jaspr_flutter_embed_example.dart):** Hybrid Jaspr HTML shell embedding a Flutter Web canvas.
- **[`example/bin/blog_publishing_example.dart`](example/bin/blog_publishing_example.dart):** Markdown publishing engine with RSS 2.0, Atom 1.0, and Google News sitemaps.
- **[`example/bin/saas_multitenant_example.dart`](example/bin/saas_multitenant_example.dart):** SaaS multi-tenant host validation, custom domain resolution, and isolated caching.

---

## 9. Documentation Index

Comprehensive technical documentation is maintained in [`docs/`](docs/):

- **[Getting Started Guide](docs/GETTING_STARTED.md)** — High-level walkthrough and engine selection.
- **[Installation Guide](docs/INSTALLATION.md)** — Dependency setup, entrypoints, and platform support.
- **[Quick Start Guide](docs/QUICK_START.md)** — Minimal working examples across all three engines.
- **[Architecture Deep-Dive](docs/ARCHITECTURE.md)** — Complete architectural specification.
- **[API Reference](docs/API.md)** — Comprehensive parameter and API documentation.
- **[E-Commerce SEO](docs/ECOMMERCE_SEO.md)** — Product models, inventory invalidation, and Merchant feeds.
- **[Documentation Portals](docs/DOCUMENTATION_SITES.md)** — Frontmatter, search indexers, and `/llms.txt`.
- **[Blogging & Publishing](docs/BLOGGING_AND_PUBLISHING.md)** — Article schemas, syndication feeds, and Google News.
- **[SaaS & Multi-Tenancy](docs/SAAS_AND_MULTITENANT.md)** — Host injection defense and tenant cache partitioning.
- **[Caching Architecture](docs/CACHING.md)** — True LRU eviction, single-flight locking, and tag invalidation.
- **[HTTP Caching & ETags](docs/HTTP_CACHING.md)** — RFC 7232 conditional requests and origin recovery.
- **[Database Providers](docs/DATABASE_PROVIDERS.md)** — SQL, NoSQL, memory, and REST/GraphQL data contracts.
- **[Security Architecture](docs/SECURITY.md)** — Host validation, SSRF protection, and XSS sanitization.
- **[Routing & Hosting](docs/ROUTING_AND_HOSTING.md)** — Deployment recipes for Firebase, Vercel, Netlify, and Docker.
- **[CLI Tooling](docs/CLI.md)** — Build, validate, inspect, doctor, crawl, and regression commands.
- **[API Stability Policy](docs/API_STABILITY.md)** — Public API guarantees and semantic versioning.
- **[Integration Contract](docs/INTEGRATION_CONTRACT.md)** — Integration contract for downstream consumers and website.
- **[Release Readiness Checklist](docs/RELEASE_READINESS.md)** — Formal quality gates for releases.

---

## 10. Contributing

Contributions are welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) for instructions on setting up your local environment, running static analysis and automated tests, and submitting pull requests.

All contributors must adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## 11. Security

MetaMantle treats security and data protection as core engineering requirements across client-side Flutter Web browsers, static build pipelines, and production server environments (SSR).

### Core Built-In Defenses & Guarantees

1. **In-Line SSRF Protection (`SsrfGuard`):**
   - Blocks outbound requests to loopback (`127.0.0.1`, `::1`), link-local, unspecified, multicast, and private RFC 1918 subnets (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`).
   - Blocks cloud instance metadata endpoints (`169.254.169.254`, AWS/GCP/Azure metadata services).
   - Validates all DNS answers before establishing socket connections to neutralize DNS rebinding attacks.
   - Pinned-address default crawler transport with strictly bounded response body streaming (2 MiB default cap) and per-hop/total operation timeouts.

2. **Host Header Injection & Multi-Tenant Defense (`TenantHostValidator`):**
   - Validates incoming HTTP `Host` headers against explicit tenant registries and domain allowlists.
   - Rejects missing or unauthorized `Host` headers immediately with `400 Bad Request`.
   - Strict tenant-isolated cache partitioning prevents cross-tenant cache poisoning.

3. **Context-Aware HTML & JSON-LD Escaping:**
   - Attribute and text values undergo HTML entity encoding (`&`, `<`, `>`, `"`, `'`) to block attribute breakout attacks (`" onmouseover="...`).
   - JSON-LD structured data in `<script type="application/ld+json">` is serialized with Unicode character escaping (`\u003c`, `\u003e`, `\u0026`) to neutralize script tag breakout attacks (`</script><script>...`).

4. **Strict HTML Sanitization (`HtmlSanitizer`):**
   - Enforces an allowlist filter on dynamic content, dropping executable tags (`<script>`, `<iframe>`, `<object>`, `<embed>`, `<form>`, `<link>`, `<style>`).
   - Strips all `on*` inline event handlers and removes CSS style expressions.
   - Rejects dangerous URL schemes (`javascript:`, `vbscript:`, `data:`).

5. **Error Sanitization & Information Disclosure Prevention:**
   - Server-side 500 error responses (`ServerResponse.serverError()`) emit sanitized, generic error pages.
   - Raw exception details, stack traces, and internal server paths are never leaked to external clients.

6. **Path Traversal & Open Redirect Defense:**
   - Static builders validate all target output paths and referenced data files to reject directory traversal attempts (`..`).
   - Redirect managers enforce internal path validation starting with `/` while rejecting backslashes (`\`) and double slashes (`//`).

7. **Automated Secret Scanning & Continuous Verification:**
   - Automated Gitleaks secret scanning runs in CI across git history and repository files.
   - All tests run against mock providers or explicit dummy tokens.

### Vulnerability Reporting & Disclosure

If you discover a security vulnerability, please report it privately via GitHub Security Advisories rather than opening a public issue:

- **Private Advisory:** Navigate to [Security Advisories](https://github.com/JRalex07/meta_mantle/security/advisories/new)
- **Security Policy:** Full policy and SLAs are documented in [SECURITY.md](SECURITY.md)
- **Security Architecture:** Detailed architectural specifications are in [docs/SECURITY.md](docs/SECURITY.md)

---

## 12. Support & Governance

- **Support:** For bug reports and feature requests, see [SUPPORT.md](SUPPORT.md).
- **Governance:** For project roles, decision-making, and release management, see [GOVERNANCE.md](GOVERNANCE.md).

---

## 13. License

MetaMantle is open-source software licensed under the [MIT License](LICENSE).
