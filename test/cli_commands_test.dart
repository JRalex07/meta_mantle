import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../bin/meta_mantle.dart' as cli;

void main() {
  group('MetaMantle CLI Parser integration', () {
    test('defines all 14 top-level command groups', () {
      final parser = cli.buildMetaMantleCliParser();

      final expectedCommands = [
        'build',
        'build-web',
        'validate',
        'inspect',
        'doctor',
        'inspect-url',
        'crawl',
        'preview',
        'report',
        'regression',
        'web',
        'html',
        'routes',
        'cache',
      ];

      for (final cmd in expectedCommands) {
        expect(
          parser.commands.containsKey(cmd),
          isTrue,
          reason: 'Parser should define "$cmd" command group',
        );
      }
    });

    test('html command defines validate and inspect subcommands', () {
      final parser = cli.buildMetaMantleCliParser();
      final html = parser.commands['html'];
      expect(html, isNotNull);
      expect(html!.commands.containsKey('validate'), isTrue);
      expect(html.commands.containsKey('inspect'), isTrue);

      final val = html.commands['validate']!;
      expect(val.options.containsKey('dir'), isTrue);
      expect(val.options.containsKey('strict'), isTrue);

      final inspect = html.commands['inspect']!;
      expect(inspect.options.containsKey('file'), isTrue);
      expect(inspect.options.containsKey('json'), isTrue);
    });

    test('routes command defines list, validate and generate subcommands', () {
      final parser = cli.buildMetaMantleCliParser();
      final routes = parser.commands['routes'];
      expect(routes, isNotNull);
      expect(routes!.commands.containsKey('list'), isTrue);
      expect(routes.commands.containsKey('validate'), isTrue);
      expect(routes.commands.containsKey('generate'), isTrue);

      final gen = routes.commands['generate']!;
      expect(gen.options.containsKey('output'), isTrue);
    });

    test('cache command defines inspect and clear subcommands', () {
      final parser = cli.buildMetaMantleCliParser();
      final cache = parser.commands['cache'];
      expect(cache, isNotNull);
      expect(cache!.commands.containsKey('inspect'), isTrue);
      expect(cache.commands.containsKey('clear'), isTrue);

      final inspect = cache.commands['inspect']!;
      expect(inspect.options.containsKey('dir'), isTrue);
    });

    test('preview and report define expected directories and flags', () {
      final parser = cli.buildMetaMantleCliParser();

      final preview = parser.commands['preview']!;
      expect(preview.options.containsKey('dir'), isTrue);
      expect(preview.options.containsKey('port'), isTrue);
      expect(preview.options.containsKey('server'), isTrue);

      final report = parser.commands['report']!;
      expect(report.options.containsKey('dir'), isTrue);
      expect(report.options.containsKey('json'), isTrue);
    });

    test('doctor and validate support --json flag', () {
      final parser = cli.buildMetaMantleCliParser();

      final doc = parser.commands['doctor']!;
      expect(doc.options.containsKey('json'), isTrue);

      final val = parser.commands['validate']!;
      expect(val.options.containsKey('json'), isTrue);
    });

    test(
      'inspect-url and regression define mandatory options and json flag',
      () {
        final parser = cli.buildMetaMantleCliParser();

        final url = parser.commands['inspect-url']!;
        expect(url.options.containsKey('url'), isTrue);
        expect(url.options['url']!.mandatory, isTrue);
        expect(url.options.containsKey('json'), isTrue);

        final reg = parser.commands['regression']!;
        expect(reg.options.containsKey('baseline'), isTrue);
        expect(reg.options['baseline']!.mandatory, isTrue);
        expect(reg.options.containsKey('current'), isTrue);
        expect(reg.options['current']!.mandatory, isTrue);
        expect(reg.options.containsKey('json'), isTrue);
      },
    );
  });

  group('MetaMantle CLI Executable Integration Tests', () {
    late Directory tempDir;
    late File configFile;
    late Directory webInputDir;

    setUp(() {
      exitCode = 0;
      tempDir = Directory.systemTemp.createTempSync('mm_cli_exec_test_');

      // Create a valid config
      configFile = File('${tempDir.path}/meta_mantle.config.json');
      configFile.writeAsStringSync(
        jsonEncode({
          'baseUrl': 'https://example.com',
          'siteName': 'Test Site',
          'routes': [
            {
              'path': '/',
              'metadata': {
                'title': 'Home',
                'description': 'Home page description',
              },
            },
            {
              'path': '/about',
              'metadata': {
                'title': 'About',
                'description': 'About page description',
              },
            },
          ],
          'patterns': [
            {
              'pathPattern': '/items/:id',
              'dataFile': 'items.json',
              'slugField': 'id',
              'metadataTemplate': {
                'title': 'Item {{name}}',
                'description': 'Description for {{name}}',
              },
            },
          ],
        }),
      );

      // Create items.json in tempDir
      File('${tempDir.path}/items.json').writeAsStringSync(
        jsonEncode([
          {'id': '1', 'name': 'First Item'},
          {'id': '2', 'name': 'Second Item'},
        ]),
      );

      // Create a valid web input directory with index.html containing flutter_bootstrap.js
      webInputDir = Directory('${tempDir.path}/build/web');
      webInputDir.createSync(recursive: true);
      File('${webInputDir.path}/index.html').writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <title>App</title>
  <meta name="description" content="Initial">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''');
    });

    tearDown(() {
      exitCode = 0;
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('doctor executes diagnostics and supports --json', () async {
      await cli.main([
        'doctor',
        '--config',
        configFile.path,
        '--input',
        webInputDir.path,
      ]);
      expect(exitCode, equals(0));

      await cli.main([
        'doctor',
        '--config',
        configFile.path,
        '--input',
        webInputDir.path,
        '--json',
      ]);
      expect(exitCode, equals(0));

      // Missing input directory
      await cli.main([
        'doctor',
        '--config',
        configFile.path,
        '--input',
        '${tempDir.path}/nonexistent_dir',
      ]);
      expect(exitCode, equals(1));
    });

    test(
      'validate verifies configuration structure and supports --json',
      () async {
        await cli.main(['validate', '--config', configFile.path]);
        expect(exitCode, equals(0));

        await cli.main(['validate', '--config', configFile.path, '--json']);
        expect(exitCode, equals(0));
      },
    );

    test('inspect prints configured routes and dynamic patterns', () async {
      await cli.main(['inspect', '--config', configFile.path]);
      expect(exitCode, equals(0));
    });

    test('build executes dry-run static head generation', () async {
      final outDir = Directory('${tempDir.path}/dist');
      await cli.main([
        'build',
        '--config',
        configFile.path,
        '--input',
        webInputDir.path,
        '--output',
        outDir.path,
        '--dry-run',
      ]);
      expect(exitCode, equals(0));
    });

    test(
      'build executes full static generation with --no-sitemap and --no-robots',
      () async {
        final outDir = Directory('${tempDir.path}/dist_nobots');
        await cli.main([
          'build',
          '--config',
          configFile.path,
          '--input',
          webInputDir.path,
          '--output',
          outDir.path,
          '--no-sitemap',
          '--no-robots',
        ]);
        expect(exitCode, equals(0));
        expect(File('${outDir.path}/index.html').existsSync(), isTrue);
        expect(File('${outDir.path}/about/index.html').existsSync(), isTrue);
        expect(File('${outDir.path}/sitemap.xml').existsSync(), isFalse);
        expect(File('${outDir.path}/robots.txt').existsSync(), isFalse);
      },
    );

    test('build-web executes dry-run in all three modes', () async {
      // Mock Flutter project structure
      File('${tempDir.path}/pubspec.yaml')
          .writeAsStringSync('name: test_app\n');
      Directory('${tempDir.path}/web').createSync();
      File('${tempDir.path}/web/index.html')
          .writeAsStringSync('<html><head></head><body></body></html>');

      for (final mode in ['metadata', 'prerender', 'hybrid']) {
        await cli.main([
          'build-web',
          '--project-dir',
          tempDir.path,
          '--config',
          configFile.path,
          '--mode',
          mode,
          '--output',
          '${tempDir.path}/build/web_$mode',
          '--dry-run',
        ]);
        expect(exitCode, equals(0));
      }
    });

    test(
      'report audits on-disk generated HTML directory and supports --json',
      () async {
        // Create test HTML files in a directory
        final reportDir = Directory('${tempDir.path}/report_target');
        reportDir.createSync();
        File('${reportDir.path}/index.html').writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <title>Home</title>
  <meta name="description" content="Desc">
  <link rel="canonical" href="https://example.com/">
  <meta property="og:title" content="Home">
  <script type="application/ld+json">{"@type":"WebSite"}</script>
</head>
<body>
  <h1>Heading 1</h1>
  <img src="/logo.png" alt="Logo">
</body>
</html>
''');
        File('${reportDir.path}/sitemap.xml')
            .writeAsStringSync('<urlset></urlset>');
        File('${reportDir.path}/robots.txt').writeAsStringSync('User-agent: *');

        await cli.main([
          'report',
          '--config',
          configFile.path,
          '--dir',
          reportDir.path,
        ]);
        expect(exitCode, equals(0));

        await cli.main([
          'report',
          '--config',
          configFile.path,
          '--dir',
          reportDir.path,
          '--json',
        ]);
        expect(exitCode, equals(0));

        // Fallback audit when directory does not exist
        await cli.main([
          'report',
          '--config',
          configFile.path,
          '--dir',
          '${tempDir.path}/missing_dir',
        ]);
        expect(exitCode, equals(0));
      },
    );

    test(
      'preview executes metadata preview fallback when server is disabled',
      () async {
        await cli.main([
          'preview',
          '--config',
          configFile.path,
          '--route',
          '/about',
          '--no-server',
        ]);
        expect(exitCode, equals(0));
      },
    );

    test('crawl audits running HTTP server routes', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(
            '<!DOCTYPE html><html><head><title>Test Crawl</title></head><body><h1>OK</h1></body></html>',
          );
        req.response.close();
      });

      try {
        await cli.main([
          'crawl',
          '--config',
          configFile.path,
          '--base-url',
          'http://127.0.0.1:${server.port}',
          '--allow-localhost',
        ]);
        expect(exitCode, equals(0));
      } finally {
        await server.close(force: true);
      }
    });

    test('regression compares SEO snapshots and detects regressions', () async {
      final baselineFile = File('${tempDir.path}/baseline.json');
      final currentFile = File('${tempDir.path}/current.json');

      final baselineData = [
        {
          'url': 'https://example.com/',
          'statusCode': 200,
          'title': 'Original Title',
          'description': 'Original Description',
        },
      ];
      baselineFile.writeAsStringSync(jsonEncode(baselineData));

      // 1. Identical current snapshot (pass)
      currentFile.writeAsStringSync(jsonEncode(baselineData));
      await cli.main([
        'regression',
        '--baseline',
        baselineFile.path,
        '--current',
        currentFile.path,
      ]);
      expect(exitCode, equals(0));

      // 2. Regressed current snapshot (missing title)
      final regressedData = [
        {
          'url': 'https://example.com/',
          'statusCode': 200,
          'title': '', // empty title triggers CRITICAL regression
          'description': 'Original Description',
        },
      ];
      currentFile.writeAsStringSync(jsonEncode(regressedData));
      await cli.main([
        'regression',
        '--baseline',
        baselineFile.path,
        '--current',
        currentFile.path,
        '--json',
      ]);
      expect(exitCode, equals(1));
    });

    test('inspect-url analyzes live HTTP response without JS', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('''
<!DOCTYPE html>
<html>
<head>
  <title>Inspected Title</title>
  <meta name="description" content="Inspected Description">
  <link rel="canonical" href="http://127.0.0.1:${server.port}/">
</head>
<body><h1>Heading</h1></body>
</html>
''');
        req.response.close();
      });

      try {
        await cli.main([
          'inspect-url',
          '--url',
          'http://127.0.0.1:${server.port}/',
          '--allow-localhost',
        ]);
        expect(exitCode, equals(0));

        await cli.main([
          'inspect-url',
          '--url',
          'http://127.0.0.1:${server.port}/',
          '--allow-localhost',
          '--json',
        ]);
        expect(exitCode, equals(0));
      } finally {
        await server.close(force: true);
      }
    });

    test(
      'html validate verifies HTML files in directory and handles errors',
      () async {
        final htmlDir = Directory('${tempDir.path}/html_val');
        htmlDir.createSync();

        File('${htmlDir.path}/valid.html').writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <title>Valid</title>
  <meta name="description" content="Valid desc">
  <link rel="canonical" href="https://example.com/valid">
</head>
<body></body>
</html>
''');

        await cli.main(['html', 'validate', '--dir', htmlDir.path]);
        expect(exitCode, equals(0));

        // Strict failure on invalid HTML
        File('${htmlDir.path}/invalid.html').writeAsStringSync('''
<!DOCTYPE html>
<html>
<head></head>
<body></body>
</html>
''');

        await cli.main(['html', 'validate', '--dir', htmlDir.path, '--strict']);
        expect(exitCode, equals(1));
        exitCode = 0;

        // Nonexistent directory
        await cli.main([
          'html',
          'validate',
          '--dir',
          '${tempDir.path}/missing',
        ]);
        expect(exitCode, equals(1));
      },
    );

    test('html inspect extracts semantic tags and supports --json', () async {
      final htmlFile = File('${tempDir.path}/test_inspect.html');
      htmlFile.writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <title>Inspected Page</title>
  <meta name="description" content="Page description">
  <link rel="canonical" href="https://example.com/inspected">
  <meta name="robots" content="index, follow">
  <meta property="og:title" content="OG Title">
  <meta property="og:image" content="https://example.com/og.png">
  <script type="application/ld+json">{"@type":"Product"}</script>
</head>
<body>
  <h1>Primary Heading</h1>
  <h2>Secondary Heading</h2>
</body>
</html>
''');

      await cli.main(['html', 'inspect', '--file', htmlFile.path]);
      expect(exitCode, equals(0));

      await cli.main(['html', 'inspect', '--file', htmlFile.path, '--json']);
      expect(exitCode, equals(0));

      // Nonexistent file
      await cli.main([
        'html',
        'inspect',
        '--file',
        '${tempDir.path}/missing.html',
      ]);
      expect(exitCode, equals(1));
    });

    test(
      'routes list and validate commands inspect route definitions',
      () async {
        await cli.main(['routes', 'list', '--config', configFile.path]);
        expect(exitCode, equals(0));

        await cli.main(['routes', 'validate', '--config', configFile.path]);
        expect(exitCode, equals(0));

        // Malformed route configuration
        final badConfigFile = File('${tempDir.path}/bad_routes.json');
        badConfigFile.writeAsStringSync(
          jsonEncode({
            'baseUrl': 'https://example.com',
            'routes': [
              {'path': 'missing_slash'},
            ],
            'patterns': [
              {'pathPattern': 'missing_slash_pattern'},
            ],
          }),
        );

        await cli.main(['routes', 'validate', '--config', badConfigFile.path]);
        expect(exitCode, equals(2));
      },
    );

    test(
      'routes generate creates template and respects existing files',
      () async {
        final genFile = File('${tempDir.path}/generated_manifest.dart');
        expect(genFile.existsSync(), isFalse);

        await cli.main(['routes', 'generate', '--output', genFile.path]);
        expect(exitCode, equals(0));
        expect(genFile.existsSync(), isTrue);

        // Running on existing file does not overwrite
        await cli.main(['routes', 'generate', '--output', genFile.path]);
        expect(exitCode, equals(0));
      },
    );

    test('cache inspect and clear purge storage directories', () async {
      final cacheDir = Directory('${tempDir.path}/cache_store');
      cacheDir.createSync();

      File('${cacheDir.path}/item1.bin').writeAsStringSync('data1');
      File('${cacheDir.path}/item2.bin').writeAsStringSync('data2');

      await cli.main(['cache', 'inspect', '--dir', cacheDir.path]);
      expect(exitCode, equals(0));

      await cli.main(['cache', 'clear', '--dir', cacheDir.path]);
      expect(exitCode, equals(0));
      expect(cacheDir.listSync().isEmpty, isTrue);

      // Running on already empty or nonexistent dir
      await cli.main([
        'cache',
        'clear',
        '--dir',
        '${tempDir.path}/nonexistent_cache',
      ]);
      expect(exitCode, equals(0));
    });

    test('web analyze, build and report commands generate optimization recommendations', () async {
      await cli.main(['web', 'analyze', '--project-dir', tempDir.path]);
      expect(exitCode, equals(0));

      await cli.main([
        'web',
        'analyze',
        '--project-dir',
        tempDir.path,
        '--json',
      ]);
      expect(exitCode, equals(0));

      await cli.main(['web', 'build', '--project-dir', tempDir.path]);
      expect(exitCode, equals(0));

      await cli.main(['web', 'report', '--project-dir', tempDir.path]);
      expect(exitCode, equals(0));

      await cli.main([
        'web',
        'report',
        '--project-dir',
        tempDir.path,
        '--json',
      ]);
      expect(exitCode, equals(0));
    });

    test(
      'top-level --help and command --help print usage without error',
      () async {
        await cli.main(['--help']);
        expect(exitCode, equals(0));

        for (final cmd in [
          'doctor',
          'validate',
          'inspect',
          'build',
          'build-web',
          'report',
          'preview',
          'crawl',
          'regression',
          'inspect-url',
          'web',
          'html',
          'routes',
          'cache',
        ]) {
          await cli.main([cmd, '--help']);
          expect(exitCode, equals(0));
        }
      },
    );
  });
}
