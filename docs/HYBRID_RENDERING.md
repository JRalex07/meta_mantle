# Hybrid rendering and regeneration (experimental)

MetaMantle currently has browser metadata updates (`MetaHead`), build-time HTML generation (`StaticHeadBuilder`), and request-time SSR (`MetaMantleServerEngine`). The additional hybrid APIs below are experimental building blocks for paginated generation and manual page regeneration; they are not yet a production ISR system.

## Generate a collection with complete HTML

Fixed pages use `FixedRouteSource` with the same versioned store and dependency index. Use a shared `routeId` for a fixed page set; regenerating that set removes paths from its previous publication that are no longer declared.

Pass `siteBaseUrl` to `HybridStaticGenerator` to derive canonical URLs for documents that do not provide their own. The versioned `sitemap.xml` includes only indexable dependencies; renderers can set `canonicalUrl`, `lastModified`, and `indexable: false` per page. A public `route-manifest.json` lists generated paths and their route IDs, canonical URLs, indexability, and timestamps. Regeneration and route deletion update both files in the same publication as the HTML and dependency index.

Import `package:meta_mantle/meta_mantle_builder.dart` from a Dart build script. Expose a paginated `discover` callback backed by your database/API, and provide a renderer that returns a complete document using MetaMantle's `HtmlDocument`.

Collection sources default to `InitialGenerationPolicy.all`. Choose `selected` and provide `includeInInitialGeneration` to render a curated subset while still discovering the full source; choose `none` to publish no initial pages for that route without calling its discovery callback. `none` removes any prior pages for that route from the new publication. Route-time missing-page fallback is still the existing SSR route, not automatic on-demand artifact creation.

The runnable [fixed and product collection example](../example/bin/hybrid_generation_example.dart) uses `HtmlDocument` and semantic nodes to generate a marketing page plus complete product content, metadata, canonical URLs, Product JSON-LD, dependency tags, and a sitemap. From the `example` directory, run `dart run bin/hybrid_generation_example.dart 10000 --keep` to generate 10,000 sample product pages and retain the output for inspection. Remove `--keep` to let the example clean up its temporary output.

On the repository's Windows development host, `dart run bin/hybrid_generation_example.dart 10000` generated 10,000 product documents in 31,826 ms and exported the static directory in 41,487 ms, including one fixed page and a 10,001-URL sitemap (2026-11-11). This is one local filesystem run over in-memory sample records; it does not measure a real database, concurrent production load, or shared storage.

The source is called one page at a time, records within a page are processed with bounded concurrency, route keys are validated and encoded, and outputs are written as `/products/<slug>/index.html`. The dependency index records route IDs, tags, source versions and generation timestamps; persisted reverse indexes map tags and route IDs to paths without scanning HTML files. Pages are generated into a versioned draft; the serving layer follows an active-version pointer, switched only after rendering and dependency-index writes succeed. Revalidation supports paths, tags, routes and all indexed pages, and route deletion atomically removes its artifacts and dependencies:

```dart
import 'dart:io';
import 'package:meta_mantle/meta_mantle_builder.dart';

final store = FileHtmlArtifactStore(Directory('build/generated'));
final revalidator = HybridRevalidator(
  store: store,
  regenerate: (path, previous) async {
    final document = HtmlDocument(
      metadata: WebMetadata(title: 'Updated page'),
      bodyNodes: [H.h1('Updated page')],
    );
    return GeneratedRouteDocument(
      html: document.render(currentUrl: previous.canonicalUrl),
      tags: previous.tags,
      sourceVersion: previous.sourceVersion,
      canonicalUrl: previous.canonicalUrl,
      indexable: previous.indexable,
    );
  },
);
await revalidator.revalidateTag('product:prod_123');
await revalidator.revalidateRoute('products');
```

`deleteRoute('products')` removes all pages registered to that route in one version publication. `revalidateAll()` regenerates all indexed paths. A worker callback can connect durable jobs to the renderer by calling `revalidatePath(job.path)` after loading the route's authoritative current data. Collection routes support `all`, `selected`, and `none` initial generation. `HybridRevalidationScheduler.revalidateExpired` scans dependency timestamps and enqueues stale routes; invoke it from your own cron or scheduler because MetaMantle does not run a background timer.

```dart
await scheduler.revalidateExpired(
  maxAge: const Duration(hours: 6),
  eventId: 'hourly-scan-2026-11-11T12',
  maxJobs: 10000,
);
```

The scan rejects a batch larger than `maxJobs` instead of silently truncating it. Give each scheduled run a fresh event ID so completed jobs do not suppress a later time-based run.

