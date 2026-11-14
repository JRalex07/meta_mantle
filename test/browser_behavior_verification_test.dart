import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:meta_mantle/meta_mantle.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';

void main() {
  group('Browser Behavior & Startup Verification Tests', () {
    late Directory tempDir;
    late Directory projectDir;
    late Directory webDir;
    late File indexHtmlFile;

    const dummyFlutterIndexHtml = '''
<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <title>Sample Flutter App</title>
</head>
<body>
  <div id="flutter_host"></div>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mm_browser_verif_');
      projectDir = Directory('${tempDir.path}/app')
        ..createSync(recursive: true);
      webDir = Directory('${projectDir.path}/web')..createSync(recursive: true);

      final pubspec = File('${projectDir.path}/pubspec.yaml');
      pubspec.writeAsStringSync(
        'name: browser_test_app\nenvironment:\n  sdk: ">=3.6.0 <4.0.0"\n',
      );

      indexHtmlFile = File('${webDir.path}/index.html');
      indexHtmlFile.writeAsStringSync(dummyFlutterIndexHtml);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Deep-link navigation delivers complete initial semantic markup for all routes before JS runs', () async {
      final manifest = StaticRouteManifest();

      // Home route
      manifest.register(
        StaticPageRoute(
          path: '/',
          metadata: const WebMetadata(
            title: 'Storefront Home',
            description: 'Premier shopping catalog',
          ),
          componentBuilder: (ctx) => MantleColumn(
            children: [
              MantleText('Welcome to Storefront'),
              MantleButton(label: 'Explore Catalog', onPressed: () {}),
            ],
          ),
        ),
      );

      // Deep route
      manifest.register(
        StaticPageRoute(
          path: '/products/artisan-keyboard',
          metadata: const WebMetadata(
            title: 'Artisan Keyboard - Storefront',
            description: 'Mechanical custom keyboard',
          ),
          componentBuilder: (ctx) => MantleColumn(
            children: [
              MantleText('Artisan Mechanical Keyboard'),
              MantleText('Price: \$199.00'),
            ],
          ),
        ),
      );

      final engine = FlutterWebBuildEngine(
        processRunner: (exe, args, {environment, workingDirectory}) async =>
            ProcessResult(100, 0, '', ''),
      );

      final result = await engine.build(
        BuildWebOptions(
          projectDir: projectDir.path,
          mode: BuildMode.hybrid,
          baseHref: '/',
          dryRun: false,
          strict: false,
        ),
        routeManifest: manifest,
      );

      expect(result.success, isTrue);

      // Check Home Route
      final homeFile = File('${projectDir.path}/build/web/index.html');
      expect(homeFile.existsSync(), isTrue);
      final homeDoc = html_parser.parse(homeFile.readAsStringSync());

      expect(homeDoc.querySelector('base')?.attributes['href'], equals('/'));
      expect(homeDoc.querySelector('title')?.text, equals('Storefront Home'));
      expect(homeDoc.body!.text, contains('Welcome to Storefront'));
      expect(
        homeDoc.querySelector('button')?.text,
        contains('Explore Catalog'),
      );

      // Check Deep Link Route
      final deepFile = File(
        '${projectDir.path}/build/web/products/artisan-keyboard/index.html',
      );
      expect(deepFile.existsSync(), isTrue);
      final deepDoc = html_parser.parse(deepFile.readAsStringSync());

      // Base href must be preserved for relative assets
      expect(deepDoc.querySelector('base')?.attributes['href'], equals('/'));
      expect(
        deepDoc.querySelector('title')?.text,
        equals('Artisan Keyboard - Storefront'),
      );
      expect(deepDoc.body!.text, contains('Artisan Mechanical Keyboard'));
      expect(deepDoc.body!.text, contains(r'Price: $199.00'));

      // No blank white screen: body must contain pre-rendered markup
      expect(deepDoc.querySelector('#mantle-prerender-root'), isNotNull);
      expect(
        deepDoc.querySelector('#mantle-prerender-root')!.children,
        isNotEmpty,
      );
    });

    test('Hybrid Mode generates coordinated client handshake with opacity transition and fallback timeout', () async {
      final manifest = StaticRouteManifest();
      manifest.register(
        StaticPageRoute(
          path: '/',
          metadata: const WebMetadata(title: 'Handshake Test'),
          componentBuilder: (ctx) => MantleText('Handshake Component'),
        ),
      );

      final engine = FlutterWebBuildEngine(
        processRunner: (exe, args, {environment, workingDirectory}) async =>
            ProcessResult(100, 0, '', ''),
      );

      await engine.build(
        BuildWebOptions(
          projectDir: projectDir.path,
          mode: BuildMode.hybrid,
          dryRun: false,
        ),
        routeManifest: manifest,
      );

      final generatedHtml = File('${projectDir.path}/build/web/index.html')
          .readAsStringSync();
      final doc = html_parser.parse(generatedHtml);

      // 1. Prerender Style element with fade-out transition
      final styleTag = doc.querySelector('#mantle-prerender-style');
      expect(styleTag, isNotNull);
      expect(styleTag!.innerHtml, contains('#mantle-prerender-root'));
      expect(
        styleTag.innerHtml,
        contains('transition: opacity 0.25s ease-out'),
      );
      expect(styleTag.innerHtml, contains('opacity: 0'));

      // 2. Prerender Root element
      final root = doc.querySelector('#mantle-prerender-root');
      expect(root, isNotNull);
      expect(root!.text, contains('Handshake Component'));

      // 3. Client Handshake Script
      final bridgeScript = doc.querySelector('#mantle-startup-bridge');
      expect(bridgeScript, isNotNull);
      expect(bridgeScript!.innerHtml, contains('window.__mantleClientReady'));
      expect(bridgeScript.innerHtml, contains('setTimeout'));
      expect(bridgeScript.innerHtml, contains('mantle-prerender-root'));

      // 4. Flutter Bootstrap script tag is retained and unaffected
      final bootstrapScript = doc.querySelector(
        'script[src="flutter_bootstrap.js"]',
      );
      expect(bootstrapScript, isNotNull);
    });

    test('Custom base-href is correctly configured in static pages', () async {
      final manifest = StaticRouteManifest();
      manifest.register(
        const StaticPageRoute(
          path: '/',
          metadata: WebMetadata(title: 'Subdirectory App'),
          htmlContent: '<h1>Subdirectory Root</h1>',
        ),
      );

      final engine = FlutterWebBuildEngine(
        processRunner: (exe, args, {environment, workingDirectory}) async =>
            ProcessResult(100, 0, '', ''),
      );

      await engine.build(
        BuildWebOptions(
          projectDir: projectDir.path,
          mode: BuildMode.prerender,
          baseHref: '/subpath/',
          dryRun: false,
        ),
        routeManifest: manifest,
      );

      final html = File('${projectDir.path}/build/web/index.html')
          .readAsStringSync();
      expect(html, contains('<h1>Subdirectory Root</h1>'));
    });
  });
}
