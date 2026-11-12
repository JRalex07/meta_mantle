import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../security/ssrf_guard.dart';
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
    this.ssrfGuard = const SsrfGuard(),
  }) : client =
           client ?? ssrfGuard.createPinnedClient(connectionTimeout: timeout);

  final String Function(RouteDataContext context) urlBuilder;
  final JsonEntityMapper<T> mapper;
  final http.Client client;
  final Map<String, String> headers;
  final Duration timeout;
  final int maxResponseSizeBytes;
  final int maxRetries;
  final String entityTag;
  final SsrfGuard ssrfGuard;
  static const int maxRedirects = 5;

  @override
  Future<DataProviderResult<T>> load(RouteDataContext context) async {
    final targetUrl = urlBuilder(context);
    final uri = Uri.parse(targetUrl);

    // 1. Validate URI against SSRF boundaries before any network request
    await ssrfGuard.validateUri(uri);

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

        final streamed = await _sendFollowingValidatedRedirects(request);

        // Check Content-Length header early
        if (streamed.contentLength != null &&
            streamed.contentLength! > maxResponseSizeBytes) {
          throw StateError(
            'REST API response Content-Length (${streamed.contentLength}) exceeded maximum allowed size of $maxResponseSizeBytes bytes.',
          );
        }

        // Stream accumulation with immediate abort on size limit breach
        final byteBuilder = BytesBuilder(copy: false);
        await for (final chunk in streamed.stream.timeout(timeout)) {
          byteBuilder.add(chunk);
          if (byteBuilder.length > maxResponseSizeBytes) {
            throw StateError(
              'REST API response stream exceeded maximum allowed size of $maxResponseSizeBytes bytes.',
            );
          }
        }

        final bodyBytes = byteBuilder.takeBytes();
        response = http.Response.bytes(
          bodyBytes,
          streamed.statusCode,
          headers: streamed.headers,
          request: streamed.request,
          isRedirect: streamed.isRedirect,
          persistentConnection: streamed.persistentConnection,
          reasonPhrase: streamed.reasonPhrase,
        );

        if (response.statusCode >= 500 && attempt < maxRetries) {
          // Idempotent GET retry on server error
          await Future<void>.delayed(
            Duration(milliseconds: 100 * (attempt + 1)),
          );
          continue;
        }
        break;
      } on SecurityException {
        rethrow;
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

    final etag =
        response.headers['etag'] ??
        response.headers['ETag'] ??
        response.headers['Etag'];

    return DataProviderResult<T>.found(
      entity,
      lastModified: lastModified,
      etag: etag,
      cacheTags: [entityTag, '$entityTag:${context.path}'],
    );
  }

  bool _isRedirect(int statusCode) =>
      statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;

  Future<http.StreamedResponse> _sendFollowingValidatedRedirects(
    http.Request initialRequest,
  ) async {
    var currentUri = initialRequest.url;
    final requestHeaders = Map<String, String>.of(initialRequest.headers);
    for (var redirects = 0; ; redirects++) {
      final request = http.Request('GET', currentUri)
        ..headers.addAll(requestHeaders)
        ..followRedirects = false
        ..maxRedirects = 0;
      final response = await client.send(request).timeout(timeout);
      final location = response.headers['location'];
      if (!_isRedirect(response.statusCode) || location == null) {
        return response;
      }
      if (redirects >= maxRedirects) {
        await response.stream.drain<void>();
        throw StateError(
          'REST API exceeded maximum of $maxRedirects redirects.',
        );
      }
      final nextUri = currentUri.resolve(location);
      await ssrfGuard.validateUri(nextUri);
      await response.stream.drain<void>();
      if (!_sameOrigin(currentUri, nextUri)) {
        // Keep only headers that are normally safe to share with an unrelated
        // origin. This also removes application-specific API key headers.
        requestHeaders.removeWhere(
          (key, _) =>
              !const {'accept', 'user-agent'}.contains(key.toLowerCase()),
        );
      }
      currentUri = nextUri;
    }
  }

  bool _sameOrigin(Uri a, Uri b) =>
      a.scheme.toLowerCase() == b.scheme.toLowerCase() &&
      a.host.toLowerCase() == b.host.toLowerCase() &&
      a.port == b.port;
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
    this.ssrfGuard = const SsrfGuard(),
  }) : client =
           client ?? ssrfGuard.createPinnedClient(connectionTimeout: timeout);

  final Uri endpoint;
  final String Function(RouteDataContext context) queryBuilder;
  final JsonEntityMapper<T> mapper;
  final http.Client client;
  final Map<String, String> headers;
  final Duration timeout;
  final int maxResponseSizeBytes;
  final String entityTag;
  final SsrfGuard ssrfGuard;

  @override
  Future<DataProviderResult<T>> load(RouteDataContext context) async {
    // 1. Validate GraphQL endpoint against SSRF boundaries
    await ssrfGuard.validateUri(endpoint);

    final query = queryBuilder(context);
    final payload = json.encode({
      'query': query,
      'variables': context.parameters,
    });

    final request = http.Request('POST', endpoint)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'MetaMantle-SSR/0.1.0',
        ...headers,
      })
      ..followRedirects = false
      ..maxRedirects = 0
      ..body = payload;

    final streamed = await client.send(request).timeout(timeout);

    if (streamed.contentLength != null &&
        streamed.contentLength! > maxResponseSizeBytes) {
      throw StateError(
        'GraphQL response Content-Length (${streamed.contentLength}) exceeded maximum allowed size of $maxResponseSizeBytes bytes.',
      );
    }

    final byteBuilder = BytesBuilder(copy: false);
    await for (final chunk in streamed.stream.timeout(timeout)) {
      byteBuilder.add(chunk);
      if (byteBuilder.length > maxResponseSizeBytes) {
        throw StateError(
          'GraphQL response stream exceeded maximum allowed size of $maxResponseSizeBytes bytes.',
        );
      }
    }

    final bodyBytes = byteBuilder.takeBytes();
    final response = http.Response.bytes(
      bodyBytes,
      streamed.statusCode,
      headers: streamed.headers,
      request: streamed.request,
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
    );

    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw http.ClientException(
        'GraphQL endpoint redirects are not followed.',
        endpoint,
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
          'GraphQL query returned errors: ${errors.first['message']}',
        );
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
