# MetaMantle API Stability Policy

This document defines the stability tiers, semantic versioning guarantees, breaking change policies, and deprecation lifecycles for the **MetaMantle** framework.

---

## 1. Guiding Principles

1. **Predictability:** Developers building production applications on MetaMantle must not experience unexpected API breaks during minor or patch version upgrades.
2. **Modular Isolation:** Public exports are strictly categorized across four independent library entrypoints:
   - `package:meta_mantle/meta_mantle.dart` (Flutter Web Client)
   - `package:meta_mantle/meta_mantle_server.dart` (Pure Dart Server Engine)
   - `package:meta_mantle/meta_mantle_core.dart` (Universal Core Models)
   - `package:meta_mantle/meta_mantle_builder.dart` (Static CLI Builders)
3. **Internal Code Privacy:** Any class or file under `lib/src/` is considered internal and is subject to refactoring or modification without notice unless explicitly re-exported by a top-level library file.

---

## 2. Stability Tiers

MetaMantle APIs are classified into three distinct stability tiers:

### Tier 1: Stable APIs (Production Ready)
Stable APIs have verified automated test coverage, established real-world usage, and strict backward-compatibility guarantees.
- **Flutter Client:** `MetaHead`, `WebHead`, `WebHeadNavigatorObserver`, `FlutterWebHead`.
- **Core Models:** `WebMetadata`, `OpenGraph`, `TwitterCard`, `RobotsDirective`, `Favicon`, `AppleTouchIcon`, `ResourceHint`, and all 13 Schema.org JSON-LD builders (`OrganizationSchema`, `WebSiteSchema`, `ProductSchema`, `ArticleSchema`, etc.).
- **Server Engine:** `MetaMantleServerEngine`, `MetaRoute`, `ServerRequest`, `ServerResponse`, `CachePolicy`.
- **Cache & Concurrency:** `CacheStore`, `CacheEntry`, `MemoryCacheStore`, `SingleFlightCoordinator`.
- **Data Providers:** `MetaMantleDataProvider`, `DataProviderResult`, `RouteDataContext`, `MemoryDataProvider`, `RelationalDatabaseAdapter`, `DocumentDatabaseAdapter`, `RestDataProvider`, `GraphQLDataProvider`.
- **Security:** `SsrfGuard`, `TenantHostValidator`, `TenantContext`.
- **CLI:** `StaticHeadBuilder`, `StaticHeadConfig`, `StaticRouteConfig`.

### Tier 2: Evolving / Advanced Subsystems
Evolving subsystems are fully implemented and verified with automated test suites, but their API surface may accept non-breaking parameter extensions as modern search specifications evolve:
- `SocialCardGenerator` (`lib/src/social/social_image_generator.dart`)
- `CoreWebVitalsCollector` (`lib/src/performance/core_web_vitals.dart`)
- `CdnInvalidator` and CDN adapters (`lib/src/cdn/cdn_invalidator.dart`)
- `SeoRegressionTester` (`lib/src/cli/seo_regression_tester.dart`)
- E-commerce vertical extensions (`InventoryEventDispatcher`, `FacetedNavPolicy`, `MerchantFeedGenerator`)
- Publishing vertical extensions (`DocVersionPolicy`, `DocSearchIndexer`, `FeedGenerator`, `NewsSitemapGenerator`)

### Tier 3: Experimental APIs
APIs explicitly marked with `@experimental` or documented as preview.
- These APIs may change based on community feedback.
- Experimental status is always stated in the Dart doc comment.
- Hybrid paginated generation and dependency-based revalidation (`FileHtmlArtifactStore`, `CollectionRouteSource`, `HybridStaticGenerator`, `HybridRevalidator`, `HybridRevalidationScheduler`, `RevalidationWebhookHandler`, `FileRegenerationQueue`, `RegenerationWorker`, and `ArtifactMissPolicy`) are experimental. The file queue and webhook replay store are single-host; applications can isolate tenants with separate validated stores and queues, while transactional multi-instance storage and production ISR guarantees are not provided.

