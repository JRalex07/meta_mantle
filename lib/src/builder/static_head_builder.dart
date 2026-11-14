import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../core/head_tag.dart';
import '../core/metadata_renderer.dart';
import '../models/metadata.dart';
import 'static_head_config.dart';

/// Result summary of static generation.
class StaticBuildResult {
  const StaticBuildResult({
    required this.generatedFiles,
    required this.routes,
    required this.warnings,
  });

  final List<File> generatedFiles;
  final List<String> routes;
  final List<String> warnings;
}

/// Creates route-specific HTML entry documents from an existing Flutter build.
///
/// This does not render Flutter widgets into HTML. It writes metadata into the
/// initial HTML response while preserving Flutter's generated bootstrap code.
class StaticHeadBuilder {
  const StaticHeadBuilder();

  /// Validates route configuration and expands JSON-backed route patterns
  /// without writing any files. Returns non-fatal metadata warnings.
  Future<List<String>> validateConfiguration({
    required StaticHeadConfig config,
    File? configFile,
  }) async {
    _absoluteRouteUrl(config.baseUrl, '/');
    final routes = <StaticRoute>[...config.routes];
    for (final pattern in config.patterns) {
      routes.addAll(await _expandPattern(pattern, configFile));
    }
    if (routes.isEmpty) {
      throw const FormatException('No static routes were configured.');
    }

    final seen = <String>{};
    final warnings = <String>[];
    final renderer = const MetadataRenderer();
    for (final route in routes) {
      final path = _normalizeRoute(route.path);
      if (!seen.add(path)) {
        throw FormatException('Duplicate route detected: $path');
      }
      final canonical =
          route.metadata.canonical ?? _absoluteRouteUrl(config.baseUrl, path);
      final merged = _mergeMetadata(config.defaults, route.metadata, canonical);
      renderer.render(
        merged,
        config: MetaMantleConfig(
          baseUrl: config.baseUrl,
          siteName: config.siteName,
          titleTemplate: config.titleTemplate,
          defaultImage: config.defaultImage,
          defaultRobots: config.defaultRobots,
          themeColor: config.themeColor,
          language: config.language,
          trailingSlash: config.trailingSlash,
        ),
      );
      if (merged.title == null || merged.title!.trim().isEmpty) {
        warnings.add('$path has no title.');
      }
      if (merged.description == null || merged.description!.trim().isEmpty) {
        warnings.add('$path has no description.');
      }
    }
    return List.unmodifiable(warnings);
  }

  /// Inspects all resolved routes and metadata without writing files.
  Future<
    ({
      List<String> routes,
      List<String> warnings,
      List<String> sitemapUrls,
      int dynamicPatternCount,
    })
  >
  inspectConfiguration({
    required StaticHeadConfig config,
    File? configFile,
  }) async {
    final routes = <StaticRoute>[...config.routes];
    for (final pattern in config.patterns) {
      routes.addAll(await _expandPattern(pattern, configFile));
    }

    final seen = <String>[];
    final warnings = <String>[];
    final sitemapUrls = <String>[];

    for (final route in routes) {
      final path = _normalizeRoute(route.path);
      seen.add(path);
      final canonical =
          route.metadata.canonical ?? _absoluteRouteUrl(config.baseUrl, path);
      final merged = _mergeMetadata(config.defaults, route.metadata, canonical);
      if (merged.title == null || merged.title!.trim().isEmpty) {
        warnings.add('$path has no title.');
      }
      if (merged.description == null || merged.description!.trim().isEmpty) {
        warnings.add('$path has no description.');
      }
      if (!_isNoindex(merged.robots ?? config.defaultRobots)) {
        final canonicalUrl = _canonicalForSitemap(
          merged.canonical,
          config.baseUrl,
          path,
        );
        if (canonicalUrl != null) sitemapUrls.add(canonicalUrl);
      }
    }

    return (
      routes: List<String>.unmodifiable(seen),
      warnings: List<String>.unmodifiable(warnings),
      sitemapUrls: List<String>.unmodifiable(
        sitemapUrls.toSet().toList()..sort(),
      ),
      dynamicPatternCount: config.patterns.length,
    );
  }

