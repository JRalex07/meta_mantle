# REST & GraphQL Data Providers

MetaMantle provides first-class HTTP client data providers for connecting SSR applications to external microservices, headless CMSs, and GraphQL endpoints (`lib/src/providers/rest_graphql_data_provider.dart`).

---

## 1. REST Data Provider (`RestDataProvider<T>`)

Connects an SSR route to any HTTP RESTful endpoint:

```dart
final productApiProvider = RestDataProvider<Product>(
  urlBuilder: (context) {
    final slug = context.parameters['slug'];
    return Uri.parse('https://api.store.internal/v1/products/$slug');
  },
  mapper: (json) => Product.fromJson(json),
  entityTag: 'products',
  timeout: const Duration(seconds: 5),
  maxRetries: 2,
  headers: {
    'Authorization': 'Bearer YOUR_INTERNAL_SECRET',
  },
);
```

### Production Resiliency:
- **Idempotent Retry**: Retries HTTP 500/502/503/504 errors up to `maxRetries` with exponential backoff.
- **Circuit Safety**: Enforces `maxResponseSizeBytes` (default 5MB) preventing runaway memory allocation.
- **HTTP Semantics**:
  - `404 Not Found` maps to `DataProviderResult.notFound()`.
  - `410 Gone` maps to `DataProviderResult.gone()`.
  - Case-insensitive `ETag` and `Last-Modified` header extraction.

---

## 2. GraphQL Data Provider (`GraphQLDataProvider<T>`)

Executes strongly typed GraphQL queries against headless CMSs (Contentful, Strapi, Shopify, Hygraph):

```dart
final blogPostProvider = GraphQLDataProvider<BlogPost>(
  endpoint: Uri.parse('https://api.cms.example/graphql'),
  query: '''
    query GetPost(\$slug: String!) {
      postBySlug(slug: \$slug) {
        id
        title
        summary
        content
        publishedAt
      }
    }
  ''',
  variablesBuilder: (context) => {
    'slug': context.parameters['slug'],
  },
  mapper: (data) => BlogPost.fromJson(data['postBySlug']),
  entityTag: 'blog',
  headers: {
    'X-Api-Key': 'YOUR_API_KEY',
  },
);
```

### Error Handling:
- Automatically validates the GraphQL `errors` array. If errors exist, throws descriptive exceptions for logging.
- When `data` or the target entity is `null`, yields `DataProviderResult.notFound()`.

