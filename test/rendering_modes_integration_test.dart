import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:meta_mantle/meta_mantle.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';

void main() {
  group('Rendering Modes Integration Tests', () {
    late Directory tempDir;
    late Directory projectDir;
    late Directory webDir;
    late File pubspecFile;
    late File indexHtmlFile;

    const dummyIndexHtml = '''
<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <title>Default App</title>
</head>
<body>
  <div id="flutter_app"></div>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mm_render_modes_test_');
      projectDir = Directory('${tempDir.path}/sample_project')
        ..createSync(recursive: true);
      webDir = Directory('${projectDir.path}/web')..createSync(recursive: true);

      pubspecFile = File('${projectDir.path}/pubspec.yaml');
      pubspecFile.writeAsStringSync('''
name: sample_project
environment:
  sdk: '>=3.6.0 <4.0.0'
''');

      indexHtmlFile = File('${webDir.path}/index.html');
      indexHtmlFile.writeAsStringSync(dummyIndexHtml);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Mode A (Metadata Only) injects SEO tags without prerender container or handshake', () async {
      final manifest = StaticRouteManifest();
      manifest.register(
        StaticPageRoute(
          path: '/',
          metadata: const WebMetadata(
            title: 'Home Page',
            description: 'SEO Optimized Home Page',
            canonical: 'https://example.com/',
          ),
          componentBuilder: (ctx) =>
              MantleText('Should not be in DOM for Mode A'),
        ),
      );

      final engine = FlutterWebBuildEngine(
        processRunner: (exe, args, {environment, workingDirectory}) async =>
            ProcessResult(100, 0, '', ''),
      );
      final options = BuildWebOptions(
        projectDir: projectDir.path,
        mode: BuildMode.metadata,
        dryRun: false,
        strict: false,
      );

      // Process runner mock so flutter build web is bypassed
      final result = await engine.build(options, routeManifest: manifest);

      expect(result.success, isTrue);
      expect(result.mode, equals(BuildMode.metadata));

      final indexGenerated = File('${projectDir.path}/build/web/index.html');
      expect(indexGenerated.existsSync(), isTrue);

      final html = indexGenerated.readAsStringSync();
      final doc = html_parser.parse(html);

      // Head metadata verification
      expect(doc.querySelector('title')?.text, equals('Home Page'));
      expect(
        doc.querySelector('meta[name="description"]')?.attributes['content'],
        equals('SEO Optimized Home Page'),
      );
      expect(
        doc.querySelector('link[rel="canonical"]')?.attributes['href'],
        equals('https://example.com/'),
      );

      // Prerender container and style checks
      expect(doc.querySelector('#mantle-prerender-root'), isNull);
      expect(doc.querySelector('#mantle-prerender-style'), isNull);
      expect(doc.querySelector('#mantle-startup-bridge'), isNull);
      expect(html.contains('Should not be in DOM for Mode A'), isFalse);
    });

    test('Mode B (Prerender) injects semantic component HTML and styles without handshake script', () async {
      final manifest = StaticRouteManifest();
      manifest.register(
        StaticPageRoute(
          path: '/',
          metadata: const WebMetadata(
            title: 'Catalog Page',
            description: 'Prerendered Product Catalog',
          ),
          componentBuilder: (ctx) => MantleColumn(
            children: [
              MantleText('Featured Products'),
              MantleButton(label: 'Buy Now', onPressed: () {}),
            ],
          ),
        ),
      );

      final engine = FlutterWebBuildEngine(
        processRunner: (exe, args, {environment, workingDirectory}) async =>
            ProcessResult(100, 0, '', ''),
      );
      final options = BuildWebOptions(
        projectDir: projectDir.path,
        mode: BuildMode.prerender,
        dryRun: false,
        strict: false,
      );

      final result = await engine.build(options, routeManifest: manifest);

      expect(result.success, isTrue);
      expect(result.mode, equals(BuildMode.prerender));

      final indexGenerated = File('${projectDir.path}/build/web/index.html');
      expect(indexGenerated.existsSync(), isTrue);

      final html = indexGenerated.readAsStringSync();
      final doc = html_parser.parse(html);

      // Head checks
      expect(doc.querySelector('title')?.text, equals('Catalog Page'));
      expect(doc.querySelector('#mantle-prerender-style'), isNotNull);

      // Body checks: root container exists and contains semantic nodes
      final root = doc.querySelector('#mantle-prerender-root');
      expect(root, isNotNull);
      expect(root!.text, contains('Featured Products'));
      expect(root.querySelector('button'), isNotNull);
      expect(root.querySelector('button')!.text, contains('Buy Now'));

      // Handshake script should NOT be present in pure prerender mode
      expect(doc.querySelector('#mantle-startup-bridge'), isNull);
      expect(html.contains('window.__mantleClientReady'), isFalse);
    });

    test('Mode C (Hybrid) injects semantic HTML and coordinated client handshake script', () async {
      final manifest = StaticRouteManifest();
      manifest.register(
        StaticPageRoute(
          path: '/dashboard',
          metadata: const WebMetadata(
            title: 'User Dashboard',
            description: 'Hybrid SEO and Client Dashboard',
          ),
          componentBuilder: (ctx) =>
              MantleContainer(child: MantleText('Welcome to your Dashboard')),
        ),
      );

      final engine = FlutterWebBuildEngine(
        processRunner: (exe, args, {environment, workingDirectory}) async =>
            ProcessResult(100, 0, '', ''),
      );
      final options = BuildWebOptions(
        projectDir: projectDir.path,
        mode: BuildMode.hybrid,
        dryRun: false,
        strict: false,
      );

      final result = await engine.build(options, routeManifest: manifest);

      expect(result.success, isTrue);
      expect(result.mode, equals(BuildMode.hybrid));

      final dashGenerated = File(
        '${projectDir.path}/build/web/dashboard/index.html',
      );
      expect(dashGenerated.existsSync(), isTrue);

      final html = dashGenerated.readAsStringSync();
      final doc = html_parser.parse(html);

      // Head checks
      expect(doc.querySelector('title')?.text, equals('User Dashboard'));
      expect(doc.querySelector('#mantle-prerender-style'), isNotNull);

      // Body checks
      final root = doc.querySelector('#mantle-prerender-root');
      expect(root, isNotNull);
      expect(root!.text, contains('Welcome to your Dashboard'));

      // Handshake script MUST be present in hybrid mode
      final bridge = doc.querySelector('#mantle-startup-bridge');
      expect(bridge, isNotNull);
      expect(bridge!.innerHtml, contains('__mantleClientReady'));
      expect(bridge.innerHtml, contains('mantle-prerender-root'));
    });

    test('Dynamic route generation resolves data source and outputs distinct static HTML', () async {
      final manifest = StaticRouteManifest();
      manifest.registerDynamic<Map<String, String>>(
        pathPattern: '/items/:id',
        items: [
          {'id': '101', 'title': 'Widget A', 'price': r'$19.99'},
          {'id': '102', 'title': 'Widget B', 'price': r'$29.99'},
        ],
        slugExtractor: (item) => item['id']!,
        metadataBuilder: (item) => WebMetadata(
          title: 'Product - ${item['title']}',
          description: 'Price is ${item['price']}',
        ),
        componentBuilder: (item, ctx) => MantleColumn(
          children: [
            MantleText('Product: ${item['title']}'),
            MantleText('Cost: ${item['price']}'),
          ],
        ),
      );

      final engine = FlutterWebBuildEngine(
        processRunner: (exe, args, {environment, workingDirectory}) async =>
            ProcessResult(100, 0, '', ''),
      );
      final options = BuildWebOptions(
        projectDir: projectDir.path,
        mode: BuildMode.prerender,
        dryRun: false,
        strict: false,
      );

      final result = await engine.build(options, routeManifest: manifest);

      expect(result.success, isTrue);
      expect(result.routes, containsAll(['/items/101', '/items/102']));

      final file101 = File('${projectDir.path}/build/web/items/101/index.html');
      final file102 = File('${projectDir.path}/build/web/items/102/index.html');

      expect(file101.existsSync(), isTrue);
      expect(file102.existsSync(), isTrue);

      final doc101 = html_parser.parse(file101.readAsStringSync());
      final doc102 = html_parser.parse(file102.readAsStringSync());

      expect(doc101.querySelector('title')?.text, equals('Product - Widget A'));
      expect(doc101.body!.text, contains('Product: Widget A'));
      expect(doc101.body!.text, contains(r'Cost: $19.99'));

      expect(doc102.querySelector('title')?.text, equals('Product - Widget B'));
      expect(doc102.body!.text, contains('Product: Widget B'));
      expect(doc102.body!.text, contains(r'Cost: $29.99'));
    });

    test(
      'Custom output directory is respected and contains sitemap and robots',
      () async {
        final customOutputDir = Directory('${tempDir.path}/custom_export');

        final manifest = StaticRouteManifest();
        manifest.register(
          StaticPageRoute(
            path: '/custom',
            metadata: const WebMetadata(title: 'Custom Destination'),
            componentBuilder: (ctx) => MantleText('Custom Content'),
          ),
        );

        final engine = FlutterWebBuildEngine(
          processRunner: (exe, args, {environment, workingDirectory}) async =>
              ProcessResult(100, 0, '', ''),
        );
        final options = BuildWebOptions(
          projectDir: projectDir.path,
          output: customOutputDir.path,
          mode: BuildMode.prerender,
          dryRun: false,
          strict: false,
        );

        final result = await engine.build(options, routeManifest: manifest);

        expect(result.success, isTrue);

        final customFile = File('${customOutputDir.path}/custom/index.html');
        final sitemapFile = File('${customOutputDir.path}/sitemap.xml');
        final robotsFile = File('${customOutputDir.path}/robots.txt');

        expect(customFile.existsSync(), isTrue);
        expect(sitemapFile.existsSync(), isTrue);
        expect(robotsFile.existsSync(), isTrue);

        expect(
          sitemapFile.readAsStringSync(),
          contains('https://example.com/custom'),
        );
        expect(
          robotsFile.readAsStringSync(),
          contains('Sitemap: https://example.com/sitemap.xml'),
        );
      },
    );

    test(
      '404 route handling produces dedicated error page with noindex metadata',
      () async {
        final manifest = StaticRouteManifest();
        manifest.register(
          StaticPageRoute(
            path: '/404',
            metadata: const WebMetadata(
              title: '404 - Not Found',
              robots: 'noindex, nofollow',
            ),
            componentBuilder: (ctx) =>
                MantleText('The requested page does not exist.'),
          ),
        );

        final engine = FlutterWebBuildEngine(
          processRunner: (exe, args, {environment, workingDirectory}) async =>
              ProcessResult(100, 0, '', ''),
        );
        final options = BuildWebOptions(
          projectDir: projectDir.path,
          mode: BuildMode.prerender,
          dryRun: false,
          strict: false,
        );

        final result = await engine.build(options, routeManifest: manifest);

        expect(result.success, isTrue);

        final notFoundFile = File(
          '${projectDir.path}/build/web/404/index.html',
        );
        expect(notFoundFile.existsSync(), isTrue);

        final doc = html_parser.parse(notFoundFile.readAsStringSync());
        expect(doc.querySelector('title')?.text, equals('404 - Not Found'));
        expect(
          doc.querySelector('meta[name="robots"]')?.attributes['content'],
          equals('noindex, nofollow'),
        );
        expect(doc.body!.text, contains('The requested page does not exist.'));

        // 404 with noindex should NOT be in sitemap.xml
        final sitemapFile = File('${projectDir.path}/build/web/sitemap.xml');
        if (sitemapFile.existsSync()) {
          expect(sitemapFile.readAsStringSync().contains('/404'), isFalse);
        }
      },
    );

    test('Missing route content in non-strict mode emits warning, but strict mode throws FormatException', () async {
      final manifest = StaticRouteManifest();
      manifest.register(
        const StaticPageRoute(
          path: '/empty',
          metadata: WebMetadata(title: 'Empty Route'),
          // No componentBuilder or htmlContent
        ),
      );

      final engine = FlutterWebBuildEngine(
        processRunner: (exe, args, {environment, workingDirectory}) async =>
            ProcessResult(100, 0, '', ''),
      );

      // 1. Non-strict mode succeeds with warnings
      final nonStrictOptions = BuildWebOptions(
        projectDir: projectDir.path,
        mode: BuildMode.prerender,
        dryRun: false,
        strict: false,
      );

      final result = await engine.build(
        nonStrictOptions,
        routeManifest: manifest,
      );

      expect(result.success, isTrue);
      expect(result.missingRouteContent, greaterThan(0));
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any(
          (w) => w.contains('has no component tree or HTML content'),
        ),
        isTrue,
      );

      // 2. Strict mode throws FormatException
      final strictOptions = BuildWebOptions(
        projectDir: projectDir.path,
        mode: BuildMode.prerender,
        dryRun: false,
        strict: true,
      );

      expect(
        () => engine.build(strictOptions, routeManifest: manifest),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