  /// Runs environmental diagnostics on the project setup.
  Future<List<String>> doctor({
    required File configFile,
    required Directory inputDirectory,
  }) async {
    final report = <String>[];

    if (!await configFile.exists()) {
      report.add('FAIL: Config file not found at ${configFile.path}');
      return report;
    }
    report.add('PASS: Config file exists at ${configFile.path}');

    StaticHeadConfig config;
    try {
      config = await StaticHeadConfig.load(configFile);
      report.add(
        'PASS: Config parsed successfully (baseUrl: ${config.baseUrl})',
      );
    } catch (e) {
      report.add('FAIL: Config parsing failed: $e');
      return report;
    }

    for (final pattern in config.patterns) {
      final baseDir = configFile.parent;
      final dataFile = File(
        '${baseDir.path}${Platform.pathSeparator}${pattern.dataFile}',
      );
      if (!await dataFile.exists()) {
        report.add(
          'FAIL: Data file for pattern ${pattern.pathPattern} not found: ${dataFile.path}',
        );
      } else {
        report.add('PASS: Data file exists: ${pattern.dataFile}');
      }
    }

    final inputIndex = File(
      '${inputDirectory.path}${Platform.pathSeparator}index.html',
    );
    if (!await inputIndex.exists()) {
      report.add(
        'FAIL: Flutter build index.html not found at ${inputIndex.path}. Did you run "flutter build web --release"?',
      );
      return report;
    }
    report.add('PASS: Flutter build index.html found');

    final sourceHtml = await inputIndex.readAsString();
    if (sourceHtml.contains('flutter_bootstrap.js') ||
        sourceHtml.contains('{{flutter_bootstrap_js}}') ||
        sourceHtml.contains('{{flutter_js}}') ||
        sourceHtml.contains('{{flutter_build_config}}') ||
        sourceHtml.contains('_flutter.loader.load') ||
        sourceHtml.contains('main.dart.js')) {
      report.add('PASS: Flutter bootstrap initialization script detected');
    } else {
      report.add(
        'WARN: Recognizable Flutter bootstrap marker not found in index.html',
      );
    }

    return report;
  }

