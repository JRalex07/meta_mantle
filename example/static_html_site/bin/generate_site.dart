// ignore_for_file: avoid_print
import 'dart:io';

import 'package:meta_mantle/meta_mantle_builder.dart';

void main() async {
  final outputDir = Directory('build/site');
  if (outputDir.existsSync()) {
    outputDir.deleteSync(recursive: true);
  }
  outputDir.createSync(recursive: true);

  const baseUrl = 'https://consumer.example.com';
  const siteConfig = MetaMantleConfig(
    siteName: 'Consumer Static Site',
    titleTemplate: '%s | Consumer Static Site',
    defaultTitle: 'Consumer Static Site',
    defaultDescription:
        'Independent consumer static website built with MetaMantle public API.',
    baseUrl: baseUrl,
    language: 'en',
  );

  final sitemapEntries = <SitemapUrlEntry>[];

  // Common Header & Nav Component
  ElementNode buildHeader(String currentPath) {
    return H.header(
      [
        H.nav(
          [
            H.a(
              '/',
              'Home',
              attrs: {
                'aria-current': currentPath == '/' ? 'page' : 'false',
                'class': currentPath == '/' ? 'nav-link active' : 'nav-link',
              },
            ),
            H.a(
              '/about',
              'About',
              attrs: {
                'aria-current': currentPath == '/about' ? 'page' : 'false',
                'class': currentPath == '/about'
                    ? 'nav-link active'
                    : 'nav-link',
              },
            ),
            H.a(
              '/contact',
              'Contact',
              attrs: {
                'aria-current': currentPath == '/contact' ? 'page' : 'false',
                'class': currentPath == '/contact'
                    ? 'nav-link active'
                    : 'nav-link',
              },
            ),
          ],
          attrs: {'aria-label': 'Main Navigation', 'class': 'site-navigation'},
        ),
      ],
      attrs: {'class': 'site-header'},
    );
  }

  // Common Footer Component
  ElementNode buildFooter() {
    return H.footer(
      [H.p('© 2026 Consumer Static Site. Built with MetaMantle.')],
      attrs: {'class': 'site-footer'},
    );
  }

  // 1. Home Page
  {
    final homeMetadata = WebMetadata(
      title: 'Home',
      description: 'Welcome to the independent consumer demonstration site.',
      canonical: '$baseUrl/',
      jsonLd: [
        JsonLd.organization(
          name: 'Consumer Demo Org',
          url: baseUrl,
          logo: '$baseUrl/assets/logo.png',
        ),
        JsonLd.website(
          name: 'Consumer Static Site',
          url: baseUrl,
          description:
              'A statically generated website verifying MetaMantle public API.',
        ),
      ],
    );

    final homeDoc = HtmlDocument(
      metadata: homeMetadata,
      config: siteConfig,
      bodyNodes: [
        buildHeader('/'),
        H.main(
          [
            H.h1('Fast, Semantic Static Web with MetaMantle'),
            H.p(
              'This website proves that MetaMantle can be consumed purely via its documented public APIs.',
            ),
            H.table(
              headers: ['Feature', 'Public API', 'Conformance'],
              rows: [
                [
                  'Semantic HTML',
                  'H.main, H.nav, H.h1, H.p, H.table',
                  'HTML5 Validated',
                ],
                [
                  'Metadata & SEO',
                  'WebMetadata, MetaMantleConfig',
                  'OpenGraph & Twitter Cards',
                ],
                [
                  'Structured Data',
                  'JsonLd.organization, JsonLd.webSite',
                  'Schema.org JSON-LD',
                ],
                [
                  'Sitemaps',
                  'SitemapGenerator, SitemapUrlEntry',
                  'sitemaps.org Protocol',
                ],
              ],
              attrs: {'class': 'feature-table'},
            ),
          ],
          attrs: {'class': 'site-main'},
        ),
        buildFooter(),
      ],
    );

    final homeFile = File('${outputDir.path}/index.html');
    homeFile.writeAsStringSync(homeDoc.render(currentUrl: '$baseUrl/'));
    sitemapEntries.add(
      SitemapUrlEntry(
        loc: '$baseUrl/',
        changeFreq: 'weekly',
        priority: 1.0,
        lastMod: DateTime.now(),
      ),
    );
  }

  // 2. About Page
  {
    final aboutMetadata = WebMetadata(
      title: 'About Us',
      description: 'Learn more about the architectural independence of MetaMantle consumer sites.',
      canonical: '$baseUrl/about',
      jsonLd: [
        JsonLd.webPage(
          name: 'About Us',
          url: '$baseUrl/about',
          description: 'Architecture and independence verification.',
        ),
      ],
    );

    final aboutDoc = HtmlDocument(
      metadata: aboutMetadata,
      config: siteConfig,
      bodyNodes: [
        buildHeader('/about'),
        H.main(
          [
            H.h1('About Our Architecture'),
            H.p(
              'We verify that public applications never need to import package:meta_mantle/src/...',
            ),
            H.ul([
              H.li('100% Valid HTML5 semantic nodes'),
              H.li('Automated sitemap.xml indexing'),
              H.li('Zero runtime Flutter overhead on pure DOM pages'),
            ]),
          ],
          attrs: {'class': 'site-main'},
        ),
        buildFooter(),
      ],
    );

    final aboutDir = Directory('${outputDir.path}/about');
    aboutDir.createSync(recursive: true);
    final aboutFile = File('${aboutDir.path}/index.html');
    aboutFile.writeAsStringSync(aboutDoc.render(currentUrl: '$baseUrl/about'));
    sitemapEntries.add(
      SitemapUrlEntry(
        loc: '$baseUrl/about',
        changeFreq: 'monthly',
        priority: 0.8,
        lastMod: DateTime.now(),
      ),
    );
  }

  // 3. Contact Page
  {
    final contactMetadata = WebMetadata(
      title: 'Contact',
      description: 'Get in touch with the MetaMantle verification team.',
      canonical: '$baseUrl/contact',
    );

    final contactDoc = HtmlDocument(
      metadata: contactMetadata,
      config: siteConfig,
      bodyNodes: [
        buildHeader('/contact'),
        H.main(
          [
            H.h1('Contact Verification Team'),
            H.p(
              'For issues or feedback regarding the public API, visit the repository on GitHub.',
            ),
            H.a(
              'https://github.com/JRalex07/meta_mantle',
              'GitHub Repository →',
              attrs: {'target': '_blank', 'rel': 'noopener noreferrer'},
            ),
          ],
          attrs: {'class': 'site-main'},
        ),
        buildFooter(),
      ],
    );

    final contactDir = Directory('${outputDir.path}/contact');
    contactDir.createSync(recursive: true);
    final contactFile = File('${contactDir.path}/index.html');
    contactFile.writeAsStringSync(
      contactDoc.render(currentUrl: '$baseUrl/contact'),
    );
    sitemapEntries.add(
      SitemapUrlEntry(
        loc: '$baseUrl/contact',
        changeFreq: 'monthly',
        priority: 0.7,
        lastMod: DateTime.now(),
      ),
    );
  }

  // 4. Generate Sitemap & Robots.txt
  const sitemapGenerator = SitemapGenerator();
  final sitemapXml = sitemapGenerator.generateUrlset(sitemapEntries);
  File('${outputDir.path}/sitemap.xml').writeAsStringSync(sitemapXml);

  final robotsTxt =
      '''User-agent: *
Allow: /
Sitemap: $baseUrl/sitemap.xml
''';
  File('${outputDir.path}/robots.txt').writeAsStringSync(robotsTxt);

  // 5. Strict HTML Validation using MetaMantle HtmlValidator
  final validator = const HtmlValidator();
  final report = await validator.validateDirectory(outputDir, strict: true);

  print('=== Consumer Static Site Generation Complete ===');
  print('Output Directory: ${outputDir.path}');
  print('HTML Files: ${report.totalFiles}');
  print('Validation Errors: ${report.totalErrors}');
  print('Validation Warnings: ${report.totalWarnings}');
  for (final r in report.reports) {
    if (!r.isValid) {
      print('File: ${r.filePath}');
      for (final err in r.errors) {
        print('  - [ERROR] ${err.rule}: ${err.message}');
      }
    }
  }

  if (!report.isSuccessful) {
    print('HTML validation failed!');
    exit(1);
  }
}
