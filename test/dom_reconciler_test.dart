import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

void main() {
  group('MantleDiffEngine & Incremental Reconciliation', () {
    const diffEngine = MantleDiffEngine();

    test('Identical nodes produce null patch', () {
      const nodeA = MantleTextNode('Hello');
      const nodeB = MantleTextNode('Hello');
      expect(diffEngine.diff(nodeA, nodeB), isNull);

      const elA = MantleElementNode(tag: 'div', classes: ['foo']);
      const elB = MantleElementNode(tag: 'div', classes: ['foo']);
      expect(diffEngine.diff(elA, elB), isNull);
    });

    test('Text node diff detects changed text', () {
      const nodeA = MantleTextNode('Old Text');
      const nodeB = MantleTextNode('New Text');

      final patch = diffEngine.diff(nodeA, nodeB);
      expect(patch, isA<UpdateTextPatch>());
      expect((patch as UpdateTextPatch).newText, equals('New Text'));
    });

    test('Tag change forces full ReplaceNodePatch', () {
      const nodeA = MantleElementNode(tag: 'div');
      const nodeB = MantleElementNode(tag: 'span');

      final patch = diffEngine.diff(nodeA, nodeB);
      expect(patch, isA<ReplaceNodePatch>());
      expect(
        ((patch as ReplaceNodePatch).newNode as MantleElementNode).tag,
        equals('span'),
      );
    });

    test('Key change forces full ReplaceNodePatch', () {
      const nodeA = MantleElementNode(
        tag: 'div',
        key: MantleValueKey('item-1'),
      );
      const nodeB = MantleElementNode(
        tag: 'div',
        key: MantleValueKey('item-2'),
      );

      final patch = diffEngine.diff(nodeA, nodeB);
      expect(patch, isA<ReplaceNodePatch>());
    });

    test('Attribute and class differences produce UpdateElementPatch', () {
      const nodeA = MantleElementNode(
        tag: 'button',
        classes: ['btn', 'btn-primary'],
        attributes: {'disabled': 'true', 'title': 'Old'},
        styles: {'color': 'red', 'font-size': '14px'},
      );

      const nodeB = MantleElementNode(
        tag: 'button',
        classes: ['btn', 'btn-active'],
        attributes: {'title': 'New', 'aria-label': 'Action'},
        styles: {'color': 'blue'},
      );

      final patch = diffEngine.diff(nodeA, nodeB);
      expect(patch, isA<UpdateElementPatch>());
      final elPatch = patch as UpdateElementPatch;

      // Classes
      expect(elPatch.classesToRemove, equals(['btn-primary']));
      expect(elPatch.classesToAdd, equals(['btn-active']));

      // Attributes
      expect(elPatch.attributesToRemove, equals(['disabled']));
      expect(
        elPatch.attributesToSet,
        equals({'title': 'New', 'aria-label': 'Action'}),
      );

      // Styles
      expect(elPatch.stylesToRemove, equals(['font-size']));
      expect(elPatch.stylesToSet, equals({'color': 'blue'}));
    });

    test('Children reconciliation detects insert, remove, and patch', () {
      const nodeA = MantleElementNode(
        tag: 'ul',
        children: [
          MantleElementNode(tag: 'li', children: [MantleTextNode('A')]),
          MantleElementNode(tag: 'li', children: [MantleTextNode('B')]),
        ],
      );

      const nodeB = MantleElementNode(
        tag: 'ul',
        children: [
          MantleElementNode(
            tag: 'li',
            children: [MantleTextNode('A-modified')],
          ),
          MantleElementNode(tag: 'li', children: [MantleTextNode('B')]),
          MantleElementNode(tag: 'li', children: [MantleTextNode('C')]),
        ],
      );

      final patch = diffEngine.diff(nodeA, nodeB);
      expect(patch, isA<UpdateElementPatch>());
      final elPatch = patch as UpdateElementPatch;

      expect(elPatch.childrenPatches.length, equals(2));
      // First child patched
      expect(elPatch.childrenPatches[0], isA<PatchChildPatch>());
      expect(elPatch.childrenPatches[0].index, equals(0));

      // Third child inserted
      expect(elPatch.childrenPatches[1], isA<InsertChildPatch>());
      expect(elPatch.childrenPatches[1].index, equals(2));
    });
  });
}
