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

  /// Total successful cache hits.
  int get hits => _hits;

  /// Total cache misses.
  int get misses => _misses;

  /// Current number of stored cache entries.
  int get count => _entries.length;

  @override
  Future<CacheEntry?> get(String key) async {
    final entry = _entries[key];
    if (entry == null) {
      _misses++;
      return null;
    }

    if (entry.isExpired()) {
      _misses++;
      await delete(key);
      return null;
    }

    _hits++;
    return entry;
  }

  @override
  Future<void> put(String key, CacheEntry entry) async {
    // Evict oldest entry if at capacity
    if (_entries.length >= maxEntries && !_entries.containsKey(key)) {
      final oldestKey = _entries.keys.first;
      await delete(oldestKey);
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
