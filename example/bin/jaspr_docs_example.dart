// ignore_for_file: avoid_print
import 'package:meta_mantle/meta_mantle_server.dart';

void main() {
  print('========================================================');
  print(' MetaMantle Jaspr Documentation Portal Example');
  print('========================================================');

  // 1. Documentation Version Policy
  const versionPolicy = DocVersionPolicy(
    baseDocsUrl: 'https://docs.metamantle.dev/docs',
    latestVersion: 'latest',
    supportedVersions: ['latest', 'v1', 'v2', 'v3'],
    canonicalizeToLatest: true,
    noindexOlderVersions: true,
  );

  final evalV1 = versionPolicy.evaluate('/docs/v1/installation');
  print('[Doc Version Routing]');
  print('  Incoming:  /docs/v1/installation');
  print('  Canonical: ${evalV1.canonicalUrl}');
  print('  Robots:    ${evalV1.robots}');
  print('  Is Latest: ${evalV1.isLatest}');

  // 2. Documentation Search Indexer
  const searchIndexer = DocSearchIndexer();
  const sampleMarkdown = '''# Getting Started
MetaMantle enables instant search engine optimization for Flutter Web and Jaspr applications.

## Installation
Add meta_mantle to your pubspec.yaml dependencies.

### Configuration
Configure static routes or server rendering pipelines.
''';

  final entries = searchIndexer.extractEntries(
    pageTitle: 'Getting Started with MetaMantle',
    pageUrl: 'https://docs.metamantle.dev/docs/latest/getting-started',
    markdownContent: sampleMarkdown,
  );

  final searchIndexJson = searchIndexer.generateJsonIndex(entries);
  print('\n[Search Index Generated]');
  print('  Total Index Entries: ${entries.length}');
  print('  Index JSON preview: ${searchIndexJson.substring(0, 150)}...');

  // 3. /llms.txt Generation for AI agent discovery
  const llmsGen = LlmsTxtGenerator(
    projectName: 'MetaMantle Documentation',
    projectSummary: 'The universal SEO, document rendering, and indexing framework for Flutter & Dart.',
    documentationBaseUrl: 'https://docs.metamantle.dev',
  );

  final llmsTxt = llmsGen.generate(
    pages: [
      (
        title: 'Architecture Overview',
        path: '/docs/latest/architecture',
        summary: 'Architecture breakdown of pure-Dart core, runtime engine, and SSR.',
      ),
      (
        title: 'Jaspr Integration',
        path: '/docs/latest/jaspr',
        summary: 'Adapters for Jaspr HTML document head and content injection.',
      ),
    ],
  );

  print('\n[llms.txt Generated]');
  print(llmsTxt);

  // 4. Jaspr Document Shell Rendering
  const jasprDoc = MetaMantleDocument(
    metadata: WebMetadata(
      title: 'Documentation Home',
      description:
          'Official technical guides and API references for MetaMantle.',
      canonical: 'https://docs.metamantle.dev/docs/latest/',
    ),
    includeFlutterBootstrap: false,
  );

  final fullHtml = jasprDoc.renderDocumentShell(
    bodyHtml: '<header><h1>MetaMantle Documentation</h1></header><main><p>Search across docs.</p></main>',
    currentUrl: 'https://docs.metamantle.dev/docs/latest/',
  );

  print('\n[Rendered Jaspr HTML Shell Preview (First 300 chars)]');
  print('${fullHtml.substring(0, 300)}...');
  print('========================================================');
}
