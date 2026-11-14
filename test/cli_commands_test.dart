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

    test('routes generate creates valid manifest template on disk', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'mm_cli_routes_test_',
      );
      try {
        final targetPath = '${tempDir.path}/test_routes.dart';
        final parser = cli.buildMetaMantleCliParser();
        final results = parser.parse([
          'routes',
          'generate',
          '--output',
          targetPath,
        ]);

        expect(results.command?.name, equals('routes'));
        expect(results.command?.command?.name, equals('generate'));
        expect(results.command?.command?['output'], equals(targetPath));

        // Execute generation logic
        final file = File(targetPath);
        expect(await file.exists(), isFalse);

        await cli.main(['routes', 'generate', '--output', targetPath]);

        expect(await file.exists(), isTrue);
        final content = await file.readAsString();
        expect(content, contains('StaticRouteManifest'));
        expect(content, contains('MantleHeading'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('cache clear removes cached files from directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('mm_cli_cache_test_');
      try {
        final dummyFile1 = File('${tempDir.path}/cache1.bin')
          ..writeAsStringSync('data1');
        final dummyFile2 = File('${tempDir.path}/cache2.bin')
          ..writeAsStringSync('data2');

        expect(dummyFile1.existsSync(), isTrue);
        expect(dummyFile2.existsSync(), isTrue);

        await cli.main(['cache', 'clear', '--dir', tempDir.path]);

        expect(dummyFile1.existsSync(), isFalse);
        expect(dummyFile2.existsSync(), isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
