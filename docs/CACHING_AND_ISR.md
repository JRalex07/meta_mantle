# MetaMantle Caching & Incremental Static Regeneration (ISR)

MetaMantle's server engine provides enterprise-grade caching, single-flight request coalescing, and fine-grained tag-based cache revalidation inspired by Next.js ISR.

---

## 1. Multi-Tier Cache Stores

MetaMantle supports multiple storage backends through `CacheStore`:
- `MemoryCacheStore`: High-performance in-memory LRU cache with TTL and stale-while-revalidate semantics.
- `FileHtmlArtifactStore`: Durable filesystem storage with atomic file publication and immutable content-addressable objects (`.objects`).
- `RedisCacheStore` / `DatabaseCacheStore`: Distributed cache backends for multi-worker server clusters.

---

## 2. Stale-While-Revalidate Lifecycle

When a route is requested:
1. **Fresh (`age < ttl`)**: Served immediately from cache.
2. **Stale (`ttl <= age < staleWhileRevalidate`)**: The stale HTML is immediately returned to the user, while an asynchronous background regeneration task is enqueued in the `RegenerationQueue`.
3. **Expired (`age >= staleWhileRevalidate`)**: Request triggers synchronous regeneration using a `SingleFlightCoordinator` so competing requests share a single execution.

---

## 3. On-Demand Tag Revalidation

Invalidate cached pages when backend data changes:

```dart
final generator = HybridStaticGenerator(store: store);

// Invalidate all pages tagged with 'products'
await generator.revalidateTag('products');

// Invalidate a specific path
await generator.revalidatePath('/products/item-123');
```

Supports webhook integrations via `RevalidationWebhookHandler` with HMAC SHA-256 signature verification.
