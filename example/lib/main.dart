import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:meta_mantle/meta_mantle.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  MetaMantle.initialize(
    config: const MetaMantleConfig(
      siteName: 'MetaMantle',
      baseUrl: 'https://metamantle.alex.runs-on.dev',
      defaultTitle: 'MetaMantle',
      defaultDescription:
          'Typed metadata management and static SEO framework for Flutter Web.',
      defaultRobots: RobotsDirective.indexFollow,
      titleTemplate: '%s | MetaMantle',
      defaultImage:
          'https://metamantle.alex.runs-on.dev/assets/social-card.png',
      includeCurrentUrlAsCanonical: true,
      themeColor: '#0066cc',
      language: 'en',
    ),
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MetaMantle Store',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      navigatorObservers: [MetaMantleNavigatorObserver()],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return WebHead(
      metadata: WebMetadata(
        title: 'Home',
        description:
            'Shop fresh groceries, daily essentials, and organic produce.',
        canonical: 'https://metamantle.alex.runs-on.dev/',
        keywords: 'groceries, basmati rice, dairy, organic, delivery',
        author: 'MetaMantle Store Team',
        openGraph: const OpenGraph(
          type: OpenGraphType.website,
          image: 'https://metamantle.alex.runs-on.dev/assets/social-card.png',
          imageAlt: 'MetaMantle Store storefront banner',
          imageWidth: 1200,
          imageHeight: 630,
        ),
        twitter: const TwitterCard(
          card: TwitterCardType.summaryLargeImage,
          site: '@MetaMantle',
        ),
        jsonLd: [
          JsonLd.website(
            name: 'MetaMantle Store',
            url: 'https://metamantle.alex.runs-on.dev/',
            description: 'Fresh groceries and daily essentials.',
          ),
          JsonLd.organization(
            name: 'MetaMantle Store Inc.',
            url: 'https://metamantle.alex.runs-on.dev/',
            logo: 'https://metamantle.alex.runs-on.dev/assets/logo.png',
          ),
        ],
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MetaMantle Store'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Welcome to Example Store',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This demo shows live, declarative document head metadata synchronization in Flutter Web, supporting both client-side route changes and static SEO generation.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.info_outline),
                  label: const Text('About Us'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Product (Basmati Rice)'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ProductPage()),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Blog Article'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BlogPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const MetadataInspector(),
          ],
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WebHead(
      metadata: const WebMetadata(
        title: 'About Us',
        description:
            'Learn about MetaMantle, its features, architecture and tools for managing Flutter Web metadata and SEO.',
        canonical: 'https://metamantle.alex.runs-on.dev/about/',
        alternates: [
          AlternateUrl(
              language: 'hi',
              url: 'https://metamantle.alex.runs-on.dev/hi/about/'),
          AlternateUrl(
              language: 'es',
              url: 'https://metamantle.alex.runs-on.dev/es/about/'),
        ],
        openGraph: OpenGraph(
          type: OpenGraphType.article,
          title: 'About MetaMantle',
          description:
              'Learn about MetaMantle, its features, architecture and tools for managing Flutter Web metadata and SEO.',
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('About Us')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Our Mission',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'We connect consumers directly with sustainable organic producers. Notice how the page title, description, and canonical hreflang alternate links updated automatically.',
              ),
              const SizedBox(height: 24),
              const MetadataInspector(),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WebHead(
      metadata: WebMetadata(
        title: 'Premium Basmati Rice (5kg)',
        description:
            'Aged long-grain aromatic basmati rice for gourmet dining.',
        canonical: 'https://metamantle.alex.runs-on.dev/products/basmati-rice/',
        openGraph: const OpenGraph(
          type: OpenGraphType.product,
          image: 'https://metamantle.alex.runs-on.dev/assets/basmati-rice.png',
          imageAlt: '5kg pack of aged basmati rice',
          imageWidth: 800,
          imageHeight: 800,
        ),
        twitter: const TwitterCard(
          card: TwitterCardType.summaryLargeImage,
          image: 'https://metamantle.alex.runs-on.dev/assets/basmati-rice.png',
        ),
        jsonLd: [
          JsonLd.product(
            name: 'Premium Basmati Rice',
            image:
                'https://metamantle.alex.runs-on.dev/assets/basmati-rice.png',
            description: 'Long-grain premium basmati rice.',
            sku: 'RICE-001',
            brand: 'Himalayan Harvest',
            offers: {
              '@type': 'Offer',
              'price': '24.99',
              'priceCurrency': 'USD',
              'availability': 'https://schema.org/InStock',
            },
          ),
        ],
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Product Detail')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Premium Basmati Rice (5kg)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('\$24.99 — In Stock'),
            const SizedBox(height: 16),
            const Text(
              'Aged for two years to yield fragrant, slender, non-sticky grains. Perfect for biryani and pilaf.',
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.reviews_outlined),
              label: const Text('Open Reviews (Nested WebHead Scope)'),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const NestedReviewsSheet(),
                );
              },
            ),
            const SizedBox(height: 24),
            const MetadataInspector(),
          ],
        ),
      ),
    );
  }
}

