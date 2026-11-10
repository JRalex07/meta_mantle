import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../cache/cache_store.dart';
import '../cache/memory_cache_store.dart';
import '../cache/single_flight.dart';
import '../html/html_document.dart';
import '../models/metadata.dart';
import '../providers/data_provider.dart';
import 'meta_route.dart';
import 'redirect_manager.dart';
import 'server_request.dart';
import 'server_response.dart';

/// Native request-time Server-Side Rendering (SSR) engine for MetaMantle.
class MetaMantleServerEngine {
  MetaMantleServerEngine({
    this.routes = const [],
    this.config = const MetaMantleConfig(),
    MetaMantleCacheStore? cacheStore,
    RedirectManager? redirectManager,
    SingleFlightCoordinator? singleFlight,
  })  : cache = cacheStore ?? MemoryCacheStore(),
        redirects = redirectManager ?? RedirectManager(),
        singleFlight = singleFlight ?? SingleFlightCoordinator();

  final List<MetaRoute<dynamic>> routes;
  final MetaMantleConfig config;
  final MetaMantleCacheStore cache;
  final RedirectManager redirects;
  final SingleFlightCoordinator singleFlight;

  /// Handles an incoming [ServerRequest] through the full SSR pipeline.
  Future<ServerResponse> handleRequest(ServerRequest request) async {
    // 1. Method verification: Only GET and HEAD are supported for SSR
    if (request.method != 'GET' && request.method != 'HEAD') {
      return ServerResponse(
        statusCode: 405,
        headers: {'Allow': 'GET, HEAD'},
        body: 'Method Not Allowed',
      );
    }

    // 2. Redirect Resolution
    final redirect = redirects.resolve(request.path);
    if (redirect != null) {
      return ServerResponse.redirect(
        redirect.targetPath,
        statusCode: redirect.statusCode,
      );
    }

    // 3. Route Matching
    final match = _findRoute(request.path);
    if (match == null) {
      return ServerResponse.notFound(
        message: 'No route matched path "${request.path}".',
      );
    }

    final route = match.route;
    final params = match.parameters;

    final context = RouteDataContext(
      path: request.path,
      parameters: params,
      queryParameters: request.queryParameters,
      headers: request.headers,
      locale: request.header('accept-language')?.split(',').first.trim() ??
          config.language,
    );

    // 4. Cache Key Calculation
    final cacheKey = _computeCacheKey(request, route);

    // 5. Cache Lookup
    if (route.cachePolicy.isCacheable) {
      final cached = await cache.get(cacheKey);
      if (cached != null) {
        // Check conditional GET
        if (_isNotModified(request, cached.etag, cached.lastModified)) {
          return ServerResponse.notModified(
            etag: cached.etag,
            cacheControl: _buildCacheControl(route.cachePolicy),
          );
        }

        // Stale-While-Revalidate background regeneration
        if (cached.isStaleWhileRevalidate()) {
          unawaited(_regenerate(route, context, cacheKey));
        }

        return _buildResponse(
          request,
          html: cached.html,
          etag: cached.etag,
          lastModified: cached.lastModified,
          policy: route.cachePolicy,
          cacheStatus: cached.isStaleWhileRevalidate() ? 'STALE' : 'HIT',
        );
      }
    }

    // 6. Cache Miss: Execute single-flight regeneration
    try {
      final rendered = await singleFlight.run(
        cacheKey,
        () => _renderRoute(route, context, cacheKey),
      );

      if (rendered.response != null) {
        return rendered.response!;
      }

      // Check conditional GET on fresh render
      if (_isNotModified(request, rendered.etag, rendered.lastModified)) {
        return ServerResponse.notModified(
          etag: rendered.etag,
          cacheControl: _buildCacheControl(route.cachePolicy),
        );
      }

      return _buildResponse(
        request,
        html: rendered.html!,
        etag: rendered.etag,
        lastModified: rendered.lastModified,
        policy: route.cachePolicy,
        cacheStatus: 'MISS',
      );
    } catch (e) {
      if (route.cachePolicy.staleIfError != null) {
        final stale = await cache.get(cacheKey, allowStale: true);
        if (stale != null && stale.isStaleIfError()) {
          return _buildResponse(
            request,
            html: stale.html,
            etag: stale.etag,
            lastModified: stale.lastModified,
            policy: route.cachePolicy,
            cacheStatus: 'STALE-IF-ERROR',
          );
        }
      }
      return ServerResponse.serverError(message: 'SSR Rendering failed: $e');
    }
  }

