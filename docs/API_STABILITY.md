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

- **SDK Compatibility:** Package constraints are Dart `>=3.6.0 <4.0.0` and Flutter `>=3.27.0`. The root package requires Flutter for resolution, even though core/server entrypoint source avoids Flutter imports.
- **WebAssembly Support:** All client-side runtime logic is guaranteed to compile and execute under `dart2wasm` without legacy `dart:html` symbols.
- **Core Source Boundary:** `meta_mantle_core.dart` will remain free of Flutter, `dart:io`, and browser imports. This source-level boundary does not make the current package independently installable with the Dart SDK alone.

