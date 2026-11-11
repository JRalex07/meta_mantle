import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('Jaspr Parity Acceptance Tests', () {
    const product = ProductItem(
      id: 'PROD-200',
      slug: 'ceramic-teapot',
      name: 'Artisan Terracotta Teapot',
      description: 'Japanese style kyusu ceramic teapot for loose leaf tea.',
      brand: 'Kyoto Crafts',
      price: 65.00,
      currency: 'USD',
      sku: 'TEA-KYO-01',
      category: 'Kitchenware',
      images: ['https://example.com/assets/teapot.jpg'],
      availability: ItemAvailability.inStock,
      variants: [
        ProductVariant(
          sku: 'TEA-KYO-01-M',
          name: 'Medium 500ml',
          price: 65.00,
          availability: ItemAvailability.inStock,
        ),
      ],
      rating: ProductRating(
        ratingValue: 4.9,
        reviewCount: 42,
      ),
      shipping: ShippingDetails(
        shippingRate: 0.00, // Free shipping
        currency: 'USD',
        shippingDestination: 'US',
      ),
      returnPolicy: ReturnPolicy(
        returnPolicyCategory:
            'https://schema.org/MerchantReturnFiniteReturnWindow',
        merchantReturnDays: 30,
      ),
    );

    final metadata = WebMetadata(
      title: product.name,
      description: product.description,
      canonical: 'https://store.example.com/products/${product.slug}/',
      robots: RobotsDirective.indexFollow,
      keywords: 'tea, kyusu, terracotta',
      author: 'Master Potter',
      openGraph: OpenGraph(
        type: OpenGraphType.product,
        title: product.name,
        description: product.description,
        image: product.images.first,
        imageWidth: 1200,
        imageHeight: 630,
        alternateLocales: const ['ja_JP', 'en_GB'],
      ),
      twitter: const TwitterCard(
        card: TwitterCardType.summaryLargeImage,
        site: '@KyotoStore',
      ),
      jsonLd: [
        product.toJsonLd(baseUrl: 'https://store.example.com'),
      ],
    );

    test(
        'Identical Product Route rendered via Native Engine vs Jaspr Adapter produces zero metadata conflicts',
        () {
      // 1. Render through Native MetaMantle Server HTML Engine
      final nativeRoute = MetaRoute<ProductItem>(
        pattern: '/products/:slug',
        dataProvider: MemoryDataProvider<ProductItem>()
          ..set(product.slug, product),
        metadataBuilder: (p, ctx) => metadata,
        htmlBuilder: (p, ctx) => [
          H.article([
            H.h1(p.name),
            H.p(p.description),
            H.p('Price: \$${p.price.toStringAsFixed(2)}'),
          ]),
        ],
      );

      final nativeDoc = HtmlDocument(
        metadata: metadata,
        bodyNodes: nativeRoute.buildHtml(
          product,
          RouteDataContext(path: '/products/ceramic-teapot'),
        ),
      );
      final nativeHtml = nativeDoc.render();

      // 2. Render through Jaspr MetaMantleDocument & MetaMantleHead
      final jasprDoc = MetaMantleDocument(
        metadata: metadata,
        includeFlutterBootstrap: false,
      );
      final jasprHtml = jasprDoc.renderDocumentShell(
        bodyHtml:
            '<article><h1>${product.name}</h1><p>${product.description}</p><p>Price: \$${product.price.toStringAsFixed(2)}</p></article>',
        currentUrl: 'https://store.example.com/products/${product.slug}/',
      );

      // Parse both generated HTML documents
      final nativeDom = html_parser.parse(nativeHtml);
      final jasprDom = html_parser.parse(jasprHtml);

      // Verify Title
      final nativeTitle = nativeDom.querySelector('title')?.text.trim();
      final jasprTitle = jasprDom.querySelector('title')?.text.trim();
      expect(nativeTitle, equals(jasprTitle));
      expect(nativeTitle, equals('Artisan Terracotta Teapot'));

      // Verify Meta Description
      final nativeDesc = nativeDom
          .querySelector('meta[name="description"]')
          ?.attributes['content'];
      final jasprDesc = jasprDom
          .querySelector('meta[name="description"]')
          ?.attributes['content'];
      expect(nativeDesc, equals(jasprDesc));
      expect(nativeDesc, equals(product.description));

      // Verify Canonical Link
      final nativeCanonical =
          nativeDom.querySelector('link[rel="canonical"]')?.attributes['href'];
      final jasprCanonical =
          jasprDom.querySelector('link[rel="canonical"]')?.attributes['href'];
      expect(nativeCanonical, equals(jasprCanonical));
      expect(nativeCanonical,
          equals('https://store.example.com/products/ceramic-teapot/'));

      // Verify Robots Directive
      final nativeRobots =
          nativeDom.querySelector('meta[name="robots"]')?.attributes['content'];
      final jasprRobots =
          jasprDom.querySelector('meta[name="robots"]')?.attributes['content'];
      expect(nativeRobots, equals(jasprRobots));
      expect(nativeRobots, equals('index, follow'));

      // Verify Open Graph Metadata
      final nativeOgTitle = nativeDom
          .querySelector('meta[property="og:title"]')
          ?.attributes['content'];
      final jasprOgTitle = jasprDom
          .querySelector('meta[property="og:title"]')
          ?.attributes['content'];
      expect(nativeOgTitle, equals(jasprOgTitle));

      final nativeOgImage = nativeDom
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];
      final jasprOgImage = jasprDom
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];
      expect(nativeOgImage, equals(jasprOgImage));

      // Verify Twitter Card
      final nativeTwitterCard = nativeDom
          .querySelector('meta[name="twitter:card"]')
          ?.attributes['content'];
      final jasprTwitterCard = jasprDom
          .querySelector('meta[name="twitter:card"]')
          ?.attributes['content'];
      expect(nativeTwitterCard, equals(jasprTwitterCard));
      expect(nativeTwitterCard, equals('summary_large_image'));

      // Verify JSON-LD Structured Data Parity
      final nativeJsonLd = nativeDom
          .querySelector('script[type="application/ld+json"]')
          ?.text
          .trim();
      final jasprJsonLd = jasprDom
          .querySelector('script[type="application/ld+json"]')
          ?.text
          .trim();
      expect(nativeJsonLd, isNotNull);
      expect(jasprJsonLd, isNotNull);

      final nativeJsonObj = json.decode(nativeJsonLd!) as Map<String, dynamic>;
      final jasprJsonObj = json.decode(jasprJsonLd!) as Map<String, dynamic>;
      expect(nativeJsonObj['@type'], equals(jasprJsonObj['@type']));
      expect(nativeJsonObj['name'], equals(jasprJsonObj['name']));
      expect(nativeJsonObj['sku'], equals(jasprJsonObj['sku']));

      // Verify Semantic Body Content
      final nativeH1 = nativeDom.querySelector('h1')?.text.trim();
      final jasprH1 = jasprDom.querySelector('h1')?.text.trim();
      expect(nativeH1, equals(jasprH1));
      expect(nativeH1, equals('Artisan Terracotta Teapot'));
    });

    test(
        'JasprTagDescriptor renders valid HTML component tags without escaping errors',
        () {
      final head = MetaMantleHead(metadata: metadata);
      final descriptors = head.renderDescriptors();

      expect(descriptors.any((d) => d.tag == 'title'), isTrue);
      expect(
          descriptors.any(
              (d) => d.tag == 'meta' && d.attributes['name'] == 'description'),
          isTrue);
      expect(
          descriptors.any(
              (d) => d.tag == 'link' && d.attributes['rel'] == 'canonical'),
          isTrue);
      expect(
          descriptors.any((d) =>
              d.tag == 'script' &&
              d.attributes['type'] == 'application/ld+json'),
          isTrue);

      final titleDescriptor = descriptors.firstWhere((d) => d.tag == 'title');
      expect(titleDescriptor.toHtml(),
          equals('<title>Artisan Terracotta Teapot</title>'));
    });
  });
}
