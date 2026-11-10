import 'dart:convert';
import 'dart:io';

import '../models/metadata.dart';

/// Configuration for the static route HTML generator.
class StaticHeadConfig {
  const StaticHeadConfig({
    required this.baseUrl,
    this.routes = const [],
    this.defaults = const WebMetadata(),
    this.siteName,
    this.titleTemplate,
    this.defaultImage,
    this.defaultRobots = 'index, follow',
    this.themeColor,
    this.language = 'en',
    this.trailingSlash,
    this.patterns = const [],
    this.sitemap = true,
    this.robotsTxt = true,
  });

  final String baseUrl;
  final List<StaticRoute> routes;
  final WebMetadata defaults;
  final String? siteName;
  final String? titleTemplate;
  final String? defaultImage;
  final String? defaultRobots;
  final String? themeColor;
  final String? language;
  final bool? trailingSlash;
  final List<StaticRoutePattern> patterns;
  final bool sitemap;
  final bool robotsTxt;

  factory StaticHeadConfig.fromJson(Map<String, Object?> json) {
    final rawRoutes = json['routes'] ?? const <Object?>[];
    if (rawRoutes is! List) {
      throw const FormatException('Config field "routes" must be an array.');
    }
    final routes = <StaticRoute>[];
    for (final value in rawRoutes) {
      if (value is! Map) {
        throw const FormatException('Every route entry must be a JSON object.');
      }
      routes.add(StaticRoute.fromJson(Map<String, Object?>.from(value)));
    }

    final rawPatterns = json['patterns'] ?? const <Object?>[];
    if (rawPatterns is! List) {
      throw const FormatException('Config field "patterns" must be an array.');
    }
    final patterns = <StaticRoutePattern>[];
    for (final value in rawPatterns) {
      if (value is! Map) {
        throw const FormatException(
            'Every route pattern must be a JSON object.');
      }
      patterns
          .add(StaticRoutePattern.fromJson(Map<String, Object?>.from(value)));
    }

    final defaultsJson = json['defaults'];
    if (defaultsJson != null && defaultsJson is! Map) {
      throw const FormatException(
          'Config field "defaults" must be a JSON object.');
    }
    final baseUrl = json['baseUrl'];
    if (baseUrl is! String || baseUrl.trim().isEmpty) {
      throw const FormatException(
          'Config field "baseUrl" must be a non-empty string.');
    }

    return StaticHeadConfig(
      baseUrl: baseUrl,
      routes: List.unmodifiable(routes),
      defaults: defaultsJson is Map
          ? WebMetadata.fromJson(Map<String, Object?>.from(defaultsJson))
          : const WebMetadata(),
      siteName: json['siteName'] as String?,
      titleTemplate: json['titleTemplate'] as String?,
      defaultImage: json['defaultImage'] as String?,
      defaultRobots: json['defaultRobots'] as String? ?? 'index, follow',
      themeColor: json['themeColor'] as String?,
      language: json['language'] as String? ?? 'en',
      trailingSlash: json['trailingSlash'] as bool?,
      patterns: List.unmodifiable(patterns),
      sitemap: json['sitemap'] as bool? ?? true,
      robotsTxt: json['robotsTxt'] as bool? ?? true,
    );
  }

  static Future<StaticHeadConfig> load(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Config root must be a JSON object.');
    }
    return StaticHeadConfig.fromJson(Map<String, Object?>.from(decoded));
  }
}

/// Static route path and its associated metadata.
class StaticRoute {
  const StaticRoute({required this.path, required this.metadata});
  final String path;
  final WebMetadata metadata;

  factory StaticRoute.fromJson(Map<String, Object?> json) {
    final metadata = json['metadata'];
    if (metadata is! Map) {
      throw FormatException('Route ${json['path']} is missing metadata.');
    }
    return StaticRoute(
      path: json['path'] as String,
      metadata: WebMetadata.fromJson(Map<String, Object?>.from(metadata)),
    );
  }
}

/// Expands one JSON data file into multiple route metadata records.
///
/// String values in [metadataTemplate] may contain `{{fieldName}}` tokens.
class StaticRoutePattern {
  const StaticRoutePattern({
    required this.pathPattern,
    required this.dataFile,
    required this.metadataTemplate,
    this.slugField = 'slug',
  });

  final String pathPattern;
  final String dataFile;
  final String slugField;
  final Map<String, Object?> metadataTemplate;

  factory StaticRoutePattern.fromJson(Map<String, Object?> json) {
    final template = json['metadataTemplate'];
    if (template is! Map) {
      throw FormatException(
          'Pattern ${json['pathPattern']} needs metadataTemplate.');
    }
    return StaticRoutePattern(
      pathPattern: json['pathPattern'] as String,
      dataFile: json['dataFile'] as String,
      slugField: json['slugField'] as String? ?? 'slug',
      metadataTemplate: Map<String, Object?>.from(template),
    );
  }
}
