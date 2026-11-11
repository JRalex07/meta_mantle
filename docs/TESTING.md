# Testing Strategy & Verification Matrix

MetaMantle enforces automated test coverage spanning unit, widget, contract, concurrency, and security dimensions.

---

## 1. Test Suite Directory

| Test File | Test Count | Scope |
|---|---|---|
| `test/html_rendering_test.dart` | 6 | Type-safe HTML generation, `H` factories, XSS sanitization, bootstrap inclusion. |
| `test/cache_and_concurrency_test.dart` | 3 | MemoryCacheStore LRU, tag invalidation, SingleFlight stampede protection. |
| `test/database_provider_contract_test.dart` | 10 | Contract tests for Memory, Relational, Document, REST, and GraphQL providers. |
| `test/server_engine_test.dart` | 12 | SSR request lifecycle, fresh/on-demand/tenant-isolated artifacts, stale-artifact revalidation callback, artifact-required fallback, 304 Not Modified, 404, 410 Gone, redirects. |
| `test/shelf_adapter_and_crawler_test.dart` | 2 | Shelf adapter handler/middleware, crawler link discovery and broken link detection. |
| `test/crawler_security_test.dart` | 11 | SSRF defaults and ranges, DNS rebinding on the pinned transport, redirect safety/limits, timeout behavior, and bounded/cancelled body streaming. |
| `test/hybrid_generation_test.dart` | 17 | Fixed and paged collection generation, all/selected/none initial policies, sitemap and route-manifest publication, static export, route and cursor validation, legacy migration, consistent snapshots, stale-source and stale-writer fencing, route revalidation/deletion, and failure preservation. |
| `test/regeneration_queue_test.dart` | 9 | File persistence, idempotent enqueue, bounded/path-serialized claims, retries, lease recovery, fencing against stale workers, worker execution, indexed event scheduling, time-based expiration scans, and input validation. |
| `test/revalidation_webhook_test.dart` | 5 | Signed tag events, signature/timestamp/tenant validation, selector validation, replay rejection, durable replay storage and bounded Shelf body streaming. |
| `test/seo_and_security_test.dart` | 5 | Sitemap chunking, image extensions, hreflang validation, SSRF guard network security. |
| `test/large_catalogue_benchmark_test.dart` | 3 | High-scale 1k/10k/50k route benchmarks and sitemap index scaling. |
| `test/extended_features_test.dart` | 15 | Canonical URL resolution, JSON-LD serialization, template rendering. |
| `test/metadata_renderer_test.dart` | 12 | Exact tag string rendering and escaping. |
| `test/runtime_lifecycle_test.dart` | 10 | Flutter WebHead widget lifecycle, DOM interop, stack restoration. |
| `test/static_head_builder_test.dart` | 10 | Static HTML file injection, strict validation, route replacement. |

The current checkout has **184 automated tests**; the full serial run passed all 184 on 2026-11-11. This directory matrix highlights the principal suites and may not list every test file.

---

## 2. Running Verification

```bash
# Run all tests
flutter test

# Run static analysis
flutter analyze

# Verify code formatting
dart format --output=none --set-exit-if-changed .

# Verify pub publishing compliance
dart pub publish --dry-run
```

