import 'dart:convert';
import 'dart:io';

import '../models/metadata.dart';
import '../static/routes/static_page_route.dart';

export '../static/routes/static_page_route.dart'
    show StaticRoute, StaticPageRoute, StaticRoutePattern;

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
    this.manifest,
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
  final String? manifest;

  StaticHeadConfig copyWith({
    String? baseUrl,
    List<StaticRoute>? routes,
    WebMetadata? defaults,
    String? siteName,
    String? titleTemplate,
    String? defaultImage,
    String? defaultRobots,
    String? themeColor,
    String? language,
    bool? trailingSlash,
    List<StaticRoutePattern>? patterns,
    bool? sitemap,
    bool? robotsTxt,
    String? manifest,
  }) {
    return StaticHeadConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      routes: routes ?? this.routes,
      defaults: defaults ?? this.defaults,
      siteName: siteName ?? this.siteName,
      titleTemplate: titleTemplate ?? this.titleTemplate,
      defaultImage: defaultImage ?? this.defaultImage,
      defaultRobots: defaultRobots ?? this.defaultRobots,
      themeColor: themeColor ?? this.themeColor,
      language: language ?? this.language,
      trailingSlash: trailingSlash ?? this.trailingSlash,
      patterns: patterns ?? this.patterns,
      sitemap: sitemap ?? this.sitemap,
      robotsTxt: robotsTxt ?? this.robotsTxt,
      manifest: manifest ?? this.manifest,
    );
  }

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
          'Every route pattern must be a JSON object.',
        );
      }
      patterns.add(
        StaticRoutePattern.fromJson(Map<String, Object?>.from(value)),
      );
    }

    final defaultsJson = json['defaults'];
    if (defaultsJson != null && defaultsJson is! Map) {
      throw const FormatException(
        'Config field "defaults" must be a JSON object.',
      );
    }
    final baseUrl = json['baseUrl'];
    if (baseUrl is! String || baseUrl.trim().isEmpty) {
      throw const FormatException(
        'Config field "baseUrl" must be a non-empty string.',
      );
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
      manifest: json['manifest'] as String?,
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
