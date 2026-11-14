import 'package:meta_mantle/meta_mantle_builder.dart';
import 'package:meta_mantle/meta_mantle_universal.dart';

/// Navigation items shared across all universal pages.
const _navItems = <MantleNavigationItem>[
  MantleNavigationItem(icon: MantleIcon('home'), label: 'Home', route: '/'),
  MantleNavigationItem(
    icon: MantleIcon('info'),
    label: 'About',
    route: '/about',
  ),
  MantleNavigationItem(
    icon: MantleIcon('shopping_bag'),
    label: 'Products',
    route: '/products',
  ),
  MantleNavigationItem(icon: MantleIcon('help'), label: 'FAQ', route: '/faq'),
];

/// Product item data model for consumer route generation.
class StoreProduct {
  const StoreProduct({
    required this.slug,
    required this.name,
    required this.description,
    required this.image,
    required this.sku,
    required this.price,
    required this.category,
  });

  final String slug;
  final String name;
  final String description;
  final String image;
  final String sku;
  final double price;
  final String category;

  factory StoreProduct.fromJson(Map<String, Object?> json) {
    return StoreProduct(
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      image: json['image'] as String,
      sku: json['sku'] as String,
      price: double.tryParse(json['price']?.toString() ?? '19.99') ?? 19.99,
      category: (json['category'] as String?) ?? 'Groceries',
    );
  }
}

/// In-memory product catalogue matching products.json.
final storeProducts = <StoreProduct>[
  const StoreProduct(
    slug: 'basmati-rice',
    name: 'Premium Basmati Rice',
    description: 'Long-grain fragrant Himalayan basmati rice harvested and aged for 2 years.',
    image: 'https://metamantle.alex.runs-on.dev/assets/basmati-rice.png',
    sku: 'RICE-001',
    price: 24.99,
    category: 'Pantry',
  ),
  const StoreProduct(
    slug: 'whole-milk',
    name: 'Whole Milk',
    description: 'Fresh organic whole milk from pasture-raised cows, delivered chilled in glass bottles.',
    image: 'https://metamantle.alex.runs-on.dev/assets/whole-milk.png',
    sku: 'DAIRY-004',
    price: 4.49,
    category: 'Dairy',
  ),
];

/// Builds Home Page universal component tree.
MantleComponent buildHomePage() {
  return const MantlePage(
    padding: MantleEdgeInsets.all(24),
    children: [
      MantleNavigation(items: _navItems),
      MantleSizedBox(height: 24),
      MantleHeading('Fresh Groceries & Farm Essentials', level: 1),
      MantleSizedBox(height: 8),
      MantleText(
        'Shop sustainably sourced groceries, aged grains, and dairy delivered chilled to your doorstep.',
      ),
      MantleSizedBox(height: 16),
      MantleImage(
        src: 'https://metamantle.alex.runs-on.dev/assets/social-card.png',
        alt: 'MetaMantle Store Featured Banner',
        width: 800,
        height: 350,
      ),
      MantleSizedBox(height: 24),
      MantleHeading('Why Choose MetaMantle Store?', level: 2),
      MantleList(
        children: [
          MantleListItem(
            child: MantleText('100% Certified Organic & Non-GMO produce'),
          ),
          MantleListItem(
            child: MantleText(
              'Zero-waste packaging and returnable glass bottles',
            ),
          ),
          MantleListItem(
            child: MantleText(
              'Universal Dart rendering with instant first-contentful paint',
            ),
          ),
        ],
      ),
      MantleSizedBox(height: 24),
      MantleLink(href: '/products', label: 'Browse Full Catalog →'),
    ],
  );
}

