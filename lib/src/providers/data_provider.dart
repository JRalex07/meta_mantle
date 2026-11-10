import 'dart:async';

/// Request-scoped context passed to a [MetaMantleDataProvider].
class RouteDataContext {
  RouteDataContext({
    required this.path,
    this.parameters = const {},
    this.queryParameters = const {},
    this.headers = const {},
    this.locale,
    this.timeout = const Duration(seconds: 15),
    this.services = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  /// Normalized request path (e.g. '/products/basmati-rice/').
  final String path;

  /// Dynamic route parameters extracted from pattern (e.g. `{'slug': 'basmati-rice'}`).
  final Map<String, String> parameters;

  /// Parsed query parameters.
  final Map<String, String> queryParameters;

  /// Safe read-only view of HTTP request headers.
  final Map<String, String> headers;

  /// Resolved request locale or language code (e.g. 'en', 'es').
  final String? locale;

  /// Operation timeout duration.
  final Duration timeout;

  /// Application services or dependency injection container scoped to this request.
  final Map<Object, Object> services;

  /// Timestamp when the request was received.
  final DateTime timestamp;

  /// Retrieves a request-scoped service of type [S].
  S? getService<S>() {
    final service = services[S];
    if (service is S) return service;
    return null;
  }
}

/// The result returned by a [MetaMantleDataProvider].
class DataProviderResult<T> {
  const DataProviderResult({
    this.data,
    this.lastModified,
    this.etag,
    this.isFound = true,
    this.isDeleted = false,
    this.cacheTags = const [],
  });

  /// Successful result containing typed data.
  factory DataProviderResult.found(
    T data, {
    DateTime? lastModified,
    String? etag,
    List<String> cacheTags = const [],
  }) {
    return DataProviderResult(
      data: data,
      lastModified: lastModified,
      etag: etag,
      isFound: true,
      isDeleted: false,
      cacheTags: cacheTags,
    );
  }

  /// Missing record result (HTTP 404 Not Found).
  factory DataProviderResult.notFound({List<String> cacheTags = const []}) {
    return DataProviderResult(
      data: null,
      isFound: false,
      isDeleted: false,
      cacheTags: cacheTags,
    );
  }

  /// Permanently removed record result (HTTP 410 Gone).
  factory DataProviderResult.gone({List<String> cacheTags = const []}) {
    return DataProviderResult(
      data: null,
      isFound: false,
      isDeleted: true,
      cacheTags: cacheTags,
    );
  }

  /// The loaded typed entity, or `null` if missing or deleted.
  final T? data;

  /// Reliable last update timestamp from the database or source.
  final DateTime? lastModified;

  /// Content hash or database version identifier for HTTP ETag calculation.
  final String? etag;

  /// Whether the target record exists.
  final bool isFound;

  /// Whether the resource has been permanently deleted (supporting HTTP 410).
  final bool isDeleted;

  /// Semantic tags for invalidation (e.g. `['products', 'category:rice']`).
  final List<String> cacheTags;
}

/// Universal database and external source provider interface.
///
/// Implementations adapt databases (PostgreSQL, Firestore, SQLite, Supabase, etc.),
/// REST APIs, GraphQL endpoints, or in-memory repositories for MetaMantle.
abstract interface class MetaMantleDataProvider<T> {
  /// Loads typed data for the given [context].
  Future<DataProviderResult<T>> load(RouteDataContext context);
}