---

## 3. Deprecation & Breaking Change Lifecycle

MetaMantle follows **Semantic Versioning 2.0.0** (`MAJOR.MINOR.PATCH`):

```
MAJOR version: Incompatible API breaks
MINOR version: Backward-compatible functionality additions
PATCH version: Backward-compatible bug fixes and security patches
```

### Deprecation Rules:
1. **Notice Period:** A public API method or class will never be deleted without being marked with `@Deprecated('...')` for at least one minor release cycle.
2. **Deprecation Messages:** Every `@Deprecated` annotation must specify:
   - The reason for deprecation.
   - The exact replacement API or migration pattern.
   - The targeted major version when the deprecated member will be removed.
3. **Graceful Fallbacks:** Where feasible, deprecated methods will forward to their newer implementations to prevent compile-time breaks for existing users.

---

## 4. Binary & Ecosystem Compatibility

- **SDK Compatibility:** Package constraints are Dart `>=3.13.0 <4.0.0` and Flutter `>=3.47.0`. The root package requires Flutter for resolution, even though core/server entrypoint source avoids Flutter imports.
- **WebAssembly Support:** All client-side runtime logic is guaranteed to compile and execute under `dart2wasm` without legacy `dart:html` symbols.
- **Core Source Boundary:** `meta_mantle_core.dart` will remain free of Flutter, `dart:io`, and browser imports. This source-level boundary does not make the current package independently installable with the Dart SDK alone.

---

## 5. HTML Sanitizer & Security Policy Guarantees

- **`HtmlSanitizer.defaults()`:** Guaranteed as a compile-time constant (`const HtmlSanitizer.defaults()`) providing zero runtime overhead for default configurations.
- **`HtmlSanitizer({ ... })`:** The default factory constructor validates custom tags, attributes, and schemes at construction time, throwing `ArgumentError` when dangerous schemes (`javascript:`, `vbscript:`, `data:`, `blob:`, `file:`) or event handlers are supplied.
- **`UrlPolicy.isSafe`:** Strictly checks the raw, un-normalized URL before any trimming, rejecting raw forbidden control characters (C0: 0x00–0x1F, C1: 0x7F–0x9F), raw whitespace, and backslashes (`\`). Decodes percent-encoding iteratively to detect obfuscated attacks while preventing leading or trailing control characters from evading detection.

---

## 6. Sitemap Protocol & Byte-Size Guarantees

- **`SitemapGenerator`:** Guaranteed compliance with the sitemaps.org specification:
  - Enforces maximum 50,000 URLs and uncompressed UTF-8 50 MB (`52,428,800` bytes) per individual sitemap file (`SitemapGenerator.protocolMaxBytes`).
  - Configurable `maxBytesPerSitemap` parameter validated in debug mode (via assertions) and at runtime by `generateUrlset` and `generateSitemapIndex` to ensure `0 < maxBytesPerSitemap <= SitemapGenerator.protocolMaxBytes`, throwing `ArgumentError` on out-of-bounds inputs in both debug and release modes.
  - Automatically splits entries across chunked sitemaps (`sitemap_1.xml`, `sitemap_2.xml`, etc.) and emits a master `sitemap_index.xml` without duplicate URLs or missing routes.
  - Rejects single entries whose individual XML size exceeds the configured byte threshold.

---

## 7. Flutter Islands Multi-View Lifecycle Guarantees

- **`MantleIsland` & Bootstrap:**
  - Strict lifecycle transitions: `uninitialized` on DOM creation, `initializing` upon entrypoint loading, `mounted` upon receiving `__mantleSignalViewReady(viewId)` from Dart, `disposing` on teardown, and `disposed` after view detachment.
  - Multi-view initialization strictly calls `initializeEngine({ multiViewEnabled: true })` without a host element, then attaches each island individually via `app.addView({ hostElement })`.
  - Static fallback content is hidden upon `mounted` state to guarantee that real Flutter interactive hit targets receive clicks and native events.


