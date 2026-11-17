import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:test/test.dart';

void main() {
  group('Independent Consumer Public API Verification', () {
    test(
      'Constructs and renders valid HTML5 document without private imports',
      () {
        final doc = HtmlDocument(
          metadata: const WebMetadata(
            title: 'Test Consumer Title',
            description: 'A test description for the consumer site.',
            canonical: 'https://consumer.example.com/test',
          ),
          bodyNodes: [
            H.header([
              H.nav([H.a('/', 'Home')]),
            ]),
            H.main([
              H.h1('Hello Consumer'),
              H.p('This is pure semantic markup.'),
            ]),
            H.footer([H.p('Footer')]),
          ],
        );

        final html = doc.render();
        expect(html, contains('<!DOCTYPE html>'));
        expect(html, contains('<html lang="en">'));
        expect(html, contains('<title>Test Consumer Title</title>'));
        expect(html, contains('<main>'));
        expect(html, contains('<h1>Hello Consumer</h1>'));
        expect(html, contains('</main>'));
      },
    );

    test('SitemapGenerator generates valid XML with protocol adherence', () {
      const generator = SitemapGenerator();
      final xml = generator.generateUrlset([
        SitemapUrlEntry(
          loc: 'https://consumer.example.com/',
          changeFreq: 'daily',
          priority: 1.0,
          lastMod: DateTime.utc(2026, 11, 17),
        ),
        SitemapUrlEntry(
          loc: 'https://consumer.example.com/about',
          changeFreq: 'monthly',
          priority: 0.8,
        ),
      ]);

      expect(xml, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(
        xml,
        contains('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"'),
      );
      expect(xml, contains('<loc>https://consumer.example.com/</loc>'));
      expect(xml, contains('<changefreq>daily</changefreq>'));
      expect(xml, contains('<priority>1.0</priority>'));
      expect(xml, contains('<lastmod>2026-11-17</lastmod>'));
      expect(xml, contains('</urlset>'));
    });

    test('HtmlValidator validates generated HTML strings without errors', () {
      final doc = HtmlDocument(
        metadata: const WebMetadata(
          title: 'Valid Document',
          description: 'Valid description.',
          canonical: 'https://consumer.example.com/valid',
        ),
        bodyNodes: [
          H.main([H.h1('Accessible Page Title'), H.p('Valid content node.')]),
        ],
      );

      final validator = const HtmlValidator();
      final result = validator.validateHtml(
        doc.render(),
        filePath: 'valid.html',
      );
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });
  });
}
