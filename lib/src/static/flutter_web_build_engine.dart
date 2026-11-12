import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;

import '../builder/static_head_config.dart';
import '../core/metadata_renderer.dart';
import '../models/metadata.dart';
import '../universal/rendering/server_renderer.dart';
import '../universal/routing/mantle_route.dart';
import 'bootstrap/bootstrap_adapter.dart';
import 'models/build_web_options.dart';
import 'routes/static_page_route.dart';

/// Production-grade Flutter Web Build Engine.
///
/// Orchestrates Flutter Web compilation, semantic HTML generation from
/// MantleComponent trees, SEO metadata injection, sitemap/robots generation,
/// and Flutter bootstrap coordination.
class FlutterWebBuildEngine {
  const FlutterWebBuildEngine({
    this.bootstrapAdapter = const BootstrapAdapter(),
    this.metadataRenderer = const MetadataRenderer(),
    this.serverRenderer =
        const MantleServerRenderer(emitHydrationMarkers: false),
    this.processRunner,
  });

  final BootstrapAdapter bootstrapAdapter;
  final MetadataRenderer metadataRenderer;
  final MantleServerRenderer serverRenderer;

  /// Optional process execution hook for testing without launching external CLI processes.
  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  })? processRunner;

  /// Executes the complete Flutter Web build and static rendering pipeline.
  Future<FlutterWebBuildResult> build(
    BuildWebOptions options, {
    StaticRouteManifest? routeManifest,
    void Function(String message)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final projectDir = Directory(options.projectDir);
    final outputDir = Directory(
      options.output.startsWith('/') || options.output.contains(':')
          ? options.output
          : '${projectDir.path}${Platform.pathSeparator}${options.output}',
    );

    onProgress?.call(
        'MetaMantle Web Build Engine starting [Mode: ${options.mode.name.toUpperCase()}]...');

    // 1. Discover and validate Flutter project
    final pubspecFile =
        File('${projectDir.path}${Platform.pathSeparator}pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw FileSystemException(
        'Not a valid Dart/Flutter project directory. Missing pubspec.yaml.',
        pubspecFile.path,
      );
    }

    final webDir = Directory('${projectDir.path}${Platform.pathSeparator}web');
    final webIndex = File('${webDir.path}${Platform.pathSeparator}index.html');
    if (!await webIndex.exists()) {
      throw FileSystemException(
        'Missing web/index.html template in Flutter project.',
        webIndex.path,
      );
    }

    // 2. Resolve configuration & routes
    final configFile = File(
      options.configPath.startsWith('/') || options.configPath.contains(':')
          ? options.configPath
          : '${projectDir.path}${Platform.pathSeparator}${options.configPath}',
    );

    StaticHeadConfig? parsedConfig;
    if (await configFile.exists()) {
      parsedConfig = await StaticHeadConfig.load(configFile);
      onProgress?.call('Loaded configuration from ${configFile.path}');
    } else {
      parsedConfig = StaticHeadConfig(
        baseUrl: 'https://example.com',
        routes: const [
          StaticRoute(path: '/', metadata: WebMetadata(title: 'Home')),
        ],
      );
      onProgress?.call(
          'Config file not found; proceeding with defaults and manifest routes.');
    }

    final resolvedRoutes = await _resolveAllRoutes(
      config: parsedConfig,
      configFile: await configFile.exists() ? configFile : null,
      manifest: routeManifest,
    );

    if (resolvedRoutes.isEmpty) {
      throw const FormatException(
          'No routes resolved for static web generation.');
    }
    onProgress
        ?.call('Resolved ${resolvedRoutes.length} route(s) for generation.');

    // 3. Compile Flutter Web project (unless dry-run)
    if (!options.dryRun) {
      if (options.clean) {
        onProgress?.call('Running flutter clean...');
        await _executeProcess('flutter', ['clean'],
            workingDirectory: projectDir.path);
      }

      onProgress?.call('Compiling Flutter Web production build...');
      final buildArgs = <String>['build', 'web'];
      if (options.release && !options.debug) {
        buildArgs.add('--release');
      } else if (options.debug) {
        buildArgs.add('--debug');
      }

      if (options.baseHref.isNotEmpty && options.baseHref != '/') {
        buildArgs.add('--base-href=${options.baseHref}');
      }
      if (options.wasm) {
        buildArgs.add('--wasm');
      }

      final buildResult = await _executeProcess(
        'flutter',
        buildArgs,
        workingDirectory: projectDir.path,
      );

      if (buildResult.exitCode != 0) {
        throw ProcessException(
          'flutter',
          buildArgs,
          'Flutter web build failed with exit code ${buildResult.exitCode}:\n${buildResult.stderr}',
          buildResult.exitCode,
        );
      }
      onProgress?.call('Flutter Web build succeeded.');
    } else {
      onProgress?.call('[DRY RUN] Skipping flutter build execution.');
    }

    // 4. Locate output template index.html
    final templateIndexFile = File(
      '${outputDir.path}${Platform.pathSeparator}index.html',
    );

    String baseTemplateHtml;
    if (await templateIndexFile.exists()) {
      baseTemplateHtml = await templateIndexFile.readAsString();
    } else if (await webIndex.exists()) {
      baseTemplateHtml = await webIndex.readAsString();
    } else {
      throw FileSystemException(
        'Unable to find compiled index.html or source web/index.html.',
        templateIndexFile.path,
      );
    }

    // 5. Generate route-specific HTML documents
    final generatedFiles = <String>[];
    final warnings = <String>[];
    final sitemapUrls = <String>[];

    final baseUrl = parsedConfig.baseUrl;

    for (final route in resolvedRoutes) {
      final normPath = _normalizeRoute(route.path);
      final canonicalUrl = route.metadata.canonical ??
          _buildAbsoluteUrl(baseUrl, normPath, parsedConfig.trailingSlash);

      if (!_isNoindex(route.metadata.robots ?? parsedConfig.defaultRobots)) {
        sitemapUrls.add(canonicalUrl);
      }

      if (route.metadata.title == null ||
          route.metadata.title!.trim().isEmpty) {
        warnings.add('Route $normPath has no title.');
      }

      // Generate HTML
      final docHtml = _renderRouteDocument(
        templateHtml: baseTemplateHtml,
        route: route,
        config: parsedConfig,
        canonicalUrl: canonicalUrl,
        mode: options.mode,
      );

      final outputFile = _determineOutputFile(outputDir, normPath);
      if (!options.dryRun) {
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsString(docHtml, flush: true);
      }
      generatedFiles.add(outputFile.path);
      if (options.verbose) {
        onProgress?.call('Generated: $normPath -> ${outputFile.path}');
      }
    }

    // 6. Generate sitemap.xml & robots.txt
    if (parsedConfig.sitemap) {
      final sitemapFile =
          File('${outputDir.path}${Platform.pathSeparator}sitemap.xml');
      final sortedUrls = sitemapUrls.toSet().toList()..sort();
      final sitemapXml = _generateSitemapXml(sortedUrls);

      if (!options.dryRun) {
        await sitemapFile.parent.create(recursive: true);
        await sitemapFile.writeAsString(sitemapXml, flush: true);
      }
      generatedFiles.add(sitemapFile.path);
      onProgress
          ?.call('Generated sitemap.xml with ${sortedUrls.length} entries.');
    }

    if (parsedConfig.robotsTxt) {
      final robotsFile =
          File('${outputDir.path}${Platform.pathSeparator}robots.txt');
      final sitemapUrl = baseUrl.endsWith('/')
          ? '${baseUrl}sitemap.xml'
          : '$baseUrl/sitemap.xml';
      final robotsContent = 'User-agent: *\nAllow: /\n\nSitemap: $sitemapUrl\n';

      if (!options.dryRun) {
        await robotsFile.parent.create(recursive: true);
        await robotsFile.writeAsString(robotsContent, flush: true);
      }
      generatedFiles.add(robotsFile.path);
      onProgress?.call('Generated robots.txt.');
    }

    stopwatch.stop();

    // 7. Write build report
    final reportFile = File(
      '${outputDir.path}${Platform.pathSeparator}meta_mantle_report.json',
    );

    final buildResult = FlutterWebBuildResult(
      success: true,
      mode: options.mode,
      routes: resolvedRoutes.map((r) => r.path).toList(),
      generatedFiles: generatedFiles,
      warnings: warnings,
      durationMs: stopwatch.elapsedMilliseconds,
      reportPath: reportFile.path,
    );

    if (!options.dryRun) {
      await reportFile.parent.create(recursive: true);
      await reportFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(buildResult.toJson()),
        flush: true,
      );
    }

    onProgress?.call(
        'Build complete in ${stopwatch.elapsedMilliseconds}ms. ${generatedFiles.length} files generated.');

    if (options.strict && warnings.isNotEmpty) {
      throw FormatException(
          'Strict mode failed due to metadata warnings:\n${warnings.join('\n')}');
    }

    return buildResult;
  }

  /// Resolves routes from JSON config, dynamic patterns, and manifest.
  Future<List<StaticPageRoute>> _resolveAllRoutes({
    required StaticHeadConfig config,
    File? configFile,
    StaticRouteManifest? manifest,
  }) async {
    final list = <StaticPageRoute>[];
    final seen = <String>{};

    // 1. Static routes from config
    for (final r in config.routes) {
      final norm = _normalizeRoute(r.path);
      if (seen.add(norm)) {
        list.add(StaticPageRoute(path: norm, metadata: r.metadata));
      }
    }

    // 2. Dynamic patterns from config
    for (final pattern in config.patterns) {
      final expanded = await _expandPattern(pattern, configFile);
      for (final r in expanded) {
        final norm = _normalizeRoute(r.path);
        if (seen.add(norm)) {
          list.add(r);
        }
      }
    }

    // 3. Programmatic manifest routes
    if (manifest != null) {
      for (final r in manifest.routes) {
        final norm = _normalizeRoute(r.path);
        if (seen.add(norm)) {
          list.add(r);
        } else {
          // If already in seen, replace or merge
          final index = list.indexWhere((existing) => existing.path == norm);
          if (index != -1) {
            list[index] = r;
          }
        }
      }
    }

    return list;
  }

  Future<List<StaticPageRoute>> _expandPattern(
    StaticRoutePattern pattern,
    File? configFile,
  ) async {
    final results = <StaticPageRoute>[];
    final baseDir = configFile?.parent.path ?? '.';
    final dataFile = File(
      pattern.dataFile.startsWith('/') || pattern.dataFile.contains(':')
          ? pattern.dataFile
          : '$baseDir${Platform.pathSeparator}${pattern.dataFile}',
    );

    if (!await dataFile.exists()) {
      return results;
    }

    final rawJson = json.decode(await dataFile.readAsString());
    if (rawJson is! List) return results;

    for (final item in rawJson) {
      if (item is! Map) continue;
      final map = Map<String, Object?>.from(item);
      final slug = map[pattern.slugField]?.toString();
      if (slug == null || slug.isEmpty) continue;

      final path = pattern.pathPattern.replaceAll(
        RegExp(r':[^/]+'),
        Uri.encodeComponent(slug),
      );

      final metadata = _substituteTemplate(pattern.metadataTemplate, map);
      results.add(StaticPageRoute(
        path: path,
        metadata: metadata,
        dataSource: map,
      ));
    }
    return results;
  }

  WebMetadata _substituteTemplate(
    Map<String, Object?> template,
    Map<String, Object?> data,
  ) {
    String sub(String input) {
      var res = input;
      for (final entry in data.entries) {
        res = res.replaceAll('{{${entry.key}}}', entry.value?.toString() ?? '');
      }
      return res;
    }

    Object? deepSub(Object? val) {
      if (val is String) return sub(val);
      if (val is Map) {
        return {
          for (final e in val.entries) e.key.toString(): deepSub(e.value)
        };
      }
      if (val is List) return val.map(deepSub).toList();
      return val;
    }

    final substituted = deepSub(template) as Map<String, Object?>;
    return WebMetadata.fromJson(substituted);
  }

  /// Synthesizes the complete HTML document for [route].
  String _renderRouteDocument({
    required String templateHtml,
    required StaticPageRoute route,
    required StaticHeadConfig config,
    required String canonicalUrl,
    required BuildMode mode,
  }) {
    final mergedMetadata = route.metadata.copyWith(
      canonical: route.metadata.canonical ?? canonicalUrl,
    );

    final tags = metadataRenderer.render(
      mergedMetadata,
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

    final document = html_parser.parse(templateHtml);
    final head = document.querySelector('head');
    final body = document.querySelector('body');

    if (head != null) {
      // 1. Inject Head Tags
      for (final tag in tags) {
        if (tag.tagName == 'title') {
          final existing = head.querySelector('title');
          if (existing != null) {
            existing.text = tag.textContent ?? '';
          } else {
            final t = document.createElement('title')
              ..text = tag.textContent ?? '';
            head.append(t);
          }
          continue;
        }

        final el = document.createElement(tag.tagName);
        for (final attr in tag.attributes.entries) {
          el.attributes[attr.key] = attr.value;
        }
        if (tag.textContent != null) {
          el.text = tag.textContent!;
        }
        head.append(el);
      }

      // 2. In Mode B & C, inject prerender CSS styles
      if (mode != BuildMode.metadata) {
        final styleEl = html_parser
            .parseFragment(bootstrapAdapter.generatePrerenderStyles());
        head.append(styleEl);
      }
    }

    // 3. Inject Semantic Body Content (Modes B & C)
    if (body != null && mode != BuildMode.metadata) {
      String semanticHtml = '';

      final navContext = MantleNavigationContext(currentPath: route.path);
      final component = route.resolveComponent(navContext);

      if (component != null) {
        final mantleNode = component.toNode(navContext);
        final htmlNode = serverRenderer.render(mantleNode);
        semanticHtml = htmlNode.toHtml();
      } else if (route.htmlContent != null && route.htmlContent!.isNotEmpty) {
        semanticHtml = route.htmlContent!;
      } else {
        // Fallback semantic representation from metadata
        semanticHtml = _generateFallbackSemanticHtml(route);
      }

      final wrappedContent = bootstrapAdapter.wrapPrerenderContent(
        semanticHtml,
        mode: mode,
      );

      final contentFragment = html_parser.parseFragment(wrappedContent);
      body.children.insert(0, contentFragment.children.first);

      // In Mode C (Hybrid), inject startup coordination script
      if (mode == BuildMode.hybrid) {
        final bridgeFragment = html_parser
            .parseFragment(bootstrapAdapter.generateClientHandshakeScript());
        body.append(bridgeFragment);
      }
    }

    return document.outerHtml;
  }

  String _generateFallbackSemanticHtml(StaticPageRoute route) {
    final title = route.metadata.title ?? 'Page';
    final desc = route.metadata.description ?? '';
    final buffer = StringBuffer();
    buffer.writeln('<section class="mantle-page-fallback">');
    buffer.writeln('  <h1>${_escape(title)}</h1>');
    if (desc.isNotEmpty) {
      buffer.writeln('  <p>${_escape(desc)}</p>');
    }
    buffer.writeln('</section>');
    return buffer.toString();
  }

  File _determineOutputFile(Directory outputDir, String routePath) {
    final clean = routePath.replaceAll(RegExp(r'^/|/$'), '');
    if (clean.isEmpty) {
      return File('${outputDir.path}${Platform.pathSeparator}index.html');
    }
    // Prevent directory traversal
    if (clean.contains('..')) {
      throw FormatException('Illegal route path containing "..": $routePath');
    }
    final relativePath = clean.replaceAll('/', Platform.pathSeparator);
    return File(
      '${outputDir.path}${Platform.pathSeparator}$relativePath${Platform.pathSeparator}index.html',
    );
  }

  String _generateSitemapXml(List<String> urls) {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    for (final u in urls) {
      buf.writeln('  <url>');
      buf.writeln('    <loc>${_escape(u)}</loc>');
      buf.writeln('  </url>');
    }
    buf.writeln('</urlset>');
    return buf.toString();
  }

  Future<ProcessResult> _executeProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    if (processRunner != null) {
      return processRunner!(executable, arguments,
          workingDirectory: workingDirectory);
    }
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );
  }

  String _normalizeRoute(String path) {
    if (!path.startsWith('/')) path = '/$path';
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  String _buildAbsoluteUrl(String base, String path, bool? trailingSlash) {
    final cleanBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    var norm = path;
    if (trailingSlash == true && !norm.endsWith('/') && norm != '/') {
      norm = '$norm/';
    }
    return '$cleanBase$norm';
  }

  bool _isNoindex(String? robots) {
    if (robots == null) return false;
    return robots.toLowerCase().contains('noindex');
  }

  String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
