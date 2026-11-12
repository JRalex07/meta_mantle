// ignore_for_file: avoid_print
import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

/// End-to-end runnable sample demonstrating MetaMantle's Universal Component Model.
///
/// Same application definition can be:
/// 1. Rendered on server to SEO-ready semantic HTML with Schema.org & OpenGraph.
/// 2. Rendered as native Flutter Widgets for Desktop, Mobile, and Web CanvasKit/Skwasm.
/// 3. Rendered directly to real browser DOM elements via package:web.
void main() {
  print('================================================================');
  print(' MetaMantle Universal Component & Multi-Target Rendering Demo ');
  print('================================================================\n');

  // 1. Define shared portable application and route hierarchy
  final app = MantleApp(
    title: 'MetaMantle Hardware Store',
    initialPath: '/',
    routes: [
      MantleRoute(
        path: '/',
        title: 'Home - Hardware Catalog',
        builder: (ctx) => _buildCatalogPage(ctx),
      ),
      MantleRoute(
        path: '/products/:id',
        title: 'Product Details',
        builder: (ctx) => _buildProductDetailPage(ctx),
      ),
      MantleRoute(
        path: '/about',
        title: 'About MetaMantle',
        builder: (ctx) => _buildAboutPage(ctx),
      ),
    ],
    notFoundBuilder: (ctx) => const MantlePage(
      title: '404 - Not Found',
      children: [
        MantleHeading('Page Not Found', level: 1),
        MantleText('The requested resource does not exist.'),
        MantleRouteLink(path: '/', label: 'Back to Catalog'),
      ],
    ),
  );

  // 2. Multi-Target Rendering Demonstration
  const serverRenderer = MantleServerRenderer();
  const flutterRenderer = MantleFlutterRenderer();
  final router = app.router;

  // Render Route 1: Catalog (SSR)
  print('--- Target 1: Server-Side Rendering (SSR) for Route "/" ---');
  final homeMatch = router.match('/')!;
  final homeContext = MantleNavigationContext(currentPath: '/');
  final homeComponent = homeMatch.build(homeContext);
  final homeNode = homeComponent.toNode(homeContext);

  final homeHtml = serverRenderer.renderDocument(
    homeNode,
    metadata: const WebMetadata(
      title: 'MetaMantle Store - High Performance Developer Hardware',
      description:
          'Universal SEO and SSR framework for Dart and Flutter web apps.',
      canonical: 'https://store.metamantle.dev/',
    ),
    currentUrl: 'https://store.metamantle.dev/',
    stylesheetUrls: ['/assets/styles.css'],
    scriptUrls: ['/assets/bootstrap.js'],
  );
  print('Generated SSR HTML Document (first 600 chars):');
  print(homeHtml.substring(0, homeHtml.length > 600 ? 600 : homeHtml.length));
  print('...\n');

  // Render Route 2: Product Detail (SSR + Parameter Extraction)
  print(
      '--- Target 2: Dynamic Route Parameter Matching for "/products/dev-pro-keyboard" ---');
  final productMatch = router.match('/products/dev-pro-keyboard')!;
  final productContext = MantleNavigationContext(
    currentPath: '/products/dev-pro-keyboard',
    pathParameters: productMatch.pathParameters,
  );
  final productComponent = productMatch.build(productContext);
  final productNode = productComponent.toNode(productContext);

  final productHtml = serverRenderer.renderDocument(
    productNode,
    metadata: WebMetadata(
      title:
          'Product - ${productMatch.pathParameters['id']} | MetaMantle Store',
      description:
          'Ergonomic mechanical keyboard designed for high-throughput coding.',
      canonical:
          'https://store.metamantle.dev/products/${productMatch.pathParameters['id']}',
    ),
  );
  print('Extracted Path Parameters: ${productMatch.pathParameters}');
  print(
      'Generated Product HTML Title tag contained: ${productHtml.contains('<title>Product - dev-pro-keyboard | MetaMantle Store</title>')}');
  print('Contains semantic <button>: ${productHtml.contains('<button')}\n');

  // Render Route 3: Flutter Widget Compilation
  print('--- Target 3: Flutter Widget Tree Compilation ---');
  final flutterWidget = flutterRenderer.render(productNode);
  print(
      'Successfully synthesized Flutter Widget tree: ${flutterWidget.runtimeType}');
  print(
      'Widget is ready for native Android/iOS/Desktop/Flutter Web execution!\n');

  // 3. Static Site Generation (SSG) Enumeration
  print('--- Target 4: Static Site Generation (SSG) Route Pre-rendering ---');
  final staticRoutes = [
    '/',
    '/products/dev-pro-keyboard',
    '/products/ultra-mouse',
    '/about'
  ];
  for (final path in staticRoutes) {
    final match = router.match(path);
    if (match != null) {
      final ctx = MantleNavigationContext(
          currentPath: path, pathParameters: match.pathParameters);
      final node = match.build(ctx).toNode(ctx);
      final renderedDoc = serverRenderer.renderDocument(node);
      print(
          '  ✓ Pre-rendered SSG document for: $path (${renderedDoc.length} bytes)');
    }
  }

  print('\n[SUCCESS] Universal multi-target execution completed flawlessly.');
}

