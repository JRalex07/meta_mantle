import 'package:flutter_test/flutter_test.dart';

import '../bin/meta_mantle.dart';

void main() {
  group('MetaMantle CLI Parser integration', () {
    test('defines all 14 top-level command groups', () {
      final parser = buildMetaMantleCliParser();

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
      final parser = buildMetaMantleCliParser();
      final html = parser.commands['html'];
      expect(html, isNotNull);
      expect(html!.commands.containsKey('validate'), isTrue);
      expect(html.commands.containsKey('inspect'), isTrue);

      final val = html.commands['validate']!;
      expect(val.options.containsKey('dir'), isTrue);
      expect(val.options.containsKey('strict'), isTrue);
    });

    test('routes command defines list, validate and generate subcommands', () {
      final parser = buildMetaMantleCliParser();
      final routes = parser.commands['routes'];
      expect(routes, isNotNull);
      expect(routes!.commands.containsKey('list'), isTrue);
      expect(routes.commands.containsKey('validate'), isTrue);
      expect(routes.commands.containsKey('generate'), isTrue);

      final gen = routes.commands['generate']!;
      expect(gen.options.containsKey('output'), isTrue);
    });

    test('cache command defines inspect and clear subcommands', () {
      final parser = buildMetaMantleCliParser();
      final cache = parser.commands['cache'];
      expect(cache, isNotNull);
      expect(cache!.commands.containsKey('inspect'), isTrue);
      expect(cache.commands.containsKey('clear'), isTrue);

      final inspect = cache.commands['inspect']!;
      expect(inspect.options.containsKey('dir'), isTrue);
    });

    test('preview and report define expected directories and flags', () {
      final parser = buildMetaMantleCliParser();

      final preview = parser.commands['preview']!;
      expect(preview.options.containsKey('dir'), isTrue);
      expect(preview.options.containsKey('port'), isTrue);
      expect(preview.options.containsKey('server'), isTrue);

      final report = parser.commands['report']!;
      expect(report.options.containsKey('dir'), isTrue);
      expect(report.options.containsKey('json'), isTrue);
    });
  });
}
