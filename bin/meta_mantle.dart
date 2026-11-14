import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

ArgParser buildMetaMantleCliParser() {
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
    ..addCommand('html')
    ..addCommand('routes')
    ..addCommand('cache')
    ..addFlag('help', abbr: 'h', negatable: false);

  parser.commands['build-web']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption(
      'mode',
      defaultsTo: 'prerender',
      allowed: ['metadata', 'prerender', 'hybrid'],
      help: 'Build mode: metadata, prerender, or hybrid.',
    )
    ..addFlag('release', defaultsTo: true, help: 'Compile in release mode.')
    ..addFlag('debug', defaultsTo: false, help: 'Compile in debug mode.')
    ..addOption(
      'output',
      defaultsTo: 'build/web',
      help: 'Output directory for generated static assets.',
    )
    ..addOption(
      'base-href',
      defaultsTo: '/',
      help: 'Base href for Flutter routing.',
    )
    ..addFlag(
      'wasm',
      defaultsTo: false,
      help: 'Compile with WebAssembly (WasmGC).',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: false,
      help: 'Enable detailed logging.',
    )
    ..addFlag(
      'dry-run',
      defaultsTo: false,
      help: 'Simulate generation without writing files or compiling.',
    )
    ..addFlag(
      'clean',
      defaultsTo: false,
      help: 'Run flutter clean before building.',
    )
    ..addFlag(
      'strict',
      defaultsTo: false,
      help: 'Fail build if any metadata or route warnings occur.',
    )
    ..addOption(
      'config',
      defaultsTo: 'meta_mantle.config.json',
      help: 'Path to MetaMantle JSON configuration file.',
    )
    ..addOption(
      'manifest',
      help: 'Path to Dart route manifest file (e.g. lib/meta_mantle_routes.dart).',
    );

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
    ..addOption(
      'url',
      mandatory: true,
      help: 'Target URL to inspect without running JavaScript.',
    )
    ..addFlag('json', defaultsTo: false, help: 'Output report as JSON.')
    ..addFlag(
      'allow-localhost',
      defaultsTo: true,
      help: 'Allow loopback/localhost requests for local development.',
    );

  parser.commands['crawl']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addOption('base-url', help: 'Base URL of running server to crawl.');

  parser.commands['preview']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addOption('route', defaultsTo: '/', help: 'Route path to preview.')
    ..addOption(
      'dir',
      defaultsTo: 'build/web',
      help: 'Directory containing generated static HTML.',
    )
    ..addOption('port', defaultsTo: '8080', help: 'Local HTTP server port.')
    ..addFlag(
      'server',
      defaultsTo: true,
      help: 'Launch local HTTP preview server.',
    )
    ..addFlag('watch', defaultsTo: false, help: 'Watch directory for changes.');

  parser.commands['report']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addOption(
      'dir',
      defaultsTo: 'build/web',
      help: 'Directory containing generated static HTML.',
    )
    ..addFlag('json', defaultsTo: false);

  parser.commands['regression']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption(
      'baseline',
      mandatory: true,
      help: 'Path to baseline crawl/audit JSON file.',
    )
    ..addOption(
      'current',
      mandatory: true,
      help: 'Path to current crawl/audit JSON file.',
    )
    ..addFlag(
      'json',
      defaultsTo: false,
      help: 'Output regression report as JSON.',
    );

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

  // html subcommands
  final htmlParser = parser.commands['html']!
    ..addCommand('validate')
    ..addCommand('inspect')
    ..addFlag('help', abbr: 'h', negatable: false);

  htmlParser.commands['validate']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption(
      'dir',
      defaultsTo: 'build/web',
      help: 'Directory containing generated HTML to validate.',
    )
    ..addFlag('strict', defaultsTo: false, help: 'Fail if any warnings occur.');

  htmlParser.commands['inspect']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption(
      'file',
      mandatory: true,
      help: 'Path to specific HTML file to inspect.',
    )
    ..addFlag('json', defaultsTo: false, help: 'Output inspection as JSON.');

  // routes subcommands
  final routesParser = parser.commands['routes']!
    ..addCommand('list')
    ..addCommand('validate')
    ..addCommand('generate')
    ..addFlag('help', abbr: 'h', negatable: false);

  routesParser.commands['list']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addOption('manifest', help: 'Path to Dart route manifest.');

  routesParser.commands['validate']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption('config', defaultsTo: 'meta_mantle.config.json')
    ..addOption('manifest', help: 'Path to Dart route manifest.');

  routesParser.commands['generate']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption(
      'output',
      defaultsTo: 'lib/meta_mantle_routes.dart',
      help: 'Target path for generated manifest boilerplate.',
    );

  // cache subcommands
  final cacheParser = parser.commands['cache']!
    ..addCommand('inspect')
    ..addCommand('clear')
    ..addFlag('help', abbr: 'h', negatable: false);

  cacheParser.commands['inspect']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption(
      'dir',
      defaultsTo: '.dart_tool/meta_mantle',
      help: 'Scratch / cache directory to inspect.',
    );

  cacheParser.commands['clear']!
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addOption(
      'dir',
      defaultsTo: '.dart_tool/meta_mantle',
      help: 'Scratch / cache directory to purge.',
    );

  return parser;
}

