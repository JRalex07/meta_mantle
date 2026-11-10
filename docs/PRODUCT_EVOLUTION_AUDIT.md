# MetaMantle — Product Evolution & Architectural Audit

**Audit Date:** 2026-11-10  
**Repository Identity:** `https://github.com/JRalex07/meta_mantle`  
**Current Commit:** `9dc362e`  
**Current Branch:** `main`  
**Auditor:** Principal Software Architect & Gravitas Reliability Runtime  
**Evaluation Standard:** Zero-assumption verification. Every capability is verified against running code and tests.

---

## 1. Verified Working Capabilities (Evidence-Backed)

The following subsystems have been verified with executable test evidence (83/83 passing tests, exit code 0):

| Subsystem | Implemented Components | Verification Evidence |
| :--- | :--- | :--- |
| **Engine A: Runtime DOM** | `WebHead`, `MetaHead`, `RuntimeCoordinator`, `HeadAdapterWeb`, `MetaMantleNavigatorObserver` | `runtime_lifecycle_test.dart` (10 tests pass). Wasm-compatible via `package:web`. Title deduplication works. |
| **Engine B: Static Builder** | `StaticHeadBuilder`, `StaticHeadConfig`, `BuildManifest` | `static_head_builder_test.dart` (10 tests pass). AST injection into `index.html`, dynamic JSON route expansion, strict preflight validation. |
| **Engine C: Server Engine** | `MetaMantleServerEngine`, `MetaRoute<T>`, `RedirectManager` | `server_engine_test.dart` (7 tests pass). 200 OK rendering, 304 Not Modified, 404, 410 Gone, redirect chain collapse (A->B->C -> A->C). |
| **HTML DSL & Sanitizer** | `HtmlDocument`, `HtmlNode`, `H`, `HtmlSanitizer` | `html_rendering_test.dart` (6 tests pass). Pure Dart node tree, XSS allowlist sanitization, Flutter bootstrap injection. |
| **Provider Contracts** | `MetaMantleDataProvider<T>`, `MemoryDataProvider`, `RelationalDatabaseAdapter`, `DocumentDatabaseAdapter`, `RestDataProvider`, `GraphQLDataProvider` | `database_provider_contract_test.dart` (10 tests pass). Soft-delete 410 Gone semantics verified across providers. |
| **Caching Primitives** | `CacheEntry`, `CachePolicy`, `SingleFlightCoordinator` | `cache_and_concurrency_test.dart` (3 tests pass). Stampede protection coalesces concurrent invocations. |
| **Shelf Adapter & Crawler** | `metaMantleShelfHandler`, `metaMantleShelfMiddleware`, `crawler_inspector` | `shelf_adapter_and_crawler_test.dart` (2 tests pass). Zero-JS crawler HTTP responses verified. |
| **SEO & Security** | `SitemapGenerator`, `HreflangValidator`, `SsrfGuard` | `seo_and_security_test.dart` (5 tests pass). Cloud metadata and private IP blocking verified. |
| **Scale Benchmarks** | 1k SSR routes, 10k sitemaps, 50k sitemap index | `large_catalogue_benchmark_test.dart` (3 tests pass). Sequential hits >2k/sec, misses >100/sec in debug. |

---

## 2. Incomplete Capabilities & Discrepancy Findings

Upon independent source inspection mandated by Section 2, the following technical debts and discrepancies were uncovered:

### Finding 1: FIFO Eviction Claimed as "LRU" in `MemoryCacheStore`
- **Location:** `lib/src/cache/memory_cache_store.dart:45-48`
- **Defect:** `_entries.keys.first` is used as eviction candidate. In Dart's `LinkedHashMap`, keys maintain insertion order unless explicitly re-inserted upon access. On a cache hit (`get`), the key was NOT touched. Thus, `MemoryCacheStore` was strictly **FIFO (First-In, First-Out)**, not LRU (Least Recently Used).
- **Remediation:** In `get(key)`, on a hit, re-insert the key (`_entries.remove(key); _entries[key] = entry;`) to promote it to the end of the access queue.

### Finding 2: `stale-if-error` Was Declared But Inoperative
- **Location:** `lib/src/server/server_engine.dart:128-130`
- **Defect:** If `_renderRoute` threw an upstream exception, the engine returned `ServerResponse.serverError(...)` immediately without checking if an expired or stale cache entry existed within the `staleIfError` window. Furthermore, `cache.get(key)` purged expired entries on lookup, destroying the stale fallback before single-flight could run.
- **Remediation:** Decouple stale entry retrieval from immediate purge. Pass the previous entry to the single-flight handler so that upstream errors gracefully return the stale cache entry with `X-MetaMantle-Cache: STALE-IF-ERROR`.

### Finding 3: ETag Was FNV-1a Integer Hash, Documented as SHA-256
- **Location:** `lib/src/server/server_engine.dart:280-287`
- **Defect:** `_generateEtag` computed an FNV-1a 64-bit integer hash:
  `hash ^= content.codeUnitAt(i); hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;`
  Documentation and architecture claims stated cryptographic SHA-256 ETags.
