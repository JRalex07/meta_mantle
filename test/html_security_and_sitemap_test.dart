import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_builder.dart';

void main() {
  group('HTML Sanitizer & Security Hardening', () {
    const sanitizer = HtmlSanitizer();

    test('Strips active executable script tags and iframes', () {
      final input =
          '<div>Hello <script>alert("XSS")</script><iframe src="https://evil.com"></iframe>World</div>';
      final cleaned = sanitizer.sanitize(input);
      expect(cleaned, isNot(contains('<script>')));
      expect(cleaned, isNot(contains('alert("XSS")')));
      expect(cleaned, isNot(contains('<iframe')));
      expect(cleaned, contains('Hello'));
      expect(cleaned, contains('World'));
    });

    test('Strips inline event handlers (on*)', () {
      final input =
          '<button onclick="evil()" onmouseover="steal()" id="btn">Click me</button>';
      final cleaned = sanitizer.sanitize(input);
      expect(cleaned, isNot(contains('onclick')));
      expect(cleaned, isNot(contains('onmouseover')));
      expect(cleaned, contains('id="btn"'));
    });

    test('Rejects dangerous URL schemes (javascript:, vbscript:, data:)', () {
      final cases = [
        '<a href="javascript:alert(1)">Link</a>',
        '<a href="  javascript:alert(1) ">Link</a>',
        '<a href="JAVASCRIPT:alert(1)">Link</a>',
        '<a href="vbscript:msgbox(1)">Link</a>',
        '<a href="data:text/html,<script>alert(1)</script>">Link</a>',
      ];

      for (final c in cases) {
        final cleaned = sanitizer.sanitize(c);
        expect(
          cleaned,
          isNot(contains('javascript:')),
          reason: 'Case failed: $c',
        );
        expect(
          cleaned,
          isNot(contains('vbscript:')),
          reason: 'Case failed: $c',
        );
        expect(cleaned, isNot(contains('data:')), reason: 'Case failed: $c');
      }
    });

    test('Blocks protocol-relative URL bypass (//evil.com) by default', () {
      final input =
          '<a href="//evil.com/phish">Phishing Link</a><img src="//evil.com/tracker.png" alt="tracker">';
      final cleaned = sanitizer.sanitize(input);
      expect(cleaned, isNot(contains('//evil.com/phish')));
      expect(cleaned, isNot(contains('//evil.com/tracker.png')));
    });

    test('Allows safe relative paths and standard schemes (http, https, mailto, tel)', () {
      final input = '''
        <a href="/products/rice">Relative Path</a>
        <a href="https://trusted.com">HTTPS</a>
        <a href="mailto:support@trusted.com">Email</a>
        <a href="tel:+1234567890">Phone</a>
      ''';
      final cleaned = sanitizer.sanitize(input);
      expect(cleaned, contains('href="/products/rice"'));
      expect(cleaned, contains('href="https://trusted.com"'));
      expect(cleaned, contains('href="mailto:support@trusted.com"'));
      expect(cleaned, contains('href="tel:+1234567890"'));
    });

    test('Preserves safe aria-* and data-* attributes with valid identifiers', () {
      final input =
          '<div data-test-id="card-1" data-category="grain" aria-label="Product Card" aria-hidden="false">Card</div>';
      final cleaned = sanitizer.sanitize(input);
      expect(cleaned, contains('data-test-id="card-1"'));
      expect(cleaned, contains('data-category="grain"'));
      expect(cleaned, contains('aria-label="Product Card"'));
      expect(cleaned, contains('aria-hidden="false"'));
    });

    test('Enforces rel="noopener noreferrer" on target="_blank" links', () {
      final input =
          '<a href="https://external.org" target="_blank">External</a>';
      final cleaned = sanitizer.sanitize(input);
      expect(cleaned, contains('rel="noopener noreferrer"'));
    });
  });

  group('ElementNode Attribute & Tag Validation', () {
    test('Throws on invalid tag names', () {
      expect(() => ElementNode('div<script>').toHtml(), throwsArgumentError);
      expect(() => ElementNode('h1 alert(1)').toHtml(), throwsArgumentError);
      expect(() => ElementNode('123tag').toHtml(), throwsArgumentError);
    });

    test('Throws on event handler attributes', () {
      expect(
        () =>
            ElementNode('button', attributes: {'onclick': 'alert(1)'}).toHtml(),
        throwsArgumentError,
      );
      expect(
        () => ElementNode(
          'img',
          attributes: {'onerror': 'alert(1)', 'alt': 'test'},
        ).toHtml(),
        throwsArgumentError,
      );
    });

    test('Throws on unsafe URL schemes in href and src', () {
      expect(
        () => ElementNode(
          'a',
          attributes: {'href': 'javascript:alert(1)'},
        ).toHtml(),
        throwsArgumentError,
      );
      expect(
        () => ElementNode(
          'img',
          attributes: {'src': 'data:text/html;alert(1)', 'alt': 'test'},
        ).toHtml(),
        throwsArgumentError,
      );
      expect(
        () =>
            ElementNode('a', attributes: {'href': '//malicious.com'}).toHtml(),
        throwsArgumentError,
      );
    });

    test('Disallows children on HTML void elements', () {
      expect(
        () => ElementNode(
          'img',
          attributes: {'alt': 'test'},
          children: [const TextNode('illegal')],
        ).toHtml(),
        throwsArgumentError,
      );
      expect(
        () => ElementNode('hr', children: [const TextNode('illegal')]).toHtml(),
        throwsArgumentError,
      );
    });

    test('Serializes boolean attributes correctly according to HTML5 spec', () {
      final el = ElementNode(
        'input',
        attributes: {
          'type': 'checkbox',
          'checked': 'true',
          'disabled': '',
          'readonly': 'false', // Should be omitted
        },
      );
      final html = el.toHtml();
      expect(html, contains(' checked'));
      expect(html, contains(' disabled'));
      expect(html, isNot(contains('readonly')));
    });

    test(
      'Always serializes non-void elements with closing tag even if empty',
      () {
        final div = ElementNode('div', attributes: {'id': 'placeholder'});
        expect(div.toHtml(), equals('<div id="placeholder"></div>'));
      },
    );
  });

  group('HeadTag Validation & Escaping', () {
    test('Escapes attribute values in head tags', () {
      final tag = HeadTag(
        key: 'desc',
        tagName: 'meta',
        attributes: {
          'name': 'description',
          'content': 'Welcome to "Organic" & Healthy Foods <store>',
        },
      );
      final html = tag.toHtml();
      expect(
        html,
        contains(
          'content="Welcome to &quot;Organic&quot; &amp; Healthy Foods &lt;store&gt;"',
        ),
      );
    });

    test('Rejects event handler attributes in HeadTag', () {
      expect(
        () => HeadTag(
          key: 'x',
          tagName: 'meta',
          attributes: {'onload': 'alert(1)'},
        ).toHtml(),
        throwsArgumentError,
      );
    });

    test('Escapes title text and prevents script breakout', () {
      final titleTag = HeadTag(
        key: 'title',
        tagName: 'title',
        textContent: 'Fresh <Fruits> & Vegetables',
      );
      expect(
        titleTag.toHtml(),
        equals('<title>Fresh &lt;Fruits&gt; &amp; Vegetables</title>'),
      );

      final scriptTag = HeadTag(
        key: 'app-script',
        tagName: 'script',
        textContent:
            'var data = {"msg": "</script><script>alert(1)</script>"};',
      );
      final scriptHtml = scriptTag.toHtml();
      expect(scriptHtml, isNot(contains('</script><script>')));
      expect(scriptHtml, contains(r'<\/script'));
    });
  });

  group('SitemapGenerator Protocol Limits & Escaping', () {
    test('Throws on invalid maxUrlsPerSitemap bounds', () {
      expect(
        () => SitemapGenerator(maxUrlsPerSitemap: 0).generateUrlset([]),
        throwsA(anyOf(isArgumentError, isAssertionError)),
      );
      expect(
        () => SitemapGenerator(maxUrlsPerSitemap: -5).generateUrlset([]),
        throwsA(anyOf(isArgumentError, isAssertionError)),
      );
      expect(
        () => SitemapGenerator(maxUrlsPerSitemap: 50001).generateUrlset([]),
        throwsA(anyOf(isArgumentError, isAssertionError)),
      );
    });

    test(
      'Escapes special characters in XML sitemap URLs and alternate links',
      () {
        const generator = SitemapGenerator();
        final xml = generator.generateUrlset([
          SitemapUrlEntry(
            loc: 'https://example.com/search?category=grains&sort=asc&lang=en',
            alternates: [
              const AlternateUrl(
                language: 'fr-CA" onclick="evil',
                url: 'https://example.com/fr?cat=grains&sort=asc',
              ),
            ],
            images: ['https://example.com/img?name=rice&size=large'],
          ),
        ]);

        expect(xml, contains('&amp;sort=asc'));
        expect(xml, contains('hreflang="fr-CA&quot; onclick=&quot;evil"'));
        expect(xml, contains('&amp;size=large'));
        expect(xml, isNot(contains('&sort=')));
      },
    );

    test('Clamps priority to [0.0, 1.0] and validates changefreq', () {
      const generator = SitemapGenerator();
      final xml = generator.generateUrlset([
        const SitemapUrlEntry(
          loc: 'https://example.com/page1',
          priority: 2.5,
          changeFreq: 'INVALID_FREQ',
        ),
        const SitemapUrlEntry(
          loc: 'https://example.com/page2',
          priority: -0.4,
          changeFreq: 'DAILY',
        ),
      ]);

      expect(xml, contains('<priority>1.0</priority>'));
      expect(xml, contains('<priority>0.0</priority>'));
      expect(
        xml,
        contains('<changefreq>weekly</changefreq>'),
      ); // Defaults invalid to weekly
      expect(xml, contains('<changefreq>daily</changefreq>'));
    });

    test('Sitemap index generation handles > 50,000 URLs cleanly', () {
      const generator = SitemapGenerator(maxUrlsPerSitemap: 100);
      final entries = List.generate(
        250,
        (i) => SitemapUrlEntry(loc: 'https://example.com/item-$i'),
      );

      final files = generator.generateSitemapIndex(
        entries: entries,
        sitemapBaseUrl: 'https://example.com/sitemaps',
      );

      expect(files.keys, contains('sitemap_index.xml'));
      expect(files.keys, contains('sitemap-1.xml'));
      expect(files.keys, contains('sitemap-2.xml'));
      expect(files.keys, contains('sitemap-3.xml'));

      final indexXml = files['sitemap_index.xml']!;
      expect(
        indexXml,
        contains(
          '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
        ),
      );
      expect(
        indexXml,
        contains('<loc>https://example.com/sitemaps/sitemap-1.xml</loc>'),
      );
      expect(
        indexXml,
        contains('<loc>https://example.com/sitemaps/sitemap-2.xml</loc>'),
      );
      expect(
        indexXml,
        contains('<loc>https://example.com/sitemaps/sitemap-3.xml</loc>'),
      );
    });
  });

  group('JsonLd Safe Script Serialization & Deduplication', () {
    test('JsonLd toSafeScriptJson escapes HTML-sensitive characters and line separators', () {
      final jsonLd = JsonLd({
        '@context': 'https://schema.org',
        '@type': 'Article',
        'headline': '</script><script>alert("attack")</script>',
        'text': 'Line 1\u2028Line 2\u2029Line 3',
        'query': 'a & b < c > d',
      });

      final safe = jsonLd.toSafeScriptJson();
      expect(safe, isNot(contains('</script>')));
      expect(safe, contains(r'\u003C/script\u003E'));
      expect(safe, contains(r'\u0026'));
      expect(safe, contains(r'\u003C'));
      expect(safe, contains(r'\u003E'));
      expect(safe, contains(r'\u2028'));
      expect(safe, contains(r'\u2029'));
    });
  });
}
