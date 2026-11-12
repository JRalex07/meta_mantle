import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';

void main() {
  group('StaticHeadBuilder', () {
    test(
      'generates route HTML, preserves bootstrap, and writes sitemap',
      () async {
        final temp = await Directory.systemTemp.createTemp('fwh_test_');
        addTearDown(() => temp.delete(recursive: true));
        final input = Directory('${temp.path}/input')..createSync();
        final output = Directory('${temp.path}/output')..createSync();
        File('${input.path}/index.html').writeAsStringSync('''
<!doctype html><html><head><base href="/">
<title>App</title><meta name="description" content="Default">
</head><body><script src="flutter_bootstrap.js" async></script></body></html>
''');
        final config = StaticHeadConfig(
          baseUrl: 'https://example.com',
          routes: const [
            StaticRoute(
              path: '/',
              metadata: WebMetadata(
                title: 'Home',
                description: 'Home description',
              ),
            ),
            StaticRoute(
              path: '/about',
              metadata: WebMetadata(
                title: 'About',
                description: 'About description',
              ),
            ),
          ],
        );

        final result = await const StaticHeadBuilder().build(
          inputDirectory: input,
          outputDirectory: output,
          config: config,
        );
        expect(result.routes, contains('/about/'));
        final about = File('${output.path}/about/index.html')
            .readAsStringSync();
        expect(about, contains('<title>About</title>'));
        expect(about, contains('flutter_bootstrap.js'));
        expect(about, contains('https://example.com/about/'));
        expect(File('${output.path}/sitemap.xml').existsSync(), isTrue);
      },
    );

    test('supports inline Flutter bootstrap tokens and preserves unrelated attributes', () async {
      final temp = await Directory.systemTemp.createTemp(
        'fwh_inline_bootstrap_',
      );
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      final output = Directory('${temp.path}/output')..createSync();
      File('${input.path}/index.html').writeAsStringSync('''
<!doctype html><html><head>
<meta name="description" content="Default" data-keep="original">
</head><body><script>
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load();
</script></body></html>
''');

      await const StaticHeadBuilder().build(
        inputDirectory: input,
        outputDirectory: output,
        config: const StaticHeadConfig(
          baseUrl: 'https://example.com',
          routes: [
            StaticRoute(
              path: '/',
              metadata: WebMetadata(
                title: 'Home',
                description: 'Route description',
              ),
            ),
          ],
        ),
      );
      final html = File('${output.path}/index.html').readAsStringSync();
      expect(html, contains('{{flutter_js}}'));
      expect(html, contains('_flutter.loader.load();'));
      expect(html, contains('data-keep="original"'));
      expect(html, contains('content="Route description"'));
    });

    test('rejects route traversal', () async {
      final temp = await Directory.systemTemp.createTemp('fwh_test_');
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      final output = Directory('${temp.path}/output')..createSync();
      File('${input.path}/index.html').writeAsStringSync(
        '<html><head></head><body><script src="flutter_bootstrap.js"></script></body></html>',
      );

      await expectLater(
        const StaticHeadBuilder().build(
          inputDirectory: input,
          outputDirectory: output,
          config: const StaticHeadConfig(
            baseUrl: 'https://example.com',
            routes: [
              StaticRoute(
                path: '/../oops',
                metadata: WebMetadata(title: 'Oops'),
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
    });

    test('copies Flutter assets to a separate output directory', () async {
      final temp = await Directory.systemTemp.createTemp('fwh_copy_test_');
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      final output = Directory('${temp.path}/output');
      File('${input.path}/index.html').writeAsStringSync(
        '<html><head></head><body><script src="flutter_bootstrap.js"></script></body></html>',
      );
      Directory('${input.path}/assets').createSync();
      File('${input.path}/assets/app.bin').writeAsStringSync('asset');

      await const StaticHeadBuilder().build(
        inputDirectory: input,
        outputDirectory: output,
        config: const StaticHeadConfig(
          baseUrl: 'https://example.com',
          routes: [
            StaticRoute(
              path: '/',
              metadata: WebMetadata(title: 'Home', description: 'Home'),
            ),
          ],
        ),
      );

      expect(File('${output.path}/assets/app.bin').readAsStringSync(), 'asset');
      expect(File('${output.path}/index.html').existsSync(), isTrue);
    });

    test('strict mode fails before creating output files', () async {
      final temp = await Directory.systemTemp.createTemp('fwh_strict_test_');
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      final output = Directory('${temp.path}/output');
      File('${input.path}/index.html').writeAsStringSync(
        '<html><head></head><body><script src="flutter_bootstrap.js"></script></body></html>',
      );

      await expectLater(
        const StaticHeadBuilder().build(
          inputDirectory: input,
          outputDirectory: output,
          strict: true,
          config: const StaticHeadConfig(
            baseUrl: 'https://example.com',
            routes: [
              StaticRoute(
                path: '/',
                metadata: WebMetadata(title: 'No description'),
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(output.existsSync(), isFalse);
    });

    test('omits noindex routes from sitemap', () async {
      final temp = await Directory.systemTemp.createTemp('fwh_sitemap_test_');
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      final output = Directory('${temp.path}/output')..createSync();
      File('${input.path}/index.html').writeAsStringSync(
        '<html><head></head><body><script src="flutter_bootstrap.js"></script></body></html>',
      );

      await const StaticHeadBuilder().build(
        inputDirectory: input,
        outputDirectory: output,
        config: const StaticHeadConfig(
          baseUrl: 'https://example.com',
          routes: [
            StaticRoute(
              path: '/',
              metadata: WebMetadata(title: 'Home', description: 'Home'),
            ),
            StaticRoute(
              path: '/private',
              metadata: WebMetadata(
                title: 'Private',
                description: 'Private',
                robots: 'noindex, nofollow',
              ),
            ),
            StaticRoute(
              path: '/hidden',
              metadata: WebMetadata(
                title: 'Hidden',
                description: 'Hidden',
                robots: 'none',
              ),
            ),
          ],
        ),
      );
      final sitemap = File('${output.path}/sitemap.xml').readAsStringSync();
      expect(sitemap, contains('https://example.com/'));
      expect(sitemap, isNot(contains('/private/')));
      expect(sitemap, isNot(contains('/hidden/')));
    });

    test('expands JSON data into static product pages', () async {
      final temp = await Directory.systemTemp.createTemp('fwh_pattern_test_');
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      final output = Directory('${temp.path}/output')..createSync();
      final configFile = File('${temp.path}/web_head.config.json');
      File('${input.path}/index.html').writeAsStringSync(
        '<html><head></head><body><script src="flutter_bootstrap.js"></script></body></html>',
      );
      File('${temp.path}/products.json').writeAsStringSync('''
[
  {
    "slug": "basmati-rice",
    "name": "Premium Basmati Rice",
    "description": "Long grain rice.",
    "image": "https://example.com/rice.png"
  }
]
''');

      final config = StaticHeadConfig(
        baseUrl: 'https://example.com',
        patterns: const [
          StaticRoutePattern(
            pathPattern: '/products/:slug',
            dataFile: 'products.json',
            metadataTemplate: {
              'title': '{{name}}',
              'description': '{{description}}',
              'openGraph': {'type': 'product', 'image': '{{image}}'},
            },
          ),
        ],
      );
      final result = await const StaticHeadBuilder().build(
        inputDirectory: input,
        outputDirectory: output,
        config: config,
        configFile: configFile,
      );

      expect(result.routes, contains('/products/basmati-rice/'));
      final product = File('${output.path}/products/basmati-rice/index.html')
          .readAsStringSync();
      expect(product, contains('<title>Premium Basmati Rice</title>'));
      expect(product, contains('Long grain rice.'));
    });

    test('rejects output folders nested inside input folders', () async {
      final temp = await Directory.systemTemp.createTemp('fwh_nested_test_');
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      File('${input.path}/index.html').writeAsStringSync(
        '<html><head></head><body><script src="flutter_bootstrap.js"></script></body></html>',
      );

      await expectLater(
        const StaticHeadBuilder().build(
          inputDirectory: input,
          outputDirectory: Directory('${input.path}/generated'),
          config: const StaticHeadConfig(
            baseUrl: 'https://example.com',
            routes: [
              StaticRoute(
                path: '/',
                metadata: WebMetadata(title: 'Home'),
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
    });
  });
}
