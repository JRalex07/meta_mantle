import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'data_provider.dart';

/// Function to map a parsed JSON response map to entity [T].
typedef JsonEntityMapper<T> = T Function(dynamic json);

/// Adapter for fetching dynamic SEO data from external RESTful API endpoints.
class RestDataProvider<T> implements MetaMantleDataProvider<T> {
  RestDataProvider({
    required this.urlBuilder,
    required this.mapper,
    http.Client? client,
    this.headers = const {},
    this.timeout = const Duration(seconds: 10),
    this.maxResponseSizeBytes = 5 * 1024 * 1024, // 5MB limit
    this.maxRetries = 2,
    this.entityTag = 'rest_api',
  }) : client = client ?? http.Client();

  final String Function(RouteDataContext context) urlBuilder;
  final JsonEntityMapper<T> mapper;
  final http.Client client;
  final Map<String, String> headers;
  final Duration timeout;
  final int maxResponseSizeBytes;
  final int maxRetries;
  final String entityTag;

  @override
  Future<DataProviderResult<T>> load(RouteDataContext context) async {
    final targetUrl = urlBuilder(context);
    final uri = Uri.parse(targetUrl);

    http.Response? response;
    Exception? lastException;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final request = http.Request('GET', uri)
          ..headers.addAll({
            'Accept': 'application/json',
            'User-Agent': 'MetaMantle-SSR/0.1.0',
            ...headers,
          });

        final streamed = await client.send(request).timeout(timeout);
        response = await http.Response.fromStream(streamed).timeout(timeout);

        if (response.statusCode >= 500 && attempt < maxRetries) {
          // Idempotent GET retry on server error
          await Future<void>.delayed(
              Duration(milliseconds: 100 * (attempt + 1)));
          continue;
        }
        break;
      } on Exception catch (e) {
        lastException = e;
        if (attempt >= maxRetries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
    }

    if (response == null) {
      throw lastException ?? StateError('Failed to communicate with REST API.');
    }

    if (response.statusCode == 404) {
      return DataProviderResult<T>.notFound(cacheTags: [entityTag]);
    }

    if (response.statusCode == 410) {
      return DataProviderResult<T>.gone(cacheTags: [entityTag]);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'REST API returned unexpected status code: ${response.statusCode}',
        uri,
      );
    }

    if (response.bodyBytes.length > maxResponseSizeBytes) {
      throw StateError(
        'REST response exceeded maximum allowed size of $maxResponseSizeBytes bytes.',
      );
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    final entity = mapper(decoded);

    DateTime? lastModified;
    final lastModHeader =
        response.headers['last-modified'] ?? response.headers['Last-Modified'];
    if (lastModHeader != null) {
      try {
        lastModified = DateTime.tryParse(lastModHeader);
      } catch (_) {}
    }

    final etag = response.headers['etag'] ??
        response.headers['ETag'] ??
        response.headers['Etag'];

    return DataProviderResult<T>.found(
      entity,
      lastModified: lastModified,
      etag: etag,
      cacheTags: [entityTag, '$entityTag:${context.path}'],
    );
  }
}

/// Adapter for querying GraphQL APIs for MetaMantle dynamic SEO.
class GraphQLDataProvider<T> implements MetaMantleDataProvider<T> {
  GraphQLDataProvider({
    required this.endpoint,
    required this.queryBuilder,
    required this.mapper,
    http.Client? client,
    this.headers = const {},
    this.timeout = const Duration(seconds: 10),
    this.maxResponseSizeBytes = 5 * 1024 * 1024,
    this.entityTag = 'graphql_api',
  }) : client = client ?? http.Client();

  final Uri endpoint;
  final String Function(RouteDataContext context) queryBuilder;
  final JsonEntityMapper<T> mapper;
  final http.Client client;
  final Map<String, String> headers;
  final Duration timeout;
  final int maxResponseSizeBytes;
  final String entityTag;

  @override
  Future<DataProviderResult<T>> load(RouteDataContext context) async {
    final query = queryBuilder(context);
    final payload = json.encode({
      'query': query,
      'variables': context.parameters,
    });

    final response = await client
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'MetaMantle-SSR/0.1.0',
            ...headers,
          },
          body: payload,
        )
        .timeout(timeout);

    if (response.bodyBytes.length > maxResponseSizeBytes) {
      throw StateError(
        'GraphQL response exceeded maximum allowed size of $maxResponseSizeBytes bytes.',
      );
    }

    if (response.statusCode != 200) {
      throw http.ClientException(
        'GraphQL endpoint returned status ${response.statusCode}',
        endpoint,
      );
    }

    final decoded =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (decoded.containsKey('errors') && decoded['errors'] != null) {
      final errors = decoded['errors'] as List;
      if (errors.isNotEmpty) {
        throw StateError(
            'GraphQL query returned errors: ${errors.first['message']}');
      }
    }

    final data = decoded['data'];
    if (data == null) {
      return DataProviderResult<T>.notFound(cacheTags: [entityTag]);
    }

    final entity = mapper(data);
    return DataProviderResult<T>.found(
      entity,
      cacheTags: [entityTag, '$entityTag:${context.path}'],
    );
  }
}
