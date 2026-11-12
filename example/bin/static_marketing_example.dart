// ignore_for_file: avoid_print
import 'dart:io';

import 'package:meta_mantle/meta_mantle_server.dart';
import 'package:meta_mantle/src/builder/static_head_builder.dart';
import 'package:meta_mantle/src/builder/static_head_config.dart';

void main() async {
  print('========================================================');
  print(' MetaMantle Static Marketing Site Generation Example');
  print('========================================================');

  final tempInputDir = Directory.systemTemp.createTempSync('metamantle_input_');
  final tempOutputDir = Directory.systemTemp.createTempSync('metamantle_dist_');

  final webIndexFile = File('${tempInputDir.path}/index.html');
  webIndexFile.writeAsStringSync('''<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <title>Default App</title>
</head>
<body>
  <div id="flutter_container">Loading Application...</div>
  <script src="flutter_bootstrap.js"></script>
</body>
</html>''');

  final config = StaticHeadConfig(
    baseUrl: 'https://metamantle.dev',
    siteName: 'MetaMantle',
    titleTemplate: '%s | MetaMantle',
    routes: [
      StaticRoute(
        path: '/',
        metadata: WebMetadata(
          title: 'Enterprise Head Management for Flutter Web',
          description: 'Eliminate blank social previews, crawler indexing drops, and head desynchronization.',
          canonical: 'https://metamantle.dev/',
          openGraph: const OpenGraph(
            type: OpenGraphType.website,
            title: 'MetaMantle — Flutter Web SEO Platform',
            description: 'Universal head management and SEO for Flutter.',
            image: 'https://metamantle.dev/og/home.png',
          ),
          twitter: const TwitterCard(
            card: TwitterCardType.summaryLargeImage,
            site: '@MetaMantle',
          ),
          jsonLd: [
            JsonLd.website(name: 'MetaMantle', url: 'https://metamantle.dev'),
          ],
        ),
      ),
      StaticRoute(
        path: '/pricing',
        metadata: const WebMetadata(
          title: 'Transparent Pricing for Growing Teams',
          description:
              'Start free with open source or scale with enterprise support.',
          canonical: 'https://metamantle.dev/pricing/',
          openGraph: OpenGraph(
            type: OpenGraphType.website,
            title: 'Pricing Plans | MetaMantle',
            description: 'Compare community and enterprise plans.',
            image: 'https://metamantle.dev/og/pricing.png',
          ),
        ),
      ),
      StaticRoute(
        path: '/faq',
        metadata: WebMetadata(
          title: 'Frequently Asked Questions',
          description:
              'Common questions about Flutter Web SEO and metadata management.',
          canonical: 'https://metamantle.dev/faq/',
          jsonLd: [
            JsonLd.faqPage([
              (
                question: 'Does Flutter Web work with Googlebot?',
                answer: 'Yes, but MetaMantle provides static prerendering and SSR for instant indexing without client execution delays.',
              ),
              (
                question: 'Can I use MetaMantle with Jaspr and Dart Shelf?',
                answer: 'Yes, MetaMantle includes first-class universal adapters for Shelf and Jaspr.',
              ),
            ]),
          ],
        ),
      ),
    ],
  );

  const builder = StaticHeadBuilder();
  final result = await builder.build(
    inputDirectory: tempInputDir,
    outputDirectory: tempOutputDir,
    config: config,
    strict: true,
  );

  print('Static Generation Complete!');
  print('Generated Files Count: ${result.generatedFiles.length}');
  print('Routes Processed:      ${result.routes}');
  print(
    'Warnings:              ${result.warnings.isEmpty ? "None" : result.warnings}',
  );

  for (final file in result.generatedFiles) {
    print(
      ' - Generated: ${file.path.split(Platform.pathSeparator).last} (${await file.length()} bytes)',
    );
  }

  // Cleanup temporary demo directories
  tempInputDir.deleteSync(recursive: true);
  tempOutputDir.deleteSync(recursive: true);
  print('========================================================');
}
