import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

void main() {
  group('Universal Routing & Router Tests', () {
    final routes = [
      MantleRoute(
        path: '/',
        title: 'Home',
        builder: (ctx) => const MantleText('Home Page'),
      ),
      MantleRoute(
        path: '/about',
        title: 'About Us',
        builder: (ctx) => const MantleText('About Page'),
      ),
      MantleRoute(
        path: '/products/:id',
        title: 'Product Details',
        builder: (ctx) => MantleText('Product ${ctx.pathParameters['id']}'),
      ),
      MantleRoute(
        path: '/orgs/:orgId/teams/:teamId',
        builder: (ctx) => MantleText(
          'Org ${ctx.pathParameters['orgId']} Team ${ctx.pathParameters['teamId']}',
        ),
      ),
    ];

    final router = MantleRouter(
      routes: routes,
      notFoundBuilder: (ctx) => const MantleText('Custom 404 Page'),
    );

    test('matches root static route', () {
      final match = router.match('/');
      expect(match, isNotNull);
      expect(match!.route.title, equals('Home'));
      expect(match.path, equals('/'));
      expect(match.pathParameters, isEmpty);
    });

    test('matches nested static route', () {
      final match = router.match('/about');
      expect(match, isNotNull);
      expect(match!.route.title, equals('About Us'));
      expect(match.path, equals('/about'));
    });

    test('matches single parameterized route segment', () {
      final match = router.match('/products/42');
      expect(match, isNotNull);
      expect(match!.pathParameters['id'], equals('42'));
    });

    test('matches multiple parameterized route segments', () {
      final match = router.match('/orgs/alpha/teams/core-dev');
      expect(match, isNotNull);
      expect(match!.pathParameters['orgId'], equals('alpha'));
      expect(match.pathParameters['teamId'], equals('core-dev'));
    });

    test('parses query parameters alongside path matching', () {
      final match = router.match('/products/99?color=blue&size=large');
      expect(match, isNotNull);
      expect(match!.pathParameters['id'], equals('99'));
      expect(match.queryParameters['color'], equals('blue'));
      expect(match.queryParameters['size'], equals('large'));
    });

    test('invokes notFoundBuilder when no route matches', () {
      final match = router.match('/unregistered/route/path');
      expect(match, isNotNull);
      expect(match!.route.title, equals('Not Found'));
      final context =
          MantleNavigationContext(currentPath: '/unregistered/route/path');
      final component = match.build(context);
      expect(component, isA<MantleText>());
    });

    test('returns null when no route matches and notFoundBuilder is null', () {
      final strictRouter = MantleRouter(routes: routes);
      final match = strictRouter.match('/non-existent');
      expect(match, isNull);
    });

    test('MantleApp creates router and provides app configuration', () {
      final app = MantleApp(
        title: 'Universal Portal',
        initialPath: '/',
        routes: routes,
      );

      expect(app.title, equals('Universal Portal'));
      expect(app.initialPath, equals('/'));
      expect(app.router.routes.length, equals(4));
    });

    test('MantleNavigationContext triggers navigation callbacks', () {
      String? navigatedPath;
      Map<String, String>? navigatedQuery;
      var backCalled = false;

      final context = MantleNavigationContext(
        currentPath: '/home',
        onGo: (path, {queryParameters}) {
          navigatedPath = path;
          navigatedQuery = queryParameters;
        },
        onBack: () => backCalled = true,
      );

      context.go('/settings', queryParameters: {'tab': 'security'});
      expect(navigatedPath, equals('/settings'));
      expect(navigatedQuery?['tab'], equals('security'));

      context.back();
      expect(backCalled, isTrue);
    });
  });
}