class NestedReviewsSheet extends StatelessWidget {
  const NestedReviewsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return WebHead(
      metadata: const WebMetadata(
        title: 'Customer Reviews - Premium Basmati Rice',
        description: 'Read verified customer reviews for Premium Basmati Rice.',
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Reviews (Nested Scope Active)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'While this modal is open, its metadata scope overrides the product page. Closing it will automatically restore the product page metadata.',
            ),
            const SizedBox(height: 16),
            const MetadataInspector(),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close Modal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlogPage extends StatelessWidget {
  const BlogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WebHead(
      metadata: WebMetadata(
        title: 'How to Cook Fluffy Basmati Rice',
        description:
            'Step-by-step master guide to cooking fluffy, long-grain basmati rice.',
        canonical:
            'https://metamantle.alex.runs-on.dev/blog/cook-fluffy-basmati-rice/',
        author: 'Chef Antonio',
        publisher: 'MetaMantle Store Culinary Team',
        openGraph: const OpenGraph(
          type: OpenGraphType.article,
          title: 'How to Cook Fluffy Basmati Rice',
          image: 'https://metamantle.alex.runs-on.dev/assets/cooking-rice.png',
        ),
        jsonLd: [
          JsonLd.article(
            headline: 'How to Cook Fluffy Basmati Rice',
            image:
                'https://metamantle.alex.runs-on.dev/assets/cooking-rice.png',
            datePublished: '2026-02-15T08:00:00+00:00',
            dateModified: '2026-03-01T12:00:00+00:00',
            author: 'Chef Antonio',
            publisher: 'MetaMantle Store',
          ),
        ],
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Cooking Blog')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How to Cook Fluffy Basmati Rice',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('By Chef Antonio • Published Feb 15, 2026'),
              const SizedBox(height: 16),
              const Text(
                'Rinse gently until water runs clear. Soak for 30 minutes, then cook in boiling salted water for exactly 8 minutes.',
              ),
              const SizedBox(height: 24),
              const MetadataInspector(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A developer debug panel displaying the live metadata state.
class MetadataInspector extends StatefulWidget {
  const MetadataInspector({super.key});

  @override
  State<MetadataInspector> createState() => _MetadataInspectorState();
}

class _MetadataInspectorState extends State<MetadataInspector> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final active = MetaMantle.activeMetadata;
    final config = MetaMantle.config;

    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Live Metadata Inspector',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Hide Details' : 'Show Details'),
                ),
              ],
            ),
            if (_expanded) ...[
              const Divider(),
              _buildRow('Active Title', active?.title ?? '(None)'),
              _buildRow('Resolved Site', config.siteName ?? '(None)'),
              _buildRow('Description', active?.description ?? '(None)'),
              _buildRow('Canonical URL', active?.canonical ?? '(Auto)'),
              _buildRow('OG Type', active?.openGraph?.type ?? '(None)'),
              _buildRow('OG Image', active?.openGraph?.image ?? '(None)'),
              _buildRow('Twitter Card', active?.twitter?.card ?? '(None)'),
              _buildRow(
                  'JSON-LD Schemas', '${active?.jsonLd.length ?? 0} active'),
              _buildRow('Generation Token', '${MetaMantle.generationToken}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      MetaMantle.setTitle('Emergency Maintenance Mode');
                      setState(() {});
                    },
                    child: const Text('Test Imperative Title'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      MetaMantle.clearUpdate();
                      setState(() {});
                    },
                    child: const Text('Clear Imperative'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
