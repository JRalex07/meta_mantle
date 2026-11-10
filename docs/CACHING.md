# Caching Architecture & Invalidation

MetaMantle includes a production-grade multi-tier caching system (`lib/src/cache/`) designed to achieve sub-millisecond response times while guaranteeing consistency.

---

## 1. Caching Lifecycle & RFC 5861 Support

MetaMantle implements modern HTTP and edge caching standards:

```dart
const policy = CachePolicy(
  ttl: Duration(minutes: 10),
  staleWhileRevalidate: Duration(hours: 1),
  staleIfError: Duration(hours: 24),
  tags: ['products', 'catalog'],
);
```

### Timeline States:
1. **Fresh (`0 -> TTL`)**:
   Returns the cached response directly with `X-MetaMantle-Cache: HIT`.
2. **Stale (`TTL -> TTL + SWR`)**:
   Returns the cached response immediately with `X-MetaMantle-Cache: STALE`.
   Asynchronously triggers a background revalidation using `SingleFlightCoordinator`.
3. **Expired (`> TTL + SWR`)**:
   Synchronously re-renders the page. If rendering fails due to an upstream failure and `staleIfError` is active, serves the stale entry rather than an error page.

---

## 2. In-Memory LRU Cache Store (`MemoryCacheStore`)

The default store provides in-process memory caching:
- **Bound Memory Consumption**: Configurable `maxEntries` (e.g. 5,000 entries) with least-recently-used (LRU) pruning.
- **Tag-Based Invalidation**: O(1) tag index mapping tags (`products`, `authors:42`) to cache keys.
- **Observability Metrics**: Tracks live `hits`, `misses`, `count`, and hit ratios.

### Programmatic Invalidation:
```dart
// Invalidate all product pages after a catalog sync
await serverEngine.invalidateTag('products');

// Invalidate a specific product
await serverEngine.invalidateTag('products:basmati-rice');

// Invalidate a specific path
await serverEngine.invalidatePath('/products/basmati-rice');
```

---

## 3. Stampede Protection (`SingleFlightCoordinator`)

When a high-traffic page expires or is invalidated, hundreds of concurrent requests could hit the database simultaneously (the "thundering herd" problem).

`SingleFlightCoordinator` ensures that **only one revalidation job runs at a time** for any given cache key. All other concurrent requests await that same future, eliminating upstream database spikes.

