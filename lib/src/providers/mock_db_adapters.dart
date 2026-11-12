import 'dart:async';

import 'data_provider.dart';

/// Function signature for executing a parameterized SQL query.
typedef SqlQueryRunner = Future<Map<String, dynamic>?> Function(
  String sql,
  List<Object?> parameters,
);

/// Function signature for mapping a SQL row map to entity [T].
typedef SqlRowMapper<T> = T Function(Map<String, dynamic> row);

/// Adapter demonstrating how Relational Databases (PostgreSQL, MySQL, SQLite)
/// integrate with MetaMantle without introducing mandatory database dependencies.
class RelationalDatabaseAdapter<T> implements MetaMantleDataProvider<T> {
  const RelationalDatabaseAdapter({
    required this.queryRunner,
    required this.rowMapper,
    required this.tableName,
    this.keyColumn = 'slug',
    this.paramName = 'slug',
  });

  final SqlQueryRunner queryRunner;
  final SqlRowMapper<T> rowMapper;
  final String tableName;
  final String keyColumn;
  final String paramName;

  @override
  Future<DataProviderResult<T>> load(RouteDataContext context) async {
    if (!_isSafeIdentifier(tableName) || !_isSafeIdentifier(keyColumn)) {
      throw ArgumentError(
        'tableName and keyColumn must be simple SQL identifiers.',
      );
    }
    final key =
        context.parameters[paramName] ?? context.queryParameters[paramName];
    if (key == null || key.isEmpty) {
      return DataProviderResult<T>.notFound();
    }

    final sql = 'SELECT * FROM $tableName WHERE $keyColumn = ? LIMIT 1';
    final row = await queryRunner(sql, [key]);

    if (row == null) {
      return DataProviderResult<T>.notFound();
    }

    if (row['is_deleted'] == true || row['deleted_at'] != null) {
      return DataProviderResult<T>.gone(
        cacheTags: [tableName, '$tableName:$key'],
      );
    }

    final entity = rowMapper(row);
    DateTime? updatedAt;
    if (row['updated_at'] is DateTime) {
      updatedAt = row['updated_at'] as DateTime;
    } else if (row['updated_at'] is String) {
      updatedAt = DateTime.tryParse(row['updated_at'] as String);
    }

    final version = row['version']?.toString() ?? row['id']?.toString();
    final etag = version != null ? 'w/"$version"' : null;

    return DataProviderResult<T>.found(
      entity,
      lastModified: updatedAt,
      etag: etag,
      cacheTags: [tableName, '$tableName:$key'],
    );
  }

  bool _isSafeIdentifier(String value) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value);
}

/// Function signature for fetching a document by collection and ID.
typedef DocumentFetcher = Future<Map<String, dynamic>?> Function(
  String collection,
  String documentId,
);

/// Function signature for mapping document fields to entity [T].
typedef DocumentMapper<T> = T Function(String id, Map<String, dynamic> data);

/// Adapter demonstrating how Document Databases (Cloud Firestore, Supabase, MongoDB)
/// integrate with MetaMantle without introducing vendor SDK dependencies into core.
class DocumentDatabaseAdapter<T> implements MetaMantleDataProvider<T> {
  const DocumentDatabaseAdapter({
    required this.fetcher,
    required this.mapper,
    required this.collection,
    this.idParam = 'slug',
  });

  final DocumentFetcher fetcher;
  final DocumentMapper<T> mapper;
  final String collection;
  final String idParam;

  @override
  Future<DataProviderResult<T>> load(RouteDataContext context) async {
    final docId =
        context.parameters[idParam] ?? context.queryParameters[idParam];
    if (docId == null || docId.isEmpty) {
      return DataProviderResult<T>.notFound();
    }

    final snapshot = await fetcher(collection, docId);
    if (snapshot == null) {
      return DataProviderResult<T>.notFound();
    }

    if (snapshot['is_deleted'] == true) {
      return DataProviderResult<T>.gone(
        cacheTags: [collection, '$collection:$docId'],
      );
    }

    final entity = mapper(docId, snapshot);
    DateTime? updatedAt;
    if (snapshot['updated_at'] is DateTime) {
      updatedAt = snapshot['updated_at'] as DateTime;
    } else if (snapshot['updated_at'] is String) {
      updatedAt = DateTime.tryParse(snapshot['updated_at'] as String);
    }

    final etag = snapshot['version'] != null
        ? 'w/"${snapshot['version']}"'
        : null;

    return DataProviderResult<T>.found(
      entity,
      lastModified: updatedAt,
      etag: etag,
      cacheTags: [collection, '$collection:$docId'],
    );
  }
}
