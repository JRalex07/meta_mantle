import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';

void main() {
  group('BootstrapAdapter Tests', () {
    const adapter = BootstrapAdapter();

    test(
      'preserves Flutter bootstrap tokens and scripts in Mode C (hybrid)',
      () {
        const templateHtml = '''
<!DOCTYPE html>
<html>
<head>
  <base href="\$FLUTTER_BASE_HREF">
  <title>Default App</title>
  {{flutter_js}}
  {{flutter_build_config}}
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''';

        const metadata = WebMetadata(
          title: 'Product Landing',
          description: 'World-class universal Dart framework',
          canonical: 'https://example.com/product',
        );

        final renderedHtml = adapter.buildPrerenderBootstrapHtml(
          templateHtml: templateHtml,
          metadata: metadata,
          semanticHtml: '<article><h1>Super Product</h1></article>',
          mode: BuildMode.hybrid,
          baseHref: '/',
        );

        // Verify template token preservation
        expect(renderedHtml, contains('{{flutter_js}}'));
        expect(renderedHtml, contains('{{flutter_build_config}}'));
        expect(renderedHtml, contains('flutter_bootstrap.js'));
        expect(renderedHtml, contains('async'));

        // Verify head metadata injection
        expect(renderedHtml, contains('<title>Product Landing</title>'));
        expect(
          renderedHtml,
          contains(
            '<meta name="description" content="World-class universal Dart framework"',
          ),
        );
        expect(
          renderedHtml,
          contains('<link rel="canonical" href="https://example.com/product"'),
        );

        // Verify CSS injection
        expect(renderedHtml, contains('id="mantle-prerender-style"'));
        expect(renderedHtml, contains('#mantle-prerender-root'));

        // Verify semantic HTML prerender container
        expect(renderedHtml, contains('id="mantle-prerender-root"'));
        expect(
          renderedHtml,
          contains('<article><h1>Super Product</h1></article>'),
        );

        // Verify client handshake script for hybrid mode
        expect(renderedHtml, contains('window.__mantleClientReady'));
        expect(renderedHtml, contains('mantle-fade-out'));
      },
    );

    test('Mode A (metadata) omits prerender root container and styles', () {
      const templateHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Original Title</title>
</head>
<body>
  <div id="app"></div>
</body>
</html>
''';

      const metadata = WebMetadata(
        title: 'Only Metadata',
        description: 'No HTML snapshots injected in Mode A',
      );

      final renderedHtml = adapter.buildPrerenderBootstrapHtml(
        templateHtml: templateHtml,
        metadata: metadata,
        semanticHtml: '<article>Should Not Appear</article>',
        mode: BuildMode.metadata,
      );

      expect(renderedHtml, contains('<title>Only Metadata</title>'));
      expect(renderedHtml, contains('<meta name="description"'));
      expect(renderedHtml, isNot(contains('#mantle-prerender-root')));
      expect(
        renderedHtml,
        isNot(contains('<article>Should Not Appear</article>')),
      );
      expect(renderedHtml, isNot(contains('window.__mantleClientReady')));
    });

    test('Mode B (prerender) injects HTML without client handshake script', () {
      const templateHtml = '<html><head></head><body></body></html>';
      const metadata = WebMetadata(title: 'Mode B Prerender');

      final renderedHtml = adapter.buildPrerenderBootstrapHtml(
        templateHtml: templateHtml,
        metadata: metadata,
        semanticHtml: '<p>Snapshot Only</p>',
        mode: BuildMode.prerender,
      );

      expect(renderedHtml, contains('id="mantle-prerender-root"'));
      expect(renderedHtml, contains('<p>Snapshot Only</p>'));
      expect(renderedHtml, isNot(contains('window.__mantleClientReady')));
    });
  });

  group('StaticRouteManifest Dynamic Expansion Tests', () {
    test('registers dynamic routes and resolves paths', () {
      final manifest = StaticRouteManifest(
        initialRoutes: const [
          StaticPageRoute(
            path: '/',
            metadata: WebMetadata(title: 'Home'),
            component: MantleHeading('Welcome Home'),
          ),
        ],
      );

      manifest.registerDynamic<Map<String, String>>(
        pathPattern: '/items/:id',
        items: [
          {'id': '101', 'name': 'Item 101'},
          {'id': '102', 'name': 'Item 102'},
        ],
        slugExtractor: (item) => item['id']!,
        metadataBuilder: (item) => WebMetadata(title: item['name']),
        componentBuilder: (item, context) => MantleText(item['name']!),
      );

      expect(manifest.routes.length, equals(3));
      expect(
        manifest.routes.map((r) => r.path).toList(),
        containsAll(['/', '/items/101', '/items/102']),
      );
    });
  });

  group('FlutterWebBuildEngine Execution Tests', () {
    late Directory tempProject;
    late Directory tempWeb;

    setUp(() {
      tempProject = Directory.systemTemp.createTempSync(
        'meta_mantle_engine_test_',
      );
      tempWeb = Directory('${tempProject.path}/web')
        ..createSync(recursive: true);

      // Create a valid pubspec.yaml
      File('${tempProject.path}/pubspec.yaml').writeAsStringSync('''
name: test_engine_app
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
''');

      // Create index.html template with Flutter tokens
      File('${tempWeb.path}/index.html').writeAsStringSync('''
<!DOCTYPE html>
<html>
<head>
  <base href="\$FLUTTER_BASE_HREF">
  <title>Default App</title>
  {{flutter_js}}
  {{flutter_build_config}}
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''');
    });

    tearDown(() {
      try {
        if (tempProject.existsSync()) {
          tempProject.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test(
      'executes complete build pipeline, generating artifacts and report',
      () async {
        final manifest = StaticRouteManifest(
          initialRoutes: const [
            StaticPageRoute(
              path: '/',
              metadata: WebMetadata(
                title: 'Home Page',
                description: 'Universal Flutter Web Application',
                canonical: 'https://example.com/',
              ),
              component: MantleArticle(
                title: 'Welcome to MetaMantle',
                children: [
                  MantleText('Full static prerendering for Flutter Web.'),
                ],
              ),
            ),
            StaticPageRoute(
              path: '/about',
              metadata: WebMetadata(
                title: 'About Us',
                description: 'Company information and mission.',
                canonical: 'https://example.com/about',
              ),
              component: MantleText('About our mission.'),
            ),
          ],
        );

        final executedCommands = <String>[];
        final engine = FlutterWebBuildEngine(
          processRunner:
              (executable, arguments, {environment, workingDirectory}) async {
                executedCommands.add('$executable ${arguments.join(' ')}');
                return ProcessResult(100, 0, 'Flutter build succeeded', '');
              },
        );

        final outputDir = '${tempProject.path}/build/web';

        final result = await engine.build(
          BuildWebOptions(
            projectDir: tempProject.path,
            output: outputDir,
            mode: BuildMode.hybrid,
            dryRun: false,
          ),
          routeManifest: manifest,
        );

        expect(result.success, isTrue);
        expect(result.mode, equals(BuildMode.hybrid));
        expect(result.routes.length, equals(2));
        expect(result.generatedFiles, isNotEmpty);
        expect(result.reportPath, isNotNull);
        expect(executedCommands, contains('flutter build web --release'));

        // Verify root index.html
        final rootHtml = File('$outputDir/index.html').readAsStringSync();
        expect(rootHtml, contains('<title>Home Page</title>'));
        expect(rootHtml, contains('id="mantle-prerender-root"'));
        expect(rootHtml, contains('Welcome to MetaMantle'));
        expect(rootHtml, contains('Full static prerendering for Flutter Web.'));
        expect(rootHtml, contains('window.__mantleClientReady'));

        // Verify sub-route /about/index.html
        final aboutHtml = File('$outputDir/about/index.html')
            .readAsStringSync();
        expect(aboutHtml, contains('<title>About Us</title>'));
        expect(aboutHtml, contains('About our mission.'));

        // Verify sitemap.xml
        final sitemapFile = File('$outputDir/sitemap.xml');
        expect(sitemapFile.existsSync(), isTrue);
        final sitemap = sitemapFile.readAsStringSync();
        expect(sitemap, contains('<loc>https://example.com/</loc>'));
        expect(sitemap, contains('<loc>https://example.com/about</loc>'));

        // Verify robots.txt
        final robotsFile = File('$outputDir/robots.txt');
        expect(robotsFile.existsSync(), isTrue);
        final robots = robotsFile.readAsStringSync();
        expect(robots, contains('User-agent: *'));
        expect(robots, contains('Sitemap: https://example.com/sitemap.xml'));

        // Verify meta_mantle_report.json
        final reportFile = File(result.reportPath!);
        expect(reportFile.existsSync(), isTrue);
        final report =
            jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
        expect(report['mode'], equals('hybrid'));
        expect(report['routesCount'], equals(2));
        expect(report['success'], isTrue);
      },
    );

    test(
      'dry-run mode does not invoke flutter CLI and does not write files',
      () async {
        final manifest = StaticRouteManifest(
          initialRoutes: const [
            StaticPageRoute(
              path: '/',
              metadata: WebMetadata(title: 'Home Dry Run'),
              component: MantleText('Dry run content'),
            ),
          ],
        );

        var processCalled = false;
        final engine = FlutterWebBuildEngine(
          processRunner:
              (executable, arguments, {environment, workingDirectory}) async {
                processCalled = true;
                return ProcessResult(101, 0, '', '');
              },
        );

        final outputDir = '${tempProject.path}/build/web_dry';

        final result = await engine.build(
          BuildWebOptions(
            projectDir: tempProject.path,
            output: outputDir,
            mode: BuildMode.prerender,
            dryRun: true,
          ),
          routeManifest: manifest,
        );

        expect(result.success, isTrue);
        expect(processCalled, isFalse);
        expect(File('$outputDir/index.html').existsSync(), isFalse);
      },
    );

    test(
      'strict mode throws FormatException when route has no component content',
      () async {
        final manifest = StaticRouteManifest(
          initialRoutes: const [
            StaticPageRoute(
              path: '/empty-route',
              metadata: WebMetadata(title: 'Empty Route'),
            ),
          ],
        );

        final engine = FlutterWebBuildEngine(
          processRunner:
              (executable, arguments, {environment, workingDirectory}) async {
                return ProcessResult(101, 0, '', '');
              },
        );

        await expectLater(
          engine.build(
            BuildWebOptions(
              projectDir: tempProject.path,
              output: '${tempProject.path}/build/web_strict',
              mode: BuildMode.prerender,
              strict: true,
              dryRun: true,
            ),
            routeManifest: manifest,
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'runStaticManifest resolves routes and writes semantic HTML JSON bundle',
      () async {
        final manifest = StaticRouteManifest(
          routes: [
            const StaticRoute(
              path: '/',
              metadata: WebMetadata(title: 'Bundle Home'),
              component: MantlePage(
                children: [
                  MantleHeading('Bundle Home Title', level: 1),
                  MantleText('Bundle content body'),
                ],
              ),
            ),
            const StaticRoute(
              path: '/about',
              metadata: WebMetadata(title: 'Bundle About'),
              component: MantleArticle(
                title: 'About Us',
                children: [MantleText('About bundle text')],
              ),
            ),
          ],
        );

        final tempBundleFile = File('${tempProject.path}/resolved_bundle.json');
        await runStaticManifest(manifest, [tempBundleFile.path]);

        expect(tempBundleFile.existsSync(), isTrue);
        final decoded = jsonDecode(
          tempBundleFile.readAsStringSync(),
        ) as Map<String, dynamic>;
        expect(decoded['version'], equals('0.2.0'));
        expect(decoded['routesCount'], equals(2));

        final routes = decoded['routes'] as List<dynamic>;
        expect(routes[0]['path'], equals('/'));
        expect(routes[0]['htmlContent'], contains('Bundle Home Title'));
        expect(routes[0]['htmlContent'], contains('Bundle content body'));

        expect(routes[1]['path'], equals('/about'));
        expect(routes[1]['htmlContent'], contains('<article'));
        expect(routes[1]['htmlContent'], contains('About bundle text'));
      },
    );

    test('MantleBreadcrumb builds accessible HTML markup', () {
      const breadcrumb = MantleBreadcrumb(
        items: [
          MantleBreadcrumbItem(label: 'Home', href: '/'),
          MantleBreadcrumbItem(label: 'Catalog', href: '/products'),
          MantleBreadcrumbItem(label: 'Rice', isCurrent: true),
        ],
      );

      final navContext = MantleNavigationContext(currentPath: '/products/rice');
      final node = breadcrumb.toNode(navContext);
      const renderer = MantleServerRenderer(emitHydrationMarkers: false);
      final html = renderer.render(node).toHtml();

      expect(
        html,
        contains('<nav aria-label="Breadcrumb" class="mantle-breadcrumb">'),
      );
      expect(html, contains('<ol class="mantle-breadcrumb-list"'));
      expect(html, contains('<li class="mantle-breadcrumb-item"'));
      expect(html, contains('href="/"'));
      expect(html, contains('href="/products"'));
      expect(html, contains('aria-current="page"'));
      expect(html, contains('Rice'));
    });

    test('build result generates accurate report summary metrics', () async {
      final manifest = StaticRouteManifest(
        routes: [
          const StaticRoute(
            path: '/',
            metadata: WebMetadata(title: 'Metrics Home'),
            component: MantleText('Home text'),
          ),
          const StaticRoute(
            path: '/faq',
            metadata: WebMetadata(title: 'FAQ'),
            component: MantleText('FAQ text'),
          ),
        ],
      );

      final engine = FlutterWebBuildEngine(
        processRunner:
            (executable, arguments, {environment, workingDirectory}) async {
              return ProcessResult(101, 0, '', '');
            },
      );

      final result = await engine.build(
        BuildWebOptions(
          projectDir: tempProject.path,
          output: '${tempProject.path}/build/web_metrics',
          mode: BuildMode.prerender,
          dryRun: false,
        ),
        routeManifest: manifest,
      );

      final summary = result.toReportSummary();
      expect(summary, contains('Routes discovered:       2'));
      expect(summary, contains('Routes rendered:         2'));
      expect(summary, contains('Components serialized:   2'));
      expect(summary, contains('Status: SUCCESS'));
    });

    test('forwards custom output directory to flutter build web and validates missing assets', () async {
      final manifest = StaticRouteManifest(
        routes: [
          const StaticRoute(
            path: '/',
            metadata: WebMetadata(title: 'Asset Test'),
            component: MantleColumn(
              children: [
                MantleText('Asset Page'),
                MantleCustomElement(
                  tag: 'img',
                  attributes: {'src': '/missing_banner.png', 'alt': 'Missing'},
                ),
              ],
            ),
          ),
        ],
      );

      final executedCommands = <String>[];
      final engine = FlutterWebBuildEngine(
        processRunner:
            (executable, arguments, {environment, workingDirectory}) async {
              executedCommands.add('$executable ${arguments.join(' ')}');
              return ProcessResult(102, 0, '', '');
            },
      );

      final customOut = '${tempProject.path}/custom_dist';

      final result = await engine.build(
        BuildWebOptions(
          projectDir: tempProject.path,
          output: customOut,
          mode: BuildMode.prerender,
          strict: false,
        ),
        routeManifest: manifest,
      );

      // Verify custom output directory was forwarded to flutter build web
      expect(
        executedCommands.any((cmd) => cmd.contains('--output=$customOut')),
        isTrue,
      );

      // Verify missing asset was detected and calculated
      expect(result.assetErrors, equals(1));
      expect(result.warnings, anyElement(contains('missing_banner.png')));

      // Verify report file was written with asset errors count
      final reportFile = File(result.reportPath!);
      expect(reportFile.existsSync(), isTrue);
      final reportJson =
          jsonDecode(reportFile.readAsStringSync()) as Map<String, dynamic>;
      expect(reportJson['assetErrors'], equals(1));
    });
  });
}
