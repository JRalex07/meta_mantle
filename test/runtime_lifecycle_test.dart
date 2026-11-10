import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle.dart';
import 'package:meta_mantle/src/runtime/head_adapter_contract.dart';
import 'package:meta_mantle/src/runtime/head_adapter_stub.dart';
import 'package:meta_mantle/src/runtime/runtime_coordinator.dart';

class RecordingHeadAdapter implements HeadAdapter {
  bool cleared = false;
  List<HeadTag>? lastAppliedTags;
  int applyCount = 0;
  int clearCount = 0;

  @override
  bool get isSupported => true;

  @override
  void apply(List<HeadTag> tags) {
    applyCount++;
    lastAppliedTags = List<HeadTag>.from(tags);
    cleared = false;
  }

  @override
  void clear() {
    clearCount++;
    cleared = true;
    lastAppliedTags = null;
  }
}

void main() {
  setUp(() {
    RuntimeCoordinator.instance = RuntimeCoordinator();
  });

  tearDown(() {
    RuntimeCoordinator.instance.clear();
  });

  group('RuntimeCoordinator Lifecycle & Scopes', () {
    test('1. Initial metadata activation registers owner and resolves metadata',
        () {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);
      coordinator.initialize(const WebHeadConfig(
        siteName: 'TestSite',
        titleTemplate: '%s | TestSite',
        baseUrl: 'https://example.com',
      ));

      final owner = Object();
      coordinator.activate(
        owner,
        const WebMetadata(
          title: 'Home',
          description: 'Welcome home',
          canonical: '/home',
        ),
      );

      expect(coordinator.activeMetadata?.title, 'Home');
      expect(adapter.applyCount, 1);
      final tags = adapter.lastAppliedTags!;
      expect(tags.firstWhere((t) => t.key == 'title').textContent,
          'Home | TestSite');
      expect(
          tags.firstWhere((t) => t.key == 'description').attributes['content'],
          'Welcome home');
      expect(tags.firstWhere((t) => t.key == 'canonical').attributes['href'],
          'https://example.com/home');
    });

    test(
        '2. Metadata updates modify active metadata without creating duplicates',
        () {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);
      coordinator
          .initialize(const WebHeadConfig(baseUrl: 'https://example.com'));

      final owner = Object();
      coordinator.activate(
          owner, const WebMetadata(title: 'V1', description: 'Desc 1'));
      expect(
          adapter.lastAppliedTags!
              .firstWhere((t) => t.key == 'title')
              .textContent,
          'V1');

      coordinator.update(
          owner, const WebMetadata(title: 'V2', description: 'Desc 2'));
      expect(coordinator.activeMetadata?.title, 'V2');
      expect(
          adapter.lastAppliedTags!
              .firstWhere((t) => t.key == 'title')
              .textContent,
          'V2');
      expect(adapter.lastAppliedTags!.where((t) => t.key == 'title').length, 1);
    });

    test('3. Removing a metadata owner restores previous scope or clears', () {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);

      final owner = Object();
      coordinator.activate(owner, const WebMetadata(title: 'OnlyPage'));
      expect(coordinator.activeMetadata?.title, 'OnlyPage');
      expect(adapter.cleared, isFalse);

      coordinator.remove(owner);
      expect(coordinator.activeMetadata, isNull);
      expect(adapter.cleared, isTrue);
      expect(adapter.clearCount, 1);
    });

    test(
        '4. Nested metadata scopes activate the inner-most scope and restore on unmount',
        () {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);

      final outerOwner = 'outer';
      final innerOwner = 'inner';

      coordinator.activate(outerOwner, const WebMetadata(title: 'Outer Page'));
      expect(coordinator.activeMetadata?.title, 'Outer Page');

      coordinator.activate(innerOwner, const WebMetadata(title: 'Inner Modal'));
      expect(coordinator.activeMetadata?.title, 'Inner Modal');
      expect(coordinator.previousMetadata?.title, 'Outer Page');

      coordinator.remove(innerOwner);
      expect(coordinator.activeMetadata?.title, 'Outer Page');
      expect(
          adapter.lastAppliedTags!
              .firstWhere((t) => t.key == 'title')
              .textContent,
          'Outer Page');
    });

    test(
        '5. Restoring previous metadata tracks prior states across multiple operations',
        () {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);

      final page1 = 'page1';
      final page2 = 'page2';
      final page3 = 'page3';

      coordinator.activate(page1, const WebMetadata(title: 'Page 1'));
      coordinator.activate(page2, const WebMetadata(title: 'Page 2'));
      coordinator.activate(page3, const WebMetadata(title: 'Page 3'));

      expect(coordinator.activeMetadata?.title, 'Page 3');

      coordinator.remove(page3);
      expect(coordinator.activeMetadata?.title, 'Page 2');

      coordinator.remove(page2);
      expect(coordinator.activeMetadata?.title, 'Page 1');

      coordinator.remove(page1);
      expect(coordinator.activeMetadata, isNull);
      expect(adapter.cleared, isTrue);
    });

    test('6. Preventing duplicate HTML tags by deterministic tag keys', () {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);

      final owner = Object();
      coordinator.activate(
        owner,
        const WebMetadata(
          title: 'Dedup',
          canonical: 'https://example.com/item',
          robots: 'noindex',
        ),
      );

      final tags = adapter.lastAppliedTags!;
      final keys = tags.map((t) => t.key).toList();
      expect(keys.toSet().length, keys.length,
          reason: 'All keys in rendered tags must be unique');
    });

    test(
        '7. Asynchronous updates from background route cannot overwrite newer active route',
        () {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);

      final routeA = 'routeA';
      final routeB = 'routeB';

      coordinator.activate(routeA, const WebMetadata(title: 'Route A Initial'));
      expect(coordinator.activeMetadata?.title, 'Route A Initial');

      // User navigates to route B
      coordinator.activate(routeB, const WebMetadata(title: 'Route B Active'));
      expect(coordinator.activeMetadata?.title, 'Route B Active');

      // Route A finishes an async operation and calls update
      coordinator.update(routeA, const WebMetadata(title: 'Route A Updated'));

      // Active metadata must STILL be Route B!
      expect(coordinator.activeMetadata?.title, 'Route B Active');
      expect(
          adapter.lastAppliedTags!
              .firstWhere((t) => t.key == 'title')
              .textContent,
          'Route B Active');

      // Now route B is popped (closed)
      coordinator.remove(routeB);

      // Route A is restored with its UPDATED metadata!
      expect(coordinator.activeMetadata?.title, 'Route A Updated');
      expect(
          adapter.lastAppliedTags!
              .firstWhere((t) => t.key == 'title')
              .textContent,
          'Route A Updated');
    });

    test(
        '8. Non-web compatibility: stub adapter is safe no-op on non-web platforms',
        () {
      final stub = createHeadAdapter();
      expect(stub.isSupported, isFalse);
      expect(() => stub.apply([]), returnsNormally);
      expect(() => stub.clear(), returnsNormally);

      final nonWebCoordinator = RuntimeCoordinator(adapter: stub);
      expect(nonWebCoordinator.isSupported, isFalse);
      final owner = Object();
      expect(
          () => nonWebCoordinator.activate(
              owner, const WebMetadata(title: 'NonWeb')),
          returnsNormally);
      expect(nonWebCoordinator.activeMetadata?.title, 'NonWeb');
      expect(
          () => nonWebCoordinator.update(
              owner, const WebMetadata(title: 'NonWeb2')),
          returnsNormally);
      expect(nonWebCoordinator.activeMetadata?.title, 'NonWeb2');
      expect(() => nonWebCoordinator.remove(owner), returnsNormally);
      expect(nonWebCoordinator.activeMetadata, isNull);
      expect(() => nonWebCoordinator.clear(), returnsNormally);
    });
  });

  group('WebHead Widget Lifecycle Integration', () {
    testWidgets(
        '9. Widget mounts, updates metadata on widget configuration changes, and disposes cleanly',
        (tester) async {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);
      RuntimeCoordinator.instance = coordinator;

      await tester.pumpWidget(
        const MaterialApp(
          home: WebHead(
            metadata: WebMetadata(title: 'Initial Title'),
            child: Text('Page 1 Content'),
          ),
        ),
      );

      expect(coordinator.activeMetadata?.title, 'Initial Title');
      expect(
          adapter.lastAppliedTags!
              .firstWhere((t) => t.key == 'title')
              .textContent,
          'Initial Title');

      // Rebuild with updated metadata
      await tester.pumpWidget(
        const MaterialApp(
          home: WebHead(
            metadata: WebMetadata(title: 'Updated Title'),
            child: Text('Page 1 Content'),
          ),
        ),
      );

      expect(coordinator.activeMetadata?.title, 'Updated Title');
      expect(
          adapter.lastAppliedTags!
              .firstWhere((t) => t.key == 'title')
              .textContent,
          'Updated Title');

      // Unmount widget (e.g. navigation away / replace widget)
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox.shrink(),
        ),
      );

      expect(coordinator.activeMetadata, isNull);
      expect(adapter.cleared, isTrue);
    });

    testWidgets(
        '10. Multi-route transitions and Navigator push/pop restore metadata properly',
        (tester) async {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);
      RuntimeCoordinator.instance = coordinator;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => WebHead(
              metadata: const WebMetadata(title: 'Home Page'),
              child: Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WebHead(
                          metadata: WebMetadata(title: 'Detail Page'),
                          child: Scaffold(body: Text('Detail')),
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Detail'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(coordinator.activeMetadata?.title, 'Home Page');

      // Navigate to Detail Page
      await tester.tap(find.text('Go to Detail'));
      await tester.pumpAndSettle();

      expect(coordinator.activeMetadata?.title, 'Detail Page');
      expect(
          adapter.lastAppliedTags!
              .firstWhere((t) => t.key == 'title')
              .textContent,
          'Detail Page');

      // Pop back to Home Page
      Navigator.of(tester.element(find.text('Detail'))).pop();
      await tester.pumpAndSettle();

      expect(coordinator.activeMetadata?.title, 'Home Page');
      expect(
          adapter.lastAppliedTags!
              .firstWhere((t) => t.key == 'title')
              .textContent,
          'Home Page');
    });

    testWidgets('WebHead inactive tab does not take ownership until active',
        (tester) async {
      final adapter = RecordingHeadAdapter();
      final coordinator = RuntimeCoordinator(adapter: adapter);
      RuntimeCoordinator.instance = coordinator;

      bool active = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Column(
                children: [
                  WebHead(
                    active: active,
                    metadata: const WebMetadata(title: 'Tab 1'),
                    child: const Text('Tab 1'),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => active = !active),
                    child: const Text('Toggle Active'),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Initially inactive: not registered
      expect(coordinator.activeMetadata, isNull);

      // Toggle active
      await tester.tap(find.text('Toggle Active'));
      await tester.pumpAndSettle();

      expect(coordinator.activeMetadata?.title, 'Tab 1');

      // Toggle inactive
      await tester.tap(find.text('Toggle Active'));
      await tester.pumpAndSettle();

      expect(coordinator.activeMetadata, isNull);
    });
  });
}
