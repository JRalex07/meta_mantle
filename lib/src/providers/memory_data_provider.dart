import 'dart:async';
import 'data_provider.dart';

class _MemoryRecord<T> {
  _MemoryRecord({
    required this.data,
    required this.lastModified,
    this.etag,
    this.cacheTags = const [],
    this.isGone = false,
  });

  T? data;
  DateTime lastModified;
  String? etag;
  List<String> cacheTags;
  bool isGone;
}

/// An in-memory implementation of [MetaMantleDataProvider] ideal for testing,
/// prototypes, and local development.
class MemoryDataProvider<T> implements MetaMantleDataProvider<T> {
  MemoryDataProvider({
    this.lookupParam = 'slug',
    this.simulatedLatency,
    this.shouldThrowError = false,
  });

  final String lookupParam;
  final Duration? simulatedLatency;
  final bool shouldThrowError;

  final Map<String, _MemoryRecord<T>> _store = {};

  /// Inserts or updates a record.
  void set(
    String key,
    T data, {
    DateTime? lastModified,
    String? etag,
    List<String> cacheTags = const [],
  }) {
    _store[key] = _MemoryRecord<T>(
      data: data,
      lastModified: lastModified ?? DateTime.now().toUtc(),
      etag: etag ??
          'w/"${data.hashCode}-${DateTime.now().millisecondsSinceEpoch}"',
      cacheTags: cacheTags,
      isGone: false,
    );
  }

  /// Marks a record as deleted or permanently gone.
  void markGone(String key, {List<String> cacheTags = const []}) {
    final existing = _store[key];
    if (existing != null) {
      existing.data = null;
      existing.isGone = true;
      existing.lastModified = DateTime.now().toUtc();
    } else {
      _store[key] = _MemoryRecord<T>(
        data: null,
        lastModified: DateTime.now().toUtc(),
        isGone: true,
        cacheTags: cacheTags,
      );
    }
  }

  /// Completely removes a record from the in-memory store.
  void remove(String key) {
    _store.remove(key);
  }

  /// Clears all stored records.
  void clear() {
    _store.clear();
  }

  @override
  Future<DataProviderResult<T>> load(RouteDataContext context) async {
    if (shouldThrowError) {
      throw StateError('Simulated database connection failure.');
    }

    if (simulatedLatency != null) {
      await Future<void>.delayed(simulatedLatency!);
    }

    final key = context.parameters[lookupParam] ??
        context.queryParameters[lookupParam] ??
        context.path;

    final record = _store[key];
    if (record == null) {
      return DataProviderResult<T>.notFound();
    }

    if (record.isGone || record.data == null) {
      return DataProviderResult<T>.gone(cacheTags: record.cacheTags);
    }

    return DataProviderResult<T>.found(
      record.data as T,
      lastModified: record.lastModified,
      etag: record.etag,
      cacheTags: record.cacheTags,
    );
  }
}
