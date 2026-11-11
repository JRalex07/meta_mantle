# MetaMantle Release Readiness Checklist

This document defines the formal engineering quality gates required before tagging and releasing any version of the **MetaMantle** package.

---

## 1. Quality Gates & Verification Matrix

Every gate must be evaluated and verified against live execution evidence before release approval:

| Gate | Verification Command / Metric | Standard | Current Status |
| :--- | :--- | :--- | :--- |
| **1. Formatting** | `dart format --output=none --set-exit-if-changed .` | 0 files modified | :white_check_mark: PASS |
| **2. Static Analysis (Root)** | `flutter analyze` | 0 issues | :white_check_mark: PASS |
| **3. Static Analysis (Example)** | `flutter analyze example` | 0 issues | :white_check_mark: PASS |
| **4. Unit & Integration Tests** | `flutter test --concurrency=1` | All tests pass | :white_check_mark: PASS (184/184, 2026-11-11) |
| **5. Package Dry-Run** | `dart pub publish --dry-run` | 0 errors, 0 warnings | WARN: 1 working-tree warning; no package published |
| **6. Flutter Web JS Build** | `flutter build web --release` in `example/` | Clean build in `build/web` | :white_check_mark: PASS |
| **7. Flutter Web Wasm Build** | `flutter build web --release --wasm` in `example/` | `main.dart.wasm` emitted | :white_check_mark: PASS |
| **8. Static CLI Builder** | `dart run meta_mantle build --config meta_mantle.config.json --strict` | HTML, sitemap.xml, robots.txt | :white_check_mark: PASS |
| **9. CLI Preflight Diagnostics** | `dart run meta_mantle doctor` | All checks pass | :white_check_mark: PASS |
| **10. Security Audit** | Pinned Gitleaks `git` and `dir` scans with `--redact` | 0 unresolved findings in history and checkout files | Pending executed CI run |

---

## 2. Detailed Verification Checklists

### A. Architectural Isolation
- [x] `lib/meta_mantle_core.dart` imports zero `package:flutter`, zero `dart:io`, and zero `package:web`.
- [x] `lib/meta_mantle_server.dart` imports zero `package:flutter` and zero `package:web`.
- [x] `lib/meta_mantle.dart` uses conditional imports for non-web platforms (`src/runtime/web_dom_stub.dart`).
- [x] Zero deprecated `dart:html` imports across the codebase.

### B. Security & Cryptographic Integrity
- [x] Crawler defaults to localhost denied, manually validates redirects, bounds response streaming, rejects downgrade/loops, and uses a direct pinned-address socket transport (no proxy or unchecked fallback). Caller-supplied crawler clients and REST/GraphQL providers do not receive this socket-pinning guarantee; enforce egress restrictions for those paths.
- [x] Chunk-by-chunk stream counting with immediate abort on oversized responses (`BytesBuilder`).
- [x] Incoming HTTP `Host` headers validated against registered tenants (`TenantHostValidator`).
- [x] Untrusted `x-tenant-id` request headers ignored when host validation is active.
- [x] Cryptographic SHA-256 ETags used on server SSR responses.
- [x] Unicode character escaping for `<script type="application/ld+json">` against XSS breakout.
- [x] HTML attribute and text escaping verified in `HtmlSanitizer` and `MetadataRenderer`.

### C. HTTP & Caching Conformance
- [x] RFC 7232 §3.3 precedence: non-matching `If-None-Match` strictly ignores `If-Modified-Since`.
- [x] Weak ETag comparison (`W/"..."` vs `"..."` vs `*`).
- [x] `Last-Modified` and `Cache-Control` headers included on 304 Not Modified responses.
- [x] True access-order LRU cache eviction in `MemoryCacheStore`.
- [x] RFC 5861 `stale-while-revalidate` and `stale-if-error` origin recovery.
- [x] Single-flight coordination preventing cache stampedes with fail-closed timeout.

### D. Vertical Solution Verification
- [x] E-commerce 9-step inventory lifecycle verified (request -> cache -> price change -> event -> invalidate -> new render -> JSON-LD -> Merchant feed).
- [x] Faceted navigation crawl budget protection verified.
- [x] Pure Dart SVG social card generation verified.
- [x] Core Web Vitals telemetry ingestion and p75 CrUX classification verified.
- [ ] Cloudflare and Nginx adapters have live request paths; CloudFront remains unsupported until AWS authentication and API calls are implemented.
- [x] SEO regression test engine and CLI command verified.
- [ ] Jaspr support is a metadata/HTML compatibility bridge; no native Jaspr component or router adapter is provided.

### E. Documentation & Repository Health
- [x] Obsolete GitHub Pages deployment workflow (`pages.yml`) deleted.
- [x] Obsolete CNAME references removed.
- [x] CI workflow (`ci.yml`) hardened and decoupled from website deployment.
- [x] `.env.example` created with safe placeholder variables.
- [x] `.gitignore` hardened against private keys, certificates, and credentials.
- [x] All 32+ documentation guides reviewed and cross-referenced.
- [x] `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`, `CODE_OF_CONDUCT.md`, `GOVERNANCE.md` created.
- [x] `API_STABILITY.md`, `INTEGRATION_CONTRACT.md`, and `RELEASE_READINESS.md` created.

---

## 3. Versioning Baseline Policy

- The package is currently at **v0.1.0** baseline.
- Version **1.0.0** will be declared after initial real-world production feedback from downstream consumers (including the standalone landing website) without breaking public API changes.