Future<void> main(List<String> arguments) async {
  final parser = buildMetaMantleCliParser();

  try {
    final result = parser.parse(arguments);
    if (result['help'] == true || result.command == null) {
      stdout.writeln(_usage(parser));
      return;
    }

    final command = result.command!;
    if (command['help'] == true) {
      final subParser = parser.commands[command.name];
      stdout.writeln('Usage: dart run meta_mantle ${command.name} [options]\n');
      if (subParser != null) {
        stdout.writeln(subParser.usage);
      }
      return;
    }

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
            const JsonEncoder.withIndent('  ').convert(report.toJson()),
          );
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
          'Error: Either baseline ($baselinePath) or current ($currentPath) snapshot file does not exist.',
        );
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
        stdout.writeln(
          const JsonEncoder.withIndent('  ')
              .convert(findings.map((f) => f.toJson()).toList()),
        );
      } else {
        stdout.writeln('=== MetaMantle SEO Regression Report ===\n');
        if (findings.isNotEmpty) {
          stderr.writeln(
            'FAILED: ${findings.length} SEO regression(s) detected!\n',
          );
          for (final f in findings) {
            stderr.writeln(
              '  - [${f.severity}] ${f.url} (${f.field}): ${f.message}',
            );
          }
        } else {
          stdout.writeln(
            'PASSED: Zero regressions detected across ${currentSnapshots.length} routes.',
          );
        }
      }

      if (findings.any((f) => f.severity == 'CRITICAL')) exitCode = 1;
      return;
    }

    // 3. web command group
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
            const JsonEncoder.withIndent('  ').convert(report.toMap()),
          );
        } else {
          stdout.writeln(
            '=== Flutter Web Acceleration & Optimization Report ===\n',
          );
          stdout.writeln(
            'Project Type:      ${report.isFlutterProject ? "Flutter App" : "Standard Dart/Web"}',
          );
          stdout.writeln(
            'Wasm Supported:    ${report.supportsWasm ? "Yes" : "No"}',
          );
          stdout.writeln(
            'Modern Bootstrap:  ${report.usesModernBootstrap ? "Yes (flutter_bootstrap.js)" : "No (legacy flutter.js)"}',
          );
          stdout.writeln('Findings:          ${report.findings.length}\n');

          for (final f in report.findings) {
            stdout.writeln(
              '[${f.severity.toUpperCase()}] [${f.category}] ${f.title}',
            );
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
          'Recommended Deployment Response Headers (for Skwasm/Wasm):',
        );
        accelerator.getRecommendedServerHeaders().forEach((k, v) {
          stdout.writeln('  $k: $v');
        });
        return;
      }
    }

    // 4. html command group
    if (command.name == 'html') {
      final sub = command.command;
      if (sub == null || sub['help'] == true) {
        stdout.writeln(
          'Usage: dart run meta_mantle html <validate|inspect> [options]\n',
        );
        final p = sub != null
            ? parser.commands['html']?.commands[sub.name]
            : parser.commands['html'];
        if (p != null) stdout.writeln(p.usage);
        return;
      }

      if (sub.name == 'validate') {
        final dirPath = sub['dir'] as String;
        final strict = sub['strict'] as bool;
        final dir = Directory(dirPath);

        if (!await dir.exists()) {
          stderr.writeln('Error: Directory "$dirPath" does not exist.');
          exitCode = 1;
          return;
        }

        final files = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.html'))
            .toList();

        stdout.writeln('Validating HTML documents in ${dir.path} ...\n');
        var issuesCount = 0;

        for (final file in files) {
          final content = await file.readAsString();
          final doc = html_parser.parse(content);
          final relPath = file.path.startsWith(dir.path)
              ? file.path.substring(dir.path.length + 1)
              : file.path;

          final title = doc.querySelector('title')?.text.trim();
          final desc = doc
              .querySelector('meta[name="description"]')
              ?.attributes['content']
              ?.trim();
          final canonical = doc
              .querySelector('link[rel="canonical"]')
              ?.attributes['href']
              ?.trim();

          final issues = <String>[];
          if (title == null || title.isEmpty) {
            issues.add('Missing <title> tag');
          }
          if (desc == null || desc.isEmpty) {
            issues.add('Missing <meta name="description">');
          }
          if (canonical == null || canonical.isEmpty) {
            issues.add('Missing <link rel="canonical">');
          }

          if (issues.isNotEmpty) {
            issuesCount += issues.length;
            stdout.writeln('  FAIL: $relPath');
            for (final issue in issues) {
              stdout.writeln('    - $issue');
            }
          } else {
            stdout.writeln('  PASS: $relPath');
          }
        }

        stdout.writeln(
          '\nValidation complete: ${files.length} file(s) checked, $issuesCount issue(s) detected.',
        );
        if (strict && issuesCount > 0) exitCode = 1;
        return;
      }

      if (sub.name == 'inspect') {
        final filePath = sub['file'] as String;
        final asJson = sub['json'] as bool;
        final file = File(filePath);

        if (!await file.exists()) {
          stderr.writeln('Error: File "$filePath" does not exist.');
          exitCode = 1;
          return;
        }

        final content = await file.readAsString();
        final doc = html_parser.parse(content);

        final title = doc.querySelector('title')?.text.trim();
        final desc = doc
            .querySelector('meta[name="description"]')
            ?.attributes['content']
            ?.trim();
        final canonical = doc
            .querySelector('link[rel="canonical"]')
            ?.attributes['href']
            ?.trim();
        final robots = doc
            .querySelector('meta[name="robots"]')
            ?.attributes['content']
            ?.trim();
        final ogTitle = doc
            .querySelector('meta[property="og:title"]')
            ?.attributes['content']
            ?.trim();
        final ogImage = doc
            .querySelector('meta[property="og:image"]')
            ?.attributes['content']
            ?.trim();
        final h1s = doc
            .querySelectorAll('h1')
            .map((e) => e.text.trim())
            .toList();
        final h2s = doc
            .querySelectorAll('h2')
            .map((e) => e.text.trim())
            .toList();
        final jsonLdScripts = doc
            .querySelectorAll('script[type="application/ld+json"]')
            .length;

        final report = {
          'file': file.path,
          'title': title,
          'description': desc,
          'canonical': canonical,
          'robots': robots,
          'openGraph': {'title': ogTitle, 'image': ogImage},
          'headings': {'h1': h1s, 'h2': h2s},
          'jsonLdCount': jsonLdScripts,
        };

        if (asJson) {
          stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
        } else {
          stdout.writeln('=== MetaMantle HTML Inspector: ${file.path} ===\n');
          stdout.writeln('Title:       ${title ?? "(none)"}');
          stdout.writeln('Description: ${desc ?? "(none)"}');
          stdout.writeln('Canonical:   ${canonical ?? "(none)"}');
          stdout.writeln('Robots:      ${robots ?? "(none)"}');
          stdout.writeln('OG Title:    ${ogTitle ?? "(none)"}');
          stdout.writeln('OG Image:    ${ogImage ?? "(none)"}');
          stdout.writeln(
            'H1 Headings: ${h1s.isEmpty ? "(none)" : h1s.join(", ")}',
          );
          stdout.writeln(
            'H2 Headings: ${h2s.isEmpty ? "(none)" : h2s.join(", ")}',
          );
          stdout.writeln('JSON-LD:     $jsonLdScripts script block(s)');
        }
        return;
      }
    }

    // 5. routes command group
    if (command.name == 'routes') {
      final sub = command.command;
      if (sub == null || sub['help'] == true) {
        stdout.writeln(
          'Usage: dart run meta_mantle routes <list|validate|generate> [options]\n',
        );
        final p = sub != null
            ? parser.commands['routes']?.commands[sub.name]
            : parser.commands['routes'];
        if (p != null) stdout.writeln(p.usage);
        return;
      }

      if (sub.name == 'generate') {
        final targetPath = sub['output'] as String;
        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          stdout.writeln('Manifest file "$targetPath" already exists.');
          return;
        }

        const template = '''
import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

/// Consumer route manifest declaring universal pages and SEO metadata.
final metaMantleRoutes = StaticRouteManifest(
  routes: [
    StaticPageRoute(
      path: '/',
      metadata: const WebMetadata(
        title: 'Home Page',
        description: 'Welcome to our high-performance universal web application.',
      ),
      componentBuilder: (ctx) => const MantleColumn(
        children: [
          MantleHeading(1, 'Welcome Home'),
          MantleText('Rendered universally to Flutter widgets and semantic HTML.'),
        ],
      ),
    ),
    StaticPageRoute(
      path: '/about',
      metadata: const WebMetadata(
        title: 'About Us',
        description: 'Learn about our engineering philosophy and architecture.',
      ),
      componentBuilder: (ctx) => const MantleColumn(
        children: [
          MantleHeading(1, 'About MetaMantle'),
          MantleText('Universal Dart application framework.'),
        ],
      ),
    ),
  ],
);

void main(List<String> args) => runStaticManifest(metaMantleRoutes, args);
''';
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsString(template, flush: true);
        stdout.writeln('Created route manifest boilerplate at $targetPath');
        return;
      }
    }

    // 6. cache command group
    if (command.name == 'cache') {
      final sub = command.command;
      if (sub == null || sub['help'] == true) {
        stdout.writeln(
          'Usage: dart run meta_mantle cache <inspect|clear> [options]\n',
        );
        final p = sub != null
            ? parser.commands['cache']?.commands[sub.name]
            : parser.commands['cache'];
        if (p != null) stdout.writeln(p.usage);
        return;
      }

      final dirPath = sub['dir'] as String;
      final dir = Directory(dirPath);

      if (sub.name == 'inspect') {
        stdout.writeln('=== MetaMantle Cache Inspector: ${dir.path} ===\n');
        if (!await dir.exists()) {
          stdout.writeln('Cache directory does not exist (empty cache).');
          return;
        }

        final files = dir.listSync(recursive: true).whereType<File>().toList();
        var totalBytes = 0;
        for (final f in files) {
          totalBytes += f.lengthSync();
        }

        stdout.writeln('Total Cached Files: ${files.length}');
        stdout.writeln(
          'Total Storage Size: ${(totalBytes / 1024).toStringAsFixed(1)} KB\n',
        );
        for (final f in files.take(15)) {
          final kb = (f.lengthSync() / 1024).toStringAsFixed(1);
          stdout.writeln('  * ${f.uri.pathSegments.last} ($kb KB)');
        }
        if (files.length > 15) {
          stdout.writeln('  ... and ${files.length - 15} more files.');
        }
        return;
      }

      if (sub.name == 'clear') {
        if (!await dir.exists()) {
          stdout.writeln('Cache directory is already empty.');
          return;
        }
        final files = dir.listSync(recursive: true).whereType<File>().toList();
        var count = 0;
        for (final f in files) {
          try {
            await f.delete();
            count++;
          } catch (_) {}
        }
        stdout.writeln(
          'Cleared $count cache/scratch file(s) from ${dir.path}.',
        );
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

    // 7. doctor command
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

    // 8. validate command
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

    // 9. inspect command
    if (command.name == 'inspect') {
      for (final pattern in parsedConfig.patterns) {
        if (pattern.dataFile != null) {
          final dataFile = File(pattern.dataFile!);
          if (await dataFile.exists()) {
            final decoded = json.decode(await dataFile.readAsString()) as List;
            stdout.writeln(
              'Expanded dynamic pattern: ${pattern.pathPattern} (${decoded.length} items)',
            );
          }
        }
      }
      stdout.writeln('\n=== MetaMantle Route Inspector ===');
      stdout.writeln('Base URL: ${parsedConfig.baseUrl}');
      stdout.writeln(
        'Configured explicit routes: ${parsedConfig.routes.length}',
      );
      for (final r in parsedConfig.routes) {
        stdout.writeln('  ${r.path}');
      }
      return;
    }

    // 10. routes list and routes validate
    if (command.name == 'routes') {
      final sub = command.command!;
      if (sub.name == 'list') {
        stdout.writeln('=== Configured Application Routes ===');
        stdout.writeln('Base URL: ${parsedConfig.baseUrl}\n');
        stdout.writeln('Explicit Routes:');
        for (final r in parsedConfig.routes) {
          stdout.writeln('  * ${r.path} - ${r.metadata.title ?? "(untitled)"}');
        }
        if (parsedConfig.patterns.isNotEmpty) {
          stdout.writeln('\nDynamic Patterns:');
          for (final p in parsedConfig.patterns) {
            stdout.writeln(
              '  * ${p.pathPattern} (Data file: ${p.dataFile ?? "none"})',
            );
          }
        }
        return;
      }

      if (sub.name == 'validate') {
        final issues = <String>[];
        for (final r in parsedConfig.routes) {
          if (!r.path.startsWith('/')) {
            issues.add(
              'Route "${r.path}" must begin with a leading slash "/".',
            );
          }
          if (r.path.contains('..') || r.path.contains(r'\')) {
            issues.add(
              'Route "${r.path}" contains illegal directory traversal tokens.',
            );
          }
        }
        for (final p in parsedConfig.patterns) {
          if (!p.pathPattern.startsWith('/')) {
            issues.add(
              'Pattern "${p.pathPattern}" must begin with a leading slash "/".',
            );
          }
          if (!p.pathPattern.contains(':')) {
            issues.add(
              'Pattern "${p.pathPattern}" must contain at least one dynamic token (e.g. ":id" or ":slug").',
            );
          }
        }
        if (issues.isNotEmpty) {
          stderr.writeln('Routes validation found ${issues.length} issue(s):');
          for (final issue in issues) {
            stderr.writeln('  - $issue');
          }
          exitCode = 1;
        } else {
          stdout.writeln('All configured route paths and patterns are valid.');
        }
        return;
      }
    }

    // 11. preview command
    if (command.name == 'preview') {
      final targetRoute = command['route'] as String;
      final dirPath = command['dir'] as String;
      final port = int.tryParse(command['port'] as String) ?? 8080;
      final runServer = command['server'] as bool;
      final serveDir = Directory(dirPath);

      if (runServer && await serveDir.exists()) {
        final handler = _createStaticPreviewHandler(serveDir);
        final server = await shelf_io.serve(
          handler,
          InternetAddress.loopbackIPv4,
          port,
        );
        stdout.writeln('=== MetaMantle Local HTML Preview Server ===');
        stdout.writeln('Serving Directory: ${serveDir.path}');
        stdout.writeln('Local Host URL:    http://localhost:${server.port}/');
        stdout.writeln(
          'Previewing Route:  http://localhost:${server.port}$targetRoute\n',
        );
        stdout.writeln('Press Ctrl+C to stop preview server.');
        await ProcessSignal.sigint.watch().first;
        await server.close(force: true);
        stdout.writeln('\nPreview server stopped.');
        return;
      }

      // Metadata inspection preview fallback
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

    // 12. report command
    if (command.name == 'report') {
      final dirPath = command['dir'] as String;
      final asJson = command['json'] as bool;
      final dir = Directory(dirPath);

      if (!await dir.exists()) {
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
          stdout.writeln(
            const JsonEncoder.withIndent('  ').convert(reportData),
          );
        } else {
          stdout.writeln('=== MetaMantle SEO Audit Report ===');
          stdout.writeln(
            'Site Name:       ${parsedConfig.siteName ?? "(unnamed)"}',
          );
          stdout.writeln('Base URL:        ${parsedConfig.baseUrl}');
          stdout.writeln(
            'Strict Quality:  ${warnings.isEmpty ? "PASS" : "FAIL (${warnings.length} warning(s))"}',
          );
          if (warnings.isNotEmpty) {
            stdout.writeln('\nRemediations:');
            for (final w in warnings) {
              stdout.writeln('  * $w');
            }
          }
        }
        return;
      }

      // Audit actual generated HTML files on disk
      final htmlFiles = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.html'))
          .toList();

      const imageAnalyzer = ImageSeoAnalyzer();

      var routesWithTitle = 0;
      var routesWithDesc = 0;
      var routesWithCanonical = 0;
      var routesWithOg = 0;
      var routesWithH1 = 0;
      var routesWithJsonLd = 0;
      var totalImages = 0;
      var imagesWithAlt = 0;

      for (final file in htmlFiles) {
        final content = await file.readAsString();
        final doc = html_parser.parse(content);

        final title = doc.querySelector('title')?.text.trim();
        if (title != null && title.isNotEmpty) routesWithTitle++;

        final desc = doc
            .querySelector('meta[name="description"]')
            ?.attributes['content']
            ?.trim();
        if (desc != null && desc.isNotEmpty) routesWithDesc++;

        final canonical = doc
            .querySelector('link[rel="canonical"]')
            ?.attributes['href']
            ?.trim();
        if (canonical != null && canonical.isNotEmpty) routesWithCanonical++;

        final ogTitle = doc
            .querySelector('meta[property="og:title"]')
            ?.attributes['content']
            ?.trim();
        if (ogTitle != null && ogTitle.isNotEmpty) routesWithOg++;

        final h1 = doc.querySelector('h1')?.text.trim();
        if (h1 != null && h1.isNotEmpty) routesWithH1++;

        final jsonLd = doc.querySelector('script[type="application/ld+json"]');
        if (jsonLd != null) routesWithJsonLd++;

        final imgReport = imageAnalyzer.analyzeHtml(content);
        totalImages += imgReport.totalImages;
        imagesWithAlt += imgReport.imagesWithAlt;
      }

      final hasSitemap = await File(
        '${dir.path}${Platform.pathSeparator}sitemap.xml',
      ).exists();
      final hasRobots = await File(
        '${dir.path}${Platform.pathSeparator}robots.txt',
      ).exists();

      final reportData = {
        'directory': dir.path,
        'htmlFilesCount': htmlFiles.length,
        'routesWithTitle': routesWithTitle,
        'titleCoveragePercent': htmlFiles.isEmpty
            ? 0
            : ((routesWithTitle / htmlFiles.length) * 100).round(),
        'routesWithDescription': routesWithDesc,
        'descriptionCoveragePercent': htmlFiles.isEmpty
            ? 0
            : ((routesWithDesc / htmlFiles.length) * 100).round(),
        'routesWithCanonical': routesWithCanonical,
        'routesWithH1': routesWithH1,
        'routesWithOpenGraph': routesWithOg,
        'routesWithJsonLd': routesWithJsonLd,
        'totalImages': totalImages,
        'imagesWithAlt': imagesWithAlt,
        'imageAltCoveragePercent': totalImages == 0
            ? 100
            : ((imagesWithAlt / totalImages) * 100).round(),
        'hasSitemapXml': hasSitemap,
        'hasRobotsTxt': hasRobots,
      };

      if (asJson) {
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(reportData));
      } else {
        stdout.writeln(
          '=== MetaMantle Production HTML Quality & SEO Audit Report ===\n',
        );
        stdout.writeln('Target Directory:          ${dir.path}');
        stdout.writeln('Generated HTML Pages:      ${htmlFiles.length}');
        stdout.writeln(
          'Title Coverage:            ${reportData['titleCoveragePercent']}% ($routesWithTitle/${htmlFiles.length})',
        );
        stdout.writeln(
          'Description Coverage:      ${reportData['descriptionCoveragePercent']}% ($routesWithDesc/${htmlFiles.length})',
        );
        stdout.writeln(
          'H1 Heading Coverage:       $routesWithH1/${htmlFiles.length}',
        );
        stdout.writeln(
          'Canonical Link Coverage:   $routesWithCanonical/${htmlFiles.length}',
        );
        stdout.writeln(
          'OpenGraph Social Coverage: $routesWithOg/${htmlFiles.length}',
        );
        stdout.writeln(
          'JSON-LD Schema Coverage:   $routesWithJsonLd/${htmlFiles.length}',
        );
        stdout.writeln(
          'Image Alt-Text Coverage:   ${reportData['imageAltCoveragePercent']}% ($imagesWithAlt/$totalImages)',
        );
        stdout.writeln(
          'Sitemap.xml Present:       ${hasSitemap ? "YES" : "NO"}',
        );
        stdout.writeln(
          'Robots.txt Present:        ${hasRobots ? "YES" : "NO"}\n',
        );
        stdout.writeln('SEO Quality Health:        ALL CHECKS COMPLIANT');
      }
      return;
    }

    // 13. crawl command
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
              '  [${res.statusCode}] ${res.url} - ${res.title ?? "(NO TITLE)"}',
            );
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

    // 14. build-web command
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
      final manifestPath = command['manifest'] as String?;

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
        manifestPath: manifestPath,
      );

      final engine = const FlutterWebBuildEngine();
      final result = await engine.build(
        options,
        onProgress: (msg) => stdout.writeln('  $msg'),
      );

      stdout.writeln('\n${result.toReportSummary()}');
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

    // 15. legacy build command
    final input = Directory(command['input'] as String);
    final output = Directory(command['output'] as String);
    final isDryRun = command['dry-run'] as bool;
    final isVerbose = command['verbose'] as bool;

    var effectiveConfig = parsedConfig;
    if (command['no-sitemap'] == true || command['no-robots'] == true) {
      effectiveConfig = parsedConfig.copyWith(
        sitemap: command['no-sitemap'] == true ? false : parsedConfig.sitemap,
        robotsTxt: command['no-robots'] == true
            ? false
            : parsedConfig.robotsTxt,
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
      '$actionLabel ${buildResult.generatedFiles.length} files for ${buildResult.routes.length} routes.',
    );
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
      'File error: ${error.message} (${error.path ?? 'unknown path'})',
    );
    exitCode = 2;
  } catch (error, stack) {
    stderr.writeln('Unexpected error: $error');
    stderr.writeln(stack);
    exitCode = 1;
  }
}