For asynchronous event processing, `HybridRevalidationScheduler` maps a tag, path, route ID, or full-index event to idempotent jobs. Supply a unique event ID to coalesce webhook retries, then run `RegenerationWorker` continuously and provide a handler that uses `HybridRevalidator` or an equivalent authoritative renderer. The scheduler's `siteId` and `tenantId` partition queue idempotency only; use separate artifact stores and queue directories per tenant because the dependency index is not tenant-aware.

`RevalidationWebhookHandler` provides a Shelf handler for signed POST events. It verifies an HMAC-SHA256 signature over the exact request body plus timestamp, event ID, and configured tenant; checks timestamp skew, payload size and selector shape; applies replay protection; and schedules jobs from the dependency index without trusting webhook content as source data. Use a secret of at least 32 random bytes, configure one handler per tenant, and put the endpoint behind a trusted network level rate limit as well. `FileWebhookReplayStore` is durable for one host on filesystems honoring exclusive locks; its replay files currently need operational cleanup. The built-in event rate limiter is process-local. This is not a multi-instance endpoint guarantee.

The callback must load authoritative current data and return the complete current dependency tag set; omitted tags are removed from the reverse index. Revalidation publishes complete replacement HTML with the updated dependency record. `HybridRevalidator` can receive `compareSourceVersions(candidate, current)`; a negative result rejects the generated page and preserves the active publication. Without a version ordering function, active-version compare-and-swap rejects jobs whose draft began before a newer publication, while a callback starting later must still fetch authoritative current data. Records without source versions rely on that authoritative read.

### Content-Addressed Storage, Persistence & Queue Architecture (Hardened)

1. **Content-Addressed Immutable Artifacts:** `FileHtmlArtifactStore` stores generated documents as content-addressed files under `.objects/{sha256}.html`. Versions do not copy HTML trees; draft creation (`beginVersion`) copies only small JSON manifests and shards. Unchanged pages across regenerations share identical underlying content objects on disk.
2. **Atomic Rollback & Garbage Collection:** `store.rollbackTo(version)` updates the active version pointer instantaneously without copying files. `store.garbageCollect({retentionGracePeriod, maxRetainedVersions})` audits all retained version manifests and safely unlinks orphaned content objects older than the configured grace period.
3. **Sharded Route & Dependency Indexing:** Route-to-artifact mapping and route dependencies are partitioned across 256 shards under `.route_shards/` and `.dep_shards/` based on SHA-256 prefixes of normalized paths. Individual route lookups and incremental updates (`saveRouteDependency`) touch only the target shard, avoiding monolithic JSON parsing on large route catalogues.
4. **Monotonic Publication Fencing Epochs:** `store.publishVersion(version, {fencingEpoch, routePath})` verifies candidate publication epochs against `.publish_epochs.json`. If a preempted or stale worker attempts to publish a draft after a newer worker has published a higher epoch, `StaleFencingEpochException` is thrown and the newer publication is preserved.
5. **Write-Ahead Journaling (WAL) & Queue Compaction:** `FileRegenerationQueue` logs state transitions append-only to `.queue.journal`. `queue.checkpoint()` atomically compacts the journal into `indexes/snapshot.json`. On restart or crash, `queue.recover()` replays the journal, safely discards partial or corrupted trailing writes, discovers unindexed job files on disk, and restores queue state.
6. **Worker Lease Heartbeats & Renewal:** `queue.renewLease()` extends lease expiration for active jobs. `RegenerationWorker` manages a periodic heartbeat timer (`heartbeatInterval`) during lengthy generation tasks and detects lease theft, reporting `RegenerationWorkerResult.leaseLost` if reclaimed by another worker.
7. **Storage & Queue Capabilities Contracts:** `store.capabilities` returns `StorageCapabilities` (declaring `supportsAtomicPublication: true`, `supportsRollback: true`, `supportsGarbageCollection: true`, `supportsDistributedLeases: false`). Similarly, `queue.capabilities` returns `QueueCapabilities` (declaring `supportsIdempotencyIndex: true`, `supportsBatchEnqueue: true`, `supportsFencing: true`, `supportsLeaseRenewal: true`, `supportsCrashRecovery: true`, `supportsPersistentJournal: true`, `isDistributed: false`).
8. **Persistent O(1) Queue Indexing & Batching:** In-memory queue state is backed by atomic snapshots and append-only WAL. Job lookups by idempotency key, pending job claims, and expired lease scans operate in O(1) time without crawling filesystem directories. `queue.enqueueAll(requests)` supports atomic batch scheduling of thousands of jobs with duplicate deduplication, benchmarked up to 10,000 scheduled jobs running with sub-quadratic linear scaling (>500 jobs/sec on disk).
9. **Multi-Worker Concurrency & Lease Fencing:** `FileRegenerationQueue` supports multi-worker execution on a single host. Competing claims serialize through `.queue.lock`. Each lease claim generates a monotonic fencing token (`leaseToken`) and monotonic fencing epoch. Expired leases are automatically reclaimed, and stale workers attempting to complete or fail a job with an obsolete token are rejected with `StateError`.
10. **Network Security & DNS Pinning:** `RestDataProvider` and `GraphQLDataProvider` default to `ssrfGuard.createPinnedClient()`, pinning HTTP sockets directly to pre-validated IP addresses to prevent DNS rebinding attacks across external data providers. All HTTP redirects are strictly re-validated against private ranges and cloud metadata.

