import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

void main() {
  group('Content & Commerce Universal Components Tests', () {
    final context = MantleNavigationContext(currentPath: '/test');

    test('MantleArticle builds semantic article node and renders HTML', () {
      const article = MantleArticle(
        title: 'Breaking Architecture News',
        author: 'MetaMantle Team',
        publishedDate: '2026-11-12',
        children: [
          MantleText('This enables lightning fast first-contentful paint.'),
          MantleText('Additional insights on universal Dart.'),
        ],
      );

      final node = article.build(context) as MantleElementNode;
      expect(node.tag, equals('article'));
      expect(node.children.length, greaterThanOrEqualTo(2));

      const renderer = MantleServerRenderer(emitHydrationMarkers: false);
      final html = renderer.render(node).toHtml();
      expect(html, contains('<article'));
      expect(html, contains('Breaking Architecture News'));
      expect(html, contains('By MetaMantle Team'));
      expect(html, contains('2026-11-12'));
      expect(html,
          contains('This enables lightning fast first-contentful paint.'));
      expect(html, contains('Additional insights on universal Dart.'));
    });

    test('MantleList and MantleListItem produce unordered and ordered lists',
        () {
      const unorderedList = MantleList(
        ordered: false,
        children: [
          MantleListItem(child: MantleText('High performance')),
          MantleListItem(child: MantleText('SEO friendly')),
        ],
      );

      final ulNode = unorderedList.build(context) as MantleElementNode;
      expect(ulNode.tag, equals('ul'));
      expect(ulNode.children.length, equals(2));
      final firstChild = ulNode.children[0] as MantleElementNode;
      expect(firstChild.tag, equals('li'));

      const renderer = MantleServerRenderer(emitHydrationMarkers: false);
      final ulHtml = renderer.render(ulNode).toHtml();
      expect(ulHtml, contains('<ul'));
      expect(ulHtml,
          contains('<li class="mantle-list-item">High performance</li>'));
      expect(
          ulHtml, contains('<li class="mantle-list-item">SEO friendly</li>'));
      expect(ulHtml, contains('</ul>'));

      const orderedList = MantleList(
        ordered: true,
        children: [
          MantleListItem(child: MantleText('First step')),
          MantleListItem(child: MantleText('Second step')),
        ],
      );

      final olNode = orderedList.build(context) as MantleElementNode;
      expect(olNode.tag, equals('ol'));
      final olHtml = renderer.render(olNode).toHtml();
      expect(olHtml, contains('<ol'));
      expect(olHtml, contains('<li class="mantle-list-item">First step</li>'));
      expect(olHtml, contains('<li class="mantle-list-item">Second step</li>'));
      expect(olHtml, contains('</ol>'));
    });

    test('MantleTextArea builds textarea node with attributes', () {
      const textArea = MantleTextArea(
        value: 'Great framework!',
        placeholder: 'Enter your feedback here...',
        rows: 5,
        cols: 40,
      );

      final node = textArea.build(context) as MantleElementNode;
      expect(node.tag, equals('textarea'));
      expect(node.attributes['placeholder'],
          equals('Enter your feedback here...'));
      expect(node.attributes['rows'], equals('5'));
      expect(node.attributes['cols'], equals('40'));
      expect((node.children.first as MantleTextNode).text,
          equals('Great framework!'));

      const renderer = MantleServerRenderer(emitHydrationMarkers: false);
      final html = renderer.render(node).toHtml();
      expect(html, contains('<textarea'));
      expect(html, contains('placeholder="Enter your feedback here..."'));
      expect(html, contains('rows="5"'));
      expect(html, contains('cols="40"'));
      expect(html, contains('Great framework!</textarea>'));
    });

    test('MantleDetails builds details and summary nodes', () {
      const details = MantleDetails(
        summary: MantleText('Frequently Asked Questions'),
        content: MantleText(
            'MetaMantle runs on Flutter, Web and Server seamlessly.'),
        open: true,
      );

      final node = details.build(context) as MantleElementNode;
      expect(node.tag, equals('details'));
      expect(node.attributes['open'], equals('open'));
      final summaryNode = node.children.first as MantleElementNode;
      expect(summaryNode.tag, equals('summary'));

      const renderer = MantleServerRenderer(emitHydrationMarkers: false);
      final html = renderer.render(node).toHtml();
      expect(html, contains('<details'));
      expect(html, contains('open="open"'));
      expect(html, contains('<summary'));
      expect(html, contains('Frequently Asked Questions'));
      expect(html,
          contains('MetaMantle runs on Flutter, Web and Server seamlessly.'));
      expect(html, contains('</details>'));
    });

    test('MantleProduct generates complete Schema.org Microdata', () {
      const product = MantleProduct(
        name: 'Super High Performance Keyboard',
        description: 'Mechanical keyboard for high productivity Dart coding.',
        price: 199.99,
        currency: 'USD',
        imageUrl: 'https://example.com/keyboard.jpg',
        sku: 'KB-DART-99',
        inStock: true,
      );

      final node = product.build(context) as MantleElementNode;
      expect(node.attributes['itemscope'], equals(''));
      expect(node.attributes['itemtype'], equals('https://schema.org/Product'));

      const renderer = MantleServerRenderer(emitHydrationMarkers: false);
      final html = renderer.render(node).toHtml();

      expect(html, contains('itemscope'));
      expect(html, contains('itemtype="https://schema.org/Product"'));
      expect(html, contains('itemprop="name"'));
      expect(html, contains('Super High Performance Keyboard'));
      expect(html, contains('itemprop="description"'));
      expect(html, contains('itemprop="offers"'));
      expect(html, contains('itemtype="https://schema.org/Offer"'));
      expect(html, contains('itemprop="price"'));
      expect(html, contains('\$199.99'));
      expect(html, contains('itemprop="priceCurrency"'));
      expect(html, contains('content="USD"'));
      expect(html, contains('https://schema.org/InStock'));
    });

    testWidgets('UniversalFlutterRenderer renders all content components',
        (WidgetTester tester) async {
      const article = MantleArticle(
        title: 'Flutter Widget Test',
        author: 'Test Author',
        children: [
          MantleText('Main text content.'),
        ],
      );
      const list = MantleList(
        children: [MantleListItem(child: MantleText('List Item 1'))],
      );
      const textArea = MantleTextArea(
        value: 'Editable text area',
        rows: 3,
      );
      const details = MantleDetails(
        summary: MantleText('Details Title'),
        content: MantleText('Hidden details content'),
      );
      const product = MantleProduct(
        name: 'Dart Book',
        price: 29.99,
      );

      const renderer = MantleFlutterRenderer();

      await tester.pumpWidget(
        material.MaterialApp(
          home: material.Scaffold(
            body: material.SingleChildScrollView(
              child: material.Column(
                children: [
                  renderer.render(article.toNode(context)),
                  renderer.render(list.toNode(context)),
                  renderer.render(textArea.toNode(context)),
                  renderer.render(details.toNode(context)),
                  renderer.render(product.toNode(context)),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Flutter Widget Test'), findsOneWidget);
      expect(find.text('By Test Author '), findsOneWidget);
      expect(find.text('Main text content.'), findsOneWidget);
      expect(find.text('List Item 1'), findsOneWidget);
      expect(find.text('Details Title'), findsOneWidget);
      expect(find.text('Dart Book'), findsOneWidget);
      expect(find.text('\$29.99'), findsOneWidget);
    });
  });
}
