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
| `test/isr_hardening_and_benchmark_test.dart` | 11 | Content-addressed artifact immutability, atomic rollback, garbage collection, storage capabilities, O(1) queue idempotency/batching/cleanup/rebuild, 10,000 jobs benchmark, multi-worker lease fencing, and REST/GraphQL socket IP pinning. |
| `test/queue_crash_consistency_test.dart` | 3 | WAL corrupted journal tail truncation, reconciliation of unindexed on-disk job files, and recovery from interrupted snapshot compaction. |
| `test/worker_heartbeat_test.dart` | 4 | Explicit lease renewal, rejection of stolen leases, periodic background heartbeat during lengthy operations, and `leaseLost` detection. |
| `test/publication_fencing_test.dart` | 2 | Monotonic epoch verification in `publishVersion`, rejection of stale workers via `StaleFencingEpochException`, and preservation of newer publications. |
| `test/sharded_route_store_test.dart` | 3 | 256-shard partitioning for route artifacts and dependencies, single-page update isolation (modifying only 1 shard and 1 object), and route deletion pruning. |
| `test/dns_rebinding_verification_test.dart` | 6 | Stateful DNS resolver rebinding attack simulation, IPv4-mapped IPv6 loopback/metadata blocking, internal redirect protection, and URL protocol/userinfo validation. |
| `test/universal_component_ir_test.dart` | 14 | Universal component model, MantleNode IR, MantleStyle bidirectional CSS/Flutter mapping, flex alignments, and progressive component catalogue. |
| `test/universal_flutter_renderer_test.dart` | 9 | MantleFlutterRenderer Widget compilation: Text, ElevatedButton, TextFormField, Checkbox, Row, Column, Container, and InkWell. |
| `test/universal_server_renderer_test.dart` | 7 | MantleServerRenderer semantic HTML generation, XSS escaping, void tags, inline CSS, and complete HTML document wrapping. |
| `test/universal_routing_test.dart` | 9 | Universal routing, parameterized path matching (`:id`), query parameters, MantleApp, and navigation context callbacks. |
| `test/flutter_web_accelerator_test.dart` | 6 | Mode A web project analysis, Wasm compatibility checks, bundle size auditing, COOP/COEP headers, and build suggestions. |
| `test/universal_store_example_test.dart` | 1 | End-to-end multi-target execution verification of the universal store example. |

The current checkout has **259 automated tests**; the full test suite passed all 259 on 2026-11-12. This directory matrix highlights the principal suites across 33 test files.

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

