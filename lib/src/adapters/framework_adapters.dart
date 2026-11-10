import 'dart:async';
import 'package:shelf/shelf.dart' as shelf;

import '../core/head_tag.dart';
import '../core/metadata_renderer.dart';
import '../models/metadata.dart';
import '../server/server_engine.dart';
import '../server/server_request.dart';
import '../server/server_response.dart';
import 'shelf_adapter.dart';

/// Dart Frog adapter for MetaMantle SSR.
///
/// Since Dart Frog is built on top of Shelf handlers and middleware, this adapter
/// bridges Dart Frog's request handling to MetaMantle.
class MetaMantleDartFrogAdapter {
  const MetaMantleDartFrogAdapter(this.engine);

  final MetaMantleServerEngine engine;

  /// Handles an incoming request in a Dart Frog route handler or middleware.
  Future<shelf.Response> handle(shelf.Request request) async {
    final adapter = MetaMantleShelfAdapter(engine);
    final handler = adapter.createHandler();
    return await handler(request);
  }
}

/// Serverpod adapter for MetaMantle SSR.
///
/// Provides request translation between Serverpod's HTTP request endpoints
/// and MetaMantle without violating Serverpod's authentication boundaries.
class MetaMantleServerpodAdapter {
  const MetaMantleServerpodAdapter(this.engine);

  final MetaMantleServerEngine engine;

  /// Translates raw request attributes into a MetaMantle [ServerRequest] and executes SSR.
  Future<ServerResponse> handleEndpointRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    List<int>? bodyBytes,
    String? clientIp,
  }) async {
    final request = ServerRequest(
      method: method,
      uri: uri,
      headers: headers,
      clientIp: clientIp,
      bodyBytes: bodyBytes,
    );
    return await engine.handleRequest(request);
  }
}

/// Jaspr interoperability adapter.
///
/// Generates Jaspr-compatible head tag definitions from MetaMantle's [WebMetadata]
/// and [MetadataRenderer], enabling shared metadata definitions between Flutter Web
/// and Jaspr SSR components.
class MetaMantleJasprAdapter {
  const MetaMantleJasprAdapter({
    this.config = const MetaMantleConfig(),
    this.renderer = const MetadataRenderer(),
  });

  final MetaMantleConfig config;
  final MetadataRenderer renderer;

  /// Converts MetaMantle [metadata] into a list of [HeadTag] descriptors suitable
  /// for rendering into Jaspr component trees.
  List<HeadTag> toHeadTags(WebMetadata metadata, {String? currentUrl}) {
    return renderer.render(metadata, config: config, currentUrl: currentUrl);
  }
}
