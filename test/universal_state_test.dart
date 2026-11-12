import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

void main() {
  group('MantleObservable & MantleStore', () {
    test('MantleObservable notifies listeners and disposes cleanly', () {
      final obs = MantleObservable<int>(10);
      expect(obs.value, equals(10));

      final values = <int>[];
      void listener(int v) => values.add(v);

      obs.addListener(listener);
      obs.value = 20;
      obs.value = 20; // Identical, should not notify
      obs.value = 30;

      expect(values, equals([20, 30]));

      obs.removeListener(listener);
      obs.value = 40;
      expect(values, equals([20, 30]));

      obs.dispose();
      obs.value = 50; // Disposed, should not update or notify
      expect(obs.value, equals(40));
    });

    test('MantleStore manages key-value state with targeted listeners', () {
      final store = MantleStore({'theme': 'light', 'count': 0});

      expect(store.get<String>('theme'), equals('light'));
      expect(store.get<int>('count'), equals(0));

      final themeChanges = <String>[];
      final globalCount = <int>[];

      void themeWatcher(Object? val) => themeChanges.add(val as String);
      void globalListener() => globalCount.add(1);

      store.watch('theme', themeWatcher);
      store.addListener(globalListener);

      store.set('count', 1);
      expect(themeChanges, isEmpty); // Theme not changed
      expect(globalCount.length, equals(1));

      store.set('theme', 'dark');
      expect(themeChanges, equals(['dark']));
      expect(globalCount.length, equals(2));

      store.unwatch('theme', themeWatcher);
      store.set('theme', 'system');
      expect(themeChanges, equals(['dark']));

      store.dispose();
      store.set('count', 99);
      expect(store.get<int>('count'), isNull);
    });

    test('MantleBuilder re-creates node when observable changes', () {
      final counter = MantleObservable<int>(0);
      final builder = MantleBuilder<int>(
        observable: counter,
        builder: (ctx, val) => MantleText('Count: $val'),
      );

      final navContext = MantleNavigationContext(currentPath: '/');
      final node1 = builder.toNode(navContext) as MantleTextNode;
      expect(node1.text, equals('Count: 0'));

      counter.value = 5;
      final node2 = builder.toNode(navContext) as MantleTextNode;
      expect(node2.text, equals('Count: 5'));
    });

    test('MantleFutureBuilder handles async loading and data', () async {
      final completer = Completer<String>();
      final fb = MantleFutureBuilder<String>(
        future: completer.future,
        initialData: 'Loading...',
        builder: (ctx, snapshot) {
          if (snapshot.isLoading) {
            return MantleText(snapshot.data ?? 'Loading');
          }
          if (snapshot.hasError) {
            return MantleText('Error: ${snapshot.error}');
          }
          return MantleText('Result: ${snapshot.data}');
        },
      );

      final navContext = MantleNavigationContext(currentPath: '/');
      final initialNode = fb.toNode(navContext) as MantleTextNode;
      expect(initialNode.text, equals('Loading...'));

      completer.complete('DataLoaded');
      await Future<void>.delayed(Duration.zero);

      final resolvedNode = fb.toNode(navContext) as MantleTextNode;
      expect(resolvedNode.text, equals('Loading...'));
    });
  });
}
