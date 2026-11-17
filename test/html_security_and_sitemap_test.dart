import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:meta_mantle/src/html/url_policy.dart';
import 'package:xml/xml.dart';

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

    test('Rejects non-finite priority values and clamps finite priority', () {
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

      final clampedHigh = generator.generateUrlset([
        const SitemapUrlEntry(loc: 'https://example.com/high', priority: 2.5),
      ]);
      expect(clampedHigh, contains('<priority>1.0</priority>'));

      final clampedLow = generator.generateUrlset([
        const SitemapUrlEntry(loc: 'https://example.com/low', priority: -0.8),
      ]);
      expect(clampedLow, contains('<priority>0.0</priority>'));
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
  });
}
