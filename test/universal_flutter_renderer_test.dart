import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meta_mantle/meta_mantle_flutter.dart';

void main() {
  const renderer = MantleFlutterRenderer();

  testWidgets('renders MantleTextNode to Flutter Text widget', (tester) async {
    final node = MantleTextNode('Universal Text');
    final widget = renderer.render(node);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    expect(find.text('Universal Text'), findsOneWidget);
  });

  testWidgets(
    'renders MantleElementNode (h1) to Flutter Text widget with styling',
    (tester) async {
      final node = MantleElementNode(
        tag: 'h1',
        styles: const {'font-size': '24.0px', 'font-weight': '700'},
        children: [MantleTextNode('Headline Text')],
      );
      final widget = renderer.render(node);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.text('Headline Text'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('Headline Text'));
      expect(textWidget.style?.fontSize, equals(24.0));
      expect(textWidget.style?.fontWeight, equals(FontWeight.bold));
    },
  );

  testWidgets(
    'renders MantleElementNode (button) to Flutter ElevatedButton with callback',
    (tester) async {
      var clicked = false;
      final node = MantleElementNode(
        tag: 'button',
        events: {'click': (_) => clicked = true},
        children: [MantleTextNode('Click Me')],
      );
      final widget = renderer.render(node);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.widgetWithText(ElevatedButton, 'Click Me'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(clicked, isTrue);
    },
  );

  testWidgets('renders MantleElementNode (flex row) to Flutter Row widget', (
    tester,
  ) async {
    final node = MantleElementNode(
      tag: 'div',
      styles: const {
        'display': 'flex',
        'flex-direction': 'row',
        'justify-content': 'center',
      },
      children: [MantleTextNode('Item 1'), MantleTextNode('Item 2')],
    );
    final widget = renderer.render(node);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    expect(find.byType(Row), findsOneWidget);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
  });

  testWidgets(
    'renders MantleElementNode (flex column) to Flutter Column widget',
    (tester) async {
      final node = MantleElementNode(
        tag: 'div',
        styles: const {'display': 'flex', 'flex-direction': 'column'},
        children: [MantleTextNode('Col 1'), MantleTextNode('Col 2')],
      );
      final widget = renderer.render(node);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.byType(Column), findsOneWidget);
      expect(find.text('Col 1'), findsOneWidget);
      expect(find.text('Col 2'), findsOneWidget);
    },
  );

  testWidgets(
    'renders MantleElementNode (input text) to Flutter TextFormField',
    (tester) async {
      String? enteredText;
      final node = MantleElementNode(
        tag: 'input',
        attributes: const {'placeholder': 'Enter email'},
        events: {'input': (e) => enteredText = e.value as String?},
      );
      final widget = renderer.render(node);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Enter email'), findsOneWidget); // placeholder / hint

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.pump();
      expect(enteredText, equals('test@example.com'));
    },
  );

  testWidgets(
    'renders MantleElementNode (input checkbox) to Flutter Checkbox',
    (tester) async {
      bool? isChecked = false;
      final node = MantleElementNode(
        tag: 'input',
        attributes: const {'type': 'checkbox'},
        events: {'change': (e) => isChecked = e.value as bool?},
      );
      final widget = renderer.render(node);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
      expect(find.byType(Checkbox), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(isChecked, isTrue);
    },
  );

  testWidgets('renders MantleFragment to Flutter Column containing children', (
    tester,
  ) async {
    final fragment = MantleFragment([
      MantleTextNode('Frag A'),
      MantleTextNode('Frag B'),
    ]);
    final widget = renderer.render(fragment);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    expect(find.text('Frag A'), findsOneWidget);
    expect(find.text('Frag B'), findsOneWidget);
  });

  testWidgets('renders MantleElementNode (a link) to Flutter InkWell', (
    tester,
  ) async {
    var linkTapped = false;
    final node = MantleElementNode(
      tag: 'a',
      attributes: const {'href': '/docs'},
      events: {'click': (_) => linkTapped = true},
      children: [MantleTextNode('Read Documentation')],
    );
    final widget = renderer.render(node);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    expect(find.byType(InkWell), findsOneWidget);
    expect(find.text('Read Documentation'), findsOneWidget);

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(linkTapped, isTrue);
  });

  testWidgets('renders select element to DropdownButton', (tester) async {
    final selectNode = MantleElementNode(
      tag: 'select',
      children: [
        const MantleElementNode(
          tag: 'option',
          attributes: {'value': 'opt1', 'selected': 'selected'},
          children: [MantleTextNode('Option 1')],
        ),
        const MantleElementNode(
          tag: 'option',
          attributes: {'value': 'opt2'},
          children: [MantleTextNode('Option 2')],
        ),
      ],
    );

    final widget = renderer.render(selectNode);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    expect(find.byType(DropdownButton<String>), findsOneWidget);
  });

  testWidgets('renders form element to Form widget', (tester) async {
    final formNode = MantleElementNode(
      tag: 'form',
      children: [
        const MantleElementNode(
          tag: 'input',
          attributes: {'type': 'text', 'placeholder': 'Username'},
        ),
      ],
    );

    final widget = renderer.render(formNode);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    expect(find.byType(Form), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('wraps element with Semantics widget when aria-label present', (
    tester,
  ) async {
    final node = MantleElementNode(
      tag: 'div',
      attributes: const {'aria-label': 'Accessible Region'},
      children: [MantleTextNode('Content')],
    );

    final widget = renderer.render(node);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
    expect(find.byType(Semantics), findsWidgets);
  });
}