/// Builds About Page universal component tree.
MantleComponent buildAboutPage() {
  return const MantlePage(
    padding: MantleEdgeInsets.all(24),
    children: [
      MantleNavigation(items: _navItems),
      MantleSizedBox(height: 16),
      MantleBreadcrumb(
        items: [
          MantleBreadcrumbItem(label: 'Home', href: '/'),
          MantleBreadcrumbItem(label: 'About', isCurrent: true),
        ],
      ),
      MantleSizedBox(height: 16),
      MantleArticle(
        title: 'About MetaMantle Store',
        author: 'MetaMantle Engineering & Operations',
        publishedDate: '2026-11-13',
        children: [
          MantleText(
            'MetaMantle Store is an end-to-end reference application demonstrating universal Dart rendering, instant static SEO pre-rendering, and seamless Flutter Web client coordination.',
          ),
          MantleHeading('Our Mission', level: 2),
          MantleText(
            'We prove that Flutter developers do not have to compromise between rich cross-platform UI and world-class SEO. Portable components render to HTML on the server and Flutter widgets in the app.',
          ),
          MantleHeading('Infrastructure Highlights', level: 2),
          MantleList(
            children: [
              MantleListItem(
                child: MantleText(
                  'Content-addressed artifact caching and versioned manifests',
                ),
              ),
              MantleListItem(
                child: MantleText(
                  'Incremental Static Regeneration (ISR) with worker fencing',
                ),
              ),
              MantleListItem(
                child: MantleText(
                  'Zero-FOUC Flutter bootstrap client readiness synchronization',
                ),
              ),
            ],
          ),
          MantleSizedBox(height: 16),
          MantleLink(href: '/', label: '← Return to Store Home'),
        ],
      ),
    ],
  );
}

/// Builds Product Catalog universal component tree.
MantleComponent buildProductsPage() {
  return const MantlePage(
    padding: MantleEdgeInsets.all(24),
    children: [
      MantleNavigation(items: _navItems),
      MantleSizedBox(height: 16),
      MantleBreadcrumb(
        items: [
          MantleBreadcrumbItem(label: 'Home', href: '/'),
          MantleBreadcrumbItem(label: 'Products', isCurrent: true),
        ],
      ),
      MantleSizedBox(height: 16),
      MantleHeading('Featured Grocery Catalog', level: 1),
      MantleSizedBox(height: 8),
      MantleText(
        'Explore our daily curated selections of farm-fresh essentials.',
      ),
      MantleSizedBox(height: 24),
      MantleTable(
        caption: 'Pantry & Dairy Inventory',
        headers: [
          MantleTableCell.header(child: MantleText('Item Name')),
          MantleTableCell.header(child: MantleText('Category')),
          MantleTableCell.header(child: MantleText('SKU')),
          MantleTableCell.header(child: MantleText('Price')),
          MantleTableCell.header(child: MantleText('Details')),
        ],
        rows: [
          MantleTableRow(
            cells: [
              MantleTableCell(child: MantleText('Premium Basmati Rice')),
              MantleTableCell(child: MantleText('Pantry')),
              MantleTableCell(child: MantleText('RICE-001')),
              MantleTableCell(child: MantleText('\$24.99')),
              MantleTableCell(
                child: MantleLink(
                  href: '/products/basmati-rice',
                  label: 'View Product →',
                ),
              ),
            ],
          ),
          MantleTableRow(
            cells: [
              MantleTableCell(child: MantleText('Whole Milk')),
              MantleTableCell(child: MantleText('Dairy')),
              MantleTableCell(child: MantleText('DAIRY-004')),
              MantleTableCell(child: MantleText('\$4.49')),
              MantleTableCell(
                child: MantleLink(
                  href: '/products/whole-milk',
                  label: 'View Product →',
                ),
              ),
            ],
          ),
        ],
      ),
      MantleSizedBox(height: 24),
      MantleLink(href: '/', label: '← Return to Home'),
    ],
  );
}

/// Builds FAQ Page universal component tree.
MantleComponent buildFaqPage() {
  return const MantlePage(
    padding: MantleEdgeInsets.all(24),
    children: [
      MantleNavigation(items: _navItems),
      MantleSizedBox(height: 16),
      MantleBreadcrumb(
        items: [
          MantleBreadcrumbItem(label: 'Home', href: '/'),
          MantleBreadcrumbItem(label: 'FAQ', isCurrent: true),
        ],
      ),
      MantleSizedBox(height: 16),
      MantleHeading('Frequently Asked Questions', level: 1),
      MantleSizedBox(height: 16),
      MantleDetails(
        summary: MantleText('How does MetaMantle static rendering work?'),
        content: MantleText(
          'MetaMantle compiles your universal MantleComponent tree directly into semantic HTML at build time, ensuring search engines index your exact content.',
        ),
        open: true,
      ),
      MantleDetails(
        summary: MantleText(
          'Does the user experience flash-of-unstyled-content (FOUC)?',
        ),
        content: MantleText(
          'No. MetaMantle injects CSS and coordinates with Flutter bootstrap so the static snapshot smoothly fades out only after Flutter renders its first frame.',
        ),
      ),
      MantleDetails(
        summary: MantleText('Can I deep-link directly into sub-routes?'),
        content: MantleText(
          'Yes. Every static route has its own index.html with accurate metadata, structured schema, and initial body HTML.',
        ),
      ),
      MantleSizedBox(height: 24),
      MantleLink(href: '/', label: '← Return to Home'),
    ],
  );
}