`FileRegenerationQueue` adds a durable, file-backed single-host job queue with idempotency keys, expiring leases, lease-token fencing, path serialization, bounded active claims and retries. `RegenerationWorker.processNext` claims and executes one job through an application callback; exceptions are stored only as a safe error code. The server can serve an expired artifact while invoking `onStaleArtifact`; connect that callback to an idempotent enqueue operation and run one or more workers separately. Repeated stale requests can call the hook concurrently, so the queue idempotency key must coalesce duplicates. The worker callback is responsible for loading current authoritative data and publishing a complete artifact. `HybridRevalidator` remains a separate direct regeneration helper.

## Deployment modes and current limits

- **Build-only static deployment:** Run generation before deployment and ship the resulting directory. Later data updates require another build/deployment.
- **Server-backed hybrid rendering:** Configure `MetaMantleServerEngine(artifactStore: store, artifactMaxAge: ...)` to serve fresh artifacts before loading route data. Artifact delivery is limited to public and request-invariant pages: requests with query parameters, authorization, cookies, or `Accept-Language` bypass artifacts. For tenant-host validated traffic, provide `artifactStoreForTenant: (tenant) => FileHtmlArtifactStore.forTenant(root, tenant.tenantId)` so every tenant resolves an isolated store only after host validation. `MetaRoute.artifactMissPolicy` defaults to `renderImmediately`, which uses ordinary SSR. `notFound` requires a previously generated artifact. `renderAndPublish` performs blocking SSR and atomically adds the complete rendered document and its dependency record to the selected local artifact store; the successful request remains valid if publication loses a race or the store fails. This is server-backed on-demand generation, not a mutation of an immutable static deployment. Stale artifacts also fall through to SSR unless `onStaleArtifact` is configured; with that hook, the server returns stale HTML and invokes the hook without waiting for it.
- **Mutable hybrid delivery:** Not currently implemented. A local filesystem write does not mutate a deployed static site's files or purge its CDN. A shared artifact store, serving/publishing integration and real job backend are required.

After generation, `await store.exportActiveVersion(Directory('build/site-output'))` copies the active public HTML, `route-manifest.json`, and `sitemap.xml` into a new directory for static hosting. It omits private dependency indexes. The destination must not already exist or overlap the artifact store. Copy that exported directory into the deployment artifact; later updates still require a new deployment unless a mutable publisher and serving layer are added.

The active-version pointer keeps readers on the previous completed generation while a draft is rendered. A failed generation discards its draft; tests verify the active artifact and dependency index remain unchanged. Writers serialize through a local filesystem lock and stale base versions are rejected. This is only as reliable as the filesystem's lock and rename semantics; it is not a distributed storage guarantee. The queue is durable across process restarts on one host, but retries have no jitter, the worker callback needs application wiring and a continuously run worker, and cross-instance guarantees are absent. Lease tokens fence stale workers from completing or failing a reclaimed job; they do not fence side effects performed inside a handler. Old artifact versions and unreferenced objects are safely purged via `store.garbageCollect()`. Tenant isolation is available only when the application uses separate stores and queues per validated tenant; it is not a shared multi-instance tenancy implementation. Do not claim complete multi-region or distributed cloud ISR without external storage/queue backends. Deleted-product redirects and slug-change redirect management remain unimplemented.

`maxRecords` defaults to 100,000 (hard maximum 1,000,000) to bound accidental unending discovery. The current generator retains discovered keys and the dependency index in memory, so memory is not constant with collection size. One in-memory 10,000-record sample was measured above; it is not a database, memory, or production-load benchmark. Measure the real workload before using large catalogs.