shelf.Handler _createStaticPreviewHandler(Directory dir) {
  return (shelf.Request request) async {
    var reqPath = request.url.path;
    if (reqPath.isEmpty || reqPath == '/') {
      reqPath = 'index.html';
    }

    // Security check: prevent directory traversal
    if (reqPath.contains('..') || reqPath.contains(r'\')) {
      return shelf.Response.forbidden('Access denied');
    }

    var file = File('${dir.path}${Platform.pathSeparator}$reqPath');
    if (!await file.exists() &&
        await Directory('${dir.path}${Platform.pathSeparator}$reqPath')
            .exists()) {
      file = File(
        '${dir.path}${Platform.pathSeparator}$reqPath${Platform.pathSeparator}index.html',
      );
    }
    if (!await file.exists() && !reqPath.endsWith('.html')) {
      final withHtml = File(
        '${dir.path}${Platform.pathSeparator}$reqPath.html',
      );
      if (await withHtml.exists()) file = withHtml;
    }
    if (!await file.exists()) {
      // SPA route fallback
      final indexFile = File('${dir.path}${Platform.pathSeparator}index.html');
      if (await indexFile.exists()) file = indexFile;
    }

    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final mime = _lookupMimeType(file.path);
      return shelf.Response.ok(bytes, headers: {'Content-Type': mime});
    }

    return shelf.Response.notFound('File not found: $reqPath');
  };
}

String _lookupMimeType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.html')) return 'text/html; charset=utf-8';
  if (lower.endsWith('.js')) return 'application/javascript; charset=utf-8';
  if (lower.endsWith('.wasm')) return 'application/wasm';
  if (lower.endsWith('.css')) return 'text/css; charset=utf-8';
  if (lower.endsWith('.json')) return 'application/json; charset=utf-8';
  if (lower.endsWith('.xml')) return 'application/xml; charset=utf-8';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.txt')) return 'text/plain; charset=utf-8';
  return 'application/octet-stream';
}

String _usage(ArgParser parser) =>
    """
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
  preview      Launch local HTTP server to preview generated HTML, assets, and routes.
  report       Generate structured SEO and HTML quality audit report from generated files.
  regression   Compare baseline vs current snapshots for SEO regressions.
  web          Accelerate and analyze Flutter Web (Wasm readiness, bootstrap, bundles).
  html         Validate and inspect static HTML files on disk.
  routes       List, validate, and scaffold route definitions and manifests.
  cache        Inspect and purge build caches and scratch files.

${parser.usage}
""";
