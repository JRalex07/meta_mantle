import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:meta_mantle/meta_mantle_builder.dart';

void main() {
  group('Independent Consumer Example Compliance & Execution', () {
    final consumerDir = Directory('example/static_html_site');
    final buildSiteDir = Directory('example/static_html_site/build/site');

    test('example/static_html_site never imports private package:meta_mantle/src/...', () {
      expect(
        consumerDir.existsSync(),
        isTrue,
        reason: 'example/static_html_site must exist',
      );

      final dartFiles = consumerDir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.dart') && !f.path.contains('.dart_tool'),
          )
          .toList();

      expect(dartFiles, isNotEmpty);

      final importSrcRegex = RegExp(
        r'''import\s+['"]package:meta_mantle/src/''',
      );
      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          importSrcRegex.hasMatch(content),
          isFalse,
          reason:
              'File ${file.path} must not import private src/ files from meta_mantle',
        );
      }
    });

    test('generate_site.dart executes successfully and generates valid site assets', () async {
      final genScript = File('example/static_html_site/bin/generate_site.dart');
      expect(genScript.existsSync(), isTrue);

      final result = await Process.run(
        'dart',
        ['run', 'bin/generate_site.dart'],
        workingDirectory: consumerDir.path,
        runInShell: true,
      );

      expect(
        result.exitCode,
        equals(0),
        reason:
            'generate_site.dart should exit with 0.\nStdout: ${result.stdout}\nStderr: ${result.stderr}',
      );

      // Verify files generated
      expect(File('${buildSiteDir.path}/index.html').existsSync(), isTrue);
      expect(
        File('${buildSiteDir.path}/about/index.html').existsSync(),
        isTrue,
      );
      expect(
        File('${buildSiteDir.path}/contact/index.html').existsSync(),
        isTrue,
      );
      expect(File('${buildSiteDir.path}/sitemap.xml').existsSync(), isTrue);
      expect(File('${buildSiteDir.path}/robots.txt').existsSync(), isTrue);
    });

    test('Generated consumer HTML documents have correct single root <html> and no <html> in head', () {
      final htmlFiles = [
        File('${buildSiteDir.path}/index.html'),
        File('${buildSiteDir.path}/about/index.html'),
        File('${buildSiteDir.path}/contact/index.html'),
      ];

      for (final file in htmlFiles) {
        final content = file.readAsStringSync();
        final lower = content.toLowerCase();

        // Exactly one opening <html
        final htmlTagCount = RegExp(r'<html\b').allMatches(lower).length;
        expect(
          htmlTagCount,
          equals(1),
          reason: '${file.path} should have exactly one <html> element',
        );

        // Parse with HTML parser
        final doc = html_parser.parse(content);
        expect(doc.head, isNotNull);
        expect(doc.body, isNotNull);

        // Zero <html> elements inside <head>
        final htmlInHead = doc.head!.querySelectorAll('html');
        expect(
          htmlInHead,
          isEmpty,
          reason: '${file.path} must not contain <html> inside <head>',
        );

        // Exactly one <title> element
        final titles = doc.head!.querySelectorAll('title');
        expect(
          titles.length,
          equals(1),
          reason: '${file.path} must have exactly one <title>',
        );

        // Language attribute on root element
        expect(doc.documentElement?.attributes['lang'], equals('en'));
      }
    });

    test(
      'Generated consumer sitemap.xml is valid XML with protocol conformance',
      () {
        final sitemapFile = File('${buildSiteDir.path}/sitemap.xml');
        expect(sitemapFile.existsSync(), isTrue);

        final xml = sitemapFile.readAsStringSync();
        expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
        expect(
          xml,
          contains(
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"',
          ),
        );
        expect(xml, contains('<loc>https://consumer.example.com/</loc>'));
        expect(xml, contains('<loc>https://consumer.example.com/about</loc>'));
        expect(
          xml,
          contains('<loc>https://consumer.example.com/contact</loc>'),
        );
        expect(
          xml.endsWith('</urlset>\n') || xml.endsWith('</urlset>'),
          isTrue,
        );

        // Verify no unclosed tags
        final openUrlCount = '<url>'.allMatches(xml).length;
        final closeUrlCount = '</url>'.allMatches(xml).length;
        expect(openUrlCount, equals(3));
        expect(closeUrlCount, equals(3));
      },
    );

    test(
      'All consumer HTML files pass HtmlValidator strict validation',
      () async {
        const validator = HtmlValidator();
        final report = await validator.validateDirectory(
          buildSiteDir,
          strict: true,
        );

        expect(report.directoryExists, isTrue);
        expect(report.totalFiles, equals(3));
        expect(report.totalErrors, equals(0));
        expect(report.isSuccessful, isTrue);
      },
    );
  });
}
