import 'dart:async';

import '../models/metadata.dart';

/// Cached representation of a rendered page, its metadata snapshot, and headers.
class CacheEntry {
  CacheEntry({
    required this.html,
    required this.metadata,
    required this.createdAt,
    required this.ttl,
    this.staleWhileRevalidate,
    this.staleIfError,
    this.etag,
    this.lastModified,
    Set<String>? tags,
  }) : tags = tags ?? const {};

  /// Rendered HTML markup.
  final String html;

  /// Metadata snapshot corresponding to the exact state when the HTML was generated.
  final WebMetadata metadata;

  /// Generation timestamp.
  final DateTime createdAt;

  /// Duration during which the entry is considered completely fresh.
  final Duration ttl;

  /// RFC 5861 Stale-While-Revalidate window. While in this window, the stale entry
  /// may be served immediately while background regeneration is initiated.
  final Duration? staleWhileRevalidate;

  /// RFC 5861 Stale-If-Error window. If an origin error occurs, stale content
  /// can be served for this additional duration.
  final Duration? staleIfError;

  /// HTTP ETag validator string.
  final String? etag;

  /// Origin Last-Modified timestamp.
  final DateTime? lastModified;

  /// Semantic tags for invalidation (e.g. `['products', 'category:rice']`).
  final Set<String> tags;

  /// Returns true if the entry is within its fresh TTL window.
  bool isFresh([DateTime? now]) {
    final current = (now ?? DateTime.now().toUtc());
    return current.difference(createdAt) <= ttl;
  }

  /// Returns true if the entry is stale (past TTL) but within the Stale-While-Revalidate window.
  bool isStaleWhileRevalidate([DateTime? now]) {
    final current = (now ?? DateTime.now().toUtc());
    final age = current.difference(createdAt);
    if (age <= ttl) return false;
    if (staleWhileRevalidate == null) return false;
    return age <= (ttl + staleWhileRevalidate!);
  }

  /// Returns true if the entry is past TTL (and SWR) but still within the Stale-If-Error window.
  bool isStaleIfError([DateTime? now]) {
    final current = (now ?? DateTime.now().toUtc());
    final age = current.difference(createdAt);
    if (staleIfError == null) return false;
    final maxAllowedAge =
        ttl + (staleWhileRevalidate ?? Duration.zero) + staleIfError!;
    return age <= maxAllowedAge;
  }

  /// Returns true if the entry is completely expired and must not be served under normal conditions.
  bool isExpired([DateTime? now]) {
    final current = (now ?? DateTime.now().toUtc());
    final age = current.difference(createdAt);
    final maxAge =
        ttl +
        (staleWhileRevalidate ?? Duration.zero) +
        (staleIfError ?? Duration.zero);
    return age > maxAge;
  }
}

/// Cache policy controlling freshness and revalidation rules for routes.
class CachePolicy {
  const CachePolicy({
    this.ttl = const Duration(minutes: 5),
    this.staleWhileRevalidate = const Duration(minutes: 15),
    this.staleIfError = const Duration(hours: 1),
    this.tags = const [],
    this.isCacheable = true,
  });

  /// Completely disables caching for this route.
  static const CachePolicy noCache = CachePolicy(
    ttl: Duration.zero,
    staleWhileRevalidate: Duration.zero,
    isCacheable: false,
  );

  /// Standard content cache policy.
  final Duration ttl;

  /// Extra window to serve stale content while regenerating in background.
  final Duration? staleWhileRevalidate;

  /// Extra window to serve stale content if origin provider fails.
  final Duration? staleIfError;

  /// Semantic tags applied to entries generated with this policy.
  final List<String> tags;

  /// Whether responses are allowed to be cached.
  final bool isCacheable;
}

/// Abstract cache store contract for MetaMantle SSR.
abstract interface class MetaMantleCacheStore {
  /// Retrieves a cache entry by key. If [allowStale] is true, returns entries within
  /// the Stale-While-Revalidate or Stale-If-Error windows.
  Future<CacheEntry?> get(String key, {bool allowStale = false});

  /// Stores or updates an entry by key.
  Future<void> put(String key, CacheEntry entry);

  /// Deletes a cache entry by key.
  Future<void> delete(String key);

  /// Invalidates and removes all cache entries tagged with [tag].
  Future<void> deleteByTag(String tag);

  /// Invalidates and removes all entries matching any of [tags].
  Future<void> deleteByTags(List<String> tags);

  /// Clears the entire cache store.
  Future<void> clear();
}
