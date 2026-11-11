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

- **SDK Compatibility:** MetaMantle guarantees compatibility with the stable channel of the Flutter and Dart SDKs (`>=3.0.0 <4.0.0`).
- **WebAssembly Support:** All client-side runtime logic is guaranteed to compile and execute under `dart2wasm` without legacy `dart:html` symbols.
- **Zero-Dependency Core:** `meta_mantle_core.dart` will strictly remain dependency-free from Flutter, `dart:io`, and browser packages.
