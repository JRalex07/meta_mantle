import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('build')
    ..addCommand('validate')
    ..addCommand('inspect')
    ..addCommand('doctor')
    ..addFlag('help', abbr: 'h', negatable: false);

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

  try {
    final result = parser.parse(arguments);
    if (result['help'] == true ||
        result.command == null ||
        result.command!['help'] == true) {
      stdout.writeln(_usage(parser));
      return;
    }

    final command = result.command!;
    var configPath = command['config'] as String;
    var configFile = File(configPath);

    // If default was used and meta_mantle.config.json does not exist, check fallback web_head.config.json
    if (!await configFile.exists() &&
        configPath == 'meta_mantle.config.json' &&
        await File('web_head.config.json').exists()) {
      configPath = 'web_head.config.json';
      configFile = File(configPath);
    }

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
      throw FileSystemException('Config file does not exist', configPath);
    }
    final config = await StaticHeadConfig.load(configFile);

    if (command.name == 'validate') {
      final warnings = await const StaticHeadBuilder().validateConfiguration(
        config: config,
        configFile: configFile,
      );
      stdout.writeln('Configuration is structurally valid.');
      stdout.writeln('Explicit routes: ${config.routes.length}');
      stdout.writeln('Dynamic patterns: ${config.patterns.length}');
      for (final warning in warnings) {
        stderr.writeln('WARNING: $warning');
      }
      return;
    }

    if (command.name == 'inspect') {
      final inspection = await const StaticHeadBuilder().inspectConfiguration(
        config: config,
        configFile: configFile,
      );
      stdout.writeln('=== MetaMantle Route Inspector ===');
      stdout.writeln('Base URL: ${config.baseUrl}');
      stdout.writeln('Total resolved routes: ${inspection.routes.length}');
      stdout.writeln(
          'Dynamic patterns expanded: ${inspection.dynamicPatternCount}');
      stdout.writeln('Sitemap URL count: ${inspection.sitemapUrls.length}\n');
      stdout.writeln('Resolved routes:');
      for (final route in inspection.routes) {
        stdout.writeln('  $route');
      }
      if (inspection.warnings.isNotEmpty) {
        stdout.writeln('\nWarnings:');
        for (final warning in inspection.warnings) {
          stderr.writeln('  WARNING: $warning');
        }
      }
      return;
    }

    // Build command
    final input = Directory(command['input'] as String);
    final output = Directory(command['output'] as String);
    final isDryRun = command['dry-run'] as bool;
    final isVerbose = command['verbose'] as bool;
    final effectiveConfig = StaticHeadConfig(
      baseUrl: config.baseUrl,
      defaults: config.defaults,
      siteName: config.siteName,
      titleTemplate: config.titleTemplate,
      defaultImage: config.defaultImage,
      defaultRobots: config.defaultRobots,
      themeColor: config.themeColor,
      language: config.language,
      trailingSlash: config.trailingSlash,
      routes: config.routes,
      patterns: config.patterns,
      sitemap: command['no-sitemap'] == true ? false : config.sitemap,
      robotsTxt: command['no-robots'] == true ? false : config.robotsTxt,
    );

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
  build     Generate route-specific HTML documents from a Flutter build.
  validate  Validate the JSON route configuration.
  inspect   Display all resolved routes and metadata without writing files.
  doctor    Diagnose project configuration and build readiness.

Build options:
  --config <file>  Config JSON (default: meta_mantle.config.json)
  --input <dir>    Flutter build directory (default: build/web)
  --output <dir>   Output directory (default: build/web)
  --strict         Fail when metadata warnings are found.
  --dry-run        Simulate file generation without writing to disk.
  --verbose, -v    Print detailed progress during generation.
  --no-sitemap     Do not generate sitemap.xml.
  --no-robots      Do not generate robots.txt.

${parser.usage}
""";