  /// Generates static HTML documents, sitemap, and robots.txt.
  Future<StaticBuildResult> build({
    required Directory inputDirectory,
    required Directory outputDirectory,
    required StaticHeadConfig config,
    File? configFile,
    bool strict = false,
    bool dryRun = false,
    bool verbose = false,
    void Function(String message)? onProgress,
  }) async {
    final inputIndex = File(
      '${inputDirectory.path}${Platform.pathSeparator}index.html',
    );
    if (!await inputIndex.exists()) {
      throw FileSystemException(
        'Flutter build index.html not found',
        inputIndex.path,
      );
    }
    final sourceHtml = await inputIndex.readAsString();
    if (!sourceHtml.toLowerCase().contains('<html')) {
      throw const FormatException(
        'index.html does not look like a complete HTML document.',
      );
    }
    final templateProbe = html_parser.parse(sourceHtml);
    if (templateProbe.querySelector('head') == null) {
      throw const FormatException('index.html has no <head> element.');
    }
    if (!sourceHtml.contains('flutter_bootstrap.js') &&
        !sourceHtml.contains('{{flutter_bootstrap_js}}') &&
        !sourceHtml.contains('{{flutter_js}}') &&
        !sourceHtml.contains('{{flutter_build_config}}') &&
        !sourceHtml.contains('_flutter.loader.load') &&
        !sourceHtml.contains('main.dart.js')) {
      throw const FormatException(
        'Flutter bootstrap marker was not detected. Refusing to generate output.',
      );
    }

    final inputPath = inputDirectory.absolute.path
        .replaceAll('/', Platform.pathSeparator)
        .toLowerCase();
    final outputPath = outputDirectory.absolute.path
        .replaceAll('/', Platform.pathSeparator)
        .toLowerCase();
    final inputPrefix = inputPath.endsWith(Platform.pathSeparator)
        ? inputPath
        : '$inputPath${Platform.pathSeparator}';
    final outputPrefix = outputPath.endsWith(Platform.pathSeparator)
        ? outputPath
        : '$outputPath${Platform.pathSeparator}';
    if (inputPath != outputPath &&
        (outputPath.startsWith(inputPrefix) ||
            inputPath.startsWith(outputPrefix))) {
      throw const FormatException(
        'Input and output directories cannot contain one another. Use the same directory or separate sibling directories.',
      );
    }

    final expandedRoutes = <StaticRoute>[...config.routes];
    for (final pattern in config.patterns) {
      expandedRoutes.addAll(await _expandPattern(pattern, configFile));
    }
    if (expandedRoutes.isEmpty) {
      throw const FormatException('No static routes were configured.');
    }

    final seen = <String>{};
    final warnings = <String>[];
    final generated = <File>[];
    final sitemapUrls = <String>[];
    final prepared = <({String path, WebMetadata metadata})>[];
    final renderer = const MetadataRenderer();

    // Preflight every route before touching the output directory. Strict mode
    // therefore cannot leave a half-generated deployment after a metadata error.
    for (final route in expandedRoutes) {
      final path = _normalizeRoute(route.path);
      if (!seen.add(path)) {
        throw FormatException('Duplicate route detected: $path');
      }
      final canonical =
          route.metadata.canonical ?? _absoluteRouteUrl(config.baseUrl, path);
      final merged = _mergeMetadata(config.defaults, route.metadata, canonical);
      // Render during preflight so invalid URLs and malformed values fail early.
      renderer.render(
        merged,
        config: MetaMantleConfig(
          baseUrl: config.baseUrl,
          siteName: config.siteName,
          titleTemplate: config.titleTemplate,
          defaultImage: config.defaultImage,
          defaultRobots: config.defaultRobots,
          themeColor: config.themeColor,
          language: config.language,
          trailingSlash: config.trailingSlash,
        ),
      );
      if (merged.title == null || merged.title!.trim().isEmpty) {
        warnings.add('$path has no title.');
      }
      if (merged.description == null || merged.description!.trim().isEmpty) {
        warnings.add('$path has no description.');
      }
      if (!_isNoindex(merged.robots ?? config.defaultRobots)) {
        final canonicalUrl = _canonicalForSitemap(
          merged.canonical,
          config.baseUrl,
          path,
        );
        if (canonicalUrl != null) sitemapUrls.add(canonicalUrl);
      }
      prepared.add((path: path, metadata: merged));
    }

    if (strict && warnings.isNotEmpty) {
      throw FormatException(
        'Strict mode failed before writing output:\n${warnings.join('\n')}',
      );
    }

    if (!dryRun && inputPath != outputPath) {
      onProgress?.call(
        'Copying build assets from $inputPath to $outputPath...',
      );
      await _copyDirectory(inputDirectory, outputDirectory);
    }

    for (final route in prepared) {
      final tags = renderer.render(
        route.metadata,
        config: MetaMantleConfig(
          baseUrl: config.baseUrl,
          siteName: config.siteName,
          titleTemplate: config.titleTemplate,
          defaultImage: config.defaultImage,
          defaultRobots: config.defaultRobots,
          themeColor: config.themeColor,
          language: config.language,
          trailingSlash: config.trailingSlash,
        ),
      );
      final document = html_parser.parse(sourceHtml);
      final head = document.querySelector('head')!;
      _inject(head, document, tags);

      final target = _routeOutputFile(outputDirectory, route.path);
      if (!dryRun) {
        await target.parent.create(recursive: true);
        await target.writeAsString(document.outerHtml, flush: true);
      }
      generated.add(target);
      if (verbose) {
        onProgress?.call('Generated: ${route.path} -> ${target.path}');
      }
    }

    if (config.sitemap) {
      final sitemap = File(
        '${outputDirectory.path}${Platform.pathSeparator}sitemap.xml',
      );
      if (!dryRun) {
        await sitemap.parent.create(recursive: true);
        final uniqueSitemapUrls = sitemapUrls.toSet().toList()..sort();
        await sitemap.writeAsString(_sitemap(uniqueSitemapUrls), flush: true);
      }
      generated.add(sitemap);
      if (verbose) {
        onProgress?.call(
          'Generated sitemap.xml with ${sitemapUrls.length} entries',
        );
      }
    }

    if (config.robotsTxt) {
      final robots = File(
        '${outputDirectory.path}${Platform.pathSeparator}robots.txt',
      );
      if (!dryRun) {
        await robots.parent.create(recursive: true);
        await robots.writeAsString(_robotsTxt(config), flush: true);
      }
      generated.add(robots);
      if (verbose) {
        onProgress?.call('Generated robots.txt');
      }
    }

    return StaticBuildResult(
      generatedFiles: List.unmodifiable(generated),
      routes: List.unmodifiable(seen),
      warnings: List.unmodifiable(warnings),
    );
  }

