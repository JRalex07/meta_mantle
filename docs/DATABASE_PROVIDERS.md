# Universal Database Abstraction Layer

MetaMantle decouples data loading from server and rendering frameworks through the `MetaMantleDataProvider<T>` interface (`lib/src/providers/`).

---

## 1. The Provider Contract

Every data provider implements `MetaMantleDataProvider<T>`:

```dart
abstract class MetaMantleDataProvider<T> {
  Future<DataProviderResult<T>> load(RouteDataContext context);
}
```

### Context & Parameters
`RouteDataContext` supplies:
- `path`: The requested URL path (e.g., `/products/basmati-rice`).
- `parameters`: Route path variables (e.g., `{'slug': 'basmati-rice'}`).
- `queryParameters`: URL query string map (e.g., `{'sort': 'price'}`).
- `headers`: HTTP request headers for multi-tenant or locale detection.
- `timestamp`: The request timestamp.

### Return Values (`DataProviderResult<T>`)
- `DataProviderResult<T>.found(data, {lastModified, etag, cacheTags})`:
  Resource was resolved successfully.
- `DataProviderResult<T>.notFound({cacheTags})`:
  Resource does not exist (HTTP 404).
- `DataProviderResult<T>.gone({cacheTags})`:
  Resource was permanently removed or discontinued (HTTP 410 Gone).

---

## 2. Relational Database Adapter (`RelationalDatabaseAdapter<T>`)

Designed for SQL databases (PostgreSQL, MySQL, SQLite, Supabase):

```dart
final productProvider = RelationalDatabaseAdapter<Product>(
  tableName: 'products',
  keyColumn: 'slug',
  paramName: 'slug',
  queryRunner: (sql, params) async {
    // Invoke your connection pool (e.g. package:postgres)
    final result = await connection.query(sql, substitutionValues: params);
    return result.isEmpty ? null : result.first.toColumnMap();
  },
  rowMapper: (row) => Product.fromMap(row),
);
```

### Automatic Features:
- Parameterized SQL execution preventing SQL injection.
- Automatic ETag extraction from version or ID columns.
- Soft-delete detection: Returns `410 Gone` if `is_deleted == true` or `deleted_at != null`.
- Cache tagging using `$tableName` and `$tableName:$key`.

---

## 3. Document Database Adapter (`DocumentDatabaseAdapter<T>`)

Designed for NoSQL and Document stores (Firestore, MongoDB, CouchDB):

```dart
final articleProvider = DocumentDatabaseAdapter<Article>(
  collection: 'articles',
  idParam: 'slug',
  fetcher: (col, docId) async {
    final snapshot = await firestore.collection(col).doc(docId).get();
    return snapshot.exists ? snapshot.data() : null;
  },
  mapper: (docId, data) => Article.fromMap(docId, data),
);
```

---

## 4. In-Memory Data Provider (`MemoryDataProvider<T>`)

High-speed in-memory store for unit tests, development, microservices, or local caches:

```dart
final mem = MemoryDataProvider<Product>(lookupParam: 'slug');

mem.set(
  'basmati-rice',
  const Product(name: 'Basmati Rice', price: 24.99),
  lastModified: DateTime.utc(2026, 1, 1),
  etag: 'w/"v1"',
);

// Soft delete
mem.markGone('discontinued-product');
```

