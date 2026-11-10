import 'dart:async';
import 'package:shelf/shelf.dart' as shelf;

import '../server/server_engine.dart';
import '../server/server_request.dart';
import '../server/server_response.dart';

/// Shelf adapter for MetaMantle Server-Side Rendering.
class MetaMantleShelfAdapter {
  const MetaMantleShelfAdapter(this.engine);

  final MetaMantleServerEngine engine;

  /// Creates a Shelf [Handler] serving SSR pages through [engine].
  shelf.Handler createHandler() {
    return (shelf.Request request) async {
      final serverRequest = await _toServerRequest(request);
      final serverResponse = await engine.handleRequest(serverRequest);
      return _toShelfResponse(serverResponse);
    };
  }

  /// Creates a Shelf [Middleware] that serves SSR routes when matched,
  /// and passes unmatched requests to the downstream handler.
  shelf.Middleware createMiddleware({bool passThroughNotFound = true}) {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        if (request.method != 'GET' && request.method != 'HEAD') {
          return innerHandler(request);
        }

        final serverRequest = await _toServerRequest(request);
        final serverResponse = await engine.handleRequest(serverRequest);

        if (passThroughNotFound && serverResponse.statusCode == 404) {
          return innerHandler(request);
        }

        return _toShelfResponse(serverResponse);
      };
    };
  }

  Future<ServerRequest> _toServerRequest(shelf.Request req) async {
    final bodyBytes = await req.read().expand((chunk) => chunk).toList();
    final fullUri = req.requestedUri;

    return ServerRequest(
      method: req.method,
      uri: fullUri,
      headers: req.headers,
      clientIp: req.headers['x-forwarded-for']?.split(',').first.trim(),
      bodyBytes: bodyBytes,
    );
  }

  shelf.Response _toShelfResponse(ServerResponse res) {
    return shelf.Response(
      res.statusCode,
      body: res.bodyBytes,
      headers: res.headers,
    );
  }
}

/// Convenience helper to create a Shelf handler from [engine].
shelf.Handler metaMantleShelfHandler(MetaMantleServerEngine engine) =>
    MetaMantleShelfAdapter(engine).createHandler();

/// Convenience helper to create Shelf middleware from [engine].
shelf.Middleware metaMantleShelfMiddleware(
  MetaMantleServerEngine engine, {
  bool passThroughNotFound = true,
}) =>
    MetaMantleShelfAdapter(engine).createMiddleware(
      passThroughNotFound: passThroughNotFound,
    );
