import 'dart:async';
import 'cache_store.dart';

/// Thread-safe in-memory cache store with tag-based indexing and metrics.
class MemoryCacheStore implements MetaMantleCacheStore {
  MemoryCacheStore({this.maxEntries = 1000});

  final int maxEntries;
  final Map<String, CacheEntry> _entries = {};
  final Map<String, Set<String>> _tagIndex = {};

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _invalidations = 0;
  int _expiredCount = 0;

  /// Total successful cache hits.
  int get hits => _hits;

  /// Total cache misses.
  int get misses => _misses;

  /// Total capacity-triggered LRU evictions.
  int get evictions => _evictions;

  /// Total entries purged via tag or key invalidation.
  int get invalidations => _invalidations;

  /// Total entries dropped due to expiration.
  int get expiredCount => _expiredCount;

  /// Current number of stored cache entries.
  int get count => _entries.length;

  /// Cache hit ratio (0.0 to 1.0).
  double get hitRatio =>
      (_hits + _misses == 0) ? 0.0 : _hits / (_hits + _misses);

  @override
  Future<CacheEntry?> get(String key, {bool allowStale = false}) async {
    final entry = _entries[key];
    if (entry == null) {
      _misses++;
      return null;
    }

    // Check expiration
    if (entry.isExpired()) {
      _expiredCount++;
      _misses++;
      await delete(key);
      return null;
    }

    // If not fresh and not allowing stale:
    if (!entry.isFresh() && !allowStale && !entry.isStaleWhileRevalidate()) {
      _misses++;
      return null;
    }

    _hits++;
    // True LRU: Move accessed entry to the tail of the linked hash map (most recently used)
    _entries.remove(key);
    _entries[key] = entry;
    return entry;
  }

  @override
  Future<void> put(String key, CacheEntry entry) async {
    // Evict least-recently-used entry if at capacity
    if (_entries.length >= maxEntries && !_entries.containsKey(key)) {
      final lruKey = _entries.keys.first;
      _evictions++;
      await delete(lruKey);
    }

    // Clean up previous tags if overwriting an existing key
    final existing = _entries[key];
    if (existing != null) {
      _unindexTags(key, existing.tags);
    }

    _entries[key] = entry;
    for (final tag in entry.tags) {
      _tagIndex.putIfAbsent(tag, () => <String>{}).add(key);
    }
  }

  @override
  Future<void> delete(String key) async {
    final entry = _entries.remove(key);
    if (entry != null) {
      _invalidations++;
      _unindexTags(key, entry.tags);
    }
  }

  @override
  Future<void> deleteByTag(String tag) async {
    final keys = _tagIndex.remove(tag);
    if (keys != null) {
      for (final key in List<String>.from(keys)) {
        final entry = _entries.remove(key);
        if (entry != null) {
          _invalidations++;
          _unindexTags(key, entry.tags);
        }
      }
    }
  }

  @override
  Future<void> deleteByTags(List<String> tags) async {
    for (final tag in tags) {
      await deleteByTag(tag);
    }
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _tagIndex.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _invalidations = 0;
    _expiredCount = 0;
  }

  void _unindexTags(String key, Set<String> tags) {
    for (final tag in tags) {
      final keys = _tagIndex[tag];
      if (keys != null) {
        keys.remove(key);
        if (keys.isEmpty) {
          _tagIndex.remove(tag);
        }
      }
    }
  }
}
