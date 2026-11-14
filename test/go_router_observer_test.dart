import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle.dart';

void main() {
  group('MetaMantleGoRouterObserver', () {
    testWidgets('synchronizes route changes and invokes callback', (
      tester,
    ) async {
      String? lastNavigatedPath;
      WebMetadata? appliedMetadata;

      final observer = MetaMantleGoRouterObserver(
        markReadyOnFirstFrame: false,
        onRouteChanged: (path) {
          lastNavigatedPath = path;
        },
        metadataProvider: (route, path) {
          appliedMetadata = WebMetadata(
            title: 'Title for $path',
            description: 'Desc for $path',
          );
          return appliedMetadata;
        },
      );

      final route1 = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => const Text('Home'),
      );
      final route2 = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/details'),
        builder: (_) => const Text('Details'),
      );

      observer.didPush(route1, null);
      expect(lastNavigatedPath, equals('/home'));
      expect(appliedMetadata?.title, equals('Title for /home'));

      observer.didPush(route2, route1);
      expect(lastNavigatedPath, equals('/details'));
      expect(appliedMetadata?.title, equals('Title for /details'));

      observer.didPop(route2, route1);
      expect(lastNavigatedPath, equals('/home'));
      expect(appliedMetadata?.title, equals('Title for /home'));
    });

    testWidgets('supports custom urlExtractor', (tester) async {
      String? lastNavigatedPath;

      final observer = MetaMantleGoRouterObserver(
        markReadyOnFirstFrame: false,
        urlExtractor: (route) => '/custom${route.settings.name}',
        onRouteChanged: (path) {
          lastNavigatedPath = path;
        },
      );

      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/test'),
        builder: (_) => const Text('Test'),
      );

      observer.didPush(route, null);
      expect(lastNavigatedPath, equals('/custom/test'));
    });
  });
}
