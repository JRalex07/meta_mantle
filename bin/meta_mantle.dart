import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('build')
    ..addCommand('build-web')
    ..addCommand('validate')
    ..addCommand('inspect')
    ..addCommand('doctor')
    ..addCommand('inspect-url')
    ..addCommand('crawl')
    ..addCommand('preview')
    ..addCommand('report')
    ..addCommand('regression')
    ..addCommand('web')
    ..addFlag('help', abbr: 'h', negatable: false);

  parser.commands['build-web']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('mode',
        defaultsTo: 'prerender',
        allowed: ['metadata', 'prerender', 'hybrid'],
        help: 'Build mode: metadata, prerender, or hybrid.')
    ..addFlag('release', defaultsTo: true, help: 'Compile in release mode.')
    ..addFlag('debug', defaultsTo: false, help: 'Compile in debug mode.')
    ..addOption('output',
        defaultsTo: 'build/web',
        help: 'Output directory for generated static assets.')
    ..addOption('base-href',
        defaultsTo: '/', help: 'Base href for Flutter routing.')
    ..addFlag('wasm',
        defaultsTo: false, help: 'Compile with WebAssembly (WasmGC).')
    ..addFlag('verbose',
        abbr: 'v', defaultsTo: false, help: 'Enable detailed logging.')
    ..addFlag('dry-run',
        defaultsTo: false,
        help: 'Simulate generation without writing files or compiling.')
    ..addFlag('clean',
        defaultsTo: false, help: 'Run flutter clean before building.')
    ..addFlag('strict',
        defaultsTo: false,
        help: 'Fail build if any metadata or route warnings occur.')
    ..addOption('config',
        defaultsTo: 'meta_mantle.config.json',
        help: 'Path to MetaMantle JSON configuration file.');

  parser.commands['build']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addOption('input', defaultsTo: 'build/web')
    ..addOption('output', defaultsTo: 'build/web')
    ..addFlag('strict', defaultsTo: false)
    ..addFlag('dry-run', defaultsTo: false)
    ..addFlag('verbose', abbr: 'v', defaultsTo: false)
    ..addFlag('no-sitemap', negatable: false)
    ..addFlag('no-robots', negatable: false);

  parser.commands['validate']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json');

  parser.commands['inspect']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json');

  parser.commands['doctor']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addOption('input', defaultsTo: 'build/web');

  parser.commands['inspect-url']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('url',
        mandatory: true,
        help: 'Target URL to inspect without running JavaScript.')
    ..addFlag('json', defaultsTo: false, help: 'Output report as JSON.')
    ..addFlag('allow-localhost',
        defaultsTo: true,
        help: 'Allow loopback/localhost requests for local development.');

  parser.commands['crawl']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addOption('base-url', help: 'Base URL of running server to crawl.');

  parser.commands['preview']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addOption('route', defaultsTo: '/', help: 'Route path to preview.');

  parser.commands['report']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addFlag('json', defaultsTo: false);

  parser.commands['regression']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('baseline',
        mandatory: true, help: 'Path to baseline crawl/audit JSON file.')
    ..addOption('current',
        mandatory: true, help: 'Path to current crawl/audit JSON file.')
    ..addFlag('json',
        defaultsTo: false, help: 'Output regression report as JSON.');

  final webParser = parser.commands['web']!
    ..addCommand('analyze')
    ..addCommand('build')
    ..addCommand('report')
    ..addFlag('help', abbr: 'h', negatable: false);

  webParser.commands['analyze']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('project-dir', defaultsTo: '.')
    ..addOption('build-dir', defaultsTo: 'build/web')
    ..addFlag('json', defaultsTo: false);

  webParser.commands['build']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('project-dir', defaultsTo: '.')
    ..addFlag('wasm', defaultsTo: true)
    ..addFlag('tree-shake-icons', defaultsTo: true);

  webParser.commands['report']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('project-dir', defaultsTo: '.')
    ..addOption('build-dir', defaultsTo: 'build/web')
    ..addFlag('json', defaultsTo: false);

  try {
    final result = parser.parse(arguments);
    if (result['help'] == true ||
        result.command == null ||
        result.command!['help'] == true) {
      stdout.writeln(_usage(parser));
      return;
    }

    final command = result.command!;

    // 1. inspect-url command
    if (command.name == 'inspect-url') {
      final targetUrl = command['url'] as String;
      final asJson = command['json'] as bool;
      final allowLocal = command['allow-localhost'] as bool;

      final inspector = CrawlerInspector(
        ssrfGuard: SsrfGuard(allowLocalhostInDev: allowLocal),
      );

      stdout.writeln('Inspecting raw HTTP endpoint: $targetUrl ...\n');
      try {
        final report = await inspector.inspectUrl(targetUrl);
        if (asJson) {
          stdout.writeln(
              const JsonEncoder.withIndent('  ').convert(report.toJson()));
        } else {
          stdout.writeln(report.toTerminalSummary());
        }
      } finally {
        inspector.close();
      }
      return;
    }

    // 2. regression command
    if (command.name == 'regression') {
      final baselinePath = command['baseline'] as String;
      final currentPath = command['current'] as String;
      final asJson = command['json'] as bool;

      final baselineFile = File(baselinePath);
      final currentFile = File(currentPath);

      if (!await baselineFile.exists() || !await currentFile.exists()) {
        stderr.writeln(
            'Error: Either baseline ($baselinePath) or current ($currentPath) snapshot file does not exist.');
        exitCode = 1;
        return;
      }

      final baselineData =
          json.decode(await baselineFile.readAsString()) as List;
      final currentData = json.decode(await currentFile.readAsString()) as List;

      final baselineSnapshots = {
        for (final item in baselineData)
          (item as Map<String, dynamic>)['url'] as String:
              PageSeoSnapshot.fromJson(item),
      };
      final currentSnapshots = {
        for (final item in currentData)
          (item as Map<String, dynamic>)['url'] as String:
              PageSeoSnapshot.fromJson(item),
      };

      const tester = SeoRegressionTester();
      final findings = tester.compareSnapshots(
        baseline: baselineSnapshots,
        current: currentSnapshots,
      );

      if (asJson) {
        stdout.writeln(const JsonEncoder.withIndent('  ')
            .convert(findings.map((f) => f.toJson()).toList()));
      } else {
        stdout.writeln('=== MetaMantle SEO Regression Report ===\n');
        if (findings.isNotEmpty) {
          stderr.writeln(
              'FAILED: ${findings.length} SEO regression(s) detected!\n');
          for (final f in findings) {
            stderr.writeln(
                '  - [${f.severity}] ${f.url} (${f.field}): ${f.message}');
          }
        } else {
          stdout.writeln(
              'PASSED: Zero regressions detected across ${currentSnapshots.length} routes.');
        }
      }

      if (findings.any((f) => f.severity == 'CRITICAL')) exitCode = 1;
      return;
    }

    // 3. web command
    if (command.name == 'web') {
      final sub = command.command;
      if (sub == null || sub.name == 'analyze' || sub.name == 'report') {
        final projectPath = sub?['project-dir'] as String? ?? '.';
        final buildPath = sub?['build-dir'] as String? ?? 'build/web';
        final asJson = sub?['json'] as bool? ?? false;

        final accelerator = const FlutterWebAccelerator();
        final report = await accelerator.analyze(
          projectDir: Directory(projectPath),
          webBuildDir: Directory(buildPath),
        );

        if (asJson) {
          stdout.writeln(
              const JsonEncoder.withIndent('  ').convert(report.toMap()));
        } else {
          stdout.writeln(
              '=== Flutter Web Acceleration & Optimization Report ===\n');
          stdout.writeln(
              'Project Type:      ${report.isFlutterProject ? "Flutter App" : "Standard Dart/Web"}');
          stdout.writeln(
              'Wasm Supported:    ${report.supportsWasm ? "Yes" : "No"}');
          stdout.writeln(
              'Modern Bootstrap:  ${report.usesModernBootstrap ? "Yes (flutter_bootstrap.js)" : "No (legacy flutter.js)"}');
          stdout.writeln('Findings:          ${report.findings.length}\n');

          for (final f in report.findings) {
            stdout.writeln(
                '[${f.severity.toUpperCase()}] [${f.category}] ${f.title}');
            stdout.writeln('  ${f.description}');
            if (f.suggestedFix != null) {
              stdout.writeln('  Suggested Fix: ${f.suggestedFix}');
            }
            stdout.writeln('');
          }

          if (report.bundleMetrics.isNotEmpty) {
            stdout.writeln('Bundle Metrics:');
            report.bundleMetrics.forEach((k, v) {
              final kb = (v / 1024).toStringAsFixed(1);
              stdout.writeln('  $k: $kb KB');
            });
            stdout.writeln('');
          }
        }
        return;
      }

      if (sub.name == 'build') {
        final wasm = sub['wasm'] as bool? ?? true;
        final treeShake = sub['tree-shake-icons'] as bool? ?? true;
        final accelerator = const FlutterWebAccelerator();
        final cmd = accelerator.suggestOptimizedBuildCommand(
          wasm: wasm,
          stripUnusedFonts: treeShake,
        );
        stdout.writeln('=== Recommended Flutter Web Build Command ===\n');
        stdout.writeln('  $cmd\n');
        stdout.writeln(
            'Recommended Deployment Response Headers (for Skwasm/Wasm):');
        accelerator.getRecommendedServerHeaders().forEach((k, v) {
          stdout.writeln('  $k: $v');
        });
        return;
      }
    }

    // Config file resolution
    var configPath = command.options.contains('config')
        ? command['config'] as String
        : 'meta_mantle.config.json';
    var configFile = File(configPath);
    if (!await configFile.exists() &&
        configPath == 'meta_mantle.config.json' &&
        await File('web_head.config.json').exists()) {
      configPath = 'web_head.config.json';
      configFile = File(configPath);
    }

    // 2. doctor command
    if (command.name == 'doctor') {
      final input = Directory(command['input'] as String);
      stdout.writeln('Running MetaMantle Doctor...\n');
      final reports = await const StaticHeadBuilder().doctor(
        configFile: configFile,
        inputDirectory: input,
      );
      var hasFailures = false;
      for (final report in reports) {
        if (report.startsWith('FAIL')) {
          hasFailures = true;
          stderr.writeln('  $report');
        } else {
          stdout.writeln('  $report');
        }
      }
      stdout.writeln('');
      if (hasFailures) {
        stderr.writeln('Doctor found setup issues.');
        exitCode = 1;
      } else {
        stdout.writeln('Doctor checks passed successfully.');
      }
      return;
    }

    if (!await configFile.exists()) {
      throw FileSystemException(
        'Configuration file not found. Create a meta_mantle.config.json file.',
        configFile.path,
      );
    }

    final parsedConfig = await StaticHeadConfig.load(configFile);

    // 3. validate command
    if (command.name == 'validate') {
      final warnings = await const StaticHeadBuilder().validateConfiguration(
        config: parsedConfig,
        configFile: configFile,
      );
      stdout.writeln('Configuration is structurally valid.');
      stdout.writeln('Explicit routes: ${parsedConfig.routes.length}');
      stdout.writeln('Dynamic patterns: ${parsedConfig.patterns.length}');
      if (warnings.isNotEmpty) {
        stdout.writeln('\nWarnings:');
        for (final w in warnings) {
          stdout.writeln('  - $w');
        }
      }
      return;
    }

    // 4. inspect command
    if (command.name == 'inspect') {
      for (final pattern in parsedConfig.patterns) {
        final dataFile = File(pattern.dataFile);
        if (await dataFile.exists()) {
          final decoded = json.decode(await dataFile.readAsString()) as List;
          stdout.writeln(
              'Expanded dynamic pattern: ${pattern.pathPattern} (${decoded.length} items)');
        }
      }
      stdout.writeln('\n=== MetaMantle Route Inspector ===');
      stdout.writeln('Base URL: ${parsedConfig.baseUrl}');
      stdout
          .writeln('Configured explicit routes: ${parsedConfig.routes.length}');
      for (final r in parsedConfig.routes) {
        stdout.writeln('  ${r.path}');
      }
      return;
    }

    // 5. preview command
    if (command.name == 'preview') {
      final targetRoute = command['route'] as String;
      final matched = parsedConfig.routes.firstWhere(
        (r) => r.path == targetRoute,
        orElse: () =>
            StaticRoute(path: targetRoute, metadata: const WebMetadata()),
      );

      final renderer = const MetadataRenderer();
      final tags = renderer.render(
        matched.metadata,
        config: MetaMantleConfig(
          baseUrl: parsedConfig.baseUrl,
          siteName: parsedConfig.siteName,
          titleTemplate: parsedConfig.titleTemplate,
          defaultImage: parsedConfig.defaultImage,
          defaultRobots: parsedConfig.defaultRobots,
        ),
      );

      stdout.writeln('=== Raw Crawler Preview for "$targetRoute" ===');
      for (final t in tags) {
        if (t.tagName == 'title') {
          stdout.writeln('TITLE:       ${t.textContent}');
        } else if (t.attributes['name'] == 'description') {
          stdout.writeln('DESCRIPTION: ${t.attributes['content']}');
        } else if (t.attributes['property'] == 'og:title') {
          stdout.writeln('OG TITLE:    ${t.attributes['content']}');
        } else if (t.attributes['property'] == 'og:image') {
          stdout.writeln('OG IMAGE:    ${t.attributes['content']}');
        }
      }
      return;
    }

    // 6. report command
    if (command.name == 'report') {
      final asJson = command['json'] as bool;
      final warnings = await const StaticHeadBuilder().validateConfiguration(
        config: parsedConfig,
        configFile: configFile,
      );

      final reportData = {
        'baseUrl': parsedConfig.baseUrl,
        'siteName': parsedConfig.siteName,
        'routesCount': parsedConfig.routes.length,
        'patternsCount': parsedConfig.patterns.length,
        'strictCompliant': warnings.isEmpty,
        'warnings': warnings,
      };

      if (asJson) {
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(reportData));
      } else {
        stdout.writeln('=== MetaMantle SEO Audit Report ===');
        stdout.writeln(
            'Site Name:       ${parsedConfig.siteName ?? "(unnamed)"}');
        stdout.writeln('Base URL:        ${parsedConfig.baseUrl}');
        stdout.writeln(
            'Strict Quality:  ${warnings.isEmpty ? "PASS" : "FAIL (${warnings.length} warning(s))"}');
        if (warnings.isNotEmpty) {
          stdout.writeln('\nRemediations:');
          for (final w in warnings) {
            stdout.writeln('  * $w');
          }
        }
      }
      return;
    }

    // 7. crawl command
    if (command.name == 'crawl') {
      final baseUrl = command['base-url'] as String? ?? parsedConfig.baseUrl;

      stdout.writeln('Crawling routes against $baseUrl ...\n');
      final inspector = CrawlerInspector();
      var failCount = 0;

      try {
        for (final route in parsedConfig.routes) {
          final fullUrl = baseUrl.endsWith('/')
              ? '$baseUrl${route.path.substring(1)}'
              : '$baseUrl${route.path}';
          try {
            final res = await inspector.inspectUrl(fullUrl);
            stdout.writeln(
                '  [${res.statusCode}] ${res.url} - ${res.title ?? "(NO TITLE)"}');
            if (res.statusCode >= 400) failCount++;
          } catch (e) {
            stderr.writeln('  [ERR] $fullUrl: $e');
            failCount++;
          }
        }
      } finally {
        inspector.close();
      }

      stdout.writeln('\nCrawl finished. Failures: $failCount');
      if (failCount > 0) exitCode = 1;
      return;
    }

    // 8. build-web command
    if (command.name == 'build-web') {
      final modeStr = command['mode'] as String;
      final mode = BuildMode.fromString(modeStr);
      final isRelease = command['release'] as bool;
      final isDebug = command['debug'] as bool;
      final output = command['output'] as String;
      final baseHref = command['base-href'] as String;
      final isWasm = command['wasm'] as bool;
      final isVerbose = command['verbose'] as bool;
      final isDryRun = command['dry-run'] as bool;
      final isClean = command['clean'] as bool;
      final isStrict = command['strict'] as bool;

      final options = BuildWebOptions(
        mode: mode,
        release: isRelease && !isDebug,
        debug: isDebug,
        output: output,
        baseHref: baseHref,
        wasm: isWasm,
        verbose: isVerbose,
        dryRun: isDryRun,
        clean: isClean,
        strict: isStrict,
        configPath: configPath,
      );

      final engine = const FlutterWebBuildEngine();
      final result = await engine.build(
        options,
        onProgress: (msg) => stdout.writeln('  $msg'),
      );

      stdout.writeln('\n=== MetaMantle Flutter Web Build Complete ===');
      stdout.writeln('Mode:            ${result.mode.name.toUpperCase()}');
      stdout.writeln('Routes:          ${result.routes.length}');
      stdout.writeln('Generated Files: ${result.generatedFiles.length}');
      stdout.writeln('Duration:        ${result.durationMs}ms');
      if (result.reportPath != null) {
        stdout.writeln('Build Report:    ${result.reportPath}');
      }

      if (result.warnings.isNotEmpty) {
        stderr.writeln('\nWarnings (${result.warnings.length}):');
        for (final w in result.warnings) {
          stderr.writeln('  * $w');
        }
      }
      return;
    }

    // 9. legacy build command
    final input = Directory(command['input'] as String);
    final output = Directory(command['output'] as String);
    final isDryRun = command['dry-run'] as bool;
    final isVerbose = command['verbose'] as bool;

    var effectiveConfig = parsedConfig;
    if (command['no-sitemap'] == true || command['no-robots'] == true) {
      effectiveConfig = parsedConfig.copyWith(
        sitemap: command['no-sitemap'] == true ? false : parsedConfig.sitemap,
        robotsTxt:
            command['no-robots'] == true ? false : parsedConfig.robotsTxt,
      );
    }

    if (isDryRun) {
      stdout.writeln('[DRY RUN] Simulating static HTML generation...');
    }

    final buildResult = await const StaticHeadBuilder().build(
      inputDirectory: input,
      outputDirectory: output,
      config: effectiveConfig,
      configFile: configFile,
      strict: command['strict'] as bool,
      dryRun: isDryRun,
      verbose: isVerbose,
      onProgress: (msg) {
        if (isVerbose) stdout.writeln('  $msg');
      },
    );

    final actionLabel = isDryRun ? 'Would generate' : 'Generated';
    stdout.writeln(
        '$actionLabel ${buildResult.generatedFiles.length} files for ${buildResult.routes.length} routes.');
    for (final warning in buildResult.warnings) {
      stderr.writeln('WARNING: $warning');
    }
    for (final file in buildResult.generatedFiles) {
      stdout.writeln('  ${file.path}');
    }
  } on UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage(parser));
    exitCode = 64;
  } on FormatException catch (error) {
    stderr.writeln('Configuration/build error: ${error.message}');
    exitCode = 2;
  } on FileSystemException catch (error) {
    stderr.writeln(
        'File error: ${error.message} (${error.path ?? 'unknown path'})');
    exitCode = 2;
  } catch (error, stack) {
    stderr.writeln('Unexpected error: $error');
    stderr.writeln(stack);
    exitCode = 1;
  }
}

String _usage(ArgParser parser) => """
MetaMantle CLI

Usage:
  dart run meta_mantle <command> [options]

Commands:
  build-web    Execute Flutter Web production build and generate semantic HTML pages.
  build        Generate route-specific HTML documents from a Flutter build.
  validate     Validate the JSON route configuration.
  inspect      Display all resolved routes and metadata without writing files.
  doctor       Diagnose project configuration and build readiness.
  inspect-url  Inspect a live HTTP URL without executing JavaScript.
  crawl        Crawl and verify all routes on a live or local server.
  preview      Preview raw crawler metadata for a given route.
  report       Generate structured SEO audit report.
  regression   Compare baseline vs current snapshots for SEO regressions.
  web          Accelerate and analyze Flutter Web (Wasm readiness, bootstrap, bundles).

${parser.usage}
""";
