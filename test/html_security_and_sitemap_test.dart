import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:meta_mantle/src/html/url_policy.dart';
import 'package:xml/xml.dart';

void main() {
  group('HTML Sanitizer & Security Hardening', () {
    final sanitizer = HtmlSanitizer();

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

    test('HtmlSanitizer honors allowProtocolRelative configuration', () {
      final permissiveSanitizer = HtmlSanitizer(allowProtocolRelative: true);
      const input = '<a href="//cdn.example.com/file.png">CDN</a>';
      final cleaned = permissiveSanitizer.sanitize(input);
      expect(cleaned, contains('href="//cdn.example.com/file.png"'));

      final strictSanitizer = HtmlSanitizer(allowProtocolRelative: false);
      final strictCleaned = strictSanitizer.sanitize(input);
      expect(strictCleaned, isNot(contains('//cdn.example.com/file.png')));

      // Dangerous schemes must still be rejected even with allowProtocolRelative: true
      const evil =
          '<a href="javascript:alert(1)">Evil</a><a href="//\\evil.com">UNC</a>';
      final evilCleaned = permissiveSanitizer.sanitize(evil);
      expect(evilCleaned, isNot(contains('javascript:')));
      expect(evilCleaned, isNot(contains('//\\evil.com')));
    });

    test('HtmlSanitizer honors custom allowedSchemes configuration', () {
      final appSanitizer = HtmlSanitizer(
        allowedSchemes: const {'https', 'myapp'},
      );

      const input = '''
        <a href="https://trusted.com">HTTPS</a>
        <a href="myapp:launch">App Deep Link</a>
        <a href="http://unsecured.com">HTTP Not Allowed</a>
        <a href="ftp://files.org">FTP Not Allowed</a>
      ''';
      final cleaned = appSanitizer.sanitize(input);
      expect(cleaned, contains('href="https://trusted.com"'));
      expect(cleaned, contains('href="myapp:launch"'));
      expect(cleaned, isNot(contains('http://unsecured.com')));
      expect(cleaned, isNot(contains('ftp://files.org')));
    });

    test(
      'HtmlSanitizer constructor rejects dangerous schemes in allowedSchemes',
      () {
        expect(
          () => HtmlSanitizer(allowedSchemes: const {'https', 'javascript'}),
          throwsArgumentError,
        );
        expect(
          () => HtmlSanitizer(allowedSchemes: const {'data', 'https'}),
          throwsArgumentError,
        );
        expect(
          () => HtmlSanitizer(allowedSchemes: const {'vbscript'}),
          throwsArgumentError,
        );
        expect(
          () => HtmlSanitizer(allowedSchemes: const {'blob'}),
          throwsArgumentError,
        );
        expect(
          () => HtmlSanitizer(allowedSchemes: const {'file'}),
          throwsArgumentError,
        );
      },
    );

    test('HtmlSanitizer constructor validates scheme format, tag names and attributes', () {
      // Invalid scheme syntax
      expect(
        () => HtmlSanitizer(allowedSchemes: const {'invalid scheme!'}),
        throwsArgumentError,
      );
      // Prohibited executable tags
      expect(
        () => HtmlSanitizer(allowedTags: const {'p', 'script'}),
        throwsArgumentError,
      );
      expect(
        () => HtmlSanitizer(allowedTags: const {'p', 'iframe'}),
        throwsArgumentError,
      );
      // Event handler in allowed attributes
      expect(
        () => HtmlSanitizer(allowedAttributes: const {'href', 'onclick'}),
        throwsArgumentError,
      );
    });

    test('HtmlSanitizer custom tag and attribute allowlists restrict output', () {
      final strict = HtmlSanitizer(
        allowedTags: const {'p', 'b'},
        allowedAttributes: const {'class'},
      );
      const input =
          '<p class="lead" id="p1">Hello <b>World</b> <a href="https://example.com">Link</a></p>';
      final cleaned = strict.sanitize(input);
      expect(cleaned, contains('<p class="lead">'));
      expect(cleaned, isNot(contains('id="p1"')));
      expect(cleaned, contains('<b>World</b>'));
      expect(cleaned, isNot(contains('<a')));
      expect(cleaned, isNot(contains('Link')));
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

      final scriptTag = HeadTag.trustedScript(
        key: 'app-script',
        content: 'var data = {"msg": "</script><script>alert(1)</script>"};',
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
                language: 'fr-CA',
                url: 'https://example.com/fr?cat=grains&sort=asc&msg="hello"',
              ),
            ],
            images: [
              'https://example.com/img?name=rice&size=large&tag=<fresh>',
            ],
          ),
        ]);

        expect(xml, contains('&amp;sort=asc'));
        expect(xml, contains('hreflang="fr-CA"'));
        expect(xml, contains('&quot;hello&quot;'));
        expect(xml, contains('&amp;size=large'));
        expect(xml, contains('&lt;fresh&gt;'));
        expect(xml, isNot(contains('&sort=')));
      },
    );

    test(
      'Rejects invalid changefreq and invalid priority with ArgumentError',
      () {
        const generator = SitemapGenerator();
        final xml = generator.generateUrlset([
          const SitemapUrlEntry(
            loc: 'https://example.com/page1',
            priority: 0.8,
            changeFreq: 'monthly',
          ),
          const SitemapUrlEntry(
            loc: 'https://example.com/page2',
            priority: 0.0,
            changeFreq: 'DAILY',
          ),
        ]);

        expect(xml, contains('<priority>0.8</priority>'));
        expect(xml, contains('<priority>0.0</priority>'));
        expect(xml, contains('<changefreq>monthly</changefreq>'));
        expect(xml, contains('<changefreq>daily</changefreq>'));

        expect(
          () => generator.generateUrlset([
            const SitemapUrlEntry(
              loc: 'https://example.com/bad-freq',
              changeFreq: 'invalid_frequency',
            ),
          ]),
          throwsArgumentError,
        );

        expect(
          () => generator.generateUrlset([
            const SitemapUrlEntry(
              loc: 'https://example.com/bad-p-high',
              priority: 1.5,
            ),
          ]),
          throwsArgumentError,
        );

        expect(
          () => generator.generateUrlset([
            const SitemapUrlEntry(
              loc: 'https://example.com/bad-p-low',
              priority: -0.1,
            ),
          ]),
          throwsArgumentError,
        );
      },
    );

    test('Sitemap index generation partitions entries according to maxUrlsPerSitemap', () {
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

    test('Genuine 50,000 URL boundary produces single valid sitemap XML', () {
      const generator = SitemapGenerator(); // default 50,000 limit
      final entries = List.generate(
        50000,
        (i) => SitemapUrlEntry(loc: 'https://example.com/page-$i'),
      );

      final files = generator.generateSitemapIndex(
        entries: entries,
        sitemapBaseUrl: 'https://example.com/sitemaps',
      );

      expect(files.length, equals(1));
      expect(files.containsKey('sitemap.xml'), isTrue);

      final xmlString = files['sitemap.xml']!;
      final doc = XmlDocument.parse(xmlString);
      final urls = doc.findAllElements('url');
      expect(urls.length, equals(50000));
    });

    test(
      'Genuine 50,001 URL boundary partitions into index and two sitemaps',
      () {
        const generator = SitemapGenerator(); // default 50,000 limit
        final entries = List.generate(
          50001,
          (i) => SitemapUrlEntry(loc: 'https://example.com/item-$i'),
        );

        expect(
          () => generator.generateUrlset(entries),
          throwsArgumentError,
          reason:
              'generateUrlset must reject entries exceeding maxUrlsPerSitemap',
        );

        final files = generator.generateSitemapIndex(
          entries: entries,
          sitemapBaseUrl: 'https://example.com/sitemaps',
        );

        expect(files.length, equals(3));
        expect(files.containsKey('sitemap_index.xml'), isTrue);
        expect(files.containsKey('sitemap-1.xml'), isTrue);
        expect(files.containsKey('sitemap-2.xml'), isTrue);

        final indexDoc = XmlDocument.parse(files['sitemap_index.xml']!);
        expect(indexDoc.findAllElements('sitemap').length, equals(2));

        final part1Doc = XmlDocument.parse(files['sitemap-1.xml']!);
        expect(part1Doc.findAllElements('url').length, equals(50000));

        final part2Doc = XmlDocument.parse(files['sitemap-2.xml']!);
        expect(part2Doc.findAllElements('url').length, equals(1));
      },
    );

    test('Handles empty entry set gracefully', () {
      const generator = SitemapGenerator();
      final xml = generator.generateUrlset([]);
      final doc = XmlDocument.parse(xml);
      expect(doc.findAllElements('urlset').length, equals(1));
      expect(doc.findAllElements('url').length, equals(0));
    });

    test('Rejects non-finite, negative, and excessive priority values', () {
      const generator = SitemapGenerator();
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(
            loc: 'https://example.com/nan',
            priority: double.nan,
          ),
        ]),
        throwsArgumentError,
      );

      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(
            loc: 'https://example.com/inf',
            priority: double.infinity,
          ),
        ]),
        throwsArgumentError,
      );

      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(
            loc: 'https://example.com/neg-inf',
            priority: double.negativeInfinity,
          ),
        ]),
        throwsArgumentError,
      );

      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: 'https://example.com/high', priority: 2.5),
        ]),
        throwsArgumentError,
      );

      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: 'https://example.com/low', priority: -0.8),
        ]),
        throwsArgumentError,
      );
    });

    test('Rejects invalid URLs and invalid languages in sitemap', () {
      const generator = SitemapGenerator();

      // Missing host
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: 'http:///no-host'),
        ]),
        throwsArgumentError,
      );

      // Relative loc
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: '/relative-path'),
        ]),
        throwsArgumentError,
      );

      // Userinfo / credentials
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: 'https://user:pass@example.com/secure'),
        ]),
        throwsArgumentError,
      );

      // Invalid alternate language
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(
            loc: 'https://example.com/en',
            alternates: [
              AlternateUrl(
                language: 'invalid_lang_tag!',
                url: 'https://example.com/fr',
              ),
            ],
          ),
        ]),
        throwsArgumentError,
      );

      // Invalid alternate URL
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(
            loc: 'https://example.com/en',
            alternates: [
              AlternateUrl(language: 'fr', url: 'javascript:alert(1)'),
            ],
          ),
        ]),
        throwsArgumentError,
      );

      // Empty or whitespace-only loc throws ArgumentError
      expect(
        () => generator.generateUrlset([const SitemapUrlEntry(loc: '')]),
        throwsArgumentError,
      );
      expect(
        () => generator.generateUrlset([const SitemapUrlEntry(loc: '   ')]),
        throwsArgumentError,
      );

      // Control characters in loc throws ArgumentError
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: 'https://example.com/test\x00path'),
        ]),
        throwsArgumentError,
      );
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: 'https://example.com/test\x1Fpath'),
        ]),
        throwsArgumentError,
      );

      // Raw unencoded whitespace in loc throws ArgumentError
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: 'https://example.com/with space'),
        ]),
        throwsArgumentError,
      );

      // Invalid percent-encoding in loc throws ArgumentError
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: 'https://example.com/item%ZZ'),
        ]),
        throwsArgumentError,
      );
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(loc: 'https://example.com/item%'),
        ]),
        throwsArgumentError,
      );

      // sitemapBaseUrl validation: must reject query and fragment
      expect(
        () => generator.generateSitemapIndex(
          entries: [const SitemapUrlEntry(loc: 'https://example.com/page')],
          sitemapBaseUrl: 'https://example.com/sitemaps?feed=1',
        ),
        throwsArgumentError,
      );
      expect(
        () => generator.generateSitemapIndex(
          entries: [const SitemapUrlEntry(loc: 'https://example.com/page')],
          sitemapBaseUrl: 'https://example.com/sitemaps#frag',
        ),
        throwsArgumentError,
      );

      // Invalid image URL
      expect(
        () => generator.generateUrlset([
          const SitemapUrlEntry(
            loc: 'https://example.com/img',
            images: ['//evil.com/pic.jpg'],
          ),
        ]),
        throwsArgumentError,
      );

      // Invalid sitemapBaseUrl
      expect(
        () => generator.generateSitemapIndex(
          entries: [const SitemapUrlEntry(loc: 'https://example.com/')],
          sitemapBaseUrl: 'not-a-valid-url',
        ),
        throwsArgumentError,
      );
    });

    test('Enforces 50 MB (52,428,800 bytes) uncompressed UTF-8 limit per sitemaps.org protocol', () {
      const generator = SitemapGenerator();

      // Single entry exceeding 50 MB throws ArgumentError
      final hugePath = 'a' * 52428800;
      expect(
        () => generator.generateSitemapIndex(
          entries: [SitemapUrlEntry(loc: 'https://example.com/$hugePath')],
          sitemapBaseUrl: 'https://example.com',
        ),
        throwsArgumentError,
      );

      // Verify that multibyte Unicode paths correctly contribute to byte count
      final unicodeEntry = SitemapUrlEntry(
        loc: 'https://example.com/products/%E4%BD%A0%E5%A5%BD',
        alternates: [
          const AlternateUrl(
            language: 'zh-CN',
            url: 'https://example.com/products/%E4%BD%A0%E5%A5%BD-cn',
          ),
        ],
      );
      final singleResult = generator.generateSitemapIndex(
        entries: [unicodeEntry],
        sitemapBaseUrl: 'https://example.com',
      );
      expect(singleResult.containsKey('sitemap.xml'), isTrue);
      final singleBytes = utf8.encode(singleResult['sitemap.xml']!).length;
      expect(singleBytes, isPositive);
      expect(singleBytes, lessThan(generator.maxBytesPerSitemap));
    });

    test(
      'Configurable maxBytesPerSitemap with protocol boundary validation',
      () {
        expect(
          () => SitemapGenerator(maxBytesPerSitemap: 52428801),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => SitemapGenerator(maxBytesPerSitemap: 0),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => SitemapGenerator(maxBytesPerSitemap: -1),
          throwsA(isA<AssertionError>()),
        );
        expect(SitemapGenerator.protocolMaxBytes, equals(52428800));

        const validSmall = SitemapGenerator(maxBytesPerSitemap: 1024);
        expect(validSmall.maxBytesPerSitemap, equals(1024));
      },
    );

    test('Aggregate-size splitting partitions valid entries exceeding byte limit', () {
      // Configure generator with a 750-byte limit (header+footer is ~200 bytes, each entry is ~90 bytes)
      const generator = SitemapGenerator(maxBytesPerSitemap: 750);

      final entries = List.generate(
        10,
        (i) => SitemapUrlEntry(loc: 'https://example.com/item-$i'),
      );

      // Verify that 2 entries fit in a single sitemap file
      final twoResult = generator.generateSitemapIndex(
        entries: entries.take(2).toList(),
        sitemapBaseUrl: 'https://example.com',
      );
      expect(twoResult.length, equals(1));
      expect(twoResult.containsKey('sitemap.xml'), isTrue);
      expect(
        utf8.encode(twoResult['sitemap.xml']!).length,
        lessThanOrEqualTo(750),
      );

      // 10 entries exceed 750 bytes and must automatically partition
      final partitionedResult = generator.generateSitemapIndex(
        entries: entries,
        sitemapBaseUrl: 'https://example.com',
      );

      expect(partitionedResult.containsKey('sitemap_index.xml'), isTrue);
      expect(partitionedResult.length, greaterThan(1));

      final indexXml = partitionedResult['sitemap_index.xml']!;
      expect(utf8.encode(indexXml).length, lessThanOrEqualTo(750));

      final collectedUrls = <String>[];
      for (final entry in partitionedResult.entries) {
        if (entry.key == 'sitemap_index.xml') continue;

        // Every generated sitemap file must be within the configured byte limit
        final sitemapBytes = utf8.encode(entry.value).length;
        expect(
          sitemapBytes,
          lessThanOrEqualTo(750),
          reason: '${entry.key} exceeds 750 bytes ($sitemapBytes bytes)',
        );

        // Verify index references each file exactly once
        expect(
          indexXml,
          contains('<loc>https://example.com/${entry.key}</loc>'),
        );

        // Extract URLs from sitemap XML
        final doc = XmlDocument.parse(entry.value);
        for (final locElement in doc.findAllElements('loc')) {
          collectedUrls.add(locElement.innerText);
        }
      }

      // No entries lost or duplicated
      expect(collectedUrls.length, equals(entries.length));
      expect(collectedUrls, equals(entries.map((e) => e.loc).toList()));
    });

    test('Rejects single entry exceeding allowed sitemap byte size', () {
      const generator = SitemapGenerator(maxBytesPerSitemap: 500);
      final oversizedEntry = SitemapUrlEntry(
        loc: 'https://example.com/${'longpath/' * 50}',
      );
      expect(
        () => generator.generateSitemapIndex(
          entries: [oversizedEntry],
          sitemapBaseUrl: 'https://example.com',
        ),
        throwsArgumentError,
      );
    });

    test(
      'Tests real Unicode characters in URLs, alternates, and image tags',
      () {
        const generator = SitemapGenerator(maxBytesPerSitemap: 2048);

        final unicodeEntries = [
          SitemapUrlEntry(
            loc: 'https://example.com/products/你好世界',
            alternates: const [
              AlternateUrl(
                language: 'zh-CN',
                url: 'https://example.com/products/你好世界?lang=zh-CN',
              ),
              AlternateUrl(
                language: 'ja-JP',
                url: 'https://example.com/products/こんにちは',
              ),
            ],
            images: const ['https://example.com/images/优质大米.png'],
          ),
          const SitemapUrlEntry(
            loc: 'https://example.com/products/café-au-lait',
            images: ['https://example.com/images/crème-brûlée.jpg'],
          ),
        ];

        final result = generator.generateSitemapIndex(
          entries: unicodeEntries,
          sitemapBaseUrl: 'https://example.com',
        );

        expect(result.containsKey('sitemap.xml'), isTrue);
        final xml = result['sitemap.xml']!;

        // Verify that utf8.encode measures true multibyte length
        final byteLength = utf8.encode(xml).length;
        expect(byteLength, greaterThan(xml.length));
        expect(byteLength, lessThanOrEqualTo(2048));

        expect(xml, contains('https://example.com/products/你好世界'));
        expect(xml, contains('https://example.com/products/こんにちは'));
        expect(xml, contains('https://example.com/images/优质大米.png'));
        expect(xml, contains('https://example.com/products/café-au-lait'));
      },
    );
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

  group('Unified URL Security Policy (UrlPolicy)', () {
    test('Rejects dangerous, active, and unknown schemes', () {
      final dangerous = [
        'javascript:alert(1)',
        'JAVASCRIPT:alert(1)',
        '  javascript:alert(1)  ',
        'java\tscript:alert(1)',
        'java\nscript:alert(1)',
        'java\r\nscript:alert(1)',
        'java\x00script:alert(1)',
        '%6a%61%76%61%73%63%72%69%70%74:alert(1)',
        'java%09script:alert(1)',
        'java%0ascript:alert(1)',
        'vbscript:msgbox(1)',
        'VBSCRIPT:msgbox(1)',
        'data:text/html,<script>alert(1)</script>',
        'DATA:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
        'blob:https://example.com/d3b3a9d7-01dd',
        'file:///etc/passwd',
        'file://C:/Windows/win.ini',
        'custom-scheme://payload',
        'intent://scan/#Intent;scheme=zxing;package=com.google.zxing.client.android;end',
        'about:blank',
        'chrome://settings',
      ];

      for (final url in dangerous) {
        expect(
          UrlPolicy.isSafe(url),
          isFalse,
          reason: 'Expected "$url" to be rejected by UrlPolicy',
        );
        expect(
          () => UrlPolicy.assertSafe(url, 'testUrl'),
          throwsArgumentError,
          reason: 'Expected assertSafe to throw for "$url"',
        );
      }
    });

    test('Rejects protocol-relative and backslash-based bypasses', () {
      final bypasses = [
        '//evil.com',
        '//evil.com/path',
        '///evil.com',
        '////evil.com',
        r'\evil.com',
        r'\\evil.com',
        r'\\\evil.com',
        r'/\evil.com',
        r'/\\evil.com',
        r'\/evil.com',
        r'\path/to/file',
        r'//',
        r'\\',
      ];

      for (final url in bypasses) {
        expect(
          UrlPolicy.isSafe(url),
          isFalse,
          reason: 'Expected bypass "$url" to be rejected by UrlPolicy',
        );
        expect(() => UrlPolicy.assertSafe(url, 'testUrl'), throwsArgumentError);
      }
    });

    test('Allows safe HTTP, HTTPS, mailto, tel, and relative paths', () {
      final safe = [
        'http://example.com',
        'http://example.com/',
        'https://example.com/products/123?ref=feed#desc',
        'https://sub.domain.example.co.uk:8080/api',
        'mailto:support@example.com',
        'mailto:user@example.com?subject=Help',
        'tel:+15551234567',
        'tel:555-1234',
        '/',
        '/products',
        '/products/item-123',
        '/search?q=dart&sort=asc',
        '/index.html#features',
        'products/item-123',
        'item.html',
        '../images/logo.png',
        './styles.css',
        '#top',
        '#heading:1',
        '?query=http:test',
        'path/to:file',
      ];

      for (final url in safe) {
        expect(
          UrlPolicy.isSafe(url),
          isTrue,
          reason: 'Expected "$url" to be allowed by UrlPolicy',
        );
        expect(() => UrlPolicy.assertSafe(url, 'testUrl'), returnsNormally);
      }
    });

    test('Rejects leading, trailing, and embedded raw whitespace and control characters across all serialization paths', () {
      final malicious = [
        '\nhttps://example.com',
        'https://example.com\n',
        '\thttps://example.com',
        'https://example.com\t',
        '\rhttps://example.com',
        'https://example.com\r',
        ' https://example.com',
        'https://example.com ',
        'https://example.com\x00path',
        'https://example.com\x7Fpath',
        'https://example.com\x80path',
        'https://example.com\x9Fpath',
        'https://example.com/path\x01evil',
        'https://example.com/path\x1Fevil',
        '%6a%61%76%61%73%63%72%69%70%74:alert(1)',
        'java\x00script:alert(1)',
        'java\x1Fscript:alert(1)',
        'java\x7Fscript:alert(1)',
        'java\x9Fscript:alert(1)',
        r'https://example.com\path',
        r'\https://example.com',
      ];

      for (final url in malicious) {
        expect(
          UrlPolicy.isSafe(url),
          isFalse,
          reason: 'Expected "$url" to be rejected by UrlPolicy.isSafe',
        );
        expect(
          () => UrlPolicy.assertSafe(url, 'testUrl'),
          throwsArgumentError,
          reason: 'Expected UrlPolicy.assertSafe to throw for "$url"',
        );

        // HtmlSanitizer
        expect(
          HtmlSanitizer(allowedSchemes: {'http', 'https'}).isValidUrl(url),
          isFalse,
          reason: 'Expected HtmlSanitizer.isValidUrl to reject "$url"',
        );

        // ElementNode serialization
        expect(
          () => ElementNode('a', attributes: {'href': url}).toHtml(),
          throwsArgumentError,
          reason: 'Expected ElementNode.toHtml to throw for "$url"',
        );

        // HeadTag serialization
        expect(
          () => HeadTag(
            key: 'link',
            tagName: 'link',
            attributes: {'rel': 'canonical', 'href': url},
          ).toHtml(),
          throwsArgumentError,
          reason: 'Expected HeadTag.toHtml to throw for "$url"',
        );

        // HtmlDocument serialization
        expect(
          () => HtmlDocument(
            metadata: const WebMetadata(title: 'Test'),
            customHeadTags: [
              HeadTag(
                key: 'link',
                tagName: 'link',
                attributes: {'rel': 'canonical', 'href': url},
              ),
            ],
          ).render(),
          throwsArgumentError,
          reason: 'Expected HtmlDocument.render to throw for "$url"',
        );

        // Sitemap URL validation
        expect(
          () => const SitemapGenerator().generateSitemapIndex(
            entries: [SitemapUrlEntry(loc: url)],
            sitemapBaseUrl: 'https://example.com',
          ),
          throwsArgumentError,
          reason: 'Expected SitemapGenerator to throw for "$url"',
        );
      }
    });
  });

  group('HtmlDocument & HeadTag Adversarial Security Suite', () {
    test('Rejects markup injection via HeadTag.tagName', () {
      final maliciousTags = [
        'script><script>alert(1)</script>',
        'meta><svg onload=alert(1)>',
        'div style="position:fixed"',
        'invalid tag',
        'title</title><script>alert(1)</script>',
        '1invalid',
      ];

      for (final tag in maliciousTags) {
        final headTag = HeadTag(key: 'malicious', tagName: tag);
        expect(
          () => headTag.toHtml(),
          throwsArgumentError,
          reason: 'HeadTag.toHtml must reject tag name "$tag"',
        );

        final doc = HtmlDocument(
          metadata: const WebMetadata(title: 'Test'),
          customHeadTags: [headTag],
        );
        expect(
          () => doc.render(),
          throwsArgumentError,
          reason: 'HtmlDocument.render must reject tag name "$tag"',
        );
      }
    });

    test('Rejects markup injection via HeadTag.attributes keys', () {
      final maliciousKeys = [
        'foo="bar" onmouseover="alert(1)"',
        'attr><script>alert(1)</script>',
        'on',
        'onclick',
        'onload',
        'onerror',
        'ONMOUSEOVER',
        'invalid key',
        'name=foo',
      ];

      for (final key in maliciousKeys) {
        final headTag = HeadTag(
          key: 'malicious',
          tagName: 'meta',
          attributes: {key: 'safe-value'},
        );
        expect(
          () => headTag.toHtml(),
          throwsArgumentError,
          reason: 'HeadTag.toHtml must reject attribute key "$key"',
        );

        final doc = HtmlDocument(
          metadata: const WebMetadata(title: 'Test'),
          customHeadTags: [headTag],
        );
        expect(
          () => doc.render(),
          throwsArgumentError,
          reason: 'HtmlDocument.render must reject attribute key "$key"',
        );
      }
    });

    test('Rejects unsafe URLs in HeadTag href and src attributes', () {
      final unsafeUrls = [
        'javascript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'vbscript:msgbox(1)',
        '//evil.com/x.js',
        r'\evil.com/x.js',
        'blob:https://evil.com/uuid',
      ];

      for (final url in unsafeUrls) {
        final scriptTag = HeadTag(
          key: 'script',
          tagName: 'script',
          attributes: {'src': url},
        );
        expect(
          () => scriptTag.toHtml(),
          throwsArgumentError,
          reason: 'HeadTag.toHtml must reject script src "$url"',
        );

        final linkTag = HeadTag(
          key: 'link',
          tagName: 'link',
          attributes: {'rel': 'stylesheet', 'href': url},
        );
        expect(
          () => linkTag.toHtml(),
          throwsArgumentError,
          reason: 'HeadTag.toHtml must reject link href "$url"',
        );
      }
    });

    test('Enforces trusted-script boundary: untrusted inline script or style throws', () {
      // Untrusted script content
      final untrustedScript = HeadTag(
        key: 'untrusted-js',
        tagName: 'script',
        textContent: 'alert("untrusted")',
      );
      expect(() => untrustedScript.toHtml(), throwsArgumentError);

      // Untrusted style content
      final untrustedStyle = HeadTag(
        key: 'untrusted-css',
        tagName: 'style',
        textContent: 'body { display: none; }',
      );
      expect(() => untrustedStyle.toHtml(), throwsArgumentError);

      // Trusted script content works and escapes </script> breakout
      final trustedScript = HeadTag.trustedScript(
        key: 'trusted-js',
        content: 'console.log("</script><script>alert(1)</script>");',
      );
      final scriptHtml = trustedScript.toHtml();
      expect(scriptHtml, isNot(contains('</script><script>')));
      expect(scriptHtml, contains(r'<\/script'));

      // Trusted style content works and escapes </style> breakout
      final trustedStyle = HeadTag.trustedStyle(
        key: 'trusted-css',
        css: 'body { background: url("</style><script>alert(1)</script>"); }',
      );
      final styleHtml = trustedStyle.toHtml();
      expect(styleHtml, isNot(contains('</style><script>')));
      expect(styleHtml, contains(r'<\/style'));
    });

    test('Rejects malicious flutterBootstrapSrc and baseHref', () {
      final maliciousUrls = [
        'javascript:alert(1)',
        '//evil.com/bootstrap.js',
        r'\evil.com/bootstrap.js',
        'data:application/javascript,alert(1)',
      ];

      for (final url in maliciousUrls) {
        final docBootstrap = HtmlDocument(
          metadata: const WebMetadata(title: 'Test'),
          includeFlutterBootstrap: true,
          flutterBootstrapSrc: url,
        );
        expect(
          () => docBootstrap.render(),
          throwsArgumentError,
          reason: 'flutterBootstrapSrc must reject "$url"',
        );

        final docBase = HtmlDocument(
          metadata: const WebMetadata(title: 'Test'),
          baseHref: url,
        );
        expect(
          () => docBase.render(),
          throwsArgumentError,
          reason: 'baseHref must reject "$url"',
        );
      }
    });

    test('Parses rendered document and verifies injected scripts/attributes cannot appear', () {
      final doc = HtmlDocument(
        metadata: WebMetadata(
          title: 'Secure Store <>&"',
          description:
              'Description with <script>alert(1)</script> and "quotes"',
          jsonLd: [
            JsonLd.website(name: 'Store & Co', url: 'https://example.com/'),
          ],
        ),
        baseHref: '/app/',
        includeFlutterBootstrap: true,
        flutterBootstrapSrc: 'flutter_bootstrap.js',
        customHeadTags: [
          const HeadTag(
            key: 'theme',
            tagName: 'meta',
            attributes: {'name': 'theme-color', 'content': '#0066cc'},
          ),
          HeadTag.jsonLd(
            key: 'custom-jsonld',
            jsonLdContent: '{"@context":"https://schema.org","@type":"Organization","name":"Acme"}',
          ),
        ],
        bodyNodes: [H.h1('Hello World'), H.p('Welcome to our secure site.')],
      );

      final html = doc.render();
      expect(html, isNot(contains('<script>alert(1)</script>')));

      // Parse with HTML5 parser to verify single root, valid head, valid body
      final parsed = html_parser.parse(html);
      expect(parsed.querySelectorAll('html').length, equals(1));
      expect(parsed.querySelectorAll('head').length, equals(1));
      expect(parsed.querySelectorAll('body').length, equals(1));

      // Title escaped
      final titleEl = parsed.querySelector('title');
      expect(titleEl?.text, equals('Secure Store <>&"'));

      // Base tag
      final baseEl = parsed.querySelector('base');
      expect(baseEl?.attributes['href'], equals('/app/'));

      // Scripts present: only JSON-LD and flutter_bootstrap.js
      final scripts = parsed.querySelectorAll('script');
      expect(scripts.length, equals(3)); // 2 JSON-LD + 1 bootstrap
      for (final s in scripts) {
        final type = s.attributes['type'];
        final src = s.attributes['src'];
        expect(
          type == 'application/ld+json' || src == 'flutter_bootstrap.js',
          isTrue,
        );
      }
    });

    test('HeadTag allowlist enforces valid HTML5 head elements (rejects div, span, html, body)', () {
      expect(
        () => const HeadTag(key: 'invalid-div', tagName: 'div').toHtml(),
        throwsArgumentError,
      );
      expect(
        () => const HeadTag(key: 'invalid-span', tagName: 'span').toHtml(),
        throwsArgumentError,
      );
      expect(
        () => const HeadTag(key: 'invalid-html', tagName: 'html').toHtml(),
        throwsArgumentError,
      );
      expect(
        () => const HeadTag(key: 'invalid-body', tagName: 'body').toHtml(),
        throwsArgumentError,
      );

      // Valid HTML5 head elements succeed
      for (final tag in HeadTag.allowedHeadTags) {
        final headTag = HeadTag(
          key: 'valid-$tag',
          tagName: tag,
          textContent: tag == 'script' || tag == 'style' ? null : 'content',
        );
        expect(headTag.toHtml(), isNotEmpty);
      }
    });

    test(
      'HeadTag escapes line separators \\u2028 and \\u2029 in script tags',
      () {
        final script = HeadTag.trustedScript(
          key: 'script-separators',
          content: 'const x = "line1\u2028line2\u2029line3";',
        );
        final html = script.toHtml();
        expect(html, contains(r'\u2028'));
        expect(html, contains(r'\u2029'));
        expect(html, isNot(contains('\u2028')));
        expect(html, isNot(contains('\u2029')));
      },
    );

    test('MetadataRenderer does not emit pseudo html-language tag and HtmlDocument preserves lang on root html', () {
      const renderer = MetadataRenderer();
      final tags = renderer.render(
        const WebMetadata(title: 'Title', language: 'fr-FR'),
      );
      expect(
        tags.any(
          (t) => t.tagName.toLowerCase() == 'html' || t.key == 'html-language',
        ),
        isFalse,
      );

      final doc = HtmlDocument(
        metadata: const WebMetadata(title: 'Doc', language: 'fr-FR'),
      );
      final html = doc.render();
      expect(html, contains('<html lang="fr-FR">'));
      expect(html, isNot(contains('<head>\n  <html')));
    });

    test('HtmlDocument deduplicates title, base, canonical, description, robots, OG and Twitter tags with customHeadTags override', () {
      final doc = HtmlDocument(
        metadata: const WebMetadata(
          title: 'Initial Title',
          description: 'Initial Description',
          canonical: 'https://example.com/initial',
          robots: 'index, follow',
          openGraph: OpenGraph(
            title: 'Initial OG',
            description: 'Initial OG Desc',
          ),
          twitter: TwitterCard(title: 'Initial Twitter'),
        ),
        baseHref: '/base1/',
        customHeadTags: [
          const HeadTag(
            key: 'custom-title',
            tagName: 'title',
            textContent: 'Overridden Title',
          ),
          const HeadTag(
            key: 'custom-desc',
            tagName: 'meta',
            attributes: {
              'name': 'description',
              'content': 'Overridden Description',
            },
          ),
          const HeadTag(
            key: 'custom-canonical',
            tagName: 'link',
            attributes: {
              'rel': 'canonical',
              'href': 'https://example.com/overridden',
            },
          ),
          const HeadTag(
            key: 'custom-robots',
            tagName: 'meta',
            attributes: {'name': 'robots', 'content': 'noindex, nofollow'},
          ),
          const HeadTag(
            key: 'custom-base',
            tagName: 'base',
            attributes: {'href': '/overridden-base/'},
          ),
          const HeadTag(
            key: 'custom-og',
            tagName: 'meta',
            attributes: {
              'property': 'og:title',
              'content': 'Overridden OG Title',
            },
          ),
        ],
      );

      final html = doc.render();
      final parsed = html_parser.parse(html);

      // Only 1 title tag, with overridden content
      final titles = parsed.querySelectorAll('title');
      expect(titles.length, equals(1));
      expect(titles.first.text, equals('Overridden Title'));

      // Only 1 canonical tag, with overridden href
      final canonicals = parsed.querySelectorAll('link[rel="canonical"]');
      expect(canonicals.length, equals(1));
      expect(
        canonicals.first.attributes['href'],
        equals('https://example.com/overridden'),
      );

      // Only 1 description meta tag, with overridden content
      final descriptions = parsed.querySelectorAll('meta[name="description"]');
      expect(descriptions.length, equals(1));
      expect(
        descriptions.first.attributes['content'],
        equals('Overridden Description'),
      );

      // Only 1 robots meta tag, with overridden content
      final robots = parsed.querySelectorAll('meta[name="robots"]');
      expect(robots.length, equals(1));
      expect(robots.first.attributes['content'], equals('noindex, nofollow'));

      // Only 1 base tag, with overridden href
      final bases = parsed.querySelectorAll('base');
      expect(bases.length, equals(1));
      expect(bases.first.attributes['href'], equals('/overridden-base/'));

      // OG title is overridden
      final ogTitles = parsed.querySelectorAll('meta[property="og:title"]');
      expect(ogTitles.length, equals(1));
      expect(
        ogTitles.first.attributes['content'],
        equals('Overridden OG Title'),
      );
    });
  });

  group('Sitemap Protocol Comprehensive Verification & Boundary Tests', () {
    test('Exact byte limit boundary: accepts at limit, rejects at limit - 1, accepts at limit + 1', () {
      const baseGen = SitemapGenerator();
      final entry = const SitemapUrlEntry(
        loc: 'https://example.com/boundary-test',
      );
      final baselineXml = baseGen.generateUrlset([entry]);
      final exactBytes = utf8.encode(baselineXml).length;

      // 1. Exactly the configured byte limit: succeeds
      final exactGen = SitemapGenerator(maxBytesPerSitemap: exactBytes);
      final exactXml = exactGen.generateUrlset([entry]);
      expect(utf8.encode(exactXml).length, equals(exactBytes));

      // 2. One byte below the configured limit: throws ArgumentError
      final underGen = SitemapGenerator(maxBytesPerSitemap: exactBytes - 1);
      expect(
        () => underGen.generateUrlset([entry]),
        throwsArgumentError,
        reason: 'Should reject when serialized XML exceeds maxBytesPerSitemap by 1 byte',
      );

      // 3. One byte above the configured limit: succeeds
      final overGen = SitemapGenerator(maxBytesPerSitemap: exactBytes + 1);
      final overXml = overGen.generateUrlset([entry]);
      expect(utf8.encode(overXml).length, lessThanOrEqualTo(exactBytes + 1));
    });

    test('Single oversized entry exceeding byte limit throws ArgumentError in generateSitemapIndex', () {
      const generator = SitemapGenerator(maxBytesPerSitemap: 500);
      // Entry with many alternates and images that alone exceeds 500 bytes
      final oversizedEntry = SitemapUrlEntry(
        loc: 'https://example.com/oversized-page-with-a-very-long-url-path-that-exceeds-the-limit',
        alternates: List.generate(
          10,
          (i) => AlternateUrl(
            language: 'es-$i',
            url:
                'https://example.com/es-$i/oversized-page-with-a-very-long-url-path-that-exceeds-the-limit',
          ),
        ),
      );

      expect(
        () => generator.generateSitemapIndex(
          entries: [oversizedEntry],
          sitemapBaseUrl: 'https://example.com/sitemaps',
        ),
        throwsArgumentError,
      );
    });

    test('Combined URL-count and byte-size constraints partition on whichever limit is hit first', () {
      // Limit to 5 URLs or 1200 bytes
      const generator = SitemapGenerator(
        maxUrlsPerSitemap: 5,
        maxBytesPerSitemap: 1200,
      );

      // 12 small entries: hits URL count limit (5) before byte limit
      final entries = List.generate(
        12,
        (i) => SitemapUrlEntry(loc: 'https://example.com/p$i'),
      );
      final files = generator.generateSitemapIndex(
        entries: entries,
        sitemapBaseUrl: 'https://example.com/sitemaps',
      );

      expect(files.containsKey('sitemap_index.xml'), isTrue);
      expect(files.containsKey('sitemap-1.xml'), isTrue);
      expect(files.containsKey('sitemap-2.xml'), isTrue);
      expect(files.containsKey('sitemap-3.xml'), isTrue);

      // Verify each chunk is <= maxUrlsPerSitemap and <= maxBytesPerSitemap
      final doc1 = XmlDocument.parse(files['sitemap-1.xml']!);
      expect(doc1.findAllElements('url').length, equals(5));
      expect(
        utf8.encode(files['sitemap-1.xml']!).length,
        lessThanOrEqualTo(1200),
      );

      final doc2 = XmlDocument.parse(files['sitemap-2.xml']!);
      expect(doc2.findAllElements('url').length, equals(5));
      expect(
        utf8.encode(files['sitemap-2.xml']!).length,
        lessThanOrEqualTo(1200),
      );

      final doc3 = XmlDocument.parse(files['sitemap-3.xml']!);
      expect(doc3.findAllElements('url').length, equals(2));
      expect(
        utf8.encode(files['sitemap-3.xml']!).length,
        lessThanOrEqualTo(1200),
      );
    });

    test('Escaped XML entities expanding byte count are correctly measured after serialization', () {
      // An entry with characters that expand under XML escaping (&, <, >, ", ')
      final rawEntry = SitemapUrlEntry(
        loc: 'https://example.com/search?q=organic&cat=food&filter="fresh"&tier=<1>',
      );

      const baseGen = SitemapGenerator();
      final xml = baseGen.generateUrlset([rawEntry]);
      final actualByteCount = utf8.encode(xml).length;

      // Ensure that configuring maxBytesPerSitemap to actualByteCount succeeds
      final exactGen = SitemapGenerator(maxBytesPerSitemap: actualByteCount);
      expect(exactGen.generateUrlset([rawEntry]), isNotEmpty);

      // And 1 byte less throws ArgumentError
      final underGen = SitemapGenerator(
        maxBytesPerSitemap: actualByteCount - 1,
      );
      expect(() => underGen.generateUrlset([rawEntry]), throwsArgumentError);
    });

    test(
      'Multibyte Unicode in loc, alternate hreflang/href, and image loc',
      () {
        const generator = SitemapGenerator();
        final unicodeEntry = SitemapUrlEntry(
          loc: 'https://example.com/products/%E6%97%A5%E6%9C%AC%E8%AA%9E-%E4%BA%AC%E9%83%BD',
          alternates: [
            const AlternateUrl(
              language: 'ja-JP',
              url: 'https://example.com/ja/%E4%BA%AC%E9%83%BD',
            ),
            const AlternateUrl(
              language: 'hi-IN',
              url: 'https://example.com/hi/%E0%A4%A8%E0%A4%AE%E0%A4%B8%E0%A5%8D%E0%A4%A4%E0%A5%87',
            ),
          ],
          images: [
            'https://example.com/images/%E5%AF%8C%E5%A3%AB%E5%B1%B1.jpg',
          ],
        );

        final xml = generator.generateUrlset([unicodeEntry]);
        final doc = XmlDocument.parse(xml);
        expect(doc.findAllElements('url').length, equals(1));
        expect(doc.findAllElements('xhtml:link').length, equals(2));
        expect(doc.findAllElements('image:image').length, equals(1));
        expect(utf8.encode(xml).length, isPositive);
      },
    );

    test('Runtime bounds checks throw ArgumentError on out-of-bounds configuration in release mode', () {
      // maxUrlsPerSitemap bounds: <= 0 or > 50000
      expect(
        () => SitemapGenerator(maxUrlsPerSitemap: 0).generateUrlset([]),
        throwsA(anyOf(isArgumentError, isAssertionError)),
      );
      expect(
        () => SitemapGenerator(maxUrlsPerSitemap: 50001).generateUrlset([]),
        throwsA(anyOf(isArgumentError, isAssertionError)),
      );

      // maxBytesPerSitemap bounds: <= 0 or > 52428800
      expect(
        () => SitemapGenerator(maxBytesPerSitemap: 0).generateUrlset([]),
        throwsA(anyOf(isArgumentError, isAssertionError)),
      );
      expect(
        () => SitemapGenerator(maxBytesPerSitemap: 52428801).generateUrlset([]),
        throwsA(anyOf(isArgumentError, isAssertionError)),
      );
    });
  });

  group('URL Security Audit Across All Serialization Entry Points', () {
    const dangerousSchemes = [
      'javascript:alert(1)',
      'vbscript:msgbox(1)',
      'data:text/html,<script>alert(1)</script>',
      'blob:https://example.com/uuid',
      'file:///etc/passwd',
    ];

    test('UrlPolicy.isSafe rejects C0 and C1 control characters, raw whitespace, and backslashes', () {
      // C0 control characters
      expect(UrlPolicy.isSafe('https://example.com/\x00test'), isFalse);
      expect(UrlPolicy.isSafe('https://example.com/\x1Ftest'), isFalse);
      expect(UrlPolicy.isSafe('\x00https://example.com/'), isFalse);
      expect(UrlPolicy.isSafe('https://example.com/\x08'), isFalse);

      // C1 control characters
      expect(UrlPolicy.isSafe('https://example.com/\x7Ftest'), isFalse);
      expect(UrlPolicy.isSafe('https://example.com/\x80test'), isFalse);
      expect(UrlPolicy.isSafe('https://example.com/\x9Ftest'), isFalse);

      // Leading, trailing, and embedded whitespace
      expect(UrlPolicy.isSafe('  https://example.com'), isFalse);
      expect(UrlPolicy.isSafe('\thttps://example.com'), isFalse);
      expect(UrlPolicy.isSafe('\nhttps://example.com'), isFalse);
      expect(UrlPolicy.isSafe('https://example.com  '), isFalse);
      expect(UrlPolicy.isSafe('https://example.com\t'), isFalse);
      expect(UrlPolicy.isSafe('https://example.com\n'), isFalse);
      expect(UrlPolicy.isSafe('https://example.com/foo bar'), isFalse);

      // Backslashes
      expect(UrlPolicy.isSafe(r'https://example.com\evil'), isFalse);
      expect(UrlPolicy.isSafe(r'https:\\example.com'), isFalse);
      expect(UrlPolicy.isSafe(r'\malicious.com'), isFalse);

      // Dangerous schemes
      for (final bad in dangerousSchemes) {
        expect(UrlPolicy.isSafe(bad), isFalse);
      }

      // Obfuscated schemes
      expect(
        UrlPolicy.isSafe('%6a%61%76%61%73%63%72%69%70%74:alert(1)'),
        isFalse,
      );
      expect(UrlPolicy.isSafe('jav%00ascript:alert(1)'), isFalse);
    });

    test('ElementNode rejects unsafe URLs across all URL attributes', () {
      final urlAttrs = [
        'href',
        'src',
        'action',
        'formaction',
        'poster',
        'cite',
      ];
      for (final attr in urlAttrs) {
        expect(
          () => ElementNode(
            'a',
            attributes: {attr: 'javascript:alert(1)'},
          ).toHtml(),
          throwsArgumentError,
        );
        expect(
          () => ElementNode(
            'a',
            attributes: {attr: r'https://example.com\evil'},
          ).toHtml(),
          throwsArgumentError,
        );
        expect(
          () => ElementNode(
            'a',
            attributes: {attr: ' \thttps://example.com'},
          ).toHtml(),
          throwsArgumentError,
        );
        expect(
          () => ElementNode(
            'a',
            attributes: {attr: 'https://example.com\x00'},
          ).toHtml(),
          throwsArgumentError,
        );
      }
    });

    test('HeadTag rejects unsafe URLs in href, src, action, formaction, cite, poster, and data', () {
      expect(
        () => HeadTag(
          key: 'bad-link',
          tagName: 'link',
          attributes: {'href': 'javascript:alert(1)'},
        ).toHtml(),
        throwsArgumentError,
      );
      expect(
        () => HeadTag(
          key: 'bad-script',
          tagName: 'script',
          attributes: {'src': 'data:text/javascript,evil()'},
        ).toHtml(),
        throwsArgumentError,
      );
      expect(
        () => HeadTag(
          key: 'bad-backslash',
          tagName: 'link',
          attributes: {'href': r'https://example.com\evil'},
        ).toHtml(),
        throwsArgumentError,
      );
      expect(
        () => HeadTag(
          key: 'bad-control',
          tagName: 'link',
          attributes: {'href': 'https://example.com/\x00test'},
        ).toHtml(),
        throwsArgumentError,
      );
    });

    test('HtmlDocument rejects unsafe baseHref and flutterBootstrapSrc', () {
      expect(
        () => const HtmlDocument(
          metadata: WebMetadata(title: 'Test'),
          baseHref: 'javascript:alert(1)',
        ).render(),
        throwsArgumentError,
      );
      expect(
        () => const HtmlDocument(
          metadata: WebMetadata(title: 'Test'),
          baseHref: r'https://example.com\evil',
        ).render(),
        throwsArgumentError,
      );
      expect(
        () => const HtmlDocument(
          metadata: WebMetadata(title: 'Test'),
          includeFlutterBootstrap: true,
          flutterBootstrapSrc: 'data:text/javascript,evil()',
        ).render(),
        throwsArgumentError,
      );
      expect(
        () => const HtmlDocument(
          metadata: WebMetadata(title: 'Test'),
          includeFlutterBootstrap: true,
          flutterBootstrapSrc: ' \tflutter_bootstrap.js',
        ).render(),
        throwsArgumentError,
      );
    });

    test('HtmlSanitizer strips unsafe URLs across href, src, action, formaction, poster, and cite', () {
      final sanitizer = HtmlSanitizer();
      final dirtyHtml = '''
<div>
  <a href="javascript:alert(1)">Bad Link</a>
  <img src="data:text/html,evil" alt="Bad Img">
  <form action="vbscript:msgbox(1)">
    <button formaction="javascript:void(0)">Submit</button>
  </form>
  <blockquote cite="https://example.com\\evil">Quote</blockquote>
</div>
''';
      final cleanHtml = sanitizer.sanitize(dirtyHtml);
      expect(cleanHtml, isNot(contains('javascript:')));
      expect(cleanHtml, isNot(contains('vbscript:')));
      expect(cleanHtml, isNot(contains('data:')));
      expect(cleanHtml, isNot(contains(r'\evil')));
    });

    test('MetadataRenderer validates URLs against UrlPolicy, control chars, whitespace, and backslashes', () {
      const renderer = MetadataRenderer();

      // Canonical validation
      expect(
        () => renderer.render(
          const WebMetadata(canonical: 'javascript:alert(1)'),
          config: const MetaMantleConfig(baseUrl: 'https://example.com'),
        ),
        throwsFormatException,
      );
      expect(
        () => renderer.render(
          const WebMetadata(canonical: r'https://example.com\evil'),
          config: const MetaMantleConfig(baseUrl: 'https://example.com'),
        ),
        throwsFormatException,
      );
      expect(
        () => renderer.render(
          const WebMetadata(canonical: ' https://example.com/page'),
          config: const MetaMantleConfig(baseUrl: 'https://example.com'),
        ),
        throwsFormatException,
      );
      expect(
        () => renderer.render(
          const WebMetadata(canonical: 'https://example.com/page\x00'),
          config: const MetaMantleConfig(baseUrl: 'https://example.com'),
        ),
        throwsFormatException,
      );

      // OpenGraph Image validation
      expect(
        () => renderer.render(
          const WebMetadata(
            openGraph: OpenGraph(image: 'data:image/svg+xml,evil'),
          ),
          config: const MetaMantleConfig(baseUrl: 'https://example.com'),
        ),
        throwsFormatException,
      );
      expect(
        () => renderer.render(
          const WebMetadata(
            openGraph: OpenGraph(image: r'https://example.com\image.png'),
          ),
          config: const MetaMantleConfig(baseUrl: 'https://example.com'),
        ),
        throwsFormatException,
      );
      expect(
        () => renderer.render(
          const WebMetadata(
            openGraph: OpenGraph(image: ' https://example.com/image.png'),
          ),
          config: const MetaMantleConfig(baseUrl: 'https://example.com'),
        ),
        throwsFormatException,
      );
    });
  });

  group('Flutter Islands Loader & Lifecycle Script Contract', () {
    const adapter = BootstrapAdapter();
    final script = adapter.generateIslandBootstrapScript();

    test('Emits single engine initialization wrapper with shared in-flight Promises', () {
      expect(script, contains('var initPromise = null;'));
      expect(script, contains('var runAppPromise = null;'));
      expect(script, contains('function createWrappedEngineInitializer'));
      expect(script, contains('multiViewEnabled: true'));
      expect(script, contains('initPromise = null;'));
      expect(script, contains('runAppPromise = null;'));
      expect(
        script,
        contains(
          'window.__mantleCreateWrappedEngineInitializer = createWrappedEngineInitializer;',
        ),
      );
    });

    test('Preserves options.config and merges userConfig', () {
      expect(
        script,
        contains('var rawConfig = options ? options.config : null;'),
      );
      expect(
        script,
        contains(
          'var merged = Object.assign({}, rawConfig || {}, consumerConfig || {}, {',
        ),
      );
    });

    test('Invokes user onEntrypointLoaded with wrappedInitializer and avoids duplicate initializeEngine', () {
      expect(
        script,
        contains('var userOnEntrypoint = options.onEntrypointLoaded;'),
      );
      expect(
        script,
        contains('var cbResult = userOnEntrypoint(wrappedInitializer);'),
      );
      expect(
        script,
        contains('var runner = await wrappedInitializer.initializeEngine();'),
      );
      expect(script, contains('await runner.runApp();'));
    });

    test('Tracks expectedIslandElements separately from activeViews', () {
      expect(script, contains('var activeViews = [];'));
      expect(script, contains('var expectedIslandElements = [];'));
      expect(script, contains('function checkGlobalReadiness() {'));
      expect(
        script,
        contains('var totalExpected = expectedIslandElements.length;'),
      );
      expect(
        script,
        contains(
          "document.documentElement.setAttribute('data-mantle-runtime', 'error');",
        ),
      );
      expect(
        script,
        contains(
          "document.documentElement.setAttribute('data-mantle-islands-ready', 'false');",
        ),
      );
      expect(script, contains('window.__mantleRuntimeReady = false;'));
    });

    test('Provides truthful disposal and remounting functions', () {
      expect(script, contains('window.__mantleDisposeIslands = function() {'));
      expect(script, contains('window.__mantleRemountIslands = function() {'));
      expect(
        script,
        contains(
          'var canRemove = currentApp && typeof currentApp.removeView === \'function\';',
        ),
      );
      expect(script, contains('Missing Flutter application instance'));
      expect(script, contains('currentApp.removeView(entry.viewId)'));
      expect(script, contains('hasDisposalError = true;'));
      expect(
        script,
        contains(
          "entry.island.setAttribute('data-mantle-island-lifecycle', 'error')",
        ),
      );
      expect(script, contains("data-mantle-disposal-error"));
      expect(
        script,
        contains(
          "isl.setAttribute('data-mantle-island-lifecycle', 'disposed')",
        ),
      );
      expect(script, contains('currentApp.addView({ hostElement: isl })'));
      expect(script, contains('window.__mantleHookLoader = hookLoader;'));
    });
  });
}
