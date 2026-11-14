import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:meta_mantle/meta_mantle_builder.dart';

void main() {
  group('HtmlValidator Quality & Conformance Checks', () {
    late HtmlValidator validator;

    setUp(() {
      validator = const HtmlValidator();
    });

    test('validates clean HTML5 document with zero errors and warnings', () {
      const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Clean Page | MetaMantle</title>
  <meta name="description" content="A clean, conforming HTML5 document for testing.">
  <link rel="canonical" href="https://example.com/clean">
  <meta property="og:title" content="Clean Page | MetaMantle">
  <meta property="og:description" content="A clean, conforming HTML5 document for testing.">
  <meta property="og:url" content="https://example.com/clean">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Clean Page | MetaMantle">
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "Clean Page",
    "url": "https://example.com/clean"
  }
  </script>
</head>
<body>
  <nav aria-label="Main Navigation">
    <a href="/clean" aria-current="page">Clean</a>
    <a href="/about">About</a>
  </nav>
  <main>
    <h1>Clean Page Headline</h1>
    <p>Valid text with arrow → and emoji 🚀.</p>
    <img src="https://example.com/hero.jpg" alt="Hero Banner" width="800" height="400" loading="lazy" decoding="async" style="max-width: 100%; height: auto; aspect-ratio: 800 / 400; display: block;">
  </main>
</body>
</html>
''';

      final result = validator.validateHtml(html, filePath: 'clean.html');
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test(
      'detects duplicate title, duplicate description, and duplicate canonical',
      () {
        const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>First Title</title>
  <title>Second Title</title>
  <meta name="description" content="First description.">
  <meta name="description" content="Second description.">
  <link rel="canonical" href="https://example.com/page1">
  <link rel="canonical" href="https://example.com/page2">
</head>
<body>
  <p>Hello world</p>
</body>
</html>
''';

        final result = validator.validateHtml(
          html,
          filePath: 'duplicates.html',
        );
        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.rule == 'title-duplicate'), isTrue);
        expect(
          result.errors.any((e) => e.rule == 'description-duplicate'),
          isTrue,
        );
        expect(
          result.errors.any((e) => e.rule == 'canonical-duplicate'),
          isTrue,
        );
      },
    );

    test('detects malformed document: nested html inside head and body inside head', () {
      const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Malformed Structure</title>
  <html lang="fr"></html>
  <body>Nested body in head</body>
</head>
<body>
  <title>Misplaced Title in Body</title>
  <p>Content</p>
</body>
</html>
''';

      final result = validator.validateHtml(html, filePath: 'malformed.html');
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'misplaced-element'), isTrue);
    });

    test('detects missing alt attribute and non-responsive image width', () {
      const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Image Tests</title>
  <meta name="description" content="Test image audit.">
</head>
<body>
  <img src="/banner.png">
  <img src="/fixed.png" alt="Fixed image" style="width: 800px; height: 400px;">
</body>
</html>
''';

      final result = validator.validateHtml(html, filePath: 'images.html');
      expect(result.warnings.any((w) => w.rule == 'img-alt'), isTrue);
      expect(result.warnings.any((w) => w.rule == 'img-responsive'), isTrue);
    });

    test(
      'detects invalid navigation semantics (button role=tab outside tablist)',
      () {
        const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Nav Semantics</title>
  <meta name="description" content="Test navigation.">
</head>
<body>
  <nav>
    <button role="tab">Tab 1</button>
  </nav>
</body>
</html>
''';

        final result = validator.validateHtml(html, filePath: 'nav.html');
        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.rule == 'nav-semantics'), isTrue);
      },
    );

    test('validates WAI-ARIA tab pattern inside role=tablist', () {
      const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Tabs</title>
  <meta name="description" content="Testing tabs.">
</head>
<body>
  <div role="tablist">
    <button role="tab" id="tab-1" aria-controls="panel-1" aria-selected="true" tabindex="0">Tab 1</button>
    <button role="tab" id="tab-2" aria-controls="panel-2" aria-selected="false" tabindex="-1">Tab 2</button>
  </div>
  <div role="tabpanel" id="panel-1" aria-labelledby="tab-1">Panel 1 Content</div>
  <div role="tabpanel" id="panel-2" aria-labelledby="tab-2" hidden>Panel 2 Content</div>
</body>
</html>
''';

      final result = validator.validateHtml(html, filePath: 'tabs.html');
      expect(result.errors.where((e) => e.rule == 'nav-semantics'), isEmpty);
    });

    test('detects Mojibake encoding artifacts', () {
      const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Mojibake Test</title>
  <meta name="description" content="Testing mojibake.">
</head>
<body>
  <p>Browse Full Catalog â†’</p>
</body>
</html>
''';

      final result = validator.validateHtml(html, filePath: 'mojibake.html');
      expect(result.errors.any((e) => e.rule == 'utf8-encoding'), isTrue);
    });

    test('detects invalid JSON-LD schema (missing @type or @context)', () {
      const html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>JSON-LD Test</title>
  <meta name="description" content="Testing JSON-LD.">
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "name": "Missing Type"
  }
  </script>
</head>
<body>
</body>
</html>
''';

      final result = validator.validateHtml(html, filePath: 'jsonld.html');
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.rule == 'jsonld-type'), isTrue);
    });

    test('HeadInjector replaces template title and description without duplicating', () {
      const templateHtml = '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Old Template Title</title>
  <meta name="description" content="Old template description">
  <link rel="canonical" href="https://example.com/old">
</head>
<body>
  <div id="app"></div>
</body>
</html>
''';

      final doc = html_parser.parse(templateHtml);
      final tags = [
        const HeadTag(
          key: 'title',
          tagName: 'title',
          textContent: 'New Route Title | MetaMantle',
        ),
        const HeadTag(
          key: 'description',
          tagName: 'meta',
          attributes: {
            'name': 'description',
            'content': 'New route description.',
          },
        ),
        const HeadTag(
          key: 'canonical',
          tagName: 'link',
          attributes: {'rel': 'canonical', 'href': 'https://example.com/new'},
        ),
        const HeadTag(
          key: 'html_lang',
          tagName: 'html',
          attributes: {'lang': 'en'},
        ),
      ];

      HeadInjector.injectTags(document: doc, tags: tags);

      // Verify root html lang updated
      expect(doc.documentElement?.attributes['lang'], equals('en'));

      // Verify no html tag inside head
      final head = doc.head!;
      expect(head.querySelectorAll('html'), isEmpty);

      // Verify exactly 1 title
      final titles = head.querySelectorAll('title');
      expect(titles.length, equals(1));
      expect(titles.first.text, equals('New Route Title | MetaMantle'));

      // Verify exactly 1 meta description
      final descriptions = head.querySelectorAll('meta[name="description"]');
      expect(descriptions.length, equals(1));
      expect(
        descriptions.first.attributes['content'],
        equals('New route description.'),
      );

      // Verify exactly 1 canonical
      final canonicals = head.querySelectorAll('link[rel="canonical"]');
      expect(canonicals.length, equals(1));
      expect(
        canonicals.first.attributes['href'],
        equals('https://example.com/new'),
      );
    });

    test('HeadInjector entity-aware JSON-LD deduplication preserves multiple Product schemas with distinct identities', () {
      const templateHtml =
          '<!DOCTYPE html><html><head></head><body></body></html>';
      final doc = html_parser.parse(templateHtml);

      final product1 = const HeadTag(
        key: 'product_rice',
        tagName: 'script',
        attributes: {'type': 'application/ld+json'},
        textContent: '{"@context":"https://schema.org","@type":"Product","@id":"https://example.com/products/basmati-rice#product","name":"Royal Aged Basmati Rice","url":"https://example.com/products/basmati-rice","offers":{"price":"18.99"}}',
      );

      final product2 = const HeadTag(
        key: 'product_milk',
        tagName: 'script',
        attributes: {'type': 'application/ld+json'},
        textContent: '{"@context":"https://schema.org","@type":"Product","@id":"https://example.com/products/whole-milk#product","name":"Farm Fresh Whole Milk","url":"https://example.com/products/whole-milk","offers":{"price":"4.49"}}',
      );

      final product3 = const HeadTag(
        key: 'product_oil',
        tagName: 'script',
        attributes: {'type': 'application/ld+json'},
        textContent: '{"@context":"https://schema.org","@type":"Product","sku":"OIL-99","name":"Cold-Pressed Olive Oil","offers":{"price":"14.99"}}',
      );

      // Inject all three distinct Product schemas
      HeadInjector.injectTags(
        document: doc,
        tags: [product1, product2, product3],
      );

      final scripts = doc.head!.querySelectorAll(
        'script[type="application/ld+json"]',
      );
      expect(
        scripts.length,
        equals(3),
        reason: 'All 3 independent Product schemas must be preserved',
      );

      // Now inject an updated version of product 1 (same @id, new price)
      const updatedProduct1 = HeadTag(
        key: 'product_rice_updated',
        tagName: 'script',
        attributes: {'type': 'application/ld+json'},
        textContent: '{"@context":"https://schema.org","@type":"Product","@id":"https://example.com/products/basmati-rice#product","name":"Royal Aged Basmati Rice","url":"https://example.com/products/basmati-rice","offers":{"price":"19.99"}}',
      );

      HeadInjector.injectTags(document: doc, tags: [updatedProduct1]);

      final scriptsAfterUpdate = doc.head!.querySelectorAll(
        'script[type="application/ld+json"]',
      );
      expect(
        scriptsAfterUpdate.length,
        equals(3),
        reason: 'Updating an existing entity must NOT add a 4th script',
      );
      expect(
        scriptsAfterUpdate.any((s) => s.text.contains('"price":"19.99"')),
        isTrue,
      );
      expect(
        scriptsAfterUpdate.any((s) => s.text.contains('Whole Milk')),
        isTrue,
      );
      expect(scriptsAfterUpdate.any((s) => s.text.contains('OIL-99')), isTrue);
    });

    test('pre-parse structural checks detect duplicate root, head, and body tags in raw source', () {
      const htmlWithTwoHeads = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>First Head</title>
</head>
<head>
  <meta name="description" content="Second Head">
</head>
<body><p>Content</p></body>
</html>
''';
      final reportHead = validator.validateHtml(
        htmlWithTwoHeads,
        filePath: 'two_heads.html',
      );
      expect(
        reportHead.errors.any((e) => e.rule == 'structure-head-duplicate'),
        isTrue,
      );

      const htmlWithTwoBodies = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Title</title>
</head>
<body><p>Body 1</p></body>
<body><p>Body 2</p></body>
</html>
''';
      final reportBody = validator.validateHtml(
        htmlWithTwoBodies,
        filePath: 'two_bodies.html',
      );
      expect(
        reportBody.errors.any((e) => e.rule == 'structure-body-duplicate'),
        isTrue,
      );

      const htmlWithTwoHtmls = '''
<!DOCTYPE html>
<html lang="en">
<head><title>Title</title></head>
<body></body>
</html>
<html lang="fr"><body></body></html>
''';
      final reportHtml = validator.validateHtml(
        htmlWithTwoHtmls,
        filePath: 'two_htmls.html',
      );
      expect(
        reportHtml.errors.any((e) => e.rule == 'structure-html-duplicate'),
        isTrue,
      );
    });

    test('validates navigation and button ARIA attributes strictly', () {
      // Anchor links with invalid aria-selected
      const badNavHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Bad Nav</title>
</head>
<body>
  <nav>
    <a href="/" aria-selected="true">Home</a>
  </nav>
</body>
</html>
''';
      final badNavReport = validator.validateHtml(
        badNavHtml,
        filePath: 'bad_nav.html',
      );
      expect(
        badNavReport.errors.any((e) => e.rule == 'nav-aria-selected'),
        isTrue,
      );

      // Button with invalid aria-selected outside tabs
      const badBtnHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Bad Button</title>
</head>
<body>
  <button type="button" aria-selected="true">Toggle</button>
</body>
</html>
''';
      final badBtnReport = validator.validateHtml(
        badBtnHtml,
        filePath: 'bad_btn.html',
      );
      expect(
        badBtnReport.errors.any((e) => e.rule == 'button-aria-selected'),
        isTrue,
      );
    });

    test('Nu HTML Checker external standards validator reports skipped and unavailable status honestly', () async {
      const cleanHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Clean</title>
</head>
<body><p>Test</p></body>
</html>
''';

      // 1. When not requested, reports skipped
      final skippedReport = await validator.validateHtmlWithStandards(
        cleanHtml,
        enableNuChecker: false,
      );
      expect(
        skippedReport.standardsResult?.status,
        equals(ExternalStandardsValidationStatus.skipped),
      );

      // 2. When unreachable endpoint, reports unavailable (never falsely reports passed)
      final unavailReport = await validator.validateHtmlWithStandards(
        cleanHtml,
        enableNuChecker: true,
        nuCheckerUrl: 'http://127.0.0.1:54321/nonexistent',
      );
      expect(
        unavailReport.standardsResult?.status,
        equals(ExternalStandardsValidationStatus.unavailable),
      );
      expect(
        unavailReport.standardsResult?.reason,
        contains('Connection to validator failed'),
      );
    });
  });

  group('Generated Example Routes Conformance Audit', () {
    const buildWebDir = 'example/build/web';

    test(
      'audits all generated routes in example/build/web if directory exists',
      () async {
        final dir = Directory(buildWebDir);
        if (!dir.existsSync()) {
          // Skip if not built yet
          return;
        }

        const validator = HtmlValidator();
        final summary = await validator.validateDirectory(dir);

        expect(summary.totalFiles, greaterThanOrEqualTo(6));
        expect(
          summary.totalErrors,
          equals(0),
          reason: 'Expected 0 HTML validation errors across generated files',
        );
        expect(
          summary.totalWarnings,
          equals(0),
          reason: 'Expected 0 HTML validation warnings across generated files',
        );

        // Verify individual routes
        final routeFiles = [
          'index.html',
          'about/index.html',
          'products/index.html',
          'faq/index.html',
          'products/basmati-rice/index.html',
          'products/whole-milk/index.html',
        ];

        for (final relPath in routeFiles) {
          final file = File('$buildWebDir/$relPath');
          expect(
            file.existsSync(),
            isTrue,
            reason: 'Missing expected generated route file: $relPath',
          );

          final content = file.readAsStringSync();
          final doc = html_parser.parse(content);

          // Document structure
          expect(
            doc.querySelectorAll('html').length,
            equals(1),
            reason: '$relPath: exactly 1 root <html>',
          );
          expect(
            doc.head?.querySelectorAll('html'),
            isEmpty,
            reason: '$relPath: no <html> inside <head>',
          );
          expect(
            doc.head?.querySelectorAll('body'),
            isEmpty,
            reason: '$relPath: no <body> inside <head>',
          );

          // Metadata uniqueness
          expect(
            doc.head?.querySelectorAll('title').length,
            equals(1),
            reason: '$relPath: exactly 1 <title>',
          );
          expect(
            doc.head?.querySelectorAll('meta[name="description"]').length,
            equals(1),
            reason: '$relPath: exactly 1 description',
          );
          expect(
            doc.head?.querySelectorAll('link[rel="canonical"]').length,
            equals(1),
            reason: '$relPath: exactly 1 canonical',
          );

          // Navigation elements
          final navItems = doc.querySelectorAll('nav a');
          expect(
            navItems,
            isNotEmpty,
            reason: '$relPath: navigation must use <a> tags',
          );
          for (final a in navItems) {
            expect(
              a.attributes['href'],
              isNotNull,
              reason: '$relPath: navigation <a> must have href',
            );
          }

          // Image responsiveness
          final images = doc.querySelectorAll('img');
          for (final img in images) {
            expect(
              img.attributes['alt'],
              isNotNull,
              reason: '$relPath: image must have alt attribute',
            );
            final style = img.attributes['style'] ?? '';
            expect(
              style,
              contains('max-width: 100%'),
              reason: '$relPath: image must have max-width: 100%',
            );
          }

          // UTF-8 check
          expect(
            content.contains('â†’'),
            isFalse,
            reason: '$relPath: should not contain mojibake â†’',
          );
        }
      },
    );
  });
}
