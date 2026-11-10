import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:meta_mantle/src/runtime/runtime_coordinator.dart';

void main() {
  setUp(() {
    RuntimeCoordinator.instance = RuntimeCoordinator();
  });

  tearDown(() {
    RuntimeCoordinator.instance.clear();
  });

  group('Extended SEO Metadata & Renderer', () {
    const renderer = MetadataRenderer();

    test('renders keywords, author, publisher, and color scheme', () {
      final tags = renderer.render(
        const WebMetadata(
          title: 'Store',
          keywords: 'groceries, food, organic',
          author: 'Alice',
          publisher: 'Acme Corp',
          applicationName: 'AcmeStore',
          referrerPolicy: 'strict-origin-when-cross-origin',
          colorScheme: 'light dark',
        ),
        config: const WebHeadConfig(baseUrl: 'https://example.com'),
      );

      expect(tags.firstWhere((t) => t.key == 'keywords').attributes['content'],
          'groceries, food, organic');
      expect(tags.firstWhere((t) => t.key == 'author').attributes['content'],
          'Alice');
      expect(tags.firstWhere((t) => t.key == 'publisher').attributes['content'],
          'Acme Corp');
      expect(
          tags
              .firstWhere((t) => t.key == 'application-name')
              .attributes['content'],
          'AcmeStore');
      expect(tags.firstWhere((t) => t.key == 'referrer').attributes['content'],
          'strict-origin-when-cross-origin');
      expect(
          tags.firstWhere((t) => t.key == 'color-scheme').attributes['content'],
          'light dark');
    });

    test('renders search engine verification tags', () {
      final tags = renderer.render(
        const WebMetadata(
          title: 'Store',
          googleSiteVerification: 'google-token-123',
          bingSiteVerification: 'bing-token-456',
          yandexVerification: 'yandex-token-789',
          baiduVerification: 'baidu-token-000',
        ),
        config: const WebHeadConfig(baseUrl: 'https://example.com'),
      );

      expect(
          tags
              .firstWhere((t) => t.key == 'google-site-verification')
              .attributes['content'],
          'google-token-123');
      expect(
          tags
              .firstWhere((t) => t.key == 'msvalidate.01')
              .attributes['content'],
          'bing-token-456');
      expect(
          tags
              .firstWhere((t) => t.key == 'yandex-verification')
              .attributes['content'],
          'yandex-token-789');
      expect(
          tags
              .firstWhere((t) => t.key == 'baidu-site-verification')
              .attributes['content'],
          'baidu-token-000');
    });

    test('renders Open Graph extended properties and media dimensions', () {
      final tags = renderer.render(
        const WebMetadata(
          title: 'Product',
          openGraph: OpenGraph(
            type: OpenGraphType.product,
            image: 'https://example.com/item.png',
            imageAlt: 'Product image',
            imageWidth: 1200,
            imageHeight: 630,
            imageType: 'image/png',
            locale: 'en_US',
            alternateLocales: ['hi_IN', 'es_ES'],
            determiner: 'auto',
            video: 'https://example.com/demo.mp4',
            audio: 'https://example.com/sound.mp3',
          ),
        ),
        config: const WebHeadConfig(baseUrl: 'https://example.com'),
      );

      expect(tags.firstWhere((t) => t.key == 'og:type').attributes['content'],
          'product');
      expect(
          tags.firstWhere((t) => t.key == 'og:image:alt').attributes['content'],
          'Product image');
      expect(
          tags
              .firstWhere((t) => t.key == 'og:image:width')
              .attributes['content'],
          '1200');
      expect(
          tags
              .firstWhere((t) => t.key == 'og:image:height')
              .attributes['content'],
          '630');
      expect(
          tags
              .firstWhere((t) => t.key == 'og:image:type')
              .attributes['content'],
          'image/png');
      expect(tags.firstWhere((t) => t.key == 'og:locale').attributes['content'],
          'en_US');
      expect(
          tags
              .firstWhere((t) => t.key == 'og:locale:alternate-0')
              .attributes['content'],
          'hi_IN');
      expect(
          tags
              .firstWhere((t) => t.key == 'og:locale:alternate-1')
              .attributes['content'],
          'es_ES');
      expect(tags.firstWhere((t) => t.key == 'og:video').attributes['content'],
          'https://example.com/demo.mp4');
      expect(tags.firstWhere((t) => t.key == 'og:audio').attributes['content'],
          'https://example.com/sound.mp3');
      expect(
          tags
              .firstWhere((t) => t.key == 'og:determiner')
              .attributes['content'],
          'auto');
    });

    test('renders resource hints properly', () {
      final tags = renderer.render(
        WebMetadata(
          title: 'Store',
          resourceHints: [
            ResourceHint.preconnect('https://fonts.googleapis.com'),
            ResourceHint.dnsPrefetch('https://api.example.com'),
            ResourceHint.preload('https://example.com/font.woff2',
                asType: 'font', type: 'font/woff2', crossOrigin: 'anonymous'),
            ResourceHint.modulePreload('https://example.com/bundle.js'),
          ],
        ),
        config: const WebHeadConfig(baseUrl: 'https://example.com'),
      );

      final preconnect =
          tags.firstWhere((t) => t.attributes['rel'] == 'preconnect');
      expect(preconnect.attributes['href'], 'https://fonts.googleapis.com');
      expect(preconnect.attributes['crossorigin'], '');

      final dns = tags.firstWhere((t) => t.attributes['rel'] == 'dns-prefetch');
      expect(dns.attributes['href'], 'https://api.example.com');

      final preload = tags.firstWhere((t) => t.attributes['rel'] == 'preload');
      expect(preload.attributes['as'], 'font');
      expect(preload.attributes['type'], 'font/woff2');
      expect(preload.attributes['crossorigin'], 'anonymous');

      final modulePreload =
          tags.firstWhere((t) => t.attributes['rel'] == 'modulepreload');
      expect(modulePreload.attributes['href'], 'https://example.com/bundle.js');
    });

    test('applies trailing slash configuration to canonical URL', () {
      final withSlash = renderer.render(
        const WebMetadata(canonical: 'https://example.com/products/rice'),
        config: const WebHeadConfig(trailingSlash: true),
      );
      expect(
          withSlash.firstWhere((t) => t.key == 'canonical').attributes['href'],
          'https://example.com/products/rice/');

      final withoutSlash = renderer.render(
        const WebMetadata(canonical: 'https://example.com/products/rice/'),
        config: const WebHeadConfig(trailingSlash: false),
      );
      expect(
          withoutSlash
              .firstWhere((t) => t.key == 'canonical')
              .attributes['href'],
          'https://example.com/products/rice');

      // Does not alter files with extensions
      final fileUrl = renderer.render(
        const WebMetadata(canonical: 'https://example.com/page.html'),
        config: const WebHeadConfig(trailingSlash: true),
      );
      expect(fileUrl.firstWhere((t) => t.key == 'canonical').attributes['href'],
          'https://example.com/page.html');
    });

    test('renders new JSON-LD schemas correctly', () {
      final jsonLdList = [
        JsonLd.webPage(
            name: 'About',
            url: 'https://example.com/about',
            description: 'About us'),
        JsonLd.localBusiness(
            name: 'Grocery Store',
            address: '123 Main St',
            telephone: '+1-555-0100'),
        JsonLd.faqPage([(question: 'Do you deliver?', answer: 'Yes, daily.')]),
        JsonLd.person(name: 'Jane Doe', jobTitle: 'CTO'),
        JsonLd.softwareApplication(
            name: 'App',
            operatingSystem: 'Web',
            applicationCategory: 'Shopping'),
        JsonLd.event(
            name: 'Spring Sale',
            startDate: '2026-03-01',
            locationName: 'Main Store'),
        JsonLd.offer(price: '29.99', priceCurrency: 'USD'),
      ];

      final tags = renderer.render(
        WebMetadata(
          title: 'All Schemas',
          jsonLd: jsonLdList,
        ),
        config: const WebHeadConfig(baseUrl: 'https://example.com'),
      );

      final jsonLdTags = tags
          .where((t) =>
              t.tagName == 'script' &&
              t.attributes['type'] == 'application/ld+json')
          .toList();
      expect(jsonLdTags.length, 7);
      expect(jsonLdTags[0].textContent, contains('WebPage'));
      expect(jsonLdTags[1].textContent, contains('LocalBusiness'));
      expect(jsonLdTags[2].textContent, contains('FAQPage'));
      expect(jsonLdTags[3].textContent, contains('Person'));
      expect(jsonLdTags[4].textContent, contains('SoftwareApplication'));
      expect(jsonLdTags[5].textContent, contains('Event'));
      expect(jsonLdTags[6].textContent, contains('Offer'));
    });
  });

  group('Imperative Metadata API & Navigator Observer', () {
    test(
        'FlutterWebHead imperative setters update active metadata and generation token',
        () {
      FlutterWebHead.initialize(
          config: const WebHeadConfig(baseUrl: 'https://example.com'));
      final token0 = FlutterWebHead.generationToken;

      FlutterWebHead.setTitle('Imperative Title');
      expect(FlutterWebHead.activeMetadata?.title, 'Imperative Title');
      expect(FlutterWebHead.generationToken, greaterThan(token0));

      FlutterWebHead.setDescription('Imperative Description');
      expect(
          FlutterWebHead.activeMetadata?.description, 'Imperative Description');
      expect(FlutterWebHead.activeMetadata?.title, 'Imperative Title');

      FlutterWebHead.setCanonical('https://example.com/custom');
      expect(FlutterWebHead.activeMetadata?.canonical,
          'https://example.com/custom');

      FlutterWebHead.clearUpdate();
      expect(FlutterWebHead.activeMetadata, isNull);
    });

    testWidgets(
        'WebHeadNavigatorObserver synchronizes route name with current URL',
        (tester) async {
      FlutterWebHead.initialize(
        config: const WebHeadConfig(
          baseUrl: 'https://example.com',
          includeCurrentUrlAsCanonical: true,
        ),
      );

      final observer = WebHeadNavigatorObserver();

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          initialRoute: '/',
          routes: {
            '/': (context) => const WebHead(
                  metadata: WebMetadata(title: 'Home'),
                  child: Text('Home'),
                ),
            '/details': (context) => const WebHead(
                  metadata: WebMetadata(title: 'Details'),
                  child: Text('Details'),
                ),
          },
        ),
      );

      expect(FlutterWebHead.activeMetadata?.title, 'Home');

      // Navigate to /details
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/details');
      await tester.pumpAndSettle();

      expect(FlutterWebHead.activeMetadata?.title, 'Details');

      // Pop back to /
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(FlutterWebHead.activeMetadata?.title, 'Home');
    });
  });

  group('Static Builder: robots.txt, dry-run, inspect, doctor', () {
    test('generates robots.txt alongside sitemap', () async {
      final temp = await Directory.systemTemp.createTemp('fwh_robots_test_');
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      final output = Directory('${temp.path}/output')..createSync();
      File('${input.path}/index.html').writeAsStringSync(
        '<!doctype html><html><head><title>App</title></head><body><script src="flutter_bootstrap.js"></script></body></html>',
      );

      final config = const StaticHeadConfig(
        baseUrl: 'https://example.com',
        routes: [
          StaticRoute(path: '/', metadata: WebMetadata(title: 'Home')),
        ],
        sitemap: true,
        robotsTxt: true,
      );

      final result = await const StaticHeadBuilder().build(
        inputDirectory: input,
        outputDirectory: output,
        config: config,
      );

      expect(File('${output.path}/robots.txt').existsSync(), isTrue);
      final robotsContent =
          File('${output.path}/robots.txt').readAsStringSync();
      expect(robotsContent, contains('User-agent: *'));
      expect(robotsContent, contains('Allow: /'));
      expect(
          robotsContent, contains('Sitemap: https://example.com/sitemap.xml'));
      expect(result.generatedFiles.any((f) => f.path.endsWith('robots.txt')),
          isTrue);
    });

    test('dry-run validates and calculates output without writing files',
        () async {
      final temp = await Directory.systemTemp.createTemp('fwh_dryrun_test_');
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      final output = Directory('${temp.path}/output')..createSync();
      File('${input.path}/index.html').writeAsStringSync(
        '<!doctype html><html><head><title>App</title></head><body><script src="flutter_bootstrap.js"></script></body></html>',
      );

      final config = const StaticHeadConfig(
        baseUrl: 'https://example.com',
        routes: [
          StaticRoute(
              path: '/dry-run-route', metadata: WebMetadata(title: 'Dry Run')),
        ],
      );

      final result = await const StaticHeadBuilder().build(
        inputDirectory: input,
        outputDirectory: output,
        config: config,
        dryRun: true,
      );

      expect(result.routes, contains('/dry-run-route/'));
      // File should NOT exist on disk because of dry-run
      expect(File('${output.path}/dry-run-route/index.html').existsSync(),
          isFalse);
    });

    test('inspectConfiguration returns route breakdown without writing files',
        () async {
      final config = const StaticHeadConfig(
        baseUrl: 'https://example.com',
        routes: [
          StaticRoute(
              path: '/a',
              metadata: WebMetadata(title: 'A', description: 'Desc A')),
          StaticRoute(
              path: '/b',
              metadata: WebMetadata(title: 'B', description: 'Desc B')),
          StaticRoute(
              path: '/c', metadata: WebMetadata(title: 'C', robots: 'noindex')),
        ],
      );

      final inspection =
          await const StaticHeadBuilder().inspectConfiguration(config: config);
      expect(inspection.routes.length, 3);
      expect(inspection.routes, contains('/a/'));
      expect(inspection.routes, contains('/b/'));
      // Route C has noindex, so sitemap should only have /a/ and /b/
      expect(inspection.sitemapUrls.length, 2);
    });

    test('doctor validates configuration and build environment', () async {
      final temp = await Directory.systemTemp.createTemp('fwh_doctor_test_');
      addTearDown(() => temp.delete(recursive: true));
      final input = Directory('${temp.path}/input')..createSync();
      File('${input.path}/index.html').writeAsStringSync(
        '<!doctype html><html><head><title>App</title></head><body><script src="flutter_bootstrap.js"></script></body></html>',
      );
      final configFile = File('${temp.path}/web_head.config.json');
      configFile.writeAsStringSync(
          '{"baseUrl": "https://example.com", "routes": [{"path": "/", "metadata": {"title": "Home"}}]}');

      final reports = await const StaticHeadBuilder().doctor(
        configFile: configFile,
        inputDirectory: input,
      );

      expect(reports.every((r) => !r.startsWith('FAIL')), isTrue);
      expect(reports.any((r) => r.contains('Flutter build index.html found')),
          isTrue);
      expect(
          reports.any((r) =>
              r.contains('Flutter bootstrap initialization script detected')),
          isTrue);
    });
  });
}
