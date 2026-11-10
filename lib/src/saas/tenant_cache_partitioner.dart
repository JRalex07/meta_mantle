import '../cache/cache_store.dart';

/// Ensures tenant cache isolation, preventing cross-tenant data leaks.
class TenantCachePartitioner {
  const TenantCachePartitioner(this.cacheStore);

  final MetaMantleCacheStore cacheStore;

  /// Builds a fully isolated cache key partitioned by tenant, host, locale, and currency.
  String buildKey({
    required String tenantId,
    required String host,
    required String path,
    String locale = 'en',
    String currency = 'USD',
    Map<String, String> queryParameters = const {},
  }) {
    final cleanPath = path.isEmpty ? '/' : path;
    final sortedQuery = queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final queryStr = sortedQuery.map((e) => '${e.key}=${e.value}').join('&');

    return 'tenant:$tenantId:host:$host:loc:$locale:cur:$currency:path:$cleanPath?$queryStr';
  }

  /// Invalidates all cached pages belonging to a specific tenant.
  Future<void> invalidateTenant(String tenantId) async {
    await cacheStore.deleteByTag('tenant:$tenantId');
  }

  /// Generates tenant-specific cache tags to attach to [CacheEntry].
  Set<String> tenantTags(String tenantId,
      [List<String> additionalTags = const []]) {
    return {
      'tenant:$tenantId',
      for (final t in additionalTags) 'tenant:$tenantId:$t',
    };
  }
}