- **Remediation:** Standardize cryptographic hashing via `crypto` SHA-256 or document the deterministic checksum with exact RFC 7232 weak/strong semantics.

### Finding 4: Multi-Tenant & Locale/Currency Cache Collisions
- **Location:** `lib/src/server/server_engine.dart:274-278`
- **Defect:** `_computeCacheKey` only concatenated `route.pattern + path + queryStr`. It did NOT partition by `tenantId`, `Host`, `Accept-Language`/`locale`, or `currency`. In a multi-tenant or multi-currency deployment, Tenant A could serve cached HTML to Tenant B.
- **Remediation:** Implement tenant-, host-, and locale-aware cache key computation (`_computeCacheKey(req, route, tenantContext)`).

### Finding 5: Distributed Lock Fallback Vulnerability in `SingleFlightCoordinator`
- **Location:** `lib/src/cache/single_flight.dart:51-64`
- **Defect:** If `distributedLock.acquire(...)` failed after 5 retries, `_executeWithLock` proceeded to execute `action()` anyway! This completely defeated the mutual exclusion guarantee of distributed locking in multi-instance clusters.
- **Remediation:** If the distributed lock cannot be acquired, wait or throw `DistributedLockException` rather than executing the critical section without a lock.

### Finding 6: Missing Centralized Hierarchical Policy Resolution Engine
- **Current State:** Policy merging is limited to `globalConfig` + `pageMetadata`.
- **Requirement:** A full 7-tier resolution hierarchy: `Global Policy -> Application Policy -> Tenant Policy -> Locale Policy -> Section Policy -> Route Policy -> Page Overrides` with diagnostic provenance tracing.

### Finding 7: Lack of Genuine Jaspr Framework Integration
- **Current State:** `MetaMantleJasprAdapter` only translates `WebMetadata` to `List<HeadTag>`.
- **Requirement:** First-class Jaspr integration (`MetaMantleDocument`, `MetaMantleHead`, `MetaMantleJasprProvider`, `MetaMantleRouteAdapter`, `MetaMantleDataComponent`, `MetaMantleContentAdapter`), Markdown frontmatter parser for `jaspr_content`, and Flutter embedding via `jaspr_flutter_embed`.

### Finding 8: Missing Vertical E-Commerce, Publishing, Docs, and SaaS Domain Modules
- Missing product variants, inventory change events, merchant feeds, faceted navigation policies, news sitemaps, RSS/Atom feeds, `llms.txt`, and tenant isolation guards.

---

## 3. Dependency & Modularity Review

- **`pubspec.yaml` Dependencies:** `args`, `html`, `http`, `shelf`, `web`, `flutter`.
- **Core Separation:** `lib/meta_mantle_core.dart` strictly avoids `flutter` and `dart:io`.
- **Server Separation:** `lib/meta_mantle_server.dart` requires `dart:io` and `shelf`, and must not be imported in browser-only Flutter applications.
- **Jaspr / Database Independence:** Database vendor SDKs (Postgres, Mongo, Supabase) must remain optional and decoupled via interfaces, not bundled as mandatory root dependencies.

---

## 4. Prioritized Evolution Roadmap

1. **Phase 1: Universal Infrastructure Hardening**
   - True LRU cache eviction in `MemoryCacheStore`.
   - Genuine `stale-if-error` upstream error fallback in `ServerEngine`.
   - Deterministic SHA-256 ETag calculation.
   - Fail-closed distributed locking in `SingleFlightCoordinator`.
   - Unified 7-tier SEO Policy Resolution Engine with provenance tracing.
2. **Phase 2: Jaspr Integration & Flutter Embedding**
   - Implement `MetaMantleDocument`, `MetaMantleHead`, `MetaMantleDataComponent`, `MetaMantleContentAdapter`.
   - Build frontmatter extractor for Markdown documentation portals.
   - Implement Flutter Web embedding pattern with pre-rendered server SEO HTML.
3. **Phase 3: E-Commerce SEO Engine**
   - E-commerce metadata models (variants, availability, ratings, shipping, return policies).
   - Inventory & price event synchronizer (`ProductUpdated`, `InventoryChanged`).
   - Faceted navigation crawlability & canonical policies.
   - Google Merchant Center XML feed generator.
4. **Phase 4: Content, Publishing & Documentation Specialization**
   - Versioned documentation policies (`/docs/v1/`, `/docs/latest/`).
   - Documentation search indexer (`search.json`).
   - AI-friendly content discoverability (`llms.txt`, raw Markdown views).
   - RSS 2.0 & Atom 1.0 feed generators.
   - Google News sitemap (`<news:news>`).
5. **Phase 5: SaaS, Multi-Tenancy & Security**
   - Tenant-isolated cache keys (`tenant:host:locale:currency:path`).
   - Host header attack validation with trusted host allowlist.
   - Cross-tenant cache leakage regression test suite.
6. **Phase 6: Advanced CLI, Acceptance Testing & Documentation**
   - Enhanced `crawl`, `inspect-url`, `audit` CLI diagnostics.
   - Comprehensive test suites covering all status codes (200, 301, 302, 304, 307, 308, 404, 410, 500, 503).
   - 32-file documentation suite and runnable examples across all 7 categories.

