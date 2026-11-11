# MetaMantle Integration Contract

This document specifies the official integration contract for downstream consumers of the **MetaMantle** framework, including the independent **MetaMantle Landing Website** repository.

---

## 1. Package Specification & Identity

| Attribute | Contract Value |
| :--- | :--- |
| **Package Name** | `meta_mantle` |
| **Official Repository** | `https://github.com/JRalex07/meta_mantle` |
| **Current Stable Baseline** | `0.1.0` |
| **License** | MIT License |
| **Dart SDK Compatibility** | `>=3.0.0 <4.0.0` |
| **Flutter SDK Compatibility** | `>=3.3.0` (Stable channel) |
| **WebAssembly Support** | Verified under `dart2wasm` |
| **Canonical Documentation Source** | `docs/` within this repository |
| **Official Documentation Domain** | `https://metamantle.alex.runs-on.dev` |

---

## 2. Public Entrypoints & Import Contracts

Consumers must strictly import public library entrypoints and avoid referencing `src/` internals:

```dart
// 1. Flutter Web Client Applications (Widgets & Reactive DOM)
import 'package:meta_mantle/meta_mantle.dart';

// 2. Pure Dart Server Applications (SSR Engine, Caching, DB Providers, Security)
import 'package:meta_mantle/meta_mantle_server.dart';

// 3. Static Site Generation CLI & Pre-rendering Builders
import 'package:meta_mantle/meta_mantle_builder.dart';

// 4. Pure Dart Core Models & Policy Primitives (Zero Flutter, Zero IO)
import 'package:meta_mantle/meta_mantle_core.dart';
```

---

## 3. Supported Rendering Engines Contract

Downstream consumers can integrate MetaMantle across three distinct rendering paradigms:

### Engine A: Runtime Web DOM Injection
- **Target:** Single-page Flutter Web applications (SPA).
- **Core Component:** `MetaHead` (and legacy alias `WebHead`).
- **Behavior:** Dynamically injects and reconciles `<title>`, `<meta>`, `<link>`, and `<script type="application/ld+json">` tags in `document.head` as user navigates.
- **Ownership Tag:** Injected tags carry `data-mm-owner="meta_mantle"` to prevent deleting third-party analytics or styling tags.

### Engine B: Static Route Pre-Rendering
- **Target:** Pre-deployment static builds.
- **Core Component:** `StaticHeadBuilder` and CLI command `meta_mantle build`.
- **Behavior:** Parses route configuration (`meta_mantle.config.json`), injects route-specific `<head>` tags into Flutter's `build/web/index.html`, and writes deep directory routes (`/about/index.html`) along with `sitemap.xml` and `robots.txt`.

### Engine C: Native Server-Side Rendering (SSR)
- **Target:** Dynamic backend servers (Shelf, Dart Frog, Docker containers).
- **Core Component:** `MetaMantleServerEngine`, `MetaRoute`, `CacheStore`.
- **Behavior:** Renders full semantic HTML documents in pure Dart VM, executes database queries via `MetaMantleDataProvider`, handles RFC 7232 conditional requests (`ETag`, `304 Not Modified`), and serves crawlers sub-50ms responses without client JavaScript.

---

## 4. Documentation Synchronization Contract

The **MetaMantle package repository** remains the canonical, authoritative source for all technical documentation.

The separate **Landing Website repository** should consume or display documentation according to the following contract:

1. **Source of Truth:** All technical Markdown documentation lives in `docs/` of this repository.
2. **Automated Synchronization:** Downstream website repositories should mirror or fetch Markdown files from `https://raw.githubusercontent.com/JRalex07/meta_mantle/main/docs/` or bundle them via Git subtrees/submodules.
3. **No Duplicate Maintenance:** Technical guides, API specifications, and security policies must never be manually duplicated in the website repository.
4. **Relative Link Resolution:** Downstream documentation viewers must resolve relative Markdown links (e.g. `[Architecture](ARCHITECTURE.md)`) to their corresponding website route URLs.
5. **Version Indication:** When rendering documentation, the site must display the corresponding package version (`0.1.0`).

---

## 5. Security & Isolation Boundaries

- **Zero Hardcoded Secrets:** Downstream consumers must provide their own environment variables for private services (e.g., database URLs, CDN tokens). MetaMantle supplies `.env.example` templates.
- **Strict Host Header Validation:** When configuring multi-tenant servers, downstream consumers must register authorized domains with `TenantHostValidator`.
- **SSRF Guarding:** Downstream consumers utilizing `RestDataProvider` must configure `SsrfGuard` allowlists if connecting to private APIs.