  Future<List<StaticRoute>> _expandPattern(
    StaticRoutePattern pattern,
    File? configFile,
  ) async {
    if (configFile == null) {
      throw const FormatException(
        'A config file path is required when route patterns use dataFile.',
      );
    }
    final baseDir = configFile.parent;
    final dataFilePath =
        '${baseDir.path}${Platform.pathSeparator}${pattern.dataFile}';
    final dataFile = File(dataFilePath);

    // Prevent directory traversal escape
    final resolvedDataPath = dataFile.absolute.path
        .replaceAll('/', Platform.pathSeparator)
        .toLowerCase();
    final allowedBasePrefix = baseDir.absolute.path
        .replaceAll('/', Platform.pathSeparator)
        .toLowerCase();
    final allowedPrefix = allowedBasePrefix.endsWith(Platform.pathSeparator)
        ? allowedBasePrefix
        : '$allowedBasePrefix${Platform.pathSeparator}';
    if (!resolvedDataPath.startsWith(allowedPrefix) &&
        resolvedDataPath != allowedBasePrefix) {
      throw FormatException(
        'Data file path escapes the configuration directory: ${pattern.dataFile}',
      );
    }

    if (!await dataFile.exists()) {
      throw FileSystemException(
        'Data file not found for pattern ${pattern.pathPattern}',
        dataFile.path,
      );
    }

    final content = await dataFile.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw FormatException(
        'Data file ${pattern.dataFile} must contain a JSON array of objects.',
      );
    }