/// Builds a dynamic Product Detail Page universal component tree.
MantleComponent buildProductDetailPage(StoreProduct product) {
  return MantlePage(
    padding: const MantleEdgeInsets.all(24),
    children: [
      const MantleNavigation(items: _navItems),
      const MantleSizedBox(height: 16),
      MantleBreadcrumb(
        items: [
          const MantleBreadcrumbItem(label: 'Home', href: '/'),
          const MantleBreadcrumbItem(label: 'Products', href: '/products'),
          MantleBreadcrumbItem(label: product.name, isCurrent: true),
        ],
      ),
      const MantleSizedBox(height: 24),
      MantleProduct(
        name: product.name,
        description: product.description,
        imageUrl: product.image,
        sku: product.sku,
        price: product.price,
        action: const MantleRow(
          children: [
            MantleButton(label: 'Add to Cart', color: MantleColor.blue),
            MantleSizedBox(width: 16),
            MantleLink(href: '/products', label: 'Back to Catalog'),
          ],
        ),
      ),
    ],
  );
}

/// The official application route manifest.
final metaMantleRoutes = StaticRouteManifest(
  routes: [
    StaticRoute(
      path: '/',
      metadata: WebMetadata(
        title: 'MetaMantle Store - Home',
        description: 'Shop fresh groceries, daily essentials, and organic produce online.',
        canonical: 'https://metamantle.alex.runs-on.dev/',
        keywords: 'groceries, basmati rice, dairy, organic, delivery',
        openGraph: const OpenGraph(
          type: OpenGraphType.website,
          image: 'https://metamantle.alex.runs-on.dev/assets/social-card.png',
        ),
        jsonLd: [
          JsonLd.website(
            name: 'MetaMantle Store',
            url: 'https://metamantle.alex.runs-on.dev/',
          ),
        ],
      ),
      component: buildHomePage(),
    ),
    StaticRoute(
      path: '/about',
      metadata: const WebMetadata(
        title: 'About Us | MetaMantle Store',
        description: 'Learn about MetaMantle Store, our organic farming mission, and universal Dart architecture.',
        canonical: 'https://metamantle.alex.runs-on.dev/about',
      ),
      component: buildAboutPage(),
    ),
    StaticRoute(
      path: '/products',
      metadata: const WebMetadata(
        title: 'Product Catalog | MetaMantle Store',
        description: 'Browse our full catalog of organic grains, whole milk, and pantry staples.',
        canonical: 'https://metamantle.alex.runs-on.dev/products',
      ),
      component: buildProductsPage(),
    ),
    StaticRoute(
      path: '/faq',
      metadata: const WebMetadata(
        title: 'Frequently Asked Questions | MetaMantle Store',
        description: 'Answers to common questions regarding delivery, organic standards, and static rendering.',
        canonical: 'https://metamantle.alex.runs-on.dev/faq',
      ),
      component: buildFaqPage(),
    ),
  ],
  patterns: [
    StaticRoutePattern<StoreProduct>(
      path: '/products/:slug',
      items: storeProducts,
      slugExtractor: (p) => p.slug,
      metadataBuilder: (p) => WebMetadata(
        title: '${p.name} | MetaMantle Store',
        description: p.description,
        canonical: 'https://metamantle.alex.runs-on.dev/products/${p.slug}',
        openGraph: OpenGraph(type: OpenGraphType.article, image: p.image),
        jsonLd: [
          JsonLd.product(
            name: p.name,
            description: p.description,
            image: p.image,
            sku: p.sku,
            offers: {
              '@type': 'Offer',
              'price': p.price.toString(),
              'priceCurrency': 'USD',
              'availability': 'https://schema.org/InStock',
            },
          ),
        ],
      ),
      componentBuilder: (p, ctx) => buildProductDetailPage(p),
    ),
  ],
);

/// CLI and standalone runner entrypoint.
void main(List<String> args) => runStaticManifest(metaMantleRoutes, args);
