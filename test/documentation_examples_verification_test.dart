import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meta_mantle/meta_mantle.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

// Example component from QUICK_START.md
class ProductCardDocExample extends StatelessMantleComponent {
  const ProductCardDocExample({
    super.key,
    required this.name,
    required this.price,
    this.onAddToCart,
  });

  final String name;
  final double price;
  final MantleVoidCallback? onAddToCart;

  @override
  MantleNode build(MantleContext context) {
    return MantleArticle(
      title: name,
      children: [
        MantleHeading(name, level: 2),
        MantleText('Price: \$${price.toStringAsFixed(2)}'),
        MantleButton(label: 'Add to Cart', onPressed: onAddToCart),
      ],
    ).toNode(context);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('Documentation Examples Verification', () {
    test(
      'QuickStart Application Entrypoint and Observers compile and execute',
      () {
        final navObserver = MetaMantleNavigatorObserver(
          markReadyOnFirstFrame: true,
          onRouteChanged: (path) {},
        );
        expect(navObserver, isNotNull);

        final goObserver = MetaMantleGoRouterObserver(
          markReadyOnFirstFrame: true,
          onRouteChanged: (path) {},
        );
        expect(goObserver, isNotNull);

        final app = MaterialApp(
          title: 'MetaMantle Universal App',
          navigatorObservers: [navObserver],
          home: const Scaffold(body: Text('Home')),
        );
        expect(app, isNotNull);
      },
    );

    test('Universal Component renders to HTML correctly according to documentation', () {
      const card = ProductCardDocExample(name: 'Basmati Rice', price: 12.99);
      const renderer = MantleServerRenderer();
      final context = MantleNavigationContext(currentPath: '/products/rice');
      final node = card.toNode(context);
      final htmlNode = renderer.render(node);
      final html = htmlNode.toHtml();
      expect(html, contains('<article'));
      expect(html, contains('<h2'));
      expect(html, contains('Basmati Rice</h2>'));
      expect(html, contains('Price: \$12.99'));
      expect(html, contains('<button'));
      expect(html, contains('Add to Cart'));
    });

    test('Metadata and SEO definitions match documentation API contracts', () {
      final metadata = WebMetadata(
        title: 'Documented Product Page',
        description: 'Comprehensive SEO metadata for product documentation.',
        canonical: 'https://example.com/products/basmati-rice',
        openGraph: const OpenGraph(
          title: 'Basmati Rice',
          description: 'Aromatic long-grain rice.',
          type: OpenGraphType.website,
        ),
        twitter: const TwitterCard(
          title: 'Basmati Rice',
          description: 'Aromatic long-grain rice.',
        ),
        jsonLd: [
          JsonLd.product(
            name: 'Basmati Rice',
            image: 'https://example.com/rice.jpg',
            description: 'Premium rice',
            sku: 'RICE-001',
            offers: {
              '@type': 'Offer',
              'price': '12.99',
              'priceCurrency': 'USD',
            },
          ),
        ],
      );

      final doc = HtmlDocument(
        metadata: metadata,
        baseHref: '/',
        bodyNodes: [
          H.div(
            [H.h1('Basmati Rice'), H.p('Price: \$12.99')],
            attrs: {'class': 'container'},
          ),
        ],
      );

      final renderedHtml = doc.render();
      expect(renderedHtml, contains('<title>Documented Product Page</title>'));
      expect(renderedHtml, contains('name="description"'));
      expect(renderedHtml, contains('rel="canonical"'));
      expect(renderedHtml, contains('property="og:title"'));
      expect(renderedHtml, contains('application/ld+json'));
      expect(renderedHtml, contains('Basmati Rice'));
    });

    test(
      'Sitemap generation examples from SITEMAPS.md compile and execute',
      () {
        const generator = SitemapGenerator();
        final entries = [
          const SitemapUrlEntry(
            loc: 'https://example.com/home',
            changeFreq: 'daily',
            priority: 1.0,
          ),
          const SitemapUrlEntry(
            loc: 'https://example.com/about',
            changeFreq: 'monthly',
            priority: 0.8,
          ),
        ];

        final xml = generator.generateUrlset(entries);
        expect(xml, contains('<loc>https://example.com/home</loc>'));
        expect(xml, contains('<changefreq>daily</changefreq>'));
        expect(xml, contains('<priority>1.0</priority>'));

        final files = generator.generateSitemapIndex(
          entries: entries,
          sitemapBaseUrl: 'https://example.com/sitemaps',
        );
        expect(files.containsKey('sitemap.xml'), isTrue);
      },
    );

    test('RenderingStrategy and BuildMode contracts match documentation', () {
      expect(
        RenderingStrategy.values,
        contains(RenderingStrategy.flutterCanvas),
      );
      expect(RenderingStrategy.values, contains(RenderingStrategy.semanticDom));
      expect(
        RenderingStrategy.values,
        contains(RenderingStrategy.domWithFlutterIslands),
      );

      expect(BuildMode.values, contains(BuildMode.metadata));
      expect(BuildMode.values, contains(BuildMode.prerender));
      expect(BuildMode.values, contains(BuildMode.hybrid));
    });
  });
}