    final routes = <StaticRoute>[];
    for (var i = 0; i < decoded.length; i++) {
      final entry = decoded[i];
      if (entry is! Map) {
        throw FormatException(
          'Row $i in ${pattern.dataFile} is not a JSON object.',
        );
      }
      final row = Map<String, Object?>.from(entry);
      final slug = row[pattern.slugField]?.toString();
      if (slug == null ||
          slug.trim().isEmpty ||
          slug.contains('/') ||
          slug.contains('\\') ||
          slug == '.' ||
          slug == '..') {
        throw FormatException(
          'Row $i has an invalid slug "${pattern.slugField}": $slug',
        );
      }
      final routePath = pattern.pathPattern.replaceAll(
        ':${pattern.slugField}',
        slug,
      );
      final resolvedMetadataJson = _interpolateTemplate(
        pattern.metadataTemplate ?? const {},
        row,
      );
      routes.add(
        StaticRoute(
          path: routePath,
          metadata: WebMetadata.fromJson(resolvedMetadataJson),
        ),
      );
    }
    return routes;
  }

  Map<String, Object?> _interpolateTemplate(
    Map<String, Object?> template,
    Map<String, Object?> row,
  ) {
    final result = <String, Object?>{};
    for (final entry in template.entries) {
      result[entry.key] = _interpolateValue(entry.value, row);
    }
    return result;
  }

  Object? _interpolateValue(Object? value, Map<String, Object?> row) {
    if (value is String) {
      return value.replaceAllMapped(RegExp(r'\{\{\s*([\w.-]+)\s*\}\}'), (
        match,
      ) {
        final parts = match.group(1)!.split('.');
        Object? current = row;
        for (final part in parts) {
          if (current is Map) {
            current = current[part];
          } else {
            return '';
          }
        }
        return current?.toString() ?? '';
      });
    }
    if (value is List) {
      return value.map((item) => _interpolateValue(item, row)).toList();
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _interpolateValue(nestedValue, row)),
      );
    }
    return value;
  }

  WebMetadata _mergeMetadata(
    WebMetadata defaults,
    WebMetadata page,
    String canonicalUrl,
  ) {
    return WebMetadata(
      title: page.title ?? defaults.title,
      description: page.description ?? defaults.description,
      canonical: page.canonical ?? canonicalUrl,
      robots: page.robots ?? defaults.robots,
      keywords: page.keywords ?? defaults.keywords,
      author: page.author ?? defaults.author,
      publisher: page.publisher ?? defaults.publisher,
      applicationName: page.applicationName ?? defaults.applicationName,
      referrerPolicy: page.referrerPolicy ?? defaults.referrerPolicy,
      themeColor: page.themeColor ?? defaults.themeColor,
      colorScheme: page.colorScheme ?? defaults.colorScheme,
      language: page.language ?? defaults.language,
      openGraph: page.openGraph ?? defaults.openGraph,
      twitter: page.twitter ?? defaults.twitter,
      jsonLd: [...defaults.jsonLd, ...page.jsonLd],
      alternates: [...defaults.alternates, ...page.alternates],
      icons: [...defaults.icons, ...page.icons],
      resourceHints: [...defaults.resourceHints, ...page.resourceHints],
      customMeta: [...defaults.customMeta, ...page.customMeta],
      customLinks: [...defaults.customLinks, ...page.customLinks],
      googleSiteVerification:
          page.googleSiteVerification ?? defaults.googleSiteVerification,
      bingSiteVerification:
          page.bingSiteVerification ?? defaults.bingSiteVerification,
      yandexVerification:
          page.yandexVerification ?? defaults.yandexVerification,
      baiduVerification: page.baiduVerification ?? defaults.baiduVerification,
      applyTitleTemplate: page.applyTitleTemplate,
      trailingSlash: page.trailingSlash ?? defaults.trailingSlash,
    );
  }

  bool _isNoindex(String? robots) {
    if (robots == null) return false;
    final normalized = robots.toLowerCase();
    return normalized.contains('noindex') || normalized.contains('none');
  }

  String? _canonicalForSitemap(
    String? canonical,
    String baseUrl,
    String routePath,
  ) {
    final candidate = canonical ?? _absoluteRouteUrl(baseUrl, routePath);
    final baseUri = Uri.parse(baseUrl);
    final resolved = Uri.tryParse(candidate);
    if (resolved == null ||
        !resolved.hasScheme ||
        resolved.scheme != baseUri.scheme ||
        resolved.host != baseUri.host ||
        resolved.hasQuery ||
        resolved.hasFragment) {
      return null;
    }
    return resolved.toString();
  }

  String _normalizeRoute(String route) {
    if (!route.startsWith('/')) {
      throw FormatException('Route paths must start with "/": $route');
    }
    final rawParts = route.split('/');
    if (rawParts.any((part) => part == '..' || part == '.')) {
      throw FormatException('Route traversal is not allowed: $route');
    }
    final uri = Uri.tryParse(route);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw FormatException(
        'Route must be a local path without query/fragment: $route',
      );
    }
    if (uri.pathSegments.any(
          (segment) =>
              segment == '..' ||
              segment == '.' ||
              segment.contains('/') ||
              segment.contains('\\'),
        ) ||
        uri.path.contains('\\')) {
      throw FormatException('Route traversal is not allowed: $route');
    }
    if (route == '/') return '/';
    final segments = uri.pathSegments
        .where((part) => part.isNotEmpty)
        .map(Uri.encodeComponent);
    return '/${segments.join('/')}/';
  }

  String _absoluteRouteUrl(String baseUrl, String path) {
    final base = Uri.parse(baseUrl);
    if ((base.scheme != 'https' && base.scheme != 'http') ||
        !base.hasAuthority ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw FormatException(
        'baseUrl must be an HTTP(S) origin or base path without credentials, query or fragment: $baseUrl',
      );
    }
    final normalizedBase = base.toString().endsWith('/')
        ? base
        : Uri.parse('${base.toString()}/');
    final routeUri = Uri.parse(path.startsWith('/') ? path.substring(1) : path);
    return normalizedBase.resolveUri(routeUri).toString();
  }

  File _routeOutputFile(Directory output, String route) {
    if (route == '/') {
      return File('${output.path}${Platform.pathSeparator}index.html');
    }
    final segments = Uri.parse(route).pathSegments
        .where((part) => part.isNotEmpty);
    return File(
      '${output.path}${Platform.pathSeparator}${segments.join(Platform.pathSeparator)}${Platform.pathSeparator}index.html',
    );
  }

  void _inject(dom.Element head, dom.Document document, List<HeadTag> tags) {
    final desiredKeys = tags.map((tag) => tag.key).toSet();
    for (final existing in head.querySelectorAll(
      '[data-mm-owner="meta_mantle"], [data-fwh-owner="flutter_web_head"]',
    )) {
      final key =
          existing.attributes['data-mm-key'] ??
          existing.attributes['data-fwh-key'];
      if (!desiredKeys.contains(key)) {
        existing.remove();
      }
    }
    for (final tag in tags) {
      if (tag.tagName == 'html') {
        final lang = tag.attributes['lang'];
        if (lang != null) document.documentElement?.attributes['lang'] = lang;
        continue;
      }

      final element =
          _findExisting(head, tag) ?? document.createElement(tag.tagName);
      final wasOwned =
          element.attributes['data-mm-owner'] == 'meta_mantle' ||
          element.attributes['data-fwh-owner'] == 'flutter_web_head';
      if (wasOwned) {
        element.attributes.clear();
      } else {
        final managedAttributes = switch (tag.tagName) {
          'meta' => const {
            'name',
            'property',
            'http-equiv',
            'content',
            'charset',
          },
          'link' => const {
            'rel',
            'href',
            'hreflang',
            'type',
            'sizes',
            'media',
            'as',
            'crossorigin',
            'referrerpolicy',
            'integrity',
          },
          'script' => const {'type'},
          _ => const <String>{},
        };
        for (final name in managedAttributes) {
          if (!tag.attributes.containsKey(name)) {
            element.attributes.remove(name);
          }
        }
      }
      tag.attributes.forEach((key, value) => element.attributes[key] = value);
      if (tag.tagName != 'title') {
        element.attributes['data-mm-owner'] = 'meta_mantle';
        element.attributes['data-mm-key'] = tag.key;
      }
      if (tag.tagName == 'title' || tag.tagName == 'script') {
        element.text = tag.textContent ?? '';
      }
      if (element.parent == null) head.append(element);
    }
  }

  dom.Element? _findExisting(dom.Element head, HeadTag tag) {
    for (final candidate in head.querySelectorAll(
      '[data-mm-owner="meta_mantle"], [data-fwh-owner="flutter_web_head"]',
    )) {
      final key =
          candidate.attributes['data-mm-key'] ??
          candidate.attributes['data-fwh-key'];
      if (key == tag.key) return candidate;
    }
    if (tag.tagName == 'title') return head.querySelector('title');
    if (tag.tagName == 'meta') {
      final identity = tag.attributes['name'] != null
          ? 'name'
          : tag.attributes['property'] != null
          ? 'property'
          : tag.attributes['http-equiv'] != null
          ? 'http-equiv'
          : null;
      if (identity == null) return null;
      final value = tag.attributes[identity];
      for (final element in head.querySelectorAll('meta')) {
        if (element.attributes['data-mm-owner'] == 'meta_mantle' ||
            element.attributes['data-fwh-owner'] == 'flutter_web_head') {
          continue;
        }
        if (element.attributes[identity] == value) return element;
      }
    }
    if (tag.tagName == 'link') {
      final rel = tag.attributes['rel'];
      final hreflang = tag.attributes['hreflang'];
      for (final element in head.querySelectorAll('link')) {
        if (element.attributes['data-mm-owner'] == 'meta_mantle' ||
            element.attributes['data-fwh-owner'] == 'flutter_web_head') {
          continue;
        }
        if (element.attributes['rel'] != rel) continue;
        if (rel == 'canonical') return element;
        if (rel == 'alternate') {
          if (hreflang != null && element.attributes['hreflang'] == hreflang) {
            return element;
          }
          continue;
        }
        if (rel == 'icon' || rel == 'apple-touch-icon' || rel == 'mask-icon') {
          if (element.attributes['sizes'] == tag.attributes['sizes'] &&
              element.attributes['type'] == tag.attributes['type'] &&
              element.attributes['href'] == tag.attributes['href']) {
            return element;
          }
          continue;
        }
        if (element.attributes['href'] == tag.attributes['href']) {
          return element;
        }
      }
    }
    return null;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(
      recursive: false,
      followLinks: false,
    )) {
      final name = entity.path
          .split(RegExp(r'[\\/]'))
          .where((part) => part.isNotEmpty)
          .last;
      final targetPath = '${destination.path}${Platform.pathSeparator}$name';
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      } else if (entity is Link) {
        // Symlinks are deliberately skipped: copying their targets can escape
        // the build directory and produce non-reproducible output.
      }
    }
  }

  String _sitemap(List<String> urls) {
    final entries = urls
        .map((url) => '  <url><loc>${_xmlEscape(url)}</loc></url>')
        .join('\n');
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        '$entries\n</urlset>\n';
  }

  String _robotsTxt(StaticHeadConfig config) {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final buffer = StringBuffer();
    buffer.writeln('User-agent: *');
    if (config.defaultRobots?.toLowerCase().contains('noindex') == true) {
      buffer.writeln('Disallow: /');
    } else {
      buffer.writeln('Allow: /');
    }
    if (config.sitemap) {
      buffer.writeln('Sitemap: $base/sitemap.xml');
    }
    return buffer.toString();
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
