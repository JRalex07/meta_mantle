import 'package:flutter_test/flutter_test.dart';
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  group('E-Commerce SEO Engine Tests', () {
    test(
        'ProductItem generates Google-compliant Product and AggregateOffer JSON-LD',
        () {
      const product = ProductItem(
        id: 'SKU-RICE-01',
        slug: 'basmati-rice',
        name: 'Organic Basmati Rice',
        description: 'Naturally aged long-grain rice.',
        price: 24.99,
        currency: 'USD',
        brand: 'Himalayan Harvest',
        sku: 'RICE-5KG',
        gtin: '0123456789012',
        category: 'Food, Beverages & Tobacco > Food Items > Grains & Rice',
        images: [
          'https://example.com/rice-front.jpg',
          'https://example.com/rice-back.jpg'
        ],
        availability: ItemAvailability.inStock,
        condition: ItemCondition.newCondition,
        rating: ProductRating(ratingValue: 4.8, reviewCount: 142),
        shipping: ShippingDetails(
          shippingRate: 4.99,
          currency: 'USD',
          shippingDestination: 'US',
          deliveryTimeDays: 2,
        ),
        returnPolicy: ReturnPolicy(merchantReturnDays: 30),
        variants: [
          ProductVariant(sku: 'RICE-1KG', name: '1 kg Bag', price: 9.99),
          ProductVariant(sku: 'RICE-5KG', name: '5 kg Bag', price: 24.99),
          ProductVariant(sku: 'RICE-10KG', name: '10 kg Bag', price: 44.99),
        ],
      );

      final jsonLd = product.toJsonLd(baseUrl: 'https://example.com');
      final data = jsonLd.data;

      expect(data['@type'], equals('ProductGroup'));
      expect(data['name'], equals('Organic Basmati Rice'));
      expect(data['url'], equals('https://example.com/products/basmati-rice/'));
      expect(data['image'], isNotEmpty);

      // AggregateOffer verification
      final offers = data['offers'] as Map<String, dynamic>;
      expect(offers['@type'], equals('AggregateOffer'));
      expect(offers['lowPrice'], equals('9.99'));
      expect(offers['highPrice'], equals('44.99'));
      expect(offers['offerCount'], equals(3));

      final rating = data['aggregateRating'] as Map<String, dynamic>;
      expect(rating['ratingValue'], equals('4.8'));
      expect(rating['reviewCount'], equals(142));
    });

    test('InventoryEventDispatcher executes targeted tag invalidation',
        () async {
      final cache = MemoryCacheStore();
      final dispatcher = InventoryEventDispatcher(cache);

      const event = PriceChanged(
        productId: 'PROD-101',
        slug: 'basmati-rice',
        categorySlug: 'pantry',
        oldPrice: 24.99,
        newPrice: 21.99,
      );

      final invalidatedTags = await dispatcher.dispatch(event);
      expect(invalidatedTags, contains('product:PROD-101'));
      expect(invalidatedTags, contains('product:basmati-rice'));
      expect(invalidatedTags, contains('prices'));
      expect(invalidatedTags, contains('category:pantry'));
    });

    test('FacetedNavPolicy enforces crawl budget and canonicalization rules',
        () {
      const policy = FacetedNavPolicy(
        baseCategoryUrl: 'https://example.com/categories/rice',
        allowedIndexableParams: {'brand'},
        maxFilterParameters: 2,
        noindexPaginationAfterPage: 5,
      );

      // Normal category page -> Index
      final d1 = policy.evaluate({});
      expect(d1.shouldIndex, isTrue);
      expect(d1.canonicalUrl, equals('https://example.com/categories/rice/'));
      expect(d1.robots, contains('index'));

      // Sort parameter -> Noindex
      final d2 = policy.evaluate({'sort': 'price_asc'});
      expect(d2.shouldIndex, isFalse);
      expect(d2.robots, contains('noindex'));

      // Too many combined filters -> Noindex
      final d3 = policy
          .evaluate({'brand': 'royal', 'weight': '5kg', 'origin': 'india'});
      expect(d3.shouldIndex, isFalse);
      expect(d3.robots, contains('noindex'));

      // Deep pagination (> 5) -> Noindex
      final d4 = policy.evaluate({'page': '6'});
      expect(d4.shouldIndex, isFalse);
      expect(d4.robots, contains('noindex'));
    });

    test('MerchantFeedGenerator creates valid Google Merchant XML RSS feed',
        () {
      const generator = MerchantFeedGenerator(
        storeName: 'MetaMantle Store',
        storeUrl: 'https://example.com',
        storeDescription: 'Organic Groceries',
      );

      const product = ProductItem(
        id: 'RICE-01',
        slug: 'basmati-rice',
        name: 'Organic Basmati Rice',
        description: 'Pure aged rice.',
        price: 24.99,
        currency: 'USD',
        brand: 'Nature Choice',
        images: ['https://example.com/rice.jpg'],
        availability: ItemAvailability.inStock,
      );

      final xml = generator.generateXmlFeed([product]);

      expect(
          xml,
          contains(
              '<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">'));
      expect(xml, contains('<g:id>RICE-01</g:id>'));
      expect(xml, contains('<g:title>Organic Basmati Rice</g:title>'));
      expect(xml, contains('<g:price>24.99 USD</g:price>'));
      expect(xml, contains('<g:availability>in_stock</g:availability>'));
    });
  });

  group('Documentation, Publishing & Content Tests', () {
    test('FrontmatterExtractor parses YAML frontmatter and body cleanly', () {
      const content = '''---
title: "Getting Started with MetaMantle"
description: "Comprehensive guide to setting up MetaMantle."
author: "Alex"
tags: "flutter, seo, dart"
---
# Getting Started

Welcome to the MetaMantle documentation.
''';

      const extractor = FrontmatterExtractor();
      final doc = extractor.parse(content);

      expect(doc.title, equals('Getting Started with MetaMantle'));
      expect(doc.description,
          equals('Comprehensive guide to setting up MetaMantle.'));
      expect(doc.author, equals('Alex'));
      expect(doc.tags, equals('flutter, seo, dart'));
      expect(doc.body, contains('# Getting Started'));
    });

    test(
        'DocVersionPolicy canonicalizes older versions to latest and applies noindex',
        () {
      const policy = DocVersionPolicy(
        baseDocsUrl: 'https://example.com/docs',
        latestVersion: 'latest',
        supportedVersions: ['latest', 'v1', 'v2'],
        canonicalizeToLatest: true,
        noindexOlderVersions: true,
      );

      // Latest version -> canonical to self, index
      final dLatest = policy.evaluate('/docs/latest/getting-started');
      expect(dLatest.isLatest, isTrue);
      expect(dLatest.canonicalUrl,
          equals('https://example.com/docs/latest/getting-started/'));
      expect(dLatest.robots, contains('index'));
      expect(dLatest.robots, isNot(contains('noindex')));

      // Older version (v1) -> canonicalizes to latest, noindex
      final dV1 = policy.evaluate('/docs/v1/getting-started');
      expect(dV1.isLatest, isFalse);
      expect(dV1.canonicalUrl,
          equals('https://example.com/docs/latest/getting-started/'));
      expect(dV1.robots, contains('noindex'));
    });

    test('DocSearchIndexer extracts heading hierarchy and generates JSON index',
        () {
      const indexer = DocSearchIndexer();
      const markdown = '''# Architecture Overview
This is the system architecture.

## Runtime Engine
Details about runtime engine.

### DOM Adapter
Details about web DOM interop.
''';

      final entries = indexer.extractEntries(
        pageTitle: 'Architecture',
        pageUrl: 'https://example.com/docs/architecture',
        markdownContent: markdown,
      );

      expect(entries.length, greaterThanOrEqualTo(3));
      expect(entries.first.section, equals('Architecture Overview'));
      expect(entries.last.hierarchy, contains('Architecture Overview'));
      expect(entries.last.hierarchy, contains('Runtime Engine'));

      final jsonOutput = indexer.generateJsonIndex(entries);
      expect(jsonOutput, contains('"Architecture Overview"'));
    });

    test('FeedGenerator emits valid RSS 2.0 and Atom 1.0 feeds', () {
      const feed = FeedGenerator(
        feedTitle: 'MetaMantle Engineering Blog',
        feedUrl: 'https://example.com/blog',
        feedDescription: 'Engineering updates and SEO strategies.',
      );

      final item = FeedItem(
        id: 'post-1',
        title: 'Announcing MetaMantle 0.1.0',
        url: 'https://example.com/blog/announcing-metamantle',
        summary: 'Universal SEO infrastructure for Flutter and Dart.',
        publishedAt: DateTime.utc(2026, 11, 10),
        author: 'MetaMantle Team',
        categories: ['Releases', 'Engineering'],
      );

      final rss = feed.generateRss2([item]);
      expect(
          rss,
          contains(
              '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">'));
      expect(rss, contains('<title>Announcing MetaMantle 0.1.0</title>'));

      final atom = feed.generateAtom([item]);
      expect(atom, contains('<feed xmlns="http://www.w3.org/2005/Atom">'));
      expect(atom, contains('<title>Announcing MetaMantle 0.1.0</title>'));
    });

    test('NewsSitemapGenerator emits Google News sitemap with news tags', () {
      const generator = NewsSitemapGenerator();
      final article = NewsArticleItem(
        loc: 'https://example.com/news/article-1',
        publicationName: 'The Tech Dispatch',
        publicationLanguage: 'en',
        publicationDate: DateTime.utc(2026, 11, 10, 12, 0),
        title: 'Dart Web SEO Framework Released',
        keywords: ['tech', 'flutter', 'dart'],
      );

      final xml = generator.generate([article]);
      expect(
          xml,
          contains(
              'xmlns:news="http://www.google.com/schemas/sitemap-news/0.9"'));
      expect(xml, contains('<news:name>The Tech Dispatch</news:name>'));
      expect(xml,
          contains('<news:title>Dart Web SEO Framework Released</news:title>'));
    });

    test('LlmsTxtGenerator emits valid /llms.txt content', () {
      const gen = LlmsTxtGenerator(
        projectName: 'MetaMantle',
        projectSummary: 'Universal SEO and SSR framework for Dart and Flutter.',
        documentationBaseUrl: 'https://metamantle.alex.runs-on.dev',
      );

      final text = gen.generate(
        pages: [
          (
            title: 'Quickstart',
            path: '/docs/quickstart',
            summary: 'Get started in 5 minutes.'
          ),
          (
            title: 'SSR Engine',
            path: '/docs/ssr',
            summary: 'Server-side rendering guide.'
          ),
        ],
      );

      expect(text, contains('# MetaMantle'));
      expect(
          text,
          contains(
              '[Quickstart](https://metamantle.alex.runs-on.dev/docs/quickstart)'));
    });
  });

  group('SaaS, Multi-Tenancy & Host Security Tests', () {
    test(
        'TenantHostValidator authorizes registered tenant domains and rejects host injection',
        () {
      const tenants = [
        TenantContext(
          tenantId: 'tenant-a',
          name: 'Acme Corp',
          primaryDomain: 'acme.store.com',
          customDomains: ['shop.acme.com'],
        ),
        TenantContext(
          tenantId: 'tenant-b',
          name: 'Beta Global',
          primaryDomain: 'beta.store.com',
        ),
      ];

      const validator = TenantHostValidator(
        tenants: tenants,
        allowedRootDomains: ['store.com'],
      );

      // Valid primary domain
      final t1 = validator.validate('acme.store.com');
      expect(t1.tenantId, equals('tenant-a'));

      // Valid custom domain
      final t2 = validator.validate('shop.acme.com:443');
      expect(t2.tenantId, equals('tenant-a'));

      // Valid subdomain resolution via allowedRootDomains
      final t3 = validator.validate('tenant-b.store.com');
      expect(t3.tenantId, equals('tenant-b'));

      // Host header injection / arbitrary domain attack must throw HostValidationException
      expect(
        () => validator.validate('evil-attacker.com'),
        throwsA(isA<HostValidationException>()),
      );
    });

    test('TenantCachePartitioner builds isolated cache keys and tenant tags',
        () {
      final cache = MemoryCacheStore();
      final partitioner = TenantCachePartitioner(cache);

      final key1 = partitioner.buildKey(
        tenantId: 'tenant-a',
        host: 'shop.acme.com',
        path: '/products/rice',
        locale: 'en',
        currency: 'USD',
      );

      final key2 = partitioner.buildKey(
        tenantId: 'tenant-b',
        host: 'beta.store.com',
        path: '/products/rice',
        locale: 'en',
        currency: 'USD',
      );

      expect(key1, isNot(equals(key2)));
      expect(key1, contains('tenant:tenant-a'));
      expect(key2, contains('tenant:tenant-b'));

      final tags = partitioner.tenantTags('tenant-a', ['catalog', 'products']);
      expect(tags, contains('tenant:tenant-a'));
      expect(tags, contains('tenant:tenant-a:catalog'));
      expect(tags, contains('tenant:tenant-a:products'));
    });
  });

  group('Jaspr Adapter & Industry Profiles Tests', () {
    test('MetaMantleHead and MetaMantleDocument render Jaspr document shell',
        () {
      const metadata = WebMetadata(
        title: 'Jaspr Page',
        description: 'Server rendered page.',
      );

      const doc = MetaMantleDocument(
        metadata: metadata,
        includeFlutterBootstrap: true,
      );

      final html = doc.renderDocumentShell(
        bodyHtml: '<h1>Welcome to Jaspr</h1>',
        currentUrl: '/jaspr',
      );

      expect(html, contains('<div id="jaspr-root">'));
      expect(html, contains('<h1>Welcome to Jaspr</h1>'));
      expect(html, contains('<title>Jaspr Page</title>'));
      expect(html, contains('flutter_bootstrap.js'));
    });

    test('MetaMantleContentAdapter extracts metadata from markdown content',
        () {
      const adapter = MetaMantleContentAdapter();
      const markdown = '''---
title: "Jaspr Content Article"
description: "Integration testing Jaspr Content."
ogImage: "https://example.com/banner.png"
---
# Content Body
''';

      final meta = adapter.extractMetadata(markdownContent: markdown);
      expect(meta.title, equals('Jaspr Content Article'));
      expect(meta.description, equals('Integration testing Jaspr Content.'));
      expect(meta.openGraph?.image, equals('https://example.com/banner.png'));
    });

    test(
        'Industry Profiles (LocalBusiness, JobPosting, Recipe, Course) produce valid JSON-LD',
        () {
      // 1. LocalBusiness
      const biz = LocalBusinessProfile(
        name: 'The Artisan Bakery',
        streetAddress: '123 Main St',
        addressLocality: 'Portland',
        addressRegion: 'OR',
        postalCode: '97201',
        telephone: '+1-503-555-0199',
        priceRange: '\$\$',
      );
      final bizJson = biz.toJsonLd(url: 'https://example.com/bakery');
      expect(bizJson.data['@type'], equals('LocalBusiness'));
      expect(bizJson.data['name'], equals('The Artisan Bakery'));

      // 2. JobPosting
      const job = JobPostingProfile(
        title: 'Senior Flutter Engineer',
        description: 'Lead mobile and web app development.',
        datePosted: '2026-11-10',
        validThrough: '2026-12-31',
        hiringOrganizationName: 'Tech Innovations Inc',
        hiringOrganizationUrl: 'https://techinnovations.example',
        jobLocationCity: 'San Francisco',
        baseSalaryAmount: 165000,
        baseSalaryCurrency: 'USD',
      );
      final jobJson = job.toJsonLd(url: 'https://example.com/jobs/flutter-eng');
      expect(jobJson.data['@type'], equals('JobPosting'));
      expect(jobJson.data['title'], equals('Senior Flutter Engineer'));

      // 3. Recipe
      const recipe = RecipeProfile(
        name: 'Classic Margherita Pizza',
        description: 'Authentic Neapolitan pizza.',
        image: 'https://example.com/pizza.jpg',
        author: 'Chef Mario',
        prepTimeMinutes: 20,
        cookTimeMinutes: 10,
        recipeYield: '4 servings',
        ingredients: [
          'Flour',
          'Water',
          'Yeast',
          'San Marzano Tomatoes',
          'Mozzarella'
        ],
        instructions: ['Knead dough', 'Spread tomato sauce', 'Bake at 500F'],
      );
      final recipeJson =
          recipe.toJsonLd(url: 'https://example.com/recipes/pizza');
      expect(recipeJson.data['@type'], equals('Recipe'));
      expect(recipeJson.data['recipeYield'], equals('4 servings'));

      // 4. Course
      const course = CourseProfile(
        name: 'Advanced Dart & Flutter Web',
        description: 'Master enterprise SSR and SEO in Dart.',
        providerName: 'Dart Academy',
        providerUrl: 'https://dartacademy.example',
        courseCode: 'DART-301',
      );
      final courseJson =
          course.toJsonLd(url: 'https://example.com/courses/dart-301');
      expect(courseJson.data['@type'], equals('Course'));
      expect(courseJson.data['courseCode'], equals('DART-301'));
    });
  });
}