  Future<_RenderResult> _renderRoute(
    MetaRoute<dynamic> route,
    RouteDataContext context,
    String cacheKey,
  ) async {
    final result = await route.dataProvider.load(context);

    if (result.isDeleted) {
      return _RenderResult(
        response: ServerResponse.gone(
          message:
              'The requested resource at "${context.path}" has been permanently removed.',
        ),
      );
    }

    if (!result.isFound || result.data == null) {
      return _RenderResult(
        response: ServerResponse.notFound(
          message: 'Resource at "${context.path}" was not found.',
        ),
      );
    }

    final metadata = route.buildMetadata(result.data, context);
    final bodyNodes = route.buildHtml(result.data, context);

    final doc = HtmlDocument(
      metadata: metadata,
      config: config,
      bodyNodes: bodyNodes,
      includeFlutterBootstrap: route.includeFlutterBootstrap,
    );

    final html = doc.render(currentUrl: context.path);
    final etag = result.etag ?? _generateEtag(html);
    final lastModified = result.lastModified ?? DateTime.now().toUtc();

    if (route.cachePolicy.isCacheable) {
      final allTags = {
        ...route.cachePolicy.tags,
        ...result.cacheTags,
        context.path,
      };

      final entry = CacheEntry(
        html: html,
        metadata: metadata,
        createdAt: DateTime.now().toUtc(),
        ttl: route.cachePolicy.ttl,
        staleWhileRevalidate: route.cachePolicy.staleWhileRevalidate,
        staleIfError: route.cachePolicy.staleIfError,
        etag: etag,
        lastModified: lastModified,
        tags: allTags,
      );
      await cache.put(cacheKey, entry);
    }

    return _RenderResult(
      html: html,
      etag: etag,
      lastModified: lastModified,
    );
  }

  Future<void> _regenerate(
    MetaRoute<dynamic> route,
    RouteDataContext context,
    String cacheKey,
  ) async {
    try {
      await singleFlight.run(
        cacheKey,
        () => _renderRoute(route, context, cacheKey),
      );
    } catch (_) {
      // Background revalidation failure silently falls back to serving stale content
    }
  }

  _RouteMatch? _findRoute(String path) {
    for (final route in routes) {
      final params = route.match(path);
      if (params != null) {
        return _RouteMatch(route: route, parameters: params);
      }
    }
    return null;
  }

  bool _isNotModified(ServerRequest req, String? etag, DateTime? lastMod) {
    if (etag != null && req.ifNoneMatch != null) {
      final clientEtags = req.ifNoneMatch!.split(',').map((e) => e.trim());
      if (clientEtags.contains(etag) || clientEtags.contains('*')) {
        return true;
      }
    }

    if (lastMod != null && req.ifModifiedSince != null) {
      if (!lastMod.isAfter(req.ifModifiedSince!)) {
        return true;
      }
    }

    return false;
  }

  ServerResponse _buildResponse(
    ServerRequest request, {
    required String html,
    required String? etag,
    required DateTime? lastModified,
    required CachePolicy policy,
    String cacheStatus = 'MISS',
  }) {
    // If request was HEAD, body should be empty but headers intact
    final body = request.method == 'HEAD' ? '' : html;
    return ServerResponse.okHtml(
      body,
      etag: etag,
      lastModified: lastModified,
      cacheControl: _buildCacheControl(policy),
      headers: {
        'X-MetaMantle-Cache': cacheStatus,
      },
    );
  }

  String _buildCacheControl(CachePolicy policy) {
    if (!policy.isCacheable || policy.ttl == Duration.zero) {
      return 'no-cache, no-store, must-revalidate';
    }

    final buf = StringBuffer('public, max-age=${policy.ttl.inSeconds}');
    if (policy.staleWhileRevalidate != null) {
      buf.write(
          ', stale-while-revalidate=${policy.staleWhileRevalidate!.inSeconds}');
    }
    if (policy.staleIfError != null) {
      buf.write(', stale-if-error=${policy.staleIfError!.inSeconds}');
    }
    return buf.toString();
  }

  String _computeCacheKey(ServerRequest req, MetaRoute<dynamic> route) {
    final queryStr =
        req.queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&');
    final tenant = req.tenantId ?? '';
    final host = req.host ?? '';
    final locale = req.locale ?? '';
    final currency = req.currency ?? '';
    final prefix = (tenant.isNotEmpty ||
            host.isNotEmpty ||
            locale.isNotEmpty ||
            currency.isNotEmpty)
        ? '[$tenant|$host|$locale|$currency]:'
        : '';
    return '$prefix${route.pattern}:${req.path}?$queryStr';
  }

  String _generateEtag(String content) {
    final digest = sha256.convert(utf8.encode(content));
    return 'w/"${digest.toString().substring(0, 32)}"';
  }
}

class _RouteMatch {
  _RouteMatch({required this.route, required this.parameters});
  final MetaRoute<dynamic> route;
  final Map<String, String> parameters;
}

class _RenderResult {
  _RenderResult({this.html, this.etag, this.lastModified, this.response});
  final String? html;
  final String? etag;
  final DateTime? lastModified;
  final ServerResponse? response;
}