MantleComponent _buildCatalogPage(MantleContext context) {
  return MantlePage(
    title: 'Hardware Catalog',
    children: [
      const MantleAppBar(title: 'MetaMantle Store'),
      const MantleHeading('Featured Developer Hardware', level: 1),
      const MantleTextField(placeholder: 'Search developer tools...'),
      MantleRow(
        mainAxisAlignment: MantleMainAxisAlignment.spaceBetween,
        children: const [
          MantleContainer(
            width: 280,
            padding: MantleEdgeInsets.all(16),
            child: MantleColumn(
              children: [
                MantleImage(
                    src:
                        'https://images.unsplash.com/photo-1587829741301-dc798b83add3',
                    alt: 'Keyboard'),
                MantleHeading('Mantle Mech Pro', level: 3),
                MantleText('\$179.00 - Split mechanical keyboard'),
                MantleRouteLink(
                    path: '/products/dev-pro-keyboard', label: 'View Details'),
              ],
            ),
          ),
          MantleContainer(
            width: 280,
            padding: MantleEdgeInsets.all(16),
            child: MantleColumn(
              children: [
                MantleImage(
                    src:
                        'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46',
                    alt: 'Mouse'),
                MantleHeading('Precision Mouse', level: 3),
                MantleText('\$89.00 - Wireless ergonomics'),
                MantleRouteLink(
                    path: '/products/ultra-mouse', label: 'View Details'),
              ],
            ),
          ),
        ],
      ),
      const MantleRouteLink(
          path: '/about', label: 'About MetaMantle Architecture'),
    ],
  );
}

MantleComponent _buildProductDetailPage(MantleContext context) {
  final productId = context.pathParameters['id'] ?? 'unknown';
  return MantlePage(
    title: 'Product - $productId',
    children: [
      const MantleAppBar(title: 'MetaMantle Store'),
      MantleRouteLink(path: '/', label: '← Back to Catalog'),
      MantleHeading('Product: $productId', level: 1),
      const MantleText(
          'Engineered specifically for full-stack Dart and Flutter developers.'),
      const MantleButton(
        label: 'Add to Cart',
        color: MantleColor.blue,
      ),
    ],
  );
}

MantleComponent _buildAboutPage(MantleContext context) {
  return const MantlePage(
    title: 'About Architecture',
    children: [
      MantleAppBar(title: 'MetaMantle Store'),
      MantleHeading('Universal Dart Architecture', level: 1),
      MantleText(
          'Write once in MantleComponent, render as native DOM, server HTML, or Flutter Widgets.'),
      MantleRouteLink(path: '/', label: 'Return to Store'),
    ],
  );
}
