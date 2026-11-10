// ignore_for_file: avoid_print
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  print('========================================================');
  print(' MetaMantle Jaspr + Flutter Embedding Demonstration');
  print('========================================================');

  // Demonstrate rendering a full HTML document that embeds a Flutter Web
  // canvas application with full pre-rendered SEO head, fallback HTML content
  // for non-JS web crawlers, and Flutter bootstrap initialization.

  const document = MetaMantleDocument(
    metadata: WebMetadata(
      title: 'Interactive Dashboard | MetaMantle Analytics',
      description:
          'High-performance interactive financial analytics built with Flutter Web and Jaspr.',
      canonical: 'https://app.metamantle.dev/dashboard/',
      openGraph: OpenGraph(
        type: OpenGraphType.website,
        title: 'MetaMantle Interactive Analytics',
        description:
            'Real-time financial charts and SEO-friendly document shell.',
        image: 'https://app.metamantle.dev/og/dashboard.png',
      ),
      twitter: TwitterCard(
        card: TwitterCardType.summaryLargeImage,
        site: '@MetaMantle',
      ),
    ),
    includeFlutterBootstrap: true,
  );

  final fallbackBodyNodes = [
    H.div([
      H.header([
        H.h1('MetaMantle Real-time Financial Dashboard'),
        H.p('Universal hybrid Jaspr HTML shell with embedded Flutter Web canvas.'),
      ]),
      // Crawler fallback content: crawlers read this immediately without waiting for WebAssembly or Skia canvas initialization
      H.section([
        H.h2('Executive Financial Summary (Server Prerendered)'),
        H.p('Q1 Total Volume: \$4,850,000 | Active Nodes: 1,420 | Uptime: 99.99%'),
        H.table(
          headers: ['Metric', 'Current Period', 'Target'],
          rows: [
            ['Gross Revenue', '\$1,250,000', '\$1,000,000'],
            ['Churn Rate', '0.4%', '< 1.0%'],
            ['Net Margin', '42%', '40%'],
          ],
        ),
      ]),
      // Mounting element for Flutter Web engine
      H.div([], attrs: {'id': 'flutter_app_target'}),
    ]),
  ];

  final bodyMarkup = fallbackBodyNodes.map((n) => n.toHtml()).join('\n');

  final htmlOutput = document.renderDocumentShell(
    bodyHtml: bodyMarkup,
    currentUrl: 'https://app.metamantle.dev/dashboard/',
  );

  print('Generated Hybrid HTML Shell:');
  print(
      '  Contains DOCTYPE:              ${htmlOutput.contains("<!DOCTYPE html>")}');
  print(
      '  Contains OpenGraph Image:      ${htmlOutput.contains("og/dashboard.png")}');
  print(
      '  Contains Prerendered Table:    ${htmlOutput.contains("Executive Financial Summary")}');
  print(
      '  Contains Flutter Bootstrap JS: ${htmlOutput.contains("flutter_bootstrap.js")}');
  print('  HTML Output Size:              ${htmlOutput.length} bytes');
  print('========================================================');
}
