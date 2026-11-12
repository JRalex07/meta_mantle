import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_core.dart';

void main() {
  group('Semantic HTML Rendering & Sanitizer Tests', () {
    test('TextNode automatically escapes raw HTML characters', () {
      const node = TextNode('<script>alert("XSS") & "foo"</script>');
      final html = node.toHtml();
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('&amp;'));
      expect(html, isNot(contains('<script>')));
    });

    test('ElementNode escapes attribute values automatically', () {
      const node = ElementNode(
        'a',
        attributes: {
          'href': '/products?foo="bar"&baz=1',
          'title': 'Click <here>',
        },
        children: [TextNode('Link')],
      );
      final html = node.toHtml();
      expect(html, contains('href="/products?foo=&quot;bar&quot;&amp;baz=1"'));
      expect(html, contains('title="Click &lt;here&gt;"'));
      expect(html, contains('>Link</a>'));
    });

    test('HtmlSanitizer strips malicious script tags and event handlers', () {
      const sanitizer = HtmlSanitizer();
      const malicious =
          '<p>Hello <script>stealCookies()</script><a href="javascript:alert(1)" onclick="hack()">Click</a></p>';
      final clean = sanitizer.sanitize(malicious);
      expect(clean, isNot(contains('<script>')));
      expect(clean, isNot(contains('stealCookies')));
      expect(clean, isNot(contains('javascript:')));
      expect(clean, isNot(contains('onclick')));
      expect(clean, contains('<p>'));
    });

    test(
      'HtmlSanitizer enforces rel="noopener noreferrer" on target="_blank"',
      () {
        const sanitizer = HtmlSanitizer();
        const input =
            '<a href="https://example.com" target="_blank">External</a>';
        final clean = sanitizer.sanitize(input);
        expect(clean, contains('rel="noopener noreferrer"'));
      },
    );

    test('Semantic tag factories create valid structured markup', () {
      final article = H.article([
        H.h1('Article Title'),
        H.p('First paragraph with details.'),
        H.img(
          'https://example.com/photo.jpg',
          alt: 'Scenic View',
          width: 800,
          height: 600,
        ),
        H.table(
          headers: ['Feature', 'Value'],
          rows: [
            ['Speed', 'Fast'],
            ['SEO', 'Native'],
          ],
        ),
      ]);

      final html = article.toHtml();
      expect(html, contains('<article>'));
      expect(html, contains('<h1>Article Title</h1>'));
      expect(html, contains('<p>First paragraph with details.</p>'));
      expect(
        html,
        contains(
          '<img src="https://example.com/photo.jpg" alt="Scenic View" width="800" height="600" />',
        ),
      );
      expect(html, contains('<th>Feature</th>'));
      expect(html, contains('<td>Fast</td>'));
      expect(html, contains('</article>'));
    });

    test('HtmlDocument renders complete valid HTML5 document with head and body', () {
      const doc = HtmlDocument(
        metadata: WebMetadata(
          title: 'Product Details',
          description: 'A detailed view of the product.',
          canonical: 'https://example.com/products/rice/',
        ),
        bodyNodes: [
          ElementNode('h1', children: [TextNode('Premium Basmati Rice')]),
          ElementNode('p', children: [TextNode('Price: \$24.99')]),
        ],
        includeFlutterBootstrap: true,
      );

      final output = doc.render();
      expect(output, startsWith('<!DOCTYPE html>'));
      expect(output, contains('<html lang="en">'));
      expect(output, contains('<title>Product Details</title>'));
      expect(
        output,
        contains(
          '<meta name="description" content="A detailed view of the product."',
        ),
      );
      expect(
        output,
        contains(
          '<link rel="canonical" href="https://example.com/products/rice/"',
        ),
      );
      expect(output, contains('<h1>Premium Basmati Rice</h1>'));
      expect(output, contains('<p>Price: \$24.99</p>'));
      expect(
        output,
        contains('<script src="flutter_bootstrap.js" async></script>'),
      );
      expect(output, endsWith('</html>\n'));
    });
  });
}
