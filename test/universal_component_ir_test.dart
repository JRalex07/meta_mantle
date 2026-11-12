import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

void main() {
  group('Universal Styling IR Tests', () {
    test('MantleColor hex and rgba conversion', () {
      const color = MantleColor(0xFF336699);
      expect(color.toCssHex(), equals('#336699'));
      expect(color.value, equals(0xFF336699));

      const semiTransparent = MantleColor.fromARGB(128, 255, 0, 0);
      expect(semiTransparent.toCssRgba(), equals('rgba(255, 0, 0, 0.502)'));
      expect(semiTransparent.alphaChannel, equals(128));
    });

    test('MantleEdgeInsets CSS padding and margin mapping', () {
      const insets =
          MantleEdgeInsets.only(left: 10, top: 20, right: 15, bottom: 25);
      expect(insets.toCssPadding(), equals('20.0px 15.0px 25.0px 10.0px'));
      expect(insets.toCssMargin(), equals('20.0px 15.0px 25.0px 10.0px'));
      expect(insets.left, equals(10.0));
      expect(insets.top, equals(20.0));
      expect(insets.right, equals(15.0));
      expect(insets.bottom, equals(25.0));
    });

    test('MantleBorder and MantleBorderRadius CSS mapping', () {
      const border = MantleBorder.all(
        color: MantleColor(0xFF112233),
        width: 2.0,
      );
      expect(border.toCss(), equals('2.0px solid rgba(17, 34, 51, 1.000)'));

      const radius = MantleBorderRadius.circular(8.0);
      expect(radius.toCss(), equals('8.0px 8.0px 8.0px 8.0px'));
      expect(radius.topLeft, equals(8.0));
    });

    test('MantleBoxShadow CSS mapping', () {
      const shadow = MantleBoxShadow(
        color: MantleColor(0x80000000),
        offset: MantleOffset(0, 4),
        blurRadius: 8,
        spreadRadius: 2,
      );
      expect(shadow.toCss(),
          equals('0.0px 4.0px 8.0px 2.0px rgba(0, 0, 0, 0.502)'));
    });

    test('MantleTextStyle properties and CSS generation', () {
      const style = MantleTextStyle(
        fontSize: 16.0,
        fontWeight: MantleFontWeight.bold,
        color: MantleColor(0xFF222222),
        lineHeight: 1.5,
        letterSpacing: 0.5,
        fontFamily: 'Inter',
      );
      final css = style.toCssProperties();
      expect(css['font-size'], equals('16.0px'));
      expect(css['font-weight'], equals('700'));
      expect(css['color'], equals('rgba(34, 34, 34, 1.000)'));
      expect(css['line-height'], equals('1.5'));
      expect(css['letter-spacing'], equals('0.5px'));
      expect(css['font-family'], equals('Inter'));
    });
  });

  group('Universal Node IR Tests', () {
    test('MantleElementNode hierarchy and props', () {
      final child1 = MantleTextNode('Hello');
      final child2 = MantleTextNode('World');
      final element = MantleElementNode(
        tag: 'div',
        key: const MantleKey('root-div'),
        attributes: {'class': 'container'},
        styles: {'padding': '16px'},
        children: [child1, child2],
      );

      expect(element.tag, equals('div'));
      expect(element.key?.value, equals('root-div'));
      expect(element.attributes['class'], equals('container'));
      expect(element.children.length, equals(2));
    });

    test('MantleFragment holds unparented list of nodes', () {
      final fragment = MantleFragment([
        MantleTextNode('First'),
        MantleTextNode('Second'),
      ]);
      expect(fragment.children.length, equals(2));
    });

    test('MantleNodeVisitor visits all node types', () {
      final visited = <String>[];
      final visitor = _TestVisitor(visited);

      final tree = MantleElementNode(
        tag: 'section',
        children: [
          MantleTextNode('Title'),
          MantleFragment([
            MantleTextNode('Item 1'),
          ]),
        ],
      );

      tree.accept(visitor);
      expect(
          visited,
          equals(
              ['element:section', 'text:Title', 'fragment:1', 'text:Item 1']));
    });
  });

  group('Progressive Component Catalogue IR Tests', () {
    final context = _MockMantleContext();

    test('Layout components build valid IR nodes', () {
      const container = MantleContainer(
        width: 200,
        height: 100,
        color: MantleColor(0xFFEEEEEE),
        child: MantleText('Inside Container'),
      );
      final containerNode = container.build(context) as MantleElementNode;
      expect(containerNode.tag, equals('div'));
      expect(containerNode.styles['width'], equals('200.0px'));

      const row = MantleRow(
        mainAxisAlignment: MantleMainAxisAlignment.center,
        children: [MantleText('A'), MantleText('B')],
      );
      final rowNode = row.build(context) as MantleElementNode;
      expect(rowNode.styles['display'], equals('flex'));
      expect(rowNode.styles['flex-direction'], equals('row'));
      expect(rowNode.styles['justify-content'], equals('center'));

      const column = MantleColumn(
        crossAxisAlignment: MantleCrossAxisAlignment.stretch,
        children: [MantleText('1'), MantleText('2')],
      );
      final colNode = column.build(context) as MantleElementNode;
      expect(colNode.styles['display'], equals('flex'));
      expect(colNode.styles['flex-direction'], equals('column'));
      expect(colNode.styles['align-items'], equals('stretch'));
    });

    test('Text components build valid IR nodes', () {
      const heading = MantleHeading('Welcome', level: 1);
      final h1Node = heading.build(context) as MantleElementNode;
      expect(h1Node.tag, equals('h1'));
      expect((h1Node.children.first as MantleTextNode).text, equals('Welcome'));

      const richText = MantleRichText(
        spans: [
          MantleTextSpan(text: 'Hello '),
          MantleTextSpan(
              text: 'bold',
              style: MantleTextStyle(fontWeight: MantleFontWeight.bold)),
        ],
      );
      final richNode = richText.build(context) as MantleElementNode;
      expect(richNode.tag, equals('p'));
      expect(richNode.children.length, equals(2));
    });

    test('Media components build valid IR nodes', () {
      const img = MantleImage(
          src: 'https://example.com/logo.png', alt: 'Company Logo', width: 120);
      final imgNode = img.build(context) as MantleElementNode;
      expect(imgNode.tag, equals('img'));
      expect(imgNode.attributes['src'], equals('https://example.com/logo.png'));
      expect(imgNode.attributes['alt'], equals('Company Logo'));
      expect(imgNode.styles['width'], equals('120.0px'));

      const icon = MantleIcon('check_circle', size: 24);
      final iconNode = icon.build(context) as MantleElementNode;
      expect(iconNode.tag, equals('i'));
    });

    test('Interaction components build valid IR nodes', () {
      var clicked = false;
      final button = MantleButton(
        label: 'Submit',
        onPressed: () => clicked = true,
      );
      final btnNode = button.build(context) as MantleElementNode;
      expect(btnNode.tag, equals('button'));
      expect(btnNode.events.containsKey('click'), isTrue);
      btnNode.events['click']!(const MantleEvent(type: 'click'));
      expect(clicked, isTrue);

      const link = MantleLink(
          href: 'https://example.com', label: 'Docs', external: true);
      final linkNode = link.build(context) as MantleElementNode;
      expect(linkNode.tag, equals('a'));
      expect(linkNode.attributes['href'], equals('https://example.com'));
      expect(linkNode.attributes['target'], equals('_blank'));
    });

    test('Form components build valid IR nodes', () {
      String? changed;
      final textField = MantleTextField(
        placeholder: 'Enter username',
        onChanged: (val) => changed = val,
      );
      final inputNode = textField.build(context) as MantleElementNode;
      expect(inputNode.tag, equals('input'));
      expect(inputNode.attributes['placeholder'], equals('Enter username'));
      inputNode.events['input']!(
          const MantleEvent(type: 'input', value: 'john_doe'));
      expect(changed, equals('john_doe'));

      final select = MantleSelect<String>(
        options: const {
          'us': 'United States',
          'in': 'India',
        },
        value: 'in',
        onChanged: (_) {},
      );
      final selectNode = select.build(context) as MantleElementNode;
      expect(selectNode.tag, equals('select'));
      expect(selectNode.children.length, equals(2));
    });

    test('Navigation and semantic components build valid IR nodes', () {
      const page = MantlePage(
        title: 'Home',
        children: [
          MantleAppBar(title: 'Portal'),
          MantleText('Main Content'),
        ],
      );
      final pageNode = page.build(context) as MantleElementNode;
      expect(pageNode.tag, equals('main'));
      expect(pageNode.children.length, equals(2));

      const landmark = MantleLandmark(
        type: MantleLandmarkType.main,
        child: MantleText('Important info'),
      );
      final landmarkNode = landmark.build(context) as MantleElementNode;
      expect(landmarkNode.tag, equals('main'));

      // MantleNavigation
      const nav = MantleNavigation(
        items: [
          MantleNavigationItem(label: 'Home', route: '/'),
          MantleNavigationItem(label: 'Profile', route: '/profile'),
        ],
        currentIndex: 1,
      );
      final navNode = nav.build(context) as MantleElementNode;
      expect(navNode.tag, equals('nav'));
      expect(navNode.attributes['role'], equals('navigation'));
      expect(navNode.children.length, equals(2));
      final activeItem = navNode.children[1] as MantleElementNode;
      expect(activeItem.attributes['aria-selected'], equals('true'));

      // MantleDrawer
      const drawer = MantleDrawer(
        isOpen: true,
        children: [MantleText('Menu item')],
      );
      final drawerNode = drawer.build(context) as MantleElementNode;
      expect(drawerNode.classes, contains('mantle-drawer-wrapper'));

      // MantleTabs
      const tabs = MantleTabs(
        tabs: [
          MantleTab(title: 'Tab 1', content: MantleText('Content 1')),
          MantleTab(title: 'Tab 2', content: MantleText('Content 2')),
        ],
        currentIndex: 0,
      );
      final tabsNode = tabs.build(context) as MantleElementNode;
      expect(tabsNode.classes, contains('mantle-tabs-container'));
      expect(tabsNode.children.length, equals(2));
    });
  });
}

class _TestVisitor implements MantleNodeVisitor<void> {
  _TestVisitor(this.visited);
  final List<String> visited;

  @override
  void visitElement(MantleElementNode node) {
    visited.add('element:${node.tag}');
    for (final child in node.children) {
      child.accept(this);
    }
  }

  @override
  void visitText(MantleTextNode node) {
    visited.add('text:${node.text}');
  }

  @override
  void visitFragment(MantleFragment node) {
    visited.add('fragment:${node.children.length}');
    for (final child in node.children) {
      child.accept(this);
    }
  }
}

class _MockMantleContext implements MantleContext {
  @override
  String get currentPath => '/';

  @override
  Map<String, String> get pathParameters => const {};

  @override
  Map<String, String> get queryParameters => const {};

  @override
  void go(String path, {Map<String, String>? queryParameters}) {}

  @override
  void back() {}
}
