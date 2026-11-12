import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  const renderer = MantleServerRenderer();

  test('renders MantleTextNode to TextNode', () {
    final textNode = MantleTextNode('Simple Server Text');
    final rendered = renderer.render(textNode);

    expect(rendered, isA<TextNode>());
    expect((rendered as TextNode).text, equals('Simple Server Text'));
    expect(rendered.toHtml(), equals('Simple Server Text'));
  });

  test('renders styled MantleTextNode into styled span element', () {
    final textNode = MantleTextNode(
      'Styled Server Text',
      style:
          const MantleTextStyle(fontSize: 18.0, color: MantleColor(0xFF0055AA)),
    );
    final rendered = renderer.render(textNode);

    expect(rendered, isA<ElementNode>());
    final el = rendered as ElementNode;
    expect(el.tag, equals('span'));
    expect(el.attributes['style'], contains('font-size: 18.0px;'));
    expect(el.attributes['style'], contains('color: rgba(0, 85, 170, 1.000);'));
  });

  test('renders MantleElementNode with attributes and inline CSS', () {
    final element = MantleElementNode(
      tag: 'section',
      id: 'features',
      classes: ['hero', 'p-4'],
      styles: const {'margin': '10px', 'display': 'flex'},
      children: [
        MantleElementNode(
          tag: 'h1',
          children: [MantleTextNode('Universal Architecture')],
        ),
      ],
    );
    final rendered = renderer.render(element) as ElementNode;

    expect(rendered.tag, equals('section'));
    expect(rendered.attributes['id'], equals('features'));
    expect(rendered.attributes['class'], equals('hero p-4'));
    expect(rendered.attributes['style'], contains('margin: 10px;'));
    expect(rendered.attributes['style'], contains('display: flex;'));
    expect(rendered.children.length, equals(1));
    expect(rendered.toHtml(),
        contains('data-mantle-node="h1">Universal Architecture</h1>'));
  });

  test('correctly handles self-closing tags like img and input', () {
    final imgNode = MantleElementNode(
      tag: 'img',
      attributes: const {'src': '/banner.png', 'alt': 'Site Banner'},
    );
    final renderedImg = renderer.render(imgNode) as ElementNode;
    expect(renderedImg.isSelfClosing, isTrue);
    expect(
        renderedImg.toHtml(),
        equals(
            '<img src="/banner.png" alt="Site Banner" data-mantle-node="img" />'));

    final inputNode = MantleElementNode(
      tag: 'input',
      attributes: const {'type': 'text', 'placeholder': 'Search'},
    );
    final renderedInput = renderer.render(inputNode) as ElementNode;
    expect(renderedInput.isSelfClosing, isTrue);
    expect(
        renderedInput.toHtml(),
        equals(
            '<input type="text" placeholder="Search" data-mantle-node="input" />'));
  });

  test('renders MantleFragment into mantle-fragment div container', () {
    final fragment = MantleFragment([
      MantleTextNode('First Item'),
      MantleTextNode('Second Item'),
    ]);
    final rendered = renderer.render(fragment) as ElementNode;

    expect(rendered.tag, equals('div'));
    expect(rendered.attributes['class'], equals('mantle-fragment'));
    expect(rendered.children.length, equals(2));
  });

  test(
      'escapes malicious HTML characters in text and attributes (XSS prevention)',
      () {
    final xssNode = MantleElementNode(
      tag: 'div',
      attributes: const {'data-info': 'foo" onclick="alert(1)'},
      children: [MantleTextNode('<script>alert("hacked")</script>')],
    );
    final html = renderer.render(xssNode).toHtml();

    expect(html, isNot(contains('<script>')));
    expect(html, contains('&lt;script&gt;'));
    expect(html, isNot(contains('onclick="alert(1)"')));
  });

  test(
      'renderDocument generates complete, production-ready HTML document with metadata',
      () {
    final root = MantleElementNode(
      tag: 'main',
      children: [
        MantleElementNode(
          tag: 'h1',
          children: [MantleTextNode('MetaMantle SSR')],
        ),
        MantleElementNode(
          tag: 'p',
          children: [
            MantleTextNode('Universal rendering for Dart and Flutter.')
          ],
        ),
      ],
    );

    final html = renderer.renderDocument(
      root,
      metadata: const WebMetadata(
        title: 'MetaMantle SSR Page',
        description: 'Server-side rendered universal components',
        canonical: 'https://example.com/universal',
      ),
      currentUrl: 'https://example.com/universal',
      stylesheetUrls: ['/styles/main.css'],
      scriptUrls: ['/scripts/app.js'],
    );

    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('<title>MetaMantle SSR Page</title>'));
    expect(
        html,
        contains(
            '<meta name="description" content="Server-side rendered universal components">'));
    expect(
        html,
        contains(
            '<link rel="canonical" href="https://example.com/universal">'));
    expect(html, contains('<link rel="stylesheet" href="/styles/main.css">'));
    expect(html, contains('<script src="/scripts/app.js">'));
    expect(html, contains('<main'));
    expect(html, contains('data-mantle-node="main"'));
    expect(html, contains('<h1'));
    expect(html, contains('MetaMantle SSR</h1>'));
  });

  test('emits hydration markers for interactive elements and keys', () {
    final interactive = MantleElementNode(
      tag: 'button',
      key: const MantleValueKey('submit-btn'),
      events: {'click': (_) {}},
      children: [MantleTextNode('Submit')],
    );

    final rendered = renderer.render(interactive) as ElementNode;
    expect(rendered.attributes['data-mantle-node'], equals('button'));
    expect(rendered.attributes['data-mantle-key'], contains('submit-btn'));
    expect(rendered.attributes['data-mantle-interactive'], equals('true'));
  });
}
